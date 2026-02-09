param(
  [Parameter(Mandatory=$true)]
  [ValidatePattern('^(00|01|02|03|04|05|06|07|08)$')]
  [string]$Phase,
  [string]$RunId
)

$ErrorActionPreference = "Stop"

function Fail($msg, $code=1) {
  Write-Host "FAIL ❌ $msg" -ForegroundColor Red
  exit $code
}

$root = (Get-Location).Path
$cfgPath = Join-Path $root "CONTRACTS\phase_requirements.json"
if (!(Test-Path $cfgPath)) { Fail "Missing contract file: $cfgPath" 2 }

$contract = Get-Content $cfgPath -Raw | ConvertFrom-Json

$phaseDir = Join-Path $root ("OUTPUTS\phase_{0}" -f $Phase)
if (!(Test-Path $phaseDir)) { Fail "Missing phase dir: $phaseDir" 2 }

# pick run folder
if ([string]::IsNullOrWhiteSpace($RunId)) {
  $runs = Get-ChildItem -Path $phaseDir -Directory -Filter "run_*" | Sort-Object LastWriteTime -Descending
  if (!$runs -or $runs.Count -eq 0) { Fail "No run_* folders found in $phaseDir" 2 }
  $run = $runs[0].FullName
} else {
  $run = Join-Path $phaseDir $RunId
  if (!(Test-Path $run)) { Fail "Run folder not found: $run" 2 }
}

Write-Host "Audit Phase $Phase" -ForegroundColor Cyan
Write-Host "Run: $run" -ForegroundColor Gray

# audit spine
$missing = @()
foreach ($f in $contract.audit_spine.required_files) {
  $p = Join-Path $run $f
  if (!(Test-Path $p)) { $missing += $f; continue }
  if ((Get-Item $p).Length -eq 0) { $missing += "$f (empty)" }
}
foreach ($g in $contract.audit_spine.required_globs) {
  $matches = Get-ChildItem -Path $run -Filter $g -File -ErrorAction SilentlyContinue
  if (!$matches -or $matches.Count -eq 0) { $missing += "$g (missing)" }
}
foreach ($d in $contract.audit_spine.required_dirs) {
  $dp = Join-Path $run $d
  if (!(Test-Path $dp)) { $missing += "$d/ (missing dir)" }
}

if ($missing.Count -gt 0) {
  Write-Host "Missing audit spine items:" -ForegroundColor Yellow
  $missing | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
  Fail "Audit spine incomplete" 1
}

# phase-specific evidence
$ph = $contract.phases.$Phase
if (!$ph) { Fail "No phase requirements found in contract for Phase $Phase" 2 }

$evidenceDir = Join-Path $run "evidence"
$foundEvidenceFiles = (Get-ChildItem -Path $evidenceDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count

$reqMissing = @()
foreach ($glob in $ph.required_evidence_globs) {
  # glob is relative to run; we support evidence/... patterns
  $rel = $glob.Replace("/", "\")
  $patternPath = Join-Path $run $rel
  $base = Split-Path $patternPath -Parent
  $filter = Split-Path $patternPath -Leaf
  $matches = Get-ChildItem -Path $base -Filter $filter -File -ErrorAction SilentlyContinue
  if (!$matches -or $matches.Count -eq 0) {
    $reqMissing += $glob
  }
}

if ($reqMissing.Count -gt 0) {
  Write-Host "Missing required evidence patterns:" -ForegroundColor Yellow
  $reqMissing | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
  Fail "Phase $Phase evidence incomplete" 1
}

if ($foundEvidenceFiles -lt [int]$ph.min_evidence_files) {
  Fail ("Evidence file count too low: {0} < {1}" -f $foundEvidenceFiles, $ph.min_evidence_files) 1
}

Write-Host "PASS ✅ Phase $Phase run is contract-complete" -ForegroundColor Green
exit 0
