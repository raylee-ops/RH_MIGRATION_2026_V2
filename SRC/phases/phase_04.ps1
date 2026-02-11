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

# ============================================================
# Configuration
# ============================================================

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
  'C:\RH\VAULT_NEVER_SYNC',
  'C:\LEGACY',
  'C:\Windows',
  'C:\Program Files',
  'C:\Program Files (x86)',
  'C:\Users'
)

$classificationRulesPath = Join-Path $RepoRoot 'SRC\rules\classification_rules_v1.yaml'
if (!(Test-Path -LiteralPath $classificationRulesPath)) {
  Fail "Missing classification rules file: $classificationRulesPath" 2
}

# ============================================================
# Load Classification Rules (YAML)
# ============================================================

Write-Host "Loading classification rules from: $classificationRulesPath" -ForegroundColor Cyan

$rulesContent = Get-Content -LiteralPath $classificationRulesPath -Raw -Encoding utf8

# Parse YAML manually (simple parser for this structure)
$rules = @()
$currentRule = $null

foreach ($line in ($rulesContent -split "`n")) {
  $line = $line.TrimEnd()

  if ($line -match '^\s*-\s+id:\s*(.+)$') {
    if ($currentRule) { $rules += $currentRule }
    $currentRule = @{
      id = $matches[1].Trim()
      bucket = ''
      confidence = 0.5
      match = @{ any = @(); ext = @() }
      reason_template = ''
    }
  }
  elseif ($currentRule) {
    if ($line -match '^\s+bucket:\s*(.+)$') {
      $currentRule.bucket = $matches[1].Trim()
    }
    elseif ($line -match '^\s+confidence:\s*(.+)$') {
      $currentRule.confidence = [double]$matches[1].Trim()
    }
    elseif ($line -match '^\s+reason_template:\s*"(.+)"$') {
      $currentRule.reason_template = $matches[1].Trim()
    }
    elseif ($line -match '^\s+any:\s*\[(.+)\]$') {
      $arrayContent = $matches[1]
      $currentRule.match.any = @($arrayContent -split ',' | ForEach-Object { $_.Trim(' "') })
    }
    elseif ($line -match '^\s+ext:\s*\[(.+)\]$') {
      $arrayContent = $matches[1]
      $currentRule.match.ext = @($arrayContent -split ',' | ForEach-Object { $_.Trim(' "') })
    }
  }
}
if ($currentRule) { $rules += $currentRule }

Write-Host "Loaded $($rules.Count) classification rules" -ForegroundColor Green

# ============================================================
# File Scanning
# ============================================================

Write-Host "`nScanning allowed roots..." -ForegroundColor Cyan
$allFiles = @()

foreach ($root in $allowedRoots) {
  if (!(Test-Path -LiteralPath $root)) {
    Write-Warning "Scan root does not exist: $root (skipping)"
    continue
  }

  Write-Host "  Scanning: $root" -ForegroundColor Gray

  $files = @(Get-ChildItem -LiteralPath $root -Recurse -File -Force -ErrorAction SilentlyContinue |
    Where-Object {
      $filePath = $_.FullName
      $excluded = $false

      # Check excluded roots
      foreach ($exRoot in $excludedRoots) {
        if (Test-IsUnderRoot -Path $filePath -Root $exRoot) {
          $excluded = $true
          break
        }
      }

      # Exclude repo itself
      if (Test-IsUnderRoot -Path $filePath -Root $RepoRoot) {
        $excluded = $true
      }

      -not $excluded
    })

  Write-Host "    Found: $($files.Count) files" -ForegroundColor Gray
  $allFiles += $files
}

Write-Host "`nTotal files to classify: $($allFiles.Count)" -ForegroundColor Green

# ============================================================
# Classification Engine
# ============================================================

Write-Host "`nClassifying files..." -ForegroundColor Cyan

$classificationResults = [System.Collections.ArrayList]::new()
$misclassQueue = [System.Collections.ArrayList]::new()

$lowConfidenceThreshold = 0.60

foreach ($file in $allFiles) {
  $sourcePath = $file.FullName
  $extension = $file.Extension.ToLowerInvariant()

  $bestRule = $null
  $bestConfidence = 0.0

  foreach ($rule in $rules) {
    $matched = $false

    # Check extension match
    if ($rule.match.ext.Count -gt 0) {
      foreach ($ext in $rule.match.ext) {
        if ($extension -eq $ext.ToLowerInvariant()) {
          $matched = $true
          break
        }
      }
    }

    # Check path match
    if (-not $matched -and $rule.match.any.Count -gt 0) {
      foreach ($pattern in $rule.match.any) {
        if ($pattern -eq '*') {
          $matched = $true
          break
        }
        if ($sourcePath -like "*$pattern*") {
          $matched = $true
          break
        }
      }
    }

    if ($matched -and $rule.confidence -gt $bestConfidence) {
      $bestRule = $rule
      $bestConfidence = $rule.confidence
    }
  }

  if ($null -eq $bestRule) {
    # Default to UNKNOWN
    $bestRule = $rules | Where-Object { $_.id -eq 'R_UNKNOWN_DEFAULT' } | Select-Object -First 1
    $bestConfidence = 0.50
  }

  $result = [ordered]@{
    source_path = $sourcePath
    bucket = $bestRule.bucket
    confidence = $bestConfidence
    rule_id = $bestRule.id
    reason = $bestRule.reason_template
    last_modified = $file.LastWriteTime.ToString('M/d/yyyy h:mm:ss tt')
    size_bytes = $file.Length
  }

  [void]$classificationResults.Add($result)

  # Queue for review if low confidence
  if ($bestConfidence -lt $lowConfidenceThreshold) {
    $misclass = [ordered]@{
      source_path = $sourcePath
      top_guess_bucket = $bestRule.bucket
      confidence = $bestConfidence
      why_uncertain = "Low confidence below threshold"
      suggested_question = "Confirm correct bucket for this path"
    }
    [void]$misclassQueue.Add($misclass)
  }
}

Write-Host "Classification complete: $($classificationResults.Count) files" -ForegroundColor Green
Write-Host "Low-confidence queue: $($misclassQueue.Count) files" -ForegroundColor Yellow

# ============================================================
# Write Outputs
# ============================================================

Write-Host "`nWriting outputs..." -ForegroundColor Cyan

# Classification results
$classificationCsv = Join-Path $RunRoot 'classification_results.csv'
$classificationResults | ForEach-Object { [pscustomobject]$_ } |
  Export-Csv -LiteralPath $classificationCsv -NoTypeInformation -Encoding utf8
Write-Host "  Wrote: classification_results.csv" -ForegroundColor Gray

# Misclass queue
$misclassCsv = Join-Path $RunRoot 'misclass_queue.csv'
if ($misclassQueue.Count -gt 0) {
  $misclassQueue | ForEach-Object { [pscustomobject]$_ } |
    Export-Csv -LiteralPath $misclassCsv -NoTypeInformation -Encoding utf8
} else {
  '"source_path","top_guess_bucket","confidence","why_uncertain","suggested_question"' |
    Out-File -LiteralPath $misclassCsv -Encoding utf8 -NoNewline
}
Write-Host "  Wrote: misclass_queue.csv" -ForegroundColor Gray

# Bucket taxonomy
$taxonomyMd = Join-Path $RunRoot 'bucket_taxonomy.md'
@"
# Bucket Taxonomy (v1)
- PROJECT: Working code/config/docs in OPS projects
- NOTES: Markdown notes and planning docs
- EVIDENCE: Screenshots, logs, run outputs
- MEDIA: Images/video/audio
- ARCHIVE: Zips, exports, old snapshots
- UNKNOWN: Needs human decision
"@ | Out-File -LiteralPath $taxonomyMd -Encoding utf8
Write-Host "  Wrote: bucket_taxonomy.md" -ForegroundColor Gray

# Copy classification rules to run folder
$rulesCopy = Join-Path $RunRoot 'classification_rules_v1.yaml'
Copy-Item -LiteralPath $classificationRulesPath -Destination $rulesCopy -Force
Write-Host "  Wrote: classification_rules_v1.yaml" -ForegroundColor Gray

# ============================================================
# Evidence Files
# ============================================================

Write-Host "`nWriting evidence..." -ForegroundColor Cyan

# Copy classification results to evidence
$evidenceClassificationCsv = Join-Path $EvidenceDir "classification_results_$timestamp.csv"
Copy-Item -LiteralPath $classificationCsv -Destination $evidenceClassificationCsv -Force
Write-Host "  Wrote: evidence/classification_results_$timestamp.csv" -ForegroundColor Gray

# Copy misclass queue to evidence
$evidenceMisclassCsv = Join-Path $EvidenceDir "misclass_queue_$timestamp.csv"
Copy-Item -LiteralPath $misclassCsv -Destination $evidenceMisclassCsv -Force
Write-Host "  Wrote: evidence/misclass_queue_$timestamp.csv" -ForegroundColor Gray

# Copy taxonomy to evidence
$evidenceTaxonomyMd = Join-Path $EvidenceDir "bucket_taxonomy_$timestamp.md"
Copy-Item -LiteralPath $taxonomyMd -Destination $evidenceTaxonomyMd -Force
Write-Host "  Wrote: evidence/bucket_taxonomy_$timestamp.md" -ForegroundColor Gray

# Rules version JSON
$rulesVersionJson = Join-Path $EvidenceDir "rules_version_$timestamp.json"
@{
  version = 1
  rules_file = 'SRC\rules\classification_rules_v1.yaml'
  rules_count = $rules.Count
  generated_at = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
  low_confidence_threshold = $lowConfidenceThreshold
} | ConvertTo-Json -Depth 5 | Out-File -LiteralPath $rulesVersionJson -Encoding utf8
Write-Host "  Wrote: evidence/rules_version_$timestamp.json" -ForegroundColor Gray

# ============================================================
# Metrics
# ============================================================

$bucketCounts = @{}
foreach ($result in $classificationResults) {
  $bucket = $result['bucket']
  if (-not $bucketCounts.ContainsKey($bucket)) {
    $bucketCounts[$bucket] = 0
  }
  $bucketCounts[$bucket]++
}

$metricsPath = Join-Path $RunRoot 'metrics.json'
@{
  phase = 4
  mode = $Mode
  files_scanned = $allFiles.Count
  files_classified = $classificationResults.Count
  low_confidence_count = $misclassQueue.Count
  bucket_distribution = $bucketCounts
  at = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
} | ConvertTo-Json -Depth 5 | Out-File -LiteralPath $metricsPath -Encoding utf8

Write-Host "`nPhase 04 COMPLETE" -ForegroundColor Green
Write-Host "Mode: $Mode" -ForegroundColor Gray
Write-Host "Files classified: $($classificationResults.Count)" -ForegroundColor Gray
Write-Host "Low-confidence queue: $($misclassQueue.Count)" -ForegroundColor Gray
Write-Host "Run root: $RunRoot" -ForegroundColor Gray

exit 0
