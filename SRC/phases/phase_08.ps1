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

# ============================================================
# Configuration
# ============================================================

$today = Get-Date -Format 'MM-dd-yyyy'
$timestamp = Get-Date -Format 'MM-dd-yyyy_HHmmss'

Write-Host "`n═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Phase 08: Semantic Labeling (Tier 2.5)" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan

# ============================================================
# Load Phase 04 Classification Results
# ============================================================

Write-Host "`nLoading Phase 04 baseline classification..." -ForegroundColor Yellow

$phase04Dir = Join-Path $RepoRoot 'OUTPUTS\phase_04'
if (!(Test-Path -LiteralPath $phase04Dir)) {
  Fail "Missing Phase 04 directory: $phase04Dir" 2
}

$latestPhase04Run = Get-ChildItem -LiteralPath $phase04Dir -Directory -Filter 'run_*' |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

if ($null -eq $latestPhase04Run) {
  Fail "No Phase 04 run_* folders found in $phase04Dir" 3
}

$classificationCsv = Join-Path $latestPhase04Run.FullName 'classification_results.csv'
if (!(Test-Path -LiteralPath $classificationCsv)) {
  Fail "Missing classification_results.csv in latest Phase 04 run: $classificationCsv" 4
}

$phase04Results = @(Import-Csv -LiteralPath $classificationCsv)
if ($phase04Results.Count -eq 0) {
  Fail "classification_results.csv is empty: $classificationCsv" 5
}

Write-Host "  Loaded: $($phase04Results.Count) files from Phase 04" -ForegroundColor Green

# ============================================================
# Load Semantic Rules
# ============================================================

Write-Host "`nLoading semantic rules..." -ForegroundColor Yellow

$semanticRulesPath = Join-Path $RepoRoot 'SRC\rules\semantic_rules_v1.yaml'
if (!(Test-Path -LiteralPath $semanticRulesPath)) {
  Fail "Missing semantic rules file: $semanticRulesPath" 6
}

$rulesContent = Get-Content -LiteralPath $semanticRulesPath -Raw -Encoding utf8

# Parse YAML (simple parser for this structure)
$semanticRules = @()
$currentRule = $null

foreach ($line in ($rulesContent -split "`n")) {
  $line = $line.TrimEnd()

  if ($line -match '^\s*-\s+id:\s*(.+)$') {
    if ($currentRule) { $semanticRules += $currentRule }
    $currentRule = @{
      id = $matches[1].Trim()
      semantic_bucket = ''
      confidence = 0.5
      confidence_adjustment = 'weak_boost'
      priority = 50
      match = @{
        path_contains = @()
        extension = @()
        filename_patterns = @()
        filename_starts_with = @()
        filename_contains = @()
      }
      reason = ''
      override_phase04 = $false
    }
  }
  elseif ($currentRule) {
    if ($line -match '^\s+semantic_bucket:\s*(.+)$') {
      $currentRule.semantic_bucket = $matches[1].Trim()
    }
    elseif ($line -match '^\s+confidence:\s*(.+)$') {
      $currentRule.confidence = [double]$matches[1].Trim()
    }
    elseif ($line -match '^\s+confidence_adjustment:\s*(.+)$') {
      $currentRule.confidence_adjustment = $matches[1].Trim()
    }
    elseif ($line -match '^\s+priority:\s*(\d+)$') {
      $currentRule.priority = [int]$matches[1].Trim()
    }
    elseif ($line -match '^\s+reason:\s*"(.+)"$') {
      $currentRule.reason = $matches[1].Trim()
    }
    elseif ($line -match '^\s+override_phase04:\s*(true|false)$') {
      $currentRule.override_phase04 = $matches[1].Trim() -eq 'true'
    }
    elseif ($line -match '^\s+path_contains:\s*\[(.+)\]$') {
      $arrayContent = $matches[1]
      $currentRule.match.path_contains = @($arrayContent -split ',' | ForEach-Object { $_.Trim(' "''') })
    }
    elseif ($line -match '^\s+extension:\s*\[(.+)\]$') {
      $arrayContent = $matches[1]
      $currentRule.match.extension = @($arrayContent -split ',' | ForEach-Object { $_.Trim(' "''') })
    }
    elseif ($line -match '^\s+filename_patterns:\s*\[(.+)\]$') {
      $arrayContent = $matches[1]
      $currentRule.match.filename_patterns = @($arrayContent -split ',' | ForEach-Object { $_.Trim(' "''') })
    }
    elseif ($line -match '^\s+filename_starts_with:\s*\[(.+)\]$') {
      $arrayContent = $matches[1]
      $currentRule.match.filename_starts_with = @($arrayContent -split ',' | ForEach-Object { $_.Trim(' "''') })
    }
    elseif ($line -match '^\s+filename_contains:\s*\[(.+)\]$') {
      $arrayContent = $matches[1]
      $currentRule.match.filename_contains = @($arrayContent -split ',' | ForEach-Object { $_.Trim(' "''') })
    }
  }
}
if ($currentRule) { $semanticRules += $currentRule }

# Sort by priority (highest first)
$semanticRules = $semanticRules | Sort-Object -Property priority -Descending

Write-Host "  Loaded: $($semanticRules.Count) semantic rules" -ForegroundColor Green

# Confidence adjustment map
$confidenceAdjustments = @{
  strong_boost = 0.20
  moderate_boost = 0.15
  weak_boost = 0.10
  weak_penalty = -0.05
  moderate_penalty = -0.10
}

# ============================================================
# Semantic Analysis Engine
# ============================================================

Write-Host "`nApplying semantic analysis..." -ForegroundColor Yellow

$semanticLabels = [System.Collections.ArrayList]::new()
$semanticMisclassQueue = [System.Collections.ArrayList]::new()

$lowConfidenceThreshold = 0.60
$overrideCount = 0
$boostCount = 0
$penaltyCount = 0

foreach ($phase04Row in $phase04Results) {
  $sourcePath = $phase04Row.source_path
  $phase04Bucket = $phase04Row.bucket
  $phase04Confidence = [double]$phase04Row.confidence
  $phase04RuleId = $phase04Row.rule_id

  # Extract filename and extension
  $fileName = [System.IO.Path]::GetFileName($sourcePath)
  $fileExt = [System.IO.Path]::GetExtension($sourcePath).ToLowerInvariant()
  $fileNameNoExt = [System.IO.Path]::GetFileNameWithoutExtension($sourcePath)

  # Find best matching semantic rule
  $bestSemanticRule = $null
  $bestPriority = -1

  foreach ($rule in $semanticRules) {
    $matched = $false

    # Check path_contains
    if ($rule.match.path_contains.Count -gt 0) {
      foreach ($pattern in $rule.match.path_contains) {
        if ($sourcePath -like "*$pattern*") {
          $matched = $true
          break
        }
      }
    }

    # Check extension
    if (-not $matched -and $rule.match.extension.Count -gt 0) {
      foreach ($ext in $rule.match.extension) {
        if ($fileExt -eq $ext.ToLowerInvariant()) {
          $matched = $true
          break
        }
      }
    }

    # Check filename_patterns
    if (-not $matched -and $rule.match.filename_patterns.Count -gt 0) {
      foreach ($pattern in $rule.match.filename_patterns) {
        if ($fileName -like "*$pattern*" -or $fileNameNoExt -like "*$pattern*") {
          $matched = $true
          break
        }
      }
    }

    # Check filename_starts_with
    if (-not $matched -and $rule.match.filename_starts_with.Count -gt 0) {
      foreach ($prefix in $rule.match.filename_starts_with) {
        if ($fileName.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase) -or
            $fileNameNoExt.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
          $matched = $true
          break
        }
      }
    }

    # Check filename_contains
    if (-not $matched -and $rule.match.filename_contains.Count -gt 0) {
      foreach ($substr in $rule.match.filename_contains) {
        if ($fileName -like "*$substr*" -or $fileNameNoExt -like "*$substr*") {
          $matched = $true
          break
        }
      }
    }

    if ($matched -and $rule.priority -gt $bestPriority) {
      $bestSemanticRule = $rule
      $bestPriority = $rule.priority
    }
  }

  # Apply semantic analysis
  $semanticBucket = $phase04Bucket
  $semanticConfidence = $phase04Confidence
  $semanticReason = "No semantic rule matched (Phase 04 baseline maintained)"
  $action = "MAINTAIN"
  $confidenceDelta = 0.0

  if ($null -ne $bestSemanticRule) {
    $adjustment = $confidenceAdjustments[$bestSemanticRule.confidence_adjustment]
    $confidenceDelta = $adjustment

    $newConfidence = $phase04Confidence + $adjustment
    if ($newConfidence -lt 0.0) { $newConfidence = 0.0 }
    if ($newConfidence -gt 1.0) { $newConfidence = 1.0 }

    # Decide whether to override bucket
    if ($bestSemanticRule.override_phase04 -and
        [Math]::Abs($adjustment) -ge 0.15 -and
        $bestSemanticRule.confidence -ge 0.75) {
      $semanticBucket = $bestSemanticRule.semantic_bucket
      $semanticConfidence = $bestSemanticRule.confidence
      $semanticReason = $bestSemanticRule.reason
      $action = "OVERRIDE"
      $overrideCount++
    }
    elseif ($adjustment -gt 0) {
      $semanticConfidence = $newConfidence
      $semanticReason = $bestSemanticRule.reason + " (confidence boost)"
      $action = "BOOST"
      $boostCount++
    }
    elseif ($adjustment -lt 0) {
      $semanticConfidence = $newConfidence
      $semanticReason = $bestSemanticRule.reason + " (confidence penalty)"
      $action = "PENALTY"
      $penaltyCount++
    }
    else {
      $semanticReason = $bestSemanticRule.reason + " (neutral)"
      $action = "NEUTRAL"
    }
  }

  # Create semantic label row
  $labelRow = [ordered]@{
    source_path = $sourcePath
    phase04_bucket = $phase04Bucket
    phase04_confidence = $phase04Confidence
    phase04_rule_id = $phase04RuleId
    semantic_bucket = $semanticBucket
    semantic_confidence = [Math]::Round($semanticConfidence, 2)
    confidence_delta = [Math]::Round($confidenceDelta, 2)
    semantic_rule_id = if ($null -ne $bestSemanticRule) { $bestSemanticRule.id } else { 'NONE' }
    semantic_reason = $semanticReason
    action = $action
  }

  [void]$semanticLabels.Add($labelRow)

  # Queue for review if low confidence
  if ($semanticConfidence -lt $lowConfidenceThreshold) {
    $misclassRow = [ordered]@{
      source_path = $sourcePath
      semantic_bucket = $semanticBucket
      semantic_confidence = [Math]::Round($semanticConfidence, 2)
      why_uncertain = "Semantic confidence below threshold ($lowConfidenceThreshold)"
      suggested_action = "Human review or add semantic rule"
      phase04_bucket = $phase04Bucket
    }
    [void]$semanticMisclassQueue.Add($misclassRow)
  }
}

Write-Host "  Semantic analysis complete:" -ForegroundColor Green
Write-Host "    Overrides: $overrideCount" -ForegroundColor White
Write-Host "    Boosts: $boostCount" -ForegroundColor White
Write-Host "    Penalties: $penaltyCount" -ForegroundColor White
Write-Host "    Low-confidence queue: $($semanticMisclassQueue.Count)" -ForegroundColor Yellow

# ============================================================
# Write Outputs
# ============================================================

Write-Host "`nWriting outputs..." -ForegroundColor Yellow

# Semantic labels CSV
$semanticLabelsCsv = Join-Path $RunRoot 'semantic_labels.csv'
$semanticLabels | ForEach-Object { [pscustomobject]$_ } |
  Export-Csv -LiteralPath $semanticLabelsCsv -NoTypeInformation -Encoding utf8
Write-Host "  Wrote: semantic_labels.csv" -ForegroundColor Gray

# Semantic misclass queue
$semanticMisclassCsv = Join-Path $RunRoot 'semantic_misclass_queue.csv'
if ($semanticMisclassQueue.Count -gt 0) {
  $semanticMisclassQueue | ForEach-Object { [pscustomobject]$_ } |
    Export-Csv -LiteralPath $semanticMisclassCsv -NoTypeInformation -Encoding utf8
} else {
  '"source_path","semantic_bucket","semantic_confidence","why_uncertain","suggested_action","phase04_bucket"' |
    Out-File -LiteralPath $semanticMisclassCsv -Encoding utf8 -NoNewline
}
Write-Host "  Wrote: semantic_misclass_queue.csv" -ForegroundColor Gray

# Training examples manifest
$trainingExamplesSrc = Join-Path $RepoRoot 'SRC\training_examples.csv'
$trainingExamplesDst = Join-Path $RunRoot 'training_examples_manifest.csv'
if (Test-Path -LiteralPath $trainingExamplesSrc) {
  Copy-Item -LiteralPath $trainingExamplesSrc -Destination $trainingExamplesDst -Force
  Write-Host "  Wrote: training_examples_manifest.csv" -ForegroundColor Gray
}

# Copy semantic rules to run folder
$semanticRulesCopy = Join-Path $RunRoot 'semantic_rules_v1.yaml'
Copy-Item -LiteralPath $semanticRulesPath -Destination $semanticRulesCopy -Force
Write-Host "  Wrote: semantic_rules_v1.yaml" -ForegroundColor Gray

# ============================================================
# Evidence Files
# ============================================================

Write-Host "`nWriting evidence..." -ForegroundColor Yellow

# Training examples manifest (evidence)
$evidenceTrainingCsv = Join-Path $EvidenceDir "training_examples_manifest_$timestamp.csv"
if (Test-Path -LiteralPath $trainingExamplesSrc) {
  Copy-Item -LiteralPath $trainingExamplesSrc -Destination $evidenceTrainingCsv -Force
  Write-Host "  Wrote: evidence/training_examples_manifest_$timestamp.csv" -ForegroundColor Gray
}

# Semantic labels (evidence)
$evidenceSemanticCsv = Join-Path $EvidenceDir "semantic_labels_$timestamp.csv"
Copy-Item -LiteralPath $semanticLabelsCsv -Destination $evidenceSemanticCsv -Force
Write-Host "  Wrote: evidence/semantic_labels_$timestamp.csv" -ForegroundColor Gray

# Semantic misclass queue (evidence)
$evidenceMisclassCsv = Join-Path $EvidenceDir "semantic_misclass_queue_$timestamp.csv"
Copy-Item -LiteralPath $semanticMisclassCsv -Destination $evidenceMisclassCsv -Force
Write-Host "  Wrote: evidence/semantic_misclass_queue_$timestamp.csv" -ForegroundColor Gray

# Merge logic documentation
$mergeLogicMd = Join-Path $EvidenceDir "merge_logic_$timestamp.md"
@"
# Semantic Label Merge Logic

**Phase:** 08 - Semantic Labeling
**Generated:** $timestamp
**Mode:** $Mode

## Merge Strategy

### Override Rules
- **Threshold:** Semantic confidence boost >= 0.15
- **Minimum confidence:** Semantic rule confidence >= 0.75
- **Override flag:** Semantic rule must have `override_phase04: true`
- **Result:** Replace Phase 04 bucket with semantic bucket

### Boost Rules
- **Threshold:** Confidence adjustment > 0.0
- **No override flag:** Semantic rule has `override_phase04: false`
- **Result:** Increase Phase 04 confidence by adjustment value

### Penalty Rules
- **Threshold:** Confidence adjustment < 0.0
- **Result:** Decrease Phase 04 confidence by adjustment value

### Maintain Rules
- **Condition:** No semantic rule matched
- **Result:** Keep Phase 04 bucket and confidence unchanged

## Execution Results

- **Files analyzed:** $($semanticLabels.Count)
- **Overrides applied:** $overrideCount
- **Confidence boosts:** $boostCount
- **Confidence penalties:** $penaltyCount
- **Maintained baseline:** $($semanticLabels.Count - $overrideCount - $boostCount - $penaltyCount)
- **Low-confidence queue:** $($semanticMisclassQueue.Count)

## Deterministic Rules

All merge decisions are deterministic and reproducible:
1. Rules are evaluated in priority order (highest first)
2. First matching rule wins
3. Confidence adjustments are fixed values from semantic_rules_v1.yaml
4. No random or probabilistic components

## Quality Metrics

- **Average confidence (Phase 04):** $(($phase04Results | ForEach-Object { [double]$_.confidence } | Measure-Object -Average).Average.ToString('F2'))
- **Average confidence (Semantic):** $(($semanticLabels | ForEach-Object { [double]$_['semantic_confidence'] } | Measure-Object -Average).Average.ToString('F2'))
- **Confidence improvement:** $(($semanticLabels | ForEach-Object { [double]$_['confidence_delta'] } | Measure-Object -Average).Average.ToString('F2'))

"@ | Out-File -LiteralPath $mergeLogicMd -Encoding utf8
Write-Host "  Wrote: evidence/merge_logic_$timestamp.md" -ForegroundColor Gray

# Evaluation notes
$evaluationNotesMd = Join-Path $EvidenceDir "evaluation_notes_$timestamp.md"
@"
# Phase 08 Semantic Labeling Evaluation

**Generated:** $timestamp
**Phase 04 Source:** $classificationCsv
**Semantic Rules:** $semanticRulesPath

## Executive Summary

Phase 08 applied semantic pattern matching to enhance Phase 04 baseline classification with context-aware rules.

### Key Achievements
- ✅ Analyzed $($semanticLabels.Count) files
- ✅ Applied $($semanticRules.Count) semantic rules
- ✅ Overrode $overrideCount low-confidence classifications with high-confidence semantic labels
- ✅ Boosted confidence for $boostCount files with semantic signals
- ✅ Identified $($semanticMisclassQueue.Count) files still requiring human review

## Confidence Distribution

### Phase 04 Baseline
- **High confidence (0.85+):** $(@($phase04Results | Where-Object { [double]$_.confidence -ge 0.85 }).Count) files
- **Medium confidence (0.60-0.84):** $(@($phase04Results | Where-Object { [double]$_.confidence -ge 0.60 -and [double]$_.confidence -lt 0.85 }).Count) files
- **Low confidence (<0.60):** $(@($phase04Results | Where-Object { [double]$_.confidence -lt 0.60 }).Count) files

### Post-Semantic
- **High confidence (0.85+):** $(@($semanticLabels | Where-Object { [double]$_['semantic_confidence'] -ge 0.85 }).Count) files
- **Medium confidence (0.60-0.84):** $(@($semanticLabels | Where-Object { [double]$_['semantic_confidence'] -ge 0.60 -and [double]$_['semantic_confidence'] -lt 0.85 }).Count) files
- **Low confidence (<0.60):** $(@($semanticLabels | Where-Object { [double]$_['semantic_confidence'] -lt 0.60 }).Count) files

## Semantic Rule Effectiveness

### Top Performing Rules (by match count)
"@ | Out-File -LiteralPath $evaluationNotesMd -Encoding utf8

# Count rule matches
$ruleMatches = @{}
foreach ($label in $semanticLabels) {
  $ruleId = $label['semantic_rule_id']
  if ($ruleId -ne 'NONE') {
    if (-not $ruleMatches.ContainsKey($ruleId)) {
      $ruleMatches[$ruleId] = 0
    }
    $ruleMatches[$ruleId]++
  }
}

$topRules = $ruleMatches.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First 10
foreach ($entry in $topRules) {
  "- **$($entry.Key)**: $($entry.Value) matches" | Out-File -LiteralPath $evaluationNotesMd -Encoding utf8 -Append
}

@"

## Low-Confidence Queue Analysis

$($semanticMisclassQueue.Count) files remain below confidence threshold and require human review:
- These files may benefit from additional semantic rules
- Manual classification can inform future rule development
- Consider creating classification_rules_v2.yaml after review

## Recommendations

1. **Review low-confidence queue** - Identify patterns in uncertain files
2. **Refine semantic rules** - Add rules for common patterns
3. **Update training examples** - Add more diverse examples
4. **Consider Phase 09** - Implement deduplication with semantic-aware logic

## Files

- **semantic_labels_$timestamp.csv** - All files with semantic analysis
- **semantic_misclass_queue_$timestamp.csv** - Files needing review
- **training_examples_manifest_$timestamp.csv** - Training set used
- **merge_logic_$timestamp.md** - Deterministic merge rules

"@ | Out-File -LiteralPath $evaluationNotesMd -Encoding utf8 -Append

Write-Host "  Wrote: evidence/evaluation_notes_$timestamp.md" -ForegroundColor Gray

# ============================================================
# Metrics
# ============================================================

$avgPhase04Conf = ($phase04Results | ForEach-Object { [double]$_.confidence } | Measure-Object -Average).Average
$avgSemanticConf = ($semanticLabels | ForEach-Object { [double]$_['semantic_confidence'] } | Measure-Object -Average).Average
$avgDelta = ($semanticLabels | ForEach-Object { [double]$_['confidence_delta'] } | Measure-Object -Average).Average

$metricsPath = Join-Path $RunRoot 'metrics.json'
@{
  phase = 8
  mode = $Mode
  files_analyzed = $semanticLabels.Count
  phase04_avg_confidence = [Math]::Round($avgPhase04Conf, 4)
  semantic_avg_confidence = [Math]::Round($avgSemanticConf, 4)
  avg_confidence_delta = [Math]::Round($avgDelta, 4)
  overrides = $overrideCount
  boosts = $boostCount
  penalties = $penaltyCount
  maintained = $semanticLabels.Count - $overrideCount - $boostCount - $penaltyCount
  low_confidence_queue = $semanticMisclassQueue.Count
  semantic_rules_applied = $semanticRules.Count
  at = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
} | ConvertTo-Json -Depth 5 | Out-File -LiteralPath $metricsPath -Encoding utf8

Write-Host "`n═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Phase 08 COMPLETE" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Mode: $Mode" -ForegroundColor Gray
Write-Host "Files analyzed: $($semanticLabels.Count)" -ForegroundColor Gray
Write-Host "Semantic improvements:" -ForegroundColor Gray
Write-Host "  - Overrides: $overrideCount" -ForegroundColor White
Write-Host "  - Boosts: $boostCount" -ForegroundColor White
Write-Host "  - Penalties: $penaltyCount" -ForegroundColor White
Write-Host "Avg confidence: $($avgPhase04Conf.ToString('F2')) → $($avgSemanticConf.ToString('F2')) (Δ $($avgDelta.ToString('F2')))" -ForegroundColor Gray
Write-Host "Low-confidence queue: $($semanticMisclassQueue.Count)" -ForegroundColor Yellow
Write-Host "Run root: $RunRoot" -ForegroundColor Gray
Write-Host ""

exit 0
