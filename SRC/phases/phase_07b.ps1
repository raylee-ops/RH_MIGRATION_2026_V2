#requires -Version 7.0
<#
Phase 07b — Context-aware rename engine
- DryRun: scan files, extract titles from content, generate rename plan (no changes)
- Execute: apply latest Phase 07b DryRun plan (RENAME rows only, skip REVIEW_MANUAL)
- No overwrites, rollback included, repo self-protection
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

# ── Helpers ──────────────────────────────────────────────────

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

# ── Content extraction ───────────────────────────────────────

function Extract-Title([string]$filePath, [string]$ext) {
  <#
    .md  → first # heading (up to ###)
    .txt → first non-empty line
    .ps1 → .SYNOPSIS content or first # comment
    .py  → triple-quote docstring or first # comment
  #>
  try {
    switch ($ext.ToLowerInvariant()) {
      '.md' {
        $lines = Get-Content -LiteralPath $filePath -TotalCount 30 -ErrorAction Stop
        foreach ($line in $lines) {
          if ($line -match '^#{1,3}\s+(.+)') {
            return $Matches[1].Trim()
          }
        }
        return $null
      }
      '.txt' {
        $lines = Get-Content -LiteralPath $filePath -TotalCount 10 -ErrorAction Stop
        foreach ($line in $lines) {
          $trimmed = $line.Trim()
          if ($trimmed.Length -ge 3) {
            return $trimmed
          }
        }
        return $null
      }
      '.ps1' {
        $lines = Get-Content -LiteralPath $filePath -TotalCount 40 -ErrorAction Stop
        $raw = $lines -join "`n"
        # Try .SYNOPSIS
        if ($raw -match '\.SYNOPSIS\s*\r?\n\s*(.+)') {
          return $Matches[1].Trim()
        }
        # Fall back to first # comment (not #requires)
        foreach ($line in $lines) {
          if ($line -match '^\s*#(?!requires|!)(.+)') {
            $c = $Matches[1].Trim()
            if ($c.Length -ge 3) { return $c }
          }
        }
        return $null
      }
      '.py' {
        $lines = Get-Content -LiteralPath $filePath -TotalCount 30 -ErrorAction Stop
        $raw = $lines -join "`n"
        # Try triple-quote docstring
        if ($raw -match '"""(.+?)"""') {
          $doc = $Matches[1].Trim()
          # Take first line only
          $firstLine = ($doc -split "`n")[0].Trim()
          if ($firstLine.Length -ge 3) { return $firstLine }
        }
        if ($raw -match "'''(.+?)'''") {
          $doc = $Matches[1].Trim()
          $firstLine = ($doc -split "`n")[0].Trim()
          if ($firstLine.Length -ge 3) { return $firstLine }
        }
        # Fall back to first # comment (not shebang)
        foreach ($line in $lines) {
          if ($line -match '^\s*#(?!!)(.+)') {
            $c = $Matches[1].Trim()
            if ($c.Length -ge 3) { return $c }
          }
        }
        return $null
      }
      default { return $null }
    }
  } catch {
    return $null
  }
}

# ── Slug generation ──────────────────────────────────────────

function Make-Slug([string]$title, [int]$maxLen) {
  if ([string]::IsNullOrWhiteSpace($title)) { return $null }

  $slug = $title

  # Replace non-alphanumeric (keep underscores and hyphens) with underscore
  $slug = [Regex]::Replace($slug, '[^a-zA-Z0-9_-]', '_')

  # Collapse consecutive underscores
  $slug = $slug -replace '_{2,}', '_'

  # Strip leading/trailing underscores and hyphens
  $slug = $slug.Trim('_', '-')

  # Lowercase
  $slug = $slug.ToLowerInvariant()

  # Truncate
  if ($slug.Length -gt $maxLen) {
    $slug = $slug.Substring(0, $maxLen).TrimEnd('_', '-')
  }

  if ($slug.Length -lt 3) { return $null }
  return $slug
}

# ── CSV helpers ──────────────────────────────────────────────

function CsvEscape([string]$s) {
  if ($null -eq $s) { return "" }
  $t = $s.Replace('"','""')
  return '"' + $t + '"'
}

function Add-PlanRow($row) {
  $line = "`n$($row.action_id),$($row.op),$(CsvEscape $row.src_path),$(CsvEscape $row.dst_path),$(CsvEscape $row.rule_id),$(CsvEscape $row.reason),$(CsvEscape $row.extracted_title)"
  Add-Content -LiteralPath $script:planTs -Value $line -Encoding utf8
}

function Add-ColRow($row) {
  $line = "`n$($row.action_id),$(CsvEscape $row.src_path),$(CsvEscape $row.dst_path),$(CsvEscape $row.rule_id),$(CsvEscape $row.reason)"
  Add-Content -LiteralPath $script:colTs -Value $line -Encoding utf8
}

function Add-ExecRow($row, [string]$status) {
  $at = (Get-Date).ToString("s")
  $line = "`n$($row.action_id),$status,$(CsvEscape $row.src_path),$(CsvEscape $row.dst_path),$(CsvEscape $row.rule_id),$(CsvEscape $row.reason),$at"
  Add-Content -LiteralPath $script:execTs -Value $line -Encoding utf8
}

# ── Preflight ────────────────────────────────────────────────

$RepoRootN = Normalize-Path $RepoRoot
$RunRootN  = Normalize-Path $RunRoot

if (-not (Test-Path -LiteralPath $RunRootN -PathType Container)) { Fail "FAIL: RunRoot missing: $RunRootN" 2 }
if (-not (Test-Path -LiteralPath $EvidenceDir -PathType Container)) { Fail "FAIL: EvidenceDir missing: $EvidenceDir" 3 }

# Load rules
$rulesPath = Join-Path $RepoRootN "SRC\rules\context_rename_rules_v1.yaml"
if (-not (Test-Path -LiteralPath $rulesPath -PathType Leaf)) {
  Fail "FAIL: Missing rules file: $rulesPath" 4
}
$rulesDoc = (Get-Content -LiteralPath $rulesPath -Raw) | ConvertFrom-Json

# Enforce repo self-protection
$rulesDoc.scope.exclude_contains += "\RH_MIGRATION_2026_V2\"

$maxSlug = [int]$rulesDoc.max_slug_length
if ($maxSlug -lt 10) { $maxSlug = 60 }
$minTitle = [int]$rulesDoc.min_title_length
if ($minTitle -lt 1) { $minTitle = 3 }
$canonicalPattern = [string]$rulesDoc.canonical_pattern

# Build extension sets
$renameExts = @($rulesDoc.scope.rename_extensions | ForEach-Object { $_.ToLowerInvariant() })
$reviewExts = @($rulesDoc.scope.review_extensions | ForEach-Object { $_.ToLowerInvariant() })
$allExts = $renameExts + $reviewExts

# Evidence paths
$stamp = Get-Date -Format "MM-dd-yyyy_HHmmss"
$script:planTs = Join-Path $EvidenceDir "rename_plan_$stamp.csv"
$planStable    = Join-Path $EvidenceDir "rename_plan.csv"
$script:execTs = Join-Path $EvidenceDir "rename_executed_$stamp.csv"
$execStable    = Join-Path $EvidenceDir "rename_executed.csv"
$script:colTs  = Join-Path $EvidenceDir "rename_collisions_$stamp.csv"
$colStable     = Join-Path $EvidenceDir "rename_collisions.csv"

# Copy rules into evidence
$rulesEvTs = Join-Path $EvidenceDir "context_rename_rules_v1_$stamp.yaml"
$rulesEvStable = Join-Path $EvidenceDir "context_rename_rules_v1.yaml"
Copy-Item -LiteralPath $rulesPath -Destination $rulesEvTs -Force
Copy-Item -LiteralPath $rulesPath -Destination $rulesEvStable -Force

# CSV headers
"action_id,op,src_path,dst_path,rule_id,reason,extracted_title" | Out-File -LiteralPath $script:planTs -Encoding utf8 -NoNewline
"action_id,op,src_path,dst_path,rule_id,reason,at" | Out-File -LiteralPath $script:execTs -Encoding utf8 -NoNewline
"action_id,src_path,dst_path,rule_id,reason" | Out-File -LiteralPath $script:colTs -Encoding utf8 -NoNewline

# ── Locate latest DryRun plan (for Execute) ──────────────────

function Get-LatestDryRunPlan([string]$repoRoot) {
  $dir = Join-Path $repoRoot "OUTPUTS\phase_07b"
  if (-not (Test-Path -LiteralPath $dir -PathType Container)) { return $null }

  $runs = Get-ChildItem -LiteralPath $dir -Directory -Filter "run_*" | Sort-Object LastWriteTime -Descending
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

# ── Main ─────────────────────────────────────────────────────

$renameCount = 0
$reviewCount = 0
$skipCount = 0
$excludedCount = 0
$collisionCount = 0
$noTitleCount = 0

if ($Mode -eq "Execute") {
  # ── Execute: load latest DryRun plan ───────────────────────
  $planPath = Get-LatestDryRunPlan $RepoRootN
  if (-not $planPath) {
    Fail "FAIL: Execute requires a Phase 07b DryRun rename_plan_*.csv. Run DryRun first." 6
  }

  Write-Log "Execute mode: loading plan: $planPath"
  $planRows = Import-Csv -LiteralPath $planPath

  $rollbackPath = Join-Path $RunRootN "rollback.ps1"
  "#!/usr/bin/env pwsh`n# Phase 07b rollback (context renames)`n" | Out-File -LiteralPath $rollbackPath -Encoding utf8

  $executed = 0
  $skippedExec = 0
  $errors = 0

  foreach ($r in $planRows) {
    $op = [string]$r.op
    $src = Normalize-Path ([string]$r.src_path)
    $dst = Normalize-Path ([string]$r.dst_path)

    # Only execute RENAME rows (skip REVIEW_MANUAL and everything else)
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
      Move-Item -LiteralPath $src -Destination $dst -ErrorAction Stop
      $rb = "Move-Item -LiteralPath $(CsvEscape $dst) -Destination $(CsvEscape $src) -ErrorAction Stop"
      Add-Content -LiteralPath $rollbackPath -Value $rb -Encoding utf8
      $executed++
      Add-ExecRow $r "EXECUTED"
    } catch {
      $errors++
      Add-ExecRow $r ("ERROR_" + $_.Exception.GetType().Name)
    }
  }

  Copy-Item -LiteralPath $script:execTs -Destination $execStable -Force

  $metricsPath = Join-Path $RunRootN "metrics.json"
  $metrics = [ordered]@{
    phase = "7b"
    mode  = $Mode
    executed = $executed
    skipped = $skippedExec
    errors = $errors
    at = (Get-Date).ToString("s")
  }
  ($metrics | ConvertTo-Json -Depth 6) | Out-File -LiteralPath $metricsPath -Encoding utf8

  Write-Log "Execute complete. executed=$executed skipped=$skippedExec errors=$errors"
  exit 0
}

# ── DryRun: scan and generate plan ───────────────────────────

$include = @($rulesDoc.scope.include_roots | ForEach-Object { Normalize-Path $_ })
$excludeRoots = @($rulesDoc.scope.exclude_roots | ForEach-Object { Normalize-Path $_ })
$excludeContains = @($rulesDoc.scope.exclude_contains)
$excludeNames = @($rulesDoc.scope.exclude_filenames | ForEach-Object { $_.ToLowerInvariant() })

Write-Log "DryRun: scanning roots: $($include -join ', ')"
Write-Log "DryRun: rename extensions: $($renameExts -join ', ')"
Write-Log "DryRun: review extensions: $($reviewExts -join ', ')"

$actionIndex = 0

foreach ($root in $include) {
  if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }

  Get-ChildItem -LiteralPath $root -Recurse -Force -File -ErrorAction SilentlyContinue | ForEach-Object {
    $fi = $_
    $full = Normalize-Path $fi.FullName
    $leaf = $fi.Name
    $ext = ([IO.Path]::GetExtension($leaf)).ToLowerInvariant()

    # Extension filter: only process rename + review extensions
    if ($allExts -notcontains $ext) {
      $excludedCount++
      return
    }

    # Excluded roots
    if (Is-UnderAnyPrefix $full $excludeRoots) {
      $excludedCount++
      return
    }

    # RepoRoot protection
    if (Is-UnderAnyPrefix $full @($RepoRootN)) {
      $excludedCount++
      return
    }

    # Excluded contains patterns
    if (Contains-Any $full $excludeContains) {
      $excludedCount++
      return
    }

    # Excluded filenames
    if ($excludeNames -contains $leaf.ToLowerInvariant()) {
      $excludedCount++
      return
    }

    $actionIndex++
    $id = ("P7B_{0:D6}" -f $actionIndex)

    # Already canonical? (name_MM-DD-YYYY.ext)
    $stem = if ($ext) { $leaf.Substring(0, $leaf.Length - $ext.Length) } else { $leaf }
    if ($canonicalPattern -and [Regex]::IsMatch($leaf, $canonicalPattern)) {
      $skipCount++
      Add-PlanRow ([pscustomobject]@{
        action_id=$id; op="SKIP_ALREADY_CANONICAL"; src_path=$full; dst_path=$full
        rule_id="canonical_check"; reason="Already matches canonical pattern"; extracted_title=""
      })
      return
    }

    # Determine op type based on extension
    $opType = if ($renameExts -contains $ext) { "RENAME" } else { "REVIEW_MANUAL" }

    # Extract title from content
    $title = Extract-Title $full $ext

    if ([string]::IsNullOrWhiteSpace($title) -or $title.Length -lt $minTitle) {
      $noTitleCount++
      $skipCount++
      Add-PlanRow ([pscustomobject]@{
        action_id=$id; op="SKIP_NO_TITLE"; src_path=$full; dst_path=$full
        rule_id="content_extract"; reason="No usable title extracted from content"; extracted_title=""
      })
      return
    }

    # Generate slug
    $slug = Make-Slug $title $maxSlug
    if ([string]::IsNullOrWhiteSpace($slug)) {
      $noTitleCount++
      $skipCount++
      Add-PlanRow ([pscustomobject]@{
        action_id=$id; op="SKIP_NO_TITLE"; src_path=$full; dst_path=$full
        rule_id="slug_gen"; reason="Slug generation produced empty result"; extracted_title=$title
      })
      return
    }

    # Build destination: slug_MM-DD-YYYY.ext
    $dateStamp = $fi.LastWriteTime.ToString("MM-dd-yyyy")
    $newName = "${slug}_${dateStamp}${ext}"
    $dstFull = Join-Path (Split-Path $full -Parent) $newName

    # Same directory check
    if ((Split-Path $dstFull -Parent) -ne (Split-Path $full -Parent)) {
      $skipCount++
      Add-PlanRow ([pscustomobject]@{
        action_id=$id; op="SKIP_INVALID"; src_path=$full; dst_path=$dstFull
        rule_id="dir_guard"; reason="Rename attempted to change directory (blocked)"; extracted_title=$title
      })
      return
    }

    # No change?
    if ($dstFull -eq $full) {
      $skipCount++
      Add-PlanRow ([pscustomobject]@{
        action_id=$id; op="SKIP_NO_CHANGE"; src_path=$full; dst_path=$full
        rule_id="content_extract"; reason="Generated name matches current name"; extracted_title=$title
      })
      return
    }

    # Collision check
    if (Test-Path -LiteralPath $dstFull -PathType Leaf) {
      $collisionCount++
      $row = [pscustomobject]@{
        action_id=$id; op="COLLISION"; src_path=$full; dst_path=$dstFull
        rule_id="content_extract"; reason="Destination exists (no overwrite)"; extracted_title=$title
      }
      Add-ColRow $row
      Add-PlanRow $row
      return
    }

    # Good to go
    if ($opType -eq "RENAME") {
      $renameCount++
    } else {
      $reviewCount++
    }

    Add-PlanRow ([pscustomobject]@{
      action_id=$id; op=$opType; src_path=$full; dst_path=$dstFull
      rule_id="content_extract"; reason="Title extracted from file content"; extracted_title=$title
    })
  }
}

# Write stable copies
Copy-Item -LiteralPath $script:planTs -Destination $planStable -Force
Copy-Item -LiteralPath $script:colTs  -Destination $colStable  -Force

# Metrics
$metricsPath = Join-Path $RunRootN "metrics.json"
$metrics = [ordered]@{
  phase = "7b"
  mode  = $Mode
  plan_rows = $actionIndex
  rename_planned = $renameCount
  review_manual = $reviewCount
  skipped = $skipCount
  excluded = $excludedCount
  collisions = $collisionCount
  no_title = $noTitleCount
  max_slug_length = $maxSlug
  date_source = $rulesDoc.date_source
  at = (Get-Date).ToString("s")
}
($metrics | ConvertTo-Json -Depth 6) | Out-File -LiteralPath $metricsPath -Encoding utf8

Write-Log "DryRun complete. rename_planned=$renameCount review_manual=$reviewCount collisions=$collisionCount skipped=$skipCount excluded=$excludedCount no_title=$noTitleCount plan_rows=$actionIndex"
exit 0
