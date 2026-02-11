#requires -Version 7.0
<#
Phase 07 — Rename engine
- DryRun: produce rename_plan + rename_collisions + rename_rules evidence (no changes)
- Execute: apply latest Phase 07 DryRun plan (no overwrites) + rollback + rename_executed
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$RunRoot,
  [Parameter(Mandatory=$true)][string]$EvidenceDir,
  [ValidateSet("DryRun","Execute")][string]$Mode = "DryRun"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Log([string]$msg) {
  $ts = (Get-Date).ToString("s")
  Write-Host "[$ts] $msg"
  $runlog = Join-Path $RunRoot "runlog.txt"
  try { Add-Content -LiteralPath $runlog -Value "[$ts] $msg" -Encoding utf8 } catch {}
}

function Fail([string]$msg, [int]$code = 1) {
  Write-Log $msg
  exit $code
}

function Normalize-Path([string]$p) {
  if ([string]::IsNullOrWhiteSpace($p)) { return $p }
  return ([IO.Path]::GetFullPath($p)).TrimEnd('\')
}

function Is-UnderAnyPrefix([string]$path, [string[]]$prefixes) {
  foreach ($pre in $prefixes) {
    if ([string]::IsNullOrWhiteSpace($pre)) { continue }
    $p = Normalize-Path $pre
    if ($path.StartsWith($p, [StringComparison]::OrdinalIgnoreCase)) { return $true }
  }
  return $false
}

function Contains-Any([string]$path, [string[]]$needles) {
  foreach ($n in $needles) {
    if ([string]::IsNullOrWhiteSpace($n)) { continue }
    if ($path -like "*$n*") { return $true }
  }
  return $false
}

function Sanitize-Name([string]$name, $san) {
  $out = $name

  # Replace spaces
  if ($san.replace_spaces_with -ne $null) {
    $out = $out -replace '\s+', [string]$san.replace_spaces_with
  }

  # Replace illegal filename chars
  $illegal = '[<>:"/\\|?*]'
  $rep = [string]$san.illegal_char_replacement
  if ([string]::IsNullOrEmpty($rep)) { $rep = "_" }
  $out = [Regex]::Replace($out, $illegal, $rep)

  # Collapse underscores
  if ($san.collapse_underscores -eq $true) {
    $out = $out -replace '_{2,}', '_'
  }

  # Strip trailing dots/spaces (Windows hates these)
  if ($san.strip_trailing_dots_spaces -eq $true) {
    $out = $out.TrimEnd(' ', '.')
  }

  return $out
}

function Get-DateStampFromFile([System.IO.FileInfo]$fi, [string]$source) {
  $dt = if ($source -eq "CreatedTime") { $fi.CreationTime } else { $fi.LastWriteTime }
  return $dt.ToString("MM-dd-yyyy")
}

function Try-ApplyRules([string]$fileNameNoDir, [System.IO.FileInfo]$fi, $rulesDoc) {
  # Returns: @{ op="RENAME|SKIP_*|COLLISION"; newName="..."; rule="..."; reason="..." }

  $san = $rulesDoc.sanitization
  $rules = $rulesDoc.rules

  $name = $fileNameNoDir
  $ext  = [IO.Path]::GetExtension($name)
  $stem = if ($ext) { $name.Substring(0, $name.Length - $ext.Length) } else { $name }

  # Sanitization pass (does not add dates, just cleans)
  $sanStem = Sanitize-Name $stem $san

  # 1) Pattern-based rules (reformat date already present)
  foreach ($r in $rules) {
    $pat = [string]$r.pattern
    if ([string]::IsNullOrWhiteSpace($pat)) { continue }

    $m = [Regex]::Match($stem, $pat)
    if (-not $m.Success) { continue }

    if ($r.type -eq "skip_if_matches") {
      return @{
        op     = "SKIP_ALREADY_CANONICAL"
        newName= $name
        rule   = $r.id
        reason = "Already matches canonical pattern"
      }
    }

    if ($r.type -eq "rename_reformat_date") {
      $base = $m.Groups["base"].Value
      if ([string]::IsNullOrWhiteSpace($base)) { $base = $sanStem }
      $mm = $m.Groups["mm"].Value
      $dd = $m.Groups["dd"].Value
      $yyyy = $m.Groups["yyyy"].Value
      $newStem = (Sanitize-Name $base $san) + "_$mm-$dd-$yyyy"
      $newName = $newStem + $ext
      if ($newName -eq $name) {
        return @{ op="SKIP_NO_CHANGE"; newName=$name; rule=$r.id; reason="No change after normalization" }
      }
      return @{ op="RENAME"; newName=$newName; rule=$r.id; reason="Reformatted date to MM-DD-YYYY" }
    }
  }

  # 2) No recognized date pattern in filename
  if ($rulesDoc.apply_if_no_date -ne $true) {
    return @{ op="SKIP_NO_DATE"; newName=$name; rule="none"; reason="No date in filename and apply_if_no_date=false" }
  }

  # 3) Apply timestamp-based date suffix
  $dateStamp = Get-DateStampFromFile $fi $rulesDoc.date_source
  $newStem = $sanStem
  if (-not $newStem.EndsWith("_$dateStamp")) {
    $newStem = $newStem + "_$dateStamp"
  }

  $newName = $newStem + $ext
  if ($newName -eq $name) {
    return @{ op="SKIP_NO_CHANGE"; newName=$name; rule="timestamp_suffix"; reason="Already matches computed canonical name" }
  }

  return @{
    op     = "RENAME"
    newName= $newName
    rule   = "timestamp_suffix"
    reason = "No date pattern detected; appended $($rulesDoc.date_source) as MM-DD-YYYY"
  }
}

# --- Preflight ---
$RepoRootN = Normalize-Path $RepoRoot
$RunRootN  = Normalize-Path $RunRoot

if (-not (Test-Path -LiteralPath $RunRootN -PathType Container)) { Fail "FAIL: RunRoot missing: $RunRootN" 2 }
if (-not (Test-Path -LiteralPath $EvidenceDir -PathType Container)) { Fail "FAIL: EvidenceDir missing: $EvidenceDir" 3 }

# Load rules (JSON content in .yaml)
$rulesPath = Join-Path $RepoRootN "SRC\rules\rename_rules_v1.yaml"
if (-not (Test-Path -LiteralPath $rulesPath -PathType Leaf)) {
  Fail "FAIL: Missing rules file: $rulesPath (create SRC\rules\rename_rules_v1.yaml first)" 4
}

$rulesText = Get-Content -LiteralPath $rulesPath -Raw
try {
  $rulesDoc = $rulesText | ConvertFrom-Json
} catch {
  Fail "FAIL: rename_rules_v1.yaml is not parseable JSON (JSON is valid YAML; keep it JSON-shaped). $_" 5
}

# Enforce repo self-protection (append to exclude_contains; RepoRoot guard is in scan loop)
$rulesDoc.scope.exclude_contains += "\RH_MIGRATION_2026_V2\"

# Evidence filenames
$stamp = Get-Date -Format "MM-dd-yyyy_HHmmss"
$rulesEvTs = Join-Path $EvidenceDir "rename_rules_v1_$stamp.yaml"
$rulesEv   = Join-Path $EvidenceDir "rename_rules_v1.yaml"
$planTs    = Join-Path $EvidenceDir "rename_plan_$stamp.csv"
$plan      = Join-Path $EvidenceDir "rename_plan.csv"
$execTs    = Join-Path $EvidenceDir "rename_executed_$stamp.csv"
$exec      = Join-Path $EvidenceDir "rename_executed.csv"
$colTs     = Join-Path $EvidenceDir "rename_collisions_$stamp.csv"
$col       = Join-Path $EvidenceDir "rename_collisions.csv"

# Copy rules into evidence
Copy-Item -LiteralPath $rulesPath -Destination $rulesEvTs -Force
Copy-Item -LiteralPath $rulesPath -Destination $rulesEv -Force

# CSV headers
"action_id,op,src_path,dst_path,rule_id,reason" | Out-File -LiteralPath $planTs -Encoding utf8 -NoNewline
"action_id,op,src_path,dst_path,rule_id,reason,at" | Out-File -LiteralPath $execTs -Encoding utf8 -NoNewline
"action_id,src_path,dst_path,rule_id,reason" | Out-File -LiteralPath $colTs -Encoding utf8 -NoNewline

# Helper: write row safely
function CsvEscape([string]$s) {
  if ($s -eq $null) { return "" }
  $t = $s.Replace('"','""')
  return '"' + $t + '"'
}
function Add-PlanRow($row) {
  $line = "`n$($row.action_id),$($row.op),$(CsvEscape $row.src_path),$(CsvEscape $row.dst_path),$(CsvEscape $row.rule_id),$(CsvEscape $row.reason)"
  Add-Content -LiteralPath $planTs -Value $line -Encoding utf8
}
function Add-ColRow($row) {
  $line = "`n$($row.action_id),$(CsvEscape $row.src_path),$(CsvEscape $row.dst_path),$(CsvEscape $row.rule_id),$(CsvEscape $row.reason)"
  Add-Content -LiteralPath $colTs -Value $line -Encoding utf8
}
function Add-ExecRow($row, [string]$status) {
  $at = (Get-Date).ToString("s")
  $line = "`n$($row.action_id),$status,$(CsvEscape $row.src_path),$(CsvEscape $row.dst_path),$(CsvEscape $row.rule_id),$(CsvEscape $row.reason),$at"
  Add-Content -LiteralPath $execTs -Value $line -Encoding utf8
}

# Locate latest Phase 07 DryRun plan if executing
function Get-LatestPhase07DryRunPlan([string]$repoRoot) {
  $p07Dir = Join-Path $repoRoot "OUTPUTS\phase_07"
  if (-not (Test-Path -LiteralPath $p07Dir -PathType Container)) { return $null }

  $runs = Get-ChildItem -LiteralPath $p07Dir -Directory -Filter "run_*" | Sort-Object LastWriteTime -Descending
  foreach ($r in $runs) {
    $mPath = Join-Path $r.FullName "metrics.json"
    if (-not (Test-Path -LiteralPath $mPath -PathType Leaf)) { continue }
    try {
      $m = (Get-Content -LiteralPath $mPath -Raw) | ConvertFrom-Json
      if ($m.mode -eq "DryRun") {
        $ev = Join-Path $r.FullName "evidence"
        $p = Get-ChildItem -LiteralPath $ev -Filter "rename_plan_*.csv" -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($p) { return $p.FullName }
      }
    } catch { continue }
  }
  return $null
}

# --- Build plan (DryRun) OR load plan (Execute) ---
$planRows = @()
$collisions = @()
$renameCount = 0
$skipCount = 0
$excludedCount = 0

if ($Mode -eq "Execute") {
  $planPath = Get-LatestPhase07DryRunPlan $RepoRootN
  if (-not $planPath) {
    Fail "FAIL: Execute requires an existing Phase 07 DryRun rename_plan_*.csv. Run Phase 07 DryRun first." 6
  }

  Write-Log "Execute mode: loading latest Phase 07 DryRun plan: $planPath"
  $planRows = Import-Csv -LiteralPath $planPath
} else {
  # DryRun: generate plan by scanning include roots
  $include = @($rulesDoc.scope.include_roots | ForEach-Object { Normalize-Path $_ })
  $excludeRoots = @($rulesDoc.scope.exclude_roots | ForEach-Object { Normalize-Path $_ })
  $excludeContains = @($rulesDoc.scope.exclude_contains)
  $excludeExt = @($rulesDoc.scope.exclude_extensions | ForEach-Object { $_.ToLowerInvariant() })
  $excludeNames = @($rulesDoc.scope.exclude_filenames | ForEach-Object { $_.ToLowerInvariant() })

  Write-Log "DryRun: scanning roots: $($include -join ', ')"

  $actionIndex = 0

  foreach ($root in $include) {
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }

    Get-ChildItem -LiteralPath $root -Recurse -Force -File -ErrorAction SilentlyContinue | ForEach-Object {
      $fi = $_
      $full = Normalize-Path $fi.FullName

      # Excluded roots
      if (Is-UnderAnyPrefix $full $excludeRoots) {
        $excludedCount++
        return
      }

      # RepoRoot protection (never rename inside repo)
      if (Is-UnderAnyPrefix $full @($RepoRootN)) {
        $excludedCount++
        return
      }

      # Excluded contains patterns
      if (Contains-Any $full $excludeContains) {
        $excludedCount++
        return
      }

      # Excluded filename / extension
      $leaf = $fi.Name
      if ($excludeNames -contains $leaf.ToLowerInvariant()) {
        $excludedCount++
        return
      }
      $ext = ([IO.Path]::GetExtension($leaf)).ToLowerInvariant()
      if ($excludeExt -contains $ext) {
        $excludedCount++
        return
      }

      $actionIndex++
      $id = ("P07_{0:D6}" -f $actionIndex)

      $res = Try-ApplyRules $leaf $fi $rulesDoc
      $dstName = [string]$res.newName
      $dstFull = Join-Path (Split-Path $full -Parent) $dstName

      # Ensure rename stays in same directory
      if ((Split-Path $dstFull -Parent) -ne (Split-Path $full -Parent)) {
        $skipCount++
        $row = [pscustomobject]@{
          action_id=$id; op="SKIP_INVALID"; src_path=$full; dst_path=$dstFull; rule_id=$res.rule; reason="Rename attempted to change directory (blocked)"
        }
        Add-PlanRow $row
        return
      }

      # If no change
      if ($dstFull -eq $full) {
        $skipCount++
        $row = [pscustomobject]@{
          action_id=$id; op="SKIP_NO_CHANGE"; src_path=$full; dst_path=$dstFull; rule_id=$res.rule; reason=$res.reason
        }
        Add-PlanRow $row
        return
      }

      # Destination exists => collision
      if (Test-Path -LiteralPath $dstFull -PathType Leaf) {
        $row = [pscustomobject]@{
          action_id=$id; op="COLLISION"; src_path=$full; dst_path=$dstFull; rule_id=$res.rule; reason="Destination exists (no overwrite)"
        }
        $collisions += $row
        Add-ColRow $row
        Add-PlanRow $row
        return
      }

      if ($res.op -eq "RENAME") {
        $renameCount++
        $row = [pscustomobject]@{
          action_id=$id; op="RENAME"; src_path=$full; dst_path=$dstFull; rule_id=$res.rule; reason=$res.reason
        }
        Add-PlanRow $row
        return
      }

      # Any other op => skip
      $skipCount++
      $row = [pscustomobject]@{
        action_id=$id; op=$res.op; src_path=$full; dst_path=$dstFull; rule_id=$res.rule; reason=$res.reason
      }
      Add-PlanRow $row
    }
  }

  # Write stable copies
  Copy-Item -LiteralPath $planTs -Destination $plan -Force
  Copy-Item -LiteralPath $colTs  -Destination $col  -Force

  # Metrics
  $metricsPath = Join-Path $RunRootN "metrics.json"
  $metrics = [ordered]@{
    phase = 7
    mode  = $Mode
    plan_rows = ($actionIndex)
    rename_planned = $renameCount
    skipped = $skipCount
    excluded = $excludedCount
    collisions = ($collisions.Count)
    rules_version = $rulesDoc.version
    date_source = $rulesDoc.date_source
    at = (Get-Date).ToString("s")
  }
  ($metrics | ConvertTo-Json -Depth 6) | Out-File -LiteralPath $metricsPath -Encoding utf8

  Write-Log "DryRun complete. rename_planned=$renameCount collisions=$($collisions.Count) skipped=$skipCount excluded=$excludedCount plan_rows=$actionIndex"
  exit 0
}

# --- Execute mode: apply plan rows (from latest DryRun) ---
$rollbackPath = Join-Path $RunRootN "rollback.ps1"
"#!/usr/bin/env pwsh`n# Phase 07 rollback (renames)`n" | Out-File -LiteralPath $rollbackPath -Encoding utf8

$executed = 0
$skippedExec = 0
$errors = 0

foreach ($r in $planRows) {
  $op = [string]$r.op
  $src = Normalize-Path ([string]$r.src_path)
  $dst = Normalize-Path ([string]$r.dst_path)
  $rid = [string]$r.rule_id
  $reason = [string]$r.reason
  $aid = [string]$r.action_id

  if ($op -ne "RENAME") {
    $skippedExec++
    Add-ExecRow $r "SKIPPED"
    continue
  }

  # Hard protections
  if (Is-UnderAnyPrefix $src @($RepoRootN)) {
    $errors++
    Add-ExecRow $r "ERROR_REPO_PROTECTED"
    continue
  }
  if (-not (Test-Path -LiteralPath $src -PathType Leaf)) {
    $errors++
    Add-ExecRow $r "ERROR_SRC_MISSING"
    continue
  }
  if (Test-Path -LiteralPath $dst -PathType Leaf) {
    $skippedExec++
    Add-ExecRow $r "SKIPPED_DEST_EXISTS"
    continue
  }
  if ((Split-Path $src -Parent) -ne (Split-Path $dst -Parent)) {
    $errors++
    Add-ExecRow $r "ERROR_DIR_CHANGE_BLOCKED"
    continue
  }

  try {
    if ($Mode -eq "Execute") {
      Move-Item -LiteralPath $src -Destination $dst -ErrorAction Stop
    }

    # rollback command (reverse move)
    $rb = "Move-Item -LiteralPath $(CsvEscape $dst) -Destination $(CsvEscape $src) -ErrorAction Stop"
    Add-Content -LiteralPath $rollbackPath -Value $rb -Encoding utf8

    $executed++
    Add-ExecRow $r "EXECUTED"
  } catch {
    $errors++
    Add-ExecRow $r ("ERROR_" + $_.Exception.GetType().Name)
  }
}

# Write stable evidence copies
Copy-Item -LiteralPath $execTs -Destination $exec -Force

# Metrics
$metricsPath = Join-Path $RunRootN "metrics.json"
$metrics = [ordered]@{
  phase = 7
  mode  = $Mode
  executed = $executed
  skipped = $skippedExec
  errors = $errors
  at = (Get-Date).ToString("s")
}
($metrics | ConvertTo-Json -Depth 6) | Out-File -LiteralPath $metricsPath -Encoding utf8

Write-Log "Execute complete. executed=$executed skipped=$skippedExec errors=$errors"
exit 0
