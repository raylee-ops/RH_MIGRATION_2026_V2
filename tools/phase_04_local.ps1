param(
  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  [string]$OutDir,

  [string[]]$Roots = @("C:\RH\OPS","C:\RH\INBOX","C:\RH\TEMPORARY"),

  [double]$LowConfidenceThreshold = 0.80
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Safety: OutDir must exist and be inside OUTPUTS
$fullOut = (Resolve-Path -LiteralPath $OutDir).Path
if ($fullOut -notmatch "\\OUTPUTS\\phase_04\\run_\d{2}-\d{2}-\d{4}_\d{6}$") {
  throw "OutDir must be like ...\OUTPUTS\phase_04\run_MM-DD-YYYY_HHMMSS (got: $fullOut)"
}

$taxonomyPath = Join-Path $fullOut "bucket_taxonomy.md"
$rulesPath    = Join-Path $fullOut "classification_rules_v1.yaml"
$resultsPath  = Join-Path $fullOut "classification_results.csv"
$misqPath     = Join-Path $fullOut "misclass_queue.csv"
$metricsPath  = Join-Path $fullOut "metrics.json"

@"
# Bucket Taxonomy (v1)
- PROJECT: Working code/config/docs in OPS projects
- NOTES: Markdown notes and planning docs
- EVIDENCE: Screenshots, logs, run outputs
- MEDIA: Images/video/audio
- ARCHIVE: Zips, exports, old snapshots
- UNKNOWN: Needs human decision
"@ | Set-Content -Encoding UTF8 -Path $taxonomyPath

@"
version: 1
rules:
  - id: R_PROJECT
    bucket: PROJECT
    confidence: 0.90
    match:
      any: ["\\OPS\\PROJECTS\\", "\\SRC\\", "\\TOOLS\\"]
    reason_template: "Project structure path"

  - id: R_NOTES
    bucket: NOTES
    confidence: 0.85
    match:
      ext: [".md", ".txt"]
    reason_template: "Notes-like extension"

  - id: R_EVIDENCE
    bucket: EVIDENCE
    confidence: 0.90
    match:
      any: ["\\OUTPUTS\\", "\\evidence\\"]
    reason_template: "Evidence/output path"

  - id: R_MEDIA
    bucket: MEDIA
    confidence: 0.85
    match:
      ext: [".png", ".jpg", ".jpeg", ".gif", ".webp", ".mp4", ".mov"]
    reason_template: "Media extension"

  - id: R_ARCHIVE
    bucket: ARCHIVE
    confidence: 0.85
    match:
      ext: [".zip", ".7z", ".rar"]
    reason_template: "Archive extension"

  - id: R_UNKNOWN_DEFAULT
    bucket: UNKNOWN
    confidence: 0.50
    match:
      any: ["*"]
    reason_template: "Default bucket (no specific rule matched)"
"@ | Set-Content -Encoding UTF8 -Path $rulesPath

function Get-RuleHit {
  param([string]$Path)

  $ext = [IO.Path]::GetExtension($Path).ToLowerInvariant()

  # Ordered rules (best-first)
  if ($Path -match "\\OPS\\PROJECTS\\" -or $Path -match "\\SRC\\" -or $Path -match "\\TOOLS\\") {
    return @{bucket="PROJECT"; confidence=0.90; rule_id="R_PROJECT"; reason="Project structure path"}
  }
  if ($ext -in @(".md",".txt")) {
    return @{bucket="NOTES"; confidence=0.85; rule_id="R_NOTES"; reason="Notes-like extension"}
  }
  if ($Path -match "\\OUTPUTS\\" -or $Path -match "\\evidence\\") {
    return @{bucket="EVIDENCE"; confidence=0.90; rule_id="R_EVIDENCE"; reason="Evidence/output path"}
  }
  if ($ext -in @(".png",".jpg",".jpeg",".gif",".webp",".mp4",".mov")) {
    return @{bucket="MEDIA"; confidence=0.85; rule_id="R_MEDIA"; reason="Media extension"}
  }
  if ($ext -in @(".zip",".7z",".rar")) {
    return @{bucket="ARCHIVE"; confidence=0.85; rule_id="R_ARCHIVE"; reason="Archive extension"}
  }

  return @{bucket="UNKNOWN"; confidence=0.50; rule_id="R_UNKNOWN_DEFAULT"; reason="Default bucket (no specific rule matched)"}
}

$items = @()
foreach ($r in $Roots) {
  if (Test-Path -LiteralPath $r) {
    $items += Get-ChildItem -LiteralPath $r -Recurse -File -ErrorAction SilentlyContinue |
      Select-Object FullName, LastWriteTime, Length
  }
}

$results = foreach ($it in $items) {
  $hit = Get-RuleHit -Path $it.FullName
  [pscustomobject]@{
    source_path   = $it.FullName
    bucket        = $hit.bucket
    confidence    = [math]::Round([double]$hit.confidence, 2)
    rule_id       = $hit.rule_id
    reason        = $hit.reason
    last_modified = $it.LastWriteTime
    size_bytes    = $it.Length
  }
}

$results | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $resultsPath

$results |
  Where-Object { $_.confidence -lt $LowConfidenceThreshold } |
  Select-Object source_path,
    @{n="top_guess_bucket";e={$_.bucket}},
    confidence,
    @{n="why_uncertain";e={"Low confidence below threshold"}},
    @{n="suggested_question";e={"Confirm correct bucket for this path"}} |
  Export-Csv -NoTypeInformation -Encoding UTF8 -Path $misqPath

@{
  phase = 4
  roots = $Roots
  item_count = $items.Count
  low_conf_threshold = $LowConfidenceThreshold
  low_conf_count = @($results | Where-Object { $_.confidence -lt $LowConfidenceThreshold }).Count
  generated_at = (Get-Date).ToString("s")
} | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 -Path $metricsPath

"OK Phase 04 local artifacts created at: $fullOut"
