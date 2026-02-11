[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$RepoRoot,
  [Parameter(Mandatory)][string]$RunRoot,
  [Parameter(Mandatory)][string]$EvidenceDir,
  [Parameter(Mandatory)][ValidateSet('DryRun','Execute')][string]$Mode,
  [string]$Phase05RunRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-RunLog([string]$Path, [string]$Line) {
  $ts = (Get-Date).ToString('s')
  Add-Content -LiteralPath $Path -Value "[$ts] $Line" -Encoding utf8
}

function Fail([string]$Message, [int]$Code = 1) {
  Write-Host "FAIL: $Message" -ForegroundColor Red
  exit $Code
}

function Get-NormalizedPath([string]$Path) {
  if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
  try {
    return [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
  } catch {
    return $Path.TrimEnd('\')
  }
}

function Test-IsUnderRoot([string]$Path, [string]$Root) {
  $p = Get-NormalizedPath -Path $Path
  $r = Get-NormalizedPath -Path $Root
  if ([string]::IsNullOrWhiteSpace($p) -or [string]::IsNullOrWhiteSpace($r)) { return $false }

  $rWithSlash = $r
  if (-not $rWithSlash.EndsWith('\')) { $rWithSlash = "$rWithSlash\" }

  return (
    $p.Equals($r, [System.StringComparison]::OrdinalIgnoreCase) -or
    $p.StartsWith($rWithSlash, [System.StringComparison]::OrdinalIgnoreCase)
  )
}

function Assert-UnderAnyRoot([string]$Path, [string[]]$Roots, [string]$What) {
  foreach ($root in $Roots) {
    if (Test-IsUnderRoot -Path $Path -Root $root) { return }
  }
  throw "$What is out of allowed roots: $Path"
}

function Assert-NotUnderAnyRoot([string]$Path, [string[]]$Roots, [string]$What) {
  foreach ($root in $Roots) {
    if (Test-IsUnderRoot -Path $Path -Root $root) {
      throw "$What is under excluded root ($root): $Path"
    }
  }
}

function Convert-OpForExecution([string]$OpRaw) {
  $op = ([string]$OpRaw).Trim().ToUpperInvariant()
  switch ($op) {
    'MOVE' { return 'MOVE' }
    'MOVE_PLAN' { return 'MOVE' }
    'QUARANTINE' { return 'QUARANTINE' }
    'QUARANTINE_PLAN' { return 'QUARANTINE' }
    default { return $null }
  }
}

$allowedRoots = @(
  'C:\RH\OPS',
  'C:\RH\INBOX',
  'C:\RH\TEMPORARY'
)

$excludedRoots = @(
  'C:\RH\VAULT',
  'C:\RH\LIFE',
  'C:\LEGACY',
  'C:\Windows',
  'C:\Program Files',
  'C:\Users'
)

if (!(Test-Path -LiteralPath $EvidenceDir)) {
  New-Item -ItemType Directory -Path $EvidenceDir -Force | Out-Null
}

$dateStamp = Get-Date -Format 'MM-dd-yyyy'
$timeStamp = Get-Date -Format 'MM-dd-yyyy_HHmmss'

$planPath = Join-Path $RunRoot 'plan.csv'
$runLogPath = Join-Path $RunRoot 'runlog.txt'
$metricsPath = Join-Path $RunRoot 'metrics.json'
$rollbackPath = Join-Path $RunRoot 'rollback.ps1'
$summaryPath = Join-Path $RunRoot "summary_$dateStamp.md"

$movesExecutedPath = Join-Path $EvidenceDir "moves_executed_$timeStamp.csv"
$errorsPath = Join-Path $EvidenceDir "errors_$timeStamp.csv"
$stateTreePath = Join-Path $EvidenceDir "state_tree_after_moves_$timeStamp.txt"
$rollbackReportPath = Join-Path $EvidenceDir "rollback_dryrun_report_$timeStamp.md"

# Optional plain deliverable names for human convenience.
$movesExecutedPlainPath = Join-Path $EvidenceDir 'moves_executed.csv'
$errorsPlainPath = Join-Path $EvidenceDir 'errors.csv'
$stateTreePlainPath = Join-Path $EvidenceDir 'state_tree_after_moves.txt'

if (!(Test-Path -LiteralPath $planPath)) {
  "action_id,op,src_path,dst_path,notes" | Out-File -LiteralPath $planPath -Encoding utf8 -NoNewline
}
if (!(Test-Path -LiteralPath $runLogPath)) {
  "" | Out-File -LiteralPath $runLogPath -Encoding utf8 -NoNewline
}
if (!(Test-Path -LiteralPath $metricsPath)) {
  "{}" | Out-File -LiteralPath $metricsPath -Encoding utf8 -NoNewline
}
if (!(Test-Path -LiteralPath $rollbackPath)) {
  "# rollback placeholder (Phase 06)" | Out-File -LiteralPath $rollbackPath -Encoding utf8 -NoNewline
}
if (!(Test-Path -LiteralPath $summaryPath)) {
@"
# Phase 06 Summary
- Mode: $Mode
- RunRoot: $RunRoot
- Started: $(Get-Date -Format 'MM-dd-yyyy HH:mm:ss')
"@ | Out-File -LiteralPath $summaryPath -Encoding utf8 -NoNewline
}

"action_id,op,src_path,dst_path,label,confidence,reason,notes,status,executed_at" | Out-File -LiteralPath $movesExecutedPath -Encoding utf8 -NoNewline
"row_id,action_id,src_path,dst_path,op,error,at" | Out-File -LiteralPath $errorsPath -Encoding utf8 -NoNewline

Write-RunLog -Path $runLogPath -Line "START Phase=06 Mode=$Mode RunRoot=$RunRoot"

try {
  $phase05Root = $null
  if ([string]::IsNullOrWhiteSpace($Phase05RunRoot)) {
    $phase05Dir = Join-Path $RepoRoot 'OUTPUTS\phase_05'
    if (!(Test-Path -LiteralPath $phase05Dir)) {
      throw "Missing directory: $phase05Dir"
    }

    $latestPhase05 = Get-ChildItem -LiteralPath $phase05Dir -Directory -Filter 'run_*' |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 1
    if ($null -eq $latestPhase05) {
      throw "No phase_05 run_* folders found under $phase05Dir"
    }
    $phase05Root = $latestPhase05.FullName
  } else {
    $phase05Root = (Resolve-Path -LiteralPath $Phase05RunRoot).Path
  }

  $phase05Evidence = Join-Path $phase05Root 'evidence'
  if (!(Test-Path -LiteralPath $phase05Evidence)) {
    throw "Missing phase_05 evidence folder: $phase05Evidence"
  }

  $movePlanFile = Get-ChildItem -LiteralPath $phase05Evidence -File -Filter 'move_plan_*.csv' |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
  if ($null -eq $movePlanFile) {
    throw "No move_plan_*.csv found in $phase05Evidence"
  }

  $movePlanPath = $movePlanFile.FullName
  Write-RunLog -Path $runLogPath -Line "Using Phase05RunRoot=$phase05Root"
  Write-RunLog -Path $runLogPath -Line "Using MovePlan=$movePlanPath"
} catch {
  Write-RunLog -Path $runLogPath -Line "FAIL locating move plan: $($_.Exception.Message)"
  Fail "$($_.Exception.Message)" 4
}

$headerLine = Get-Content -LiteralPath $movePlanPath -TotalCount 1
$requiredColumns = @('action_id','op','src_path','dst_path','label','confidence','reason','notes')
foreach ($columnName in $requiredColumns) {
  if ($headerLine -notmatch "(^|,)\s*`"?$columnName`"?\s*(,|$)") {
    Write-RunLog -Path $runLogPath -Line "Header validation failed. Header=$headerLine"
    Fail "move plan missing required column '$columnName'. Header: $headerLine" 5
  }
}

$rows = @(Import-Csv -LiteralPath $movePlanPath)
Write-RunLog -Path $runLogPath -Line "Plan rows loaded: $($rows.Count)"

if ($rows.Count -eq 0) {
  Fail "move_plan has 0 rows" 6
}

$rollbackLines = New-Object System.Collections.Generic.List[string]
$planRows = New-Object System.Collections.Generic.List[object]

$executed = 0
$skipped = 0
$skippedDestExists = 0
$errors = 0
$rowId = 0

foreach ($row in $rows) {
  $rowId++

  $actionId = [string]$row.action_id
  $rawOp = [string]$row.op
  $src = [string]$row.src_path
  $dst = [string]$row.dst_path
  $label = [string]$row.label
  $confidence = [string]$row.confidence
  $reason = [string]$row.reason
  $notes = [string]$row.notes

  try {
    $execOp = Convert-OpForExecution -OpRaw $rawOp
    if ([string]::IsNullOrWhiteSpace($execOp)) {
      $skipped++
      $planRows.Add([pscustomobject]@{
        action_id = $actionId
        op = 'SKIP'
        src_path = $src
        dst_path = $dst
        notes = "unsupported_or_review_op:$rawOp"
      }) | Out-Null
      continue
    }

    if ([string]::IsNullOrWhiteSpace($src) -or [string]::IsNullOrWhiteSpace($dst)) {
      throw "Empty src_path or dst_path for executable op"
    }

    $srcFull = [System.IO.Path]::GetFullPath($src)
    $dstFull = [System.IO.Path]::GetFullPath($dst)

    Assert-UnderAnyRoot -Path $srcFull -Roots $allowedRoots -What 'src_path'
    Assert-NotUnderAnyRoot -Path $srcFull -Roots $excludedRoots -What 'src_path'
    Assert-UnderAnyRoot -Path $dstFull -Roots $allowedRoots -What 'dst_path'
    Assert-NotUnderAnyRoot -Path $dstFull -Roots $excludedRoots -What 'dst_path'

    if (!(Test-Path -LiteralPath $srcFull -PathType Leaf)) {
      throw "Source missing: $srcFull"
    }

    # No overwrites: if destination exists, SKIP (idempotent behavior)
    if (Test-Path -LiteralPath $dstFull -PathType Leaf) {
      $skippedDestExists++
      $line = "`n$actionId,$execOp,`"$srcFull`",`"$dstFull`",`"$label`",`"$confidence`",`"$reason`",`"$notes`",SKIPPED_DEST_EXISTS,$((Get-Date).ToString('s'))"
      Add-Content -LiteralPath $movesExecutedPath -Value $line -Encoding utf8
      $planRows.Add([pscustomobject]@{
        action_id = $actionId
        op = 'SKIP'
        src_path = $srcFull
        dst_path = $dstFull
        notes = "SKIPPED_DEST_EXISTS"
      }) | Out-Null
      continue
    }

    $dstDir = Split-Path -Path $dstFull -Parent
    if ($Mode -eq 'Execute' -and -not [string]::IsNullOrWhiteSpace($dstDir) -and !(Test-Path -LiteralPath $dstDir)) {
      New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
    }

    if ($Mode -eq 'Execute') {
      Move-Item -LiteralPath $srcFull -Destination $dstFull -Force:$false
      $rollbackLines.Add("Move-Item -LiteralPath `"$dstFull`" -Destination `"$srcFull`" -Force:`$false") | Out-Null
      $status = 'EXECUTED'
    } else {
      $status = 'DRYRUN'
    }

    $executed++
    $movesLine = "`n$actionId,$execOp,`"$srcFull`",`"$dstFull`",`"$label`",`"$confidence`",`"$reason`",`"$notes`",$status,$(Get-Date -Format 's')"
    Add-Content -LiteralPath $movesExecutedPath -Value $movesLine -Encoding utf8

    $planRows.Add([pscustomobject]@{
      action_id = $actionId
      op = $execOp
      src_path = $srcFull
      dst_path = $dstFull
      notes = $status
    }) | Out-Null
  } catch {
    $errors++
    $errorMessage = $_.Exception.Message.Replace("`r", ' ').Replace("`n", ' ')
    $errorLine = "`n$rowId,$actionId,`"$src`",`"$dst`",`"$rawOp`",`"$errorMessage`",$((Get-Date).ToString('s'))"
    Add-Content -LiteralPath $errorsPath -Value $errorLine -Encoding utf8
    Write-RunLog -Path $runLogPath -Line "ERROR row=$rowId action_id=$actionId : $errorMessage"

    $planRows.Add([pscustomobject]@{
      action_id = $actionId
      op = 'ERROR'
      src_path = $src
      dst_path = $dst
      notes = $errorMessage
    }) | Out-Null
  }
}

$planRows | Export-Csv -LiteralPath $planPath -NoTypeInformation -Encoding utf8

$rollbackHeader = @"
# rollback.ps1 — Phase 06
# Reverses executed moves in reverse order.

Set-StrictMode -Version Latest
`$ErrorActionPreference = 'Stop'

Write-Host 'Phase 06 rollback starting...'
"@
$rollbackHeader | Out-File -LiteralPath $rollbackPath -Encoding utf8 -NoNewline

$rollbackArray = $rollbackLines.ToArray()
[Array]::Reverse($rollbackArray)
foreach ($line in $rollbackArray) {
  Add-Content -LiteralPath $rollbackPath -Value $line -Encoding utf8
}
Add-Content -LiteralPath $rollbackPath -Value "Write-Host 'Phase 06 rollback complete.'" -Encoding utf8

if ($Mode -eq 'Execute') {
  "STATE TREE AFTER MOVES (allowed roots)" | Out-File -LiteralPath $stateTreePath -Encoding utf8 -NoNewline
  foreach ($root in $allowedRoots) {
    Add-Content -LiteralPath $stateTreePath -Value "`n`nROOT: $root" -Encoding utf8
    if (Test-Path -LiteralPath $root) {
      Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
        Select-Object FullName, Length, LastWriteTime |
        ForEach-Object {
          Add-Content -LiteralPath $stateTreePath -Value "$($_.FullName)`t$($_.Length)`t$($_.LastWriteTime)" -Encoding utf8
        }
    } else {
      Add-Content -LiteralPath $stateTreePath -Value 'MISSING ROOT' -Encoding utf8
    }
  }
} else {
  "DRYRUN: state tree not generated (no file changes)." | Out-File -LiteralPath $stateTreePath -Encoding utf8 -NoNewline
}

$rollbackReport = @(
  "# Rollback DryRun Report (Phase 06)"
  ""
  "- Mode: $Mode"
  "- Generated: $(Get-Date -Format 'MM-dd-yyyy HH:mm:ss')"
  "- Rollback file: $rollbackPath"
  "- Rollback command count: $($rollbackLines.Count)"
  "- Executable rows processed: $executed"
  "- Skipped rows: $skipped"
  "- Error rows: $errors"
  ""
  "## Notes"
  "- In DryRun, rollback entries are generated only as a preview."
  "- No user files are moved in DryRun mode."
)
$rollbackReport -join [Environment]::NewLine | Out-File -LiteralPath $rollbackReportPath -Encoding utf8 -NoNewline

Copy-Item -LiteralPath $movesExecutedPath -Destination $movesExecutedPlainPath -Force
Copy-Item -LiteralPath $errorsPath -Destination $errorsPlainPath -Force
Copy-Item -LiteralPath $stateTreePath -Destination $stateTreePlainPath -Force

$metricsObject = @{
  phase = '06'
  mode = $Mode
  phase05_move_plan = $movePlanPath
  plan_rows = $rows.Count
  executed_rows = $executed
  skipped_rows = $skipped
  skipped_dest_exists = $skippedDestExists
  error_rows = $errors
  rollback_commands = $rollbackLines.Count
  generated_at = (Get-Date).ToString('o')
}
$metricsObject | ConvertTo-Json -Depth 8 | Out-File -LiteralPath $metricsPath -Encoding utf8 -NoNewline

Add-Content -LiteralPath $summaryPath -Encoding utf8 -Value @"

Completed: $(Get-Date -Format 'MM-dd-yyyy HH:mm:ss')
Plan rows: $($rows.Count)
Executed rows: $executed
Skipped rows: $skipped
Skipped (dest exists): $skippedDestExists
Error rows: $errors
Phase05 plan: $movePlanPath
"@

Write-RunLog -Path $runLogPath -Line "DONE executed=$executed skipped=$skipped skipped_dest_exists=$skippedDestExists errors=$errors mode=$Mode"
exit 0
