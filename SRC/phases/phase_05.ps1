[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$RepoRoot,
  [Parameter(Mandatory)][string]$RunRoot,
  [Parameter(Mandatory)][string]$EvidenceDir,
  [Parameter(Mandatory)][ValidateSet('DryRun','Execute')][string]$Mode
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string]$Message, [int]$Code = 1) {
  Write-Error $Message
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

function Test-PathStartsWith([string]$Path, [string]$Root) {
  $pathNorm = Get-NormalizedPath -Path $Path
  $rootNorm = Get-NormalizedPath -Path $Root
  if ([string]::IsNullOrWhiteSpace($pathNorm) -or [string]::IsNullOrWhiteSpace($rootNorm)) {
    return $false
  }
  return $pathNorm.StartsWith($rootNorm, [System.StringComparison]::OrdinalIgnoreCase)
}

function To-Double([string]$Value) {
  $parsed = 0.0
  if ([double]::TryParse($Value, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsed)) {
    return $parsed
  }
  return 0.0
}

function Write-CsvOrHeader {
  param(
    [Parameter(Mandatory)][string]$LiteralPath,
    [Parameter(Mandatory)][array]$Rows,
    [Parameter(Mandatory)][string]$Header
  )

  if ($Rows.Count -gt 0) {
    $Rows | Export-Csv -LiteralPath $LiteralPath -NoTypeInformation -Encoding utf8
  } else {
    Set-Content -LiteralPath $LiteralPath -Encoding utf8 -NoNewline -Value $Header
  }
}

$today = Get-Date -Format 'MM-dd-yyyy'
$stamp = Get-Date -Format 'MM-dd-yyyy_HHmmss'

$configPath = Join-Path $RepoRoot 'project_config.json'
if (!(Test-Path -LiteralPath $configPath)) {
  Fail "FAIL: Missing config: $configPath" 2
}

$config = Get-Content -LiteralPath $configPath -Raw -Encoding utf8 | ConvertFrom-Json

$phase04Dir = Join-Path $RepoRoot 'OUTPUTS\phase_04'
if (!(Test-Path -LiteralPath $phase04Dir)) {
  Fail "FAIL: Missing Phase 04 outputs: $phase04Dir" 3
}

$phase04Runs = @(Get-ChildItem -LiteralPath $phase04Dir -Directory -Filter 'run_*' | Sort-Object LastWriteTime -Descending)
if ($phase04Runs.Count -eq 0) {
  Fail "FAIL: No Phase 04 run folders found in $phase04Dir" 4
}

$sourceRun = $null
foreach ($candidate in $phase04Runs) {
  $candidateCsv = Join-Path $candidate.FullName 'classification_results.csv'
  if (Test-Path -LiteralPath $candidateCsv) {
    $sourceRun = $candidate
    break
  }
}

if ($null -eq $sourceRun) {
  Fail "FAIL: No usable Phase 04 run with classification_results.csv found" 5
}

$classificationCsv = Join-Path $sourceRun.FullName 'classification_results.csv'
$rows = @(Import-Csv -LiteralPath $classificationCsv)
if ($rows.Count -eq 0) {
  Fail "FAIL: Phase 04 classification_results.csv is empty: $classificationCsv" 6
}

$movePlanPath = Join-Path $RunRoot 'move_plan.csv'
$collisionsPath = Join-Path $RunRoot 'collisions.csv'
$exclusionsPath = Join-Path $RunRoot 'exclusions_applied.txt'
$summaryPath = Join-Path $RunRoot ("planned_changes_summary_{0}.md" -f $today)
$planPath = Join-Path $RunRoot 'plan.csv'
$metricsPath = Join-Path $RunRoot 'metrics.json'
$runLogPath = Join-Path $RunRoot 'runlog.txt'

$evidenceMovePlanPath = Join-Path $EvidenceDir ("move_plan_{0}.csv" -f $stamp)
$evidenceCollisionsPath = Join-Path $EvidenceDir ("collisions_{0}.csv" -f $stamp)
$evidenceExclusionsPath = Join-Path $EvidenceDir ("exclusions_applied_{0}.txt" -f $stamp)
$evidenceSummaryPath = Join-Path $EvidenceDir ("planned_changes_summary_{0}.md" -f $stamp)

$legacyBlockedRoots = @(
  'C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026',
  'C:\RH\OPS\PROJECTS\oldrh_migration_attempt2'
)

$excludeRoots = @()
$excludeRoots += @($config.exclude_roots)
$excludeRoots += $legacyBlockedRoots
$excludeRoots += @(
  $RepoRoot,
  (Join-Path $RepoRoot 'OUTPUTS')
)
$excludeRoots = @($excludeRoots | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)

$quarantineRoot = [string]$config.quarantine_root
if ([string]::IsNullOrWhiteSpace($quarantineRoot)) {
  $quarantineRoot = 'C:\RH\TEMPORARY'
}

$routeMap = @{
  'PROJECT'  = 'C:\RH\OPS\PROJECTS'
  'NOTES'    = 'C:\RH\OPS'
  'EVIDENCE' = 'C:\RH\OPS\SYSTEM\DATA\runs'
  'MEDIA'    = 'C:\RH\INBOX\DESKTOP_SWEEP'
  'ARCHIVE'  = 'C:\RH\ARCHIVE'
  'UNKNOWN'  = $quarantineRoot
}

$autoMove = To-Double -Value ([string]$config.confidence_thresholds.auto_move)
$reviewMin = To-Double -Value ([string]$config.confidence_thresholds.review_queue_min)
$reviewMax = To-Double -Value ([string]$config.confidence_thresholds.review_queue_max)
$quarantineMax = To-Double -Value ([string]$config.confidence_thresholds.quarantine_max)

$planRows = New-Object System.Collections.Generic.List[object]
$collisionCandidates = New-Object System.Collections.Generic.List[object]
$collisionRows = New-Object System.Collections.Generic.List[object]
$spineRows = New-Object System.Collections.Generic.List[object]
$exclusionsLog = New-Object System.Collections.Generic.List[string]

$counts = @{
  total = 0
  excluded = 0
  plan_move = 0
  review_required = 0
  review_quarantine = 0
}

$actionIndex = 1
foreach ($row in $rows) {
  $counts.total++

  $src = [string]$row.source_path
  if ([string]::IsNullOrWhiteSpace($src)) {
    continue
  }

  $bucket = [string]$row.bucket
  if ([string]::IsNullOrWhiteSpace($bucket)) {
    $bucket = 'UNKNOWN'
  }
  $bucketUpper = $bucket.ToUpperInvariant()
  if (-not $routeMap.ContainsKey($bucketUpper)) {
    $bucketUpper = 'UNKNOWN'
  }

  $confidence = To-Double -Value ([string]$row.confidence)

  $isExcluded = $false
  $excludeReason = ''

  foreach ($root in $excludeRoots) {
    if (Test-PathStartsWith -Path $src -Root $root) {
      $isExcluded = $true
      $excludeReason = "excluded_root:$root"
      break
    }
  }

  if (-not $isExcluded -and $src -match '\\OUTPUTS\\') {
    $isExcluded = $true
    $excludeReason = 'excluded_outputs_path'
  }

  if (-not $isExcluded) {
    if (!(Test-Path -LiteralPath $src)) {
      $isExcluded = $true
      $excludeReason = 'missing_source_at_plan_time'
    }
  }

  $destPath = ''
  $decision = ''
  $note = ''

  if ($isExcluded) {
    $decision = 'EXCLUDED'
    $note = $excludeReason
    $counts.excluded++
    $exclusionsLog.Add("{0}`t{1}" -f $src, $excludeReason) | Out-Null
  } else {
    $leafName = Split-Path -Path $src -Leaf
    if ([string]::IsNullOrWhiteSpace($leafName)) {
      $leafName = 'unnamed_item'
    }

    $destRoot = [string]$routeMap[$bucketUpper]
    $destPath = Join-Path $destRoot $leafName

    if ($bucketUpper -eq 'UNKNOWN' -or $confidence -le $quarantineMax) {
      $decision = 'REVIEW_QUARANTINE'
      $counts.review_quarantine++
      if ($bucketUpper -eq 'UNKNOWN') {
        $note = 'bucket_unknown'
      } else {
        $note = "confidence_le_quarantine_max:$quarantineMax"
      }
    } elseif ($confidence -ge $autoMove) {
      $decision = 'PLAN_MOVE'
      $counts.plan_move++
    } elseif ($confidence -ge $reviewMin -and $confidence -le $reviewMax) {
      $decision = 'REVIEW_REQUIRED'
      $counts.review_required++
      $note = "confidence_review_band:$reviewMin-$reviewMax"
    } else {
      $decision = 'REVIEW_REQUIRED'
      $counts.review_required++
      $note = "confidence_between_review_max_and_auto_move:$reviewMax-$autoMove"
    }

    $collisionCandidates.Add([pscustomobject]@{
      source_path = $src
      dst_path = $destPath
      bucket = $bucketUpper
      decision = $decision
    }) | Out-Null
  }

  $actionId = "P05-{0:d6}" -f $actionIndex
  $actionIndex++

  $planRows.Add([pscustomobject]@{
    action_id = $actionId
    decision = $decision
    source_path = $src
    proposed_destination = $destPath
    bucket = $bucketUpper
    confidence = [math]::Round($confidence, 2)
    rule_id = [string]$row.rule_id
    reason = [string]$row.reason
    notes = $note
  }) | Out-Null

  $spineRows.Add([pscustomobject]@{
    action_id = $actionId
    op = $decision
    src_path = $src
    dst_path = $destPath
    notes = $note
  }) | Out-Null
}

$collisionId = 1
$groupedByDestination = $collisionCandidates | Where-Object { -not [string]::IsNullOrWhiteSpace($_.dst_path) } | Group-Object -Property dst_path
foreach ($group in $groupedByDestination) {
  $destination = [string]$group.Name
  $existingDestination = Test-Path -LiteralPath $destination
  $sourceCount = $group.Count

  if ($sourceCount -gt 1 -or $existingDestination) {
    $collisionType = if ($sourceCount -gt 1 -and $existingDestination) {
      'MULTI_SOURCE_AND_DESTINATION_EXISTS'
    } elseif ($sourceCount -gt 1) {
      'MULTI_SOURCE'
    } else {
      'DESTINATION_EXISTS'
    }

    foreach ($item in $group.Group) {
      $collisionRows.Add([pscustomobject]@{
        collision_id = "COL-{0:d5}" -f $collisionId
        dst_path = $destination
        collision_type = $collisionType
        source_path = $item.source_path
        bucket = $item.bucket
        decision = $item.decision
        resolution = 'suffix_policy__01_to__99_or_manual_review'
      }) | Out-Null
    }

    $collisionId++
  }
}

Write-CsvOrHeader -LiteralPath $movePlanPath -Rows $planRows -Header 'action_id,decision,source_path,proposed_destination,bucket,confidence,rule_id,reason,notes'
Write-CsvOrHeader -LiteralPath $collisionsPath -Rows $collisionRows -Header 'collision_id,dst_path,collision_type,source_path,bucket,decision,resolution'
Write-CsvOrHeader -LiteralPath $planPath -Rows $spineRows -Header 'action_id,op,src_path,dst_path,notes'

$exclusionLines = @(
  "Phase: 05"
  "Mode: $Mode"
  "Generated: $(Get-Date -Format 'MM-dd-yyyy HH:mm:ss')"
  "Source Phase 04 Run: $($sourceRun.Name)"
  "Source CSV: $classificationCsv"
  ""
  "Hard-excluded roots:"
) + ($excludeRoots | ForEach-Object { "  - $_" }) + @(
  ""
  "Excluded records ($($counts.excluded)):"
) + ($exclusionsLog | ForEach-Object { $_ })

Set-Content -LiteralPath $exclusionsPath -Encoding utf8 -NoNewline -Value ($exclusionLines -join [Environment]::NewLine)

$summaryLines = @(
  "# Phase 05 Planned Changes Summary"
  ""
  "- Date: $today"
  "- Mode: $Mode"
  "- Source Phase 04 run: $($sourceRun.Name)"
  "- Source rows scanned: $($counts.total)"
  "- Planned move rows: $($counts.plan_move)"
  "- Review-required rows: $($counts.review_required)"
  "- Quarantine-review rows: $($counts.review_quarantine)"
  "- Excluded rows: $($counts.excluded)"
  "- Collision rows: $($collisionRows.Count)"
  ""
  "## Outputs"
  "- $movePlanPath"
  "- $collisionsPath"
  "- $exclusionsPath"
  ""
  "## Notes"
  "- Plan-only phase: no file moves are executed."
  "- Legacy paths are hard-excluded by prefix match before filesystem checks."
)

Set-Content -LiteralPath $summaryPath -Encoding utf8 -NoNewline -Value ($summaryLines -join [Environment]::NewLine)

Copy-Item -LiteralPath $movePlanPath -Destination $evidenceMovePlanPath -Force
Copy-Item -LiteralPath $collisionsPath -Destination $evidenceCollisionsPath -Force
Copy-Item -LiteralPath $exclusionsPath -Destination $evidenceExclusionsPath -Force
Copy-Item -LiteralPath $summaryPath -Destination $evidenceSummaryPath -Force

$metrics = @{}
if (Test-Path -LiteralPath $metricsPath) {
  try {
    $existingMetrics = Get-Content -LiteralPath $metricsPath -Raw -Encoding utf8 | ConvertFrom-Json
    foreach ($prop in $existingMetrics.PSObject.Properties) {
      $metrics[$prop.Name] = $prop.Value
    }
  } catch {
    $metrics = @{}
  }
}

$metrics.phase05 = @{
  source_phase04_run = $sourceRun.Name
  source_csv = $classificationCsv
  total_rows = $counts.total
  planned_move_rows = $counts.plan_move
  review_required_rows = $counts.review_required
  review_quarantine_rows = $counts.review_quarantine
  excluded_rows = $counts.excluded
  collision_rows = $collisionRows.Count
  thresholds = @{
    auto_move = $autoMove
    review_queue_min = $reviewMin
    review_queue_max = $reviewMax
    quarantine_max = $quarantineMax
  }
  generated_at = (Get-Date).ToUniversalTime().ToString('o')
}

$metrics | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $metricsPath -Encoding utf8 -NoNewline

Add-Content -LiteralPath $runLogPath -Encoding utf8 -Value ("PHASE05 source_phase04_run={0} rows={1} plan_move={2} review={3} quarantine={4} excluded={5} collisions={6}" -f $sourceRun.Name, $counts.total, $counts.plan_move, $counts.review_required, $counts.review_quarantine, $counts.excluded, $collisionRows.Count)

exit 0
