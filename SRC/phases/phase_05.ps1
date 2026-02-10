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
  $pathNorm = Get-NormalizedPath -Path $Path
  $rootNorm = Get-NormalizedPath -Path $Root
  if ([string]::IsNullOrWhiteSpace($pathNorm) -or [string]::IsNullOrWhiteSpace($rootNorm)) {
    return $false
  }

  $rootWithSlash = $rootNorm
  if (-not $rootWithSlash.EndsWith('\')) {
    $rootWithSlash = "$rootWithSlash\"
  }

  return (
    $pathNorm.Equals($rootNorm, [System.StringComparison]::OrdinalIgnoreCase) -or
    $pathNorm.StartsWith($rootWithSlash, [System.StringComparison]::OrdinalIgnoreCase)
  )
}

function Convert-ToDouble([object]$Value, [double]$DefaultValue = 0.0) {
  if ($null -eq $Value) { return $DefaultValue }
  $parsed = 0.0
  $text = [string]$Value
  if ([double]::TryParse($text, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsed)) {
    return $parsed
  }
  return $DefaultValue
}

function Resolve-ColumnName([string[]]$Headers, [string[]]$Candidates) {
  foreach ($candidate in $Candidates) {
    $match = $Headers | Where-Object { $_ -ieq $candidate } | Select-Object -First 1
    if ($match) { return [string]$match }
  }
  return $null
}

function Export-RowsOrHeader {
  param(
    [Parameter(Mandatory)][string]$LiteralPath,
    [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.ArrayList]$Rows,
    [Parameter(Mandatory)][string]$HeaderLine
  )

  if ($Rows.Count -gt 0) {
    $Rows | ForEach-Object { [pscustomobject]$_ } | Export-Csv -LiteralPath $LiteralPath -NoTypeInformation -Encoding utf8
  } else {
    Set-Content -LiteralPath $LiteralPath -Encoding utf8 -NoNewline -Value $HeaderLine
  }
}

$today = Get-Date -Format 'MM-dd-yyyy'
$timestamp = Get-Date -Format 'MM-dd-yyyy_HHmmss'

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

$routingRulesPath = Join-Path $RepoRoot 'SRC\rules\routing_rules_v1.json'
if (!(Test-Path -LiteralPath $routingRulesPath)) {
  Fail "Missing routing rules file: $routingRulesPath" 2
}

$routingRules = Get-Content -LiteralPath $routingRulesPath -Raw -Encoding utf8 | ConvertFrom-Json
$requiredRuleProps = @(
  'version',
  'destination_base',
  'label_to_relative_dest',
  'low_confidence_threshold',
  'default_low_confidence_bucket'
)

foreach ($propName in $requiredRuleProps) {
  if (-not $routingRules.PSObject.Properties.Name.Contains($propName)) {
    Fail "routing_rules_v1.json missing required key: $propName" 3
  }
}

$labelMap = @{}
foreach ($p in $routingRules.label_to_relative_dest.PSObject.Properties) {
  $labelMap[$p.Name.ToUpperInvariant()] = [string]$p.Value
}

$destinationBase = [string]$routingRules.destination_base
$lowConfidenceThreshold = Convert-ToDouble -Value $routingRules.low_confidence_threshold -DefaultValue 0.8
$defaultLowConfidenceBucket = [string]$routingRules.default_low_confidence_bucket

$phase04Dir = Join-Path $RepoRoot 'OUTPUTS\phase_04'
if (!(Test-Path -LiteralPath $phase04Dir)) {
  Fail "Missing Phase 04 directory: $phase04Dir" 4
}

$latestPhase04Run = Get-ChildItem -LiteralPath $phase04Dir -Directory -Filter 'run_*' |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

if ($null -eq $latestPhase04Run) {
  Fail "No Phase 04 run_* folders found in $phase04Dir" 5
}

$classificationCsv = Join-Path $latestPhase04Run.FullName 'classification_results.csv'
if (!(Test-Path -LiteralPath $classificationCsv)) {
  Fail "Missing classification_results.csv in latest Phase 04 run: $classificationCsv" 6
}

$phase04Rows = @(Import-Csv -LiteralPath $classificationCsv)
if ($phase04Rows.Count -eq 0) {
  Fail "classification_results.csv is empty: $classificationCsv" 7
}

$headers = @($phase04Rows[0].PSObject.Properties.Name)
$sourceColumn = Resolve-ColumnName -Headers $headers -Candidates @('SourcePath')
$labelColumn = Resolve-ColumnName -Headers $headers -Candidates @('Label')
$legacyColumnsUsed = $false

if ([string]::IsNullOrWhiteSpace($sourceColumn) -or [string]::IsNullOrWhiteSpace($labelColumn)) {
  # Explicit compatibility for older Phase 04 outputs.
  $sourceColumn = Resolve-ColumnName -Headers $headers -Candidates @('source_path')
  $labelColumn = Resolve-ColumnName -Headers $headers -Candidates @('bucket')
  if (-not [string]::IsNullOrWhiteSpace($sourceColumn) -and -not [string]::IsNullOrWhiteSpace($labelColumn)) {
    $legacyColumnsUsed = $true
  } else {
    $headerList = ($headers -join ', ')
    Fail "Required columns missing. Need SourcePath and Label. Found headers: $headerList" 8
  }
}

$confidenceColumn = Resolve-ColumnName -Headers $headers -Candidates @('Confidence', 'confidence')

$movePlanPath = Join-Path $RunRoot 'move_plan.csv'
$collisionsPath = Join-Path $RunRoot 'collisions.csv'
$exclusionsPath = Join-Path $RunRoot 'exclusions_applied.txt'
$plannedSummaryPath = Join-Path $RunRoot "planned_changes_summary_$today.md"
$planPath = Join-Path $RunRoot 'plan.csv'
$runLogPath = Join-Path $RunRoot 'runlog.txt'
$metricsPath = Join-Path $RunRoot 'metrics.json'

$evidenceMovePlanPath = Join-Path $EvidenceDir "move_plan_$timestamp.csv"
$evidenceCollisionsPath = Join-Path $EvidenceDir "collisions_$timestamp.csv"
$evidenceExclusionsPath = Join-Path $EvidenceDir "exclusions_applied_$timestamp.txt"
$evidenceSummaryPath = Join-Path $EvidenceDir "planned_changes_summary_$timestamp.md"

$movePlanRows = [System.Collections.ArrayList]::new()
$collisionRows = [System.Collections.ArrayList]::new()
$exclusionLines = [System.Collections.ArrayList]::new()
$collisionActionIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

$sequence = 1
foreach ($row in $phase04Rows) {
  $sourcePath = [string]$row.$sourceColumn
  if ([string]::IsNullOrWhiteSpace($sourcePath)) { continue }

  $label = [string]$row.$labelColumn
  if ([string]::IsNullOrWhiteSpace($label)) { $label = 'UNKNOWN' }
  $labelKey = $label.ToUpperInvariant()

  $confidence = 0.0
  if (-not [string]::IsNullOrWhiteSpace($confidenceColumn)) {
    $confidence = Convert-ToDouble -Value $row.$confidenceColumn -DefaultValue 0.0
  }

  $actionId = "P05_$($sequence.ToString('000000'))"
  $sequence++

  $op = ''
  $dstPath = ''
  $reason = ''
  $notes = ''

  if ($legacyColumnsUsed) {
    $notes = 'legacy_header_compatibility_mode'
  }

  # Exclude .git internals (directories and files inside .git)
  if ($sourcePath -like '*\.git\*') {
    $op = 'EXCLUDED'
    $reason = 'Excluded: .git internals'
  } else {
    $firstExcluded = $excludedRoots | Where-Object { Test-IsUnderRoot -Path $sourcePath -Root $_ } | Select-Object -First 1
    if ($firstExcluded) {
      $op = 'EXCLUDED'
      $reason = "excluded_root:$firstExcluded"
    } else {
      $isAllowed = $false
      foreach ($root in $allowedRoots) {
        if (Test-IsUnderRoot -Path $sourcePath -Root $root) {
          $isAllowed = $true
          break
        }
      }

      if (-not $isAllowed) {
        $op = 'EXCLUDED'
        $reason = 'outside_allowed_roots'
      } elseif ($sourcePath -match '\\OUTPUTS\\') {
        $op = 'EXCLUDED'
        $reason = 'outputs_source_disallowed'
      } else {
        $leafName = Split-Path -Path $sourcePath -Leaf
        if ([string]::IsNullOrWhiteSpace($leafName)) { $leafName = 'unnamed_item' }

        # Determine which allowed root the source is under and compute relative path
        $matchedRoot = ''
        foreach ($root in $allowedRoots) {
          if (Test-IsUnderRoot -Path $sourcePath -Root $root) {
            $matchedRoot = Get-NormalizedPath -Path $root
            break
          }
        }
        $normalizedSrc = Get-NormalizedPath -Path $sourcePath
        $relFromRoot = ''
        if (-not [string]::IsNullOrWhiteSpace($matchedRoot)) {
          $rootPrefix = $matchedRoot
          if (-not $rootPrefix.EndsWith('\')) { $rootPrefix = "$rootPrefix\" }
          if ($normalizedSrc.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            $relFromRoot = $normalizedSrc.Substring($rootPrefix.Length)
          }
        }

        $relativeDest = ''
        $isLowConfidence = $confidence -lt $lowConfidenceThreshold
        if ($labelMap.ContainsKey($labelKey) -and -not $isLowConfidence) {
          $relativeDest = [string]$labelMap[$labelKey]
          $op = 'MOVE_PLAN'
          $reason = 'mapped_label'
        } else {
          $relativeDest = $defaultLowConfidenceBucket
          $op = 'QUARANTINE_PLAN'
          if (-not $labelMap.ContainsKey($labelKey)) {
            $reason = 'label_unmapped'
          } else {
            $reason = "confidence_below_threshold:$lowConfidenceThreshold"
          }
        }

        $relativeDest = $relativeDest.TrimStart('\')
        $destDir = Join-Path $destinationBase $relativeDest
        # Preserve relative parent directories from source to prevent collisions
        $relParent = Split-Path $relFromRoot -Parent
        if (-not [string]::IsNullOrWhiteSpace($relParent)) {
          $destDir = Join-Path $destDir $relParent
        }
        $dstPath = Join-Path $destDir $leafName
      }
    }
  }

  if ($op -eq 'EXCLUDED') {
    $null = $exclusionLines.Add("$sourcePath`t$reason")
  }

  $null = $movePlanRows.Add([ordered]@{
    action_id = $actionId
    op = $op
    src_path = $sourcePath
    dst_path = $dstPath
    label = $label
    confidence = [math]::Round($confidence, 4)
    reason = $reason
    notes = $notes
  })
}

$collisionId = 1
$collisionCandidates = $movePlanRows | Where-Object { -not [string]::IsNullOrWhiteSpace($_['dst_path']) }
$collisionGroups = $collisionCandidates | Group-Object -Property { [string]$_['dst_path'] }

foreach ($group in $collisionGroups) {
  $dst = [string]$group.Name
  $destinationExists = Test-Path -LiteralPath $dst -PathType Leaf
  $hasMultipleSources = $group.Count -gt 1

  # Skip self-mapping: single source that IS the destination file is not a collision
  if (-not $hasMultipleSources -and $destinationExists) {
    $srcOfSingle = [string]$group.Group[0]['src_path']
    if ($srcOfSingle.Equals($dst, [System.StringComparison]::OrdinalIgnoreCase)) {
      continue
    }
  }

  if ($destinationExists -or $hasMultipleSources) {
    $collisionType = ''
    if ($destinationExists -and $hasMultipleSources) {
      $collisionType = 'MULTI_SOURCE_AND_DESTINATION_EXISTS'
    } elseif ($hasMultipleSources) {
      $collisionType = 'MULTI_SOURCE'
    } else {
      $collisionType = 'DESTINATION_EXISTS'
    }

    foreach ($entry in $group.Group) {
      $null = $collisionActionIds.Add([string]$entry['action_id'])
      $null = $collisionRows.Add([ordered]@{
        collision_id = "COL_$($collisionId.ToString('00000'))"
        action_id = [string]$entry['action_id']
        dst_path = $dst
        collision_type = $collisionType
        src_path = [string]$entry['src_path']
        prior_op = [string]$entry['op']
        resolution = 'manual_review_required_no_overwrite'
      })
    }

    $collisionId++
  }
}

foreach ($row in $movePlanRows) {
  if ($collisionActionIds.Contains([string]$row['action_id'])) {
    $row['op'] = 'REVIEW_COLLISION'
    if ([string]::IsNullOrWhiteSpace([string]$row['reason'])) {
      $row['reason'] = 'collision_detected'
    } else {
      $row['reason'] = "$($row['reason']);collision_detected"
    }
  }
}

$planRows = [System.Collections.ArrayList]::new()
foreach ($row in $movePlanRows) {
  $null = $planRows.Add([ordered]@{
    action_id = [string]$row['action_id']
    op = [string]$row['op']
    src_path = [string]$row['src_path']
    dst_path = [string]$row['dst_path']
    notes = [string]$row['reason']
  })
}

Export-RowsOrHeader -LiteralPath $movePlanPath -Rows $movePlanRows -HeaderLine 'action_id,op,src_path,dst_path,label,confidence,reason,notes'
Export-RowsOrHeader -LiteralPath $collisionsPath -Rows $collisionRows -HeaderLine 'collision_id,action_id,dst_path,collision_type,src_path,prior_op,resolution'
Export-RowsOrHeader -LiteralPath $planPath -Rows $planRows -HeaderLine 'action_id,op,src_path,dst_path,notes'

$excludedCount = @($movePlanRows | Where-Object { $_['op'] -eq 'EXCLUDED' }).Count
$moveCount = @($movePlanRows | Where-Object { $_['op'] -eq 'MOVE_PLAN' }).Count
$quarantineCount = @($movePlanRows | Where-Object { $_['op'] -eq 'QUARANTINE_PLAN' }).Count
$collisionReviewCount = @($movePlanRows | Where-Object { $_['op'] -eq 'REVIEW_COLLISION' }).Count

$exclusionsText = @(
  "Phase: 05"
  "Mode: $Mode"
  "Generated: $(Get-Date -Format 'MM-dd-yyyy HH:mm:ss')"
  "Latest Phase 04 run: $($latestPhase04Run.Name)"
  "Classification CSV: $classificationCsv"
  "Headers used: Source=$sourceColumn Label=$labelColumn Confidence=$confidenceColumn"
  "Legacy header compatibility: $legacyColumnsUsed"
  ''
  'Allowed roots:'
) + ($allowedRoots | ForEach-Object { "  - $_" }) + @(
  ''
  'Excluded roots:'
) + ($excludedRoots | ForEach-Object { "  - $_" }) + @(
  ''
  "Excluded records ($excludedCount):"
) + ($exclusionLines | ForEach-Object { $_ })

Set-Content -LiteralPath $exclusionsPath -Encoding utf8 -NoNewline -Value ($exclusionsText -join [Environment]::NewLine)

$plannedSummary = @(
  "# Phase 05 Planned Changes Summary"
  ""
  "- Date: $today"
  "- Mode: $Mode"
  "- Latest Phase 04 run: $($latestPhase04Run.Name)"
  "- Input rows: $($movePlanRows.Count)"
  "- MOVE_PLAN rows: $moveCount"
  "- QUARANTINE_PLAN rows: $quarantineCount"
  "- REVIEW_COLLISION rows: $collisionReviewCount"
  "- EXCLUDED rows: $excludedCount"
  "- Collisions listed: $($collisionRows.Count)"
  "- Legacy header compatibility used: $legacyColumnsUsed"
  ""
  "## Routing Rule File"
  "- $routingRulesPath"
  ""
  "## Guarantees"
  "- Plan-only phase: no user files moved or renamed."
  "- Collision rows are never left as MOVE_PLAN."
)

Set-Content -LiteralPath $plannedSummaryPath -Encoding utf8 -NoNewline -Value ($plannedSummary -join [Environment]::NewLine)

Copy-Item -LiteralPath $movePlanPath -Destination $evidenceMovePlanPath -Force
Copy-Item -LiteralPath $collisionsPath -Destination $evidenceCollisionsPath -Force
Copy-Item -LiteralPath $exclusionsPath -Destination $evidenceExclusionsPath -Force
Copy-Item -LiteralPath $plannedSummaryPath -Destination $evidenceSummaryPath -Force

$metricsData = @{}
if (Test-Path -LiteralPath $metricsPath) {
  try {
    $existing = Get-Content -LiteralPath $metricsPath -Raw -Encoding utf8 | ConvertFrom-Json
    foreach ($prop in $existing.PSObject.Properties) {
      $metricsData[$prop.Name] = $prop.Value
    }
  } catch {
    $metricsData = @{}
  }
}

$metricsData.phase05 = @{
  latest_phase04_run = $latestPhase04Run.Name
  classification_csv = $classificationCsv
  rows_total = $movePlanRows.Count
  rows_move_plan = $moveCount
  rows_quarantine_plan = $quarantineCount
  rows_review_collision = $collisionReviewCount
  rows_excluded = $excludedCount
  collisions = $collisionRows.Count
  low_confidence_threshold = $lowConfidenceThreshold
  legacy_header_compatibility = $legacyColumnsUsed
  generated_utc = (Get-Date).ToUniversalTime().ToString('o')
}

$metricsData | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $metricsPath -Encoding utf8 -NoNewline

Add-Content -LiteralPath $runLogPath -Encoding utf8 -Value "PHASE05 latest_phase04_run=$($latestPhase04Run.Name) rows=$($movePlanRows.Count) move=$moveCount quarantine=$quarantineCount collision_review=$collisionReviewCount excluded=$excludedCount"

exit 0
