# tools\bootstrap_phase03.ps1
# Creates Phase 03 control-plane files WITHOUT overwriting existing ones.
# Writes with _01/_02 suffix if collisions exist.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string]$Msg, [int]$Code=1) { Write-Error $Msg; exit $Code }

function Ensure-Dir([string]$Path) {
  if (!(Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Force -Path $Path | Out-Null }
}

function Get-AvailablePath([string]$Path) {
  if (!(Test-Path -LiteralPath $Path)) { return $Path }
  $dir  = Split-Path -Parent $Path
  $base = Split-Path -LeafBase $Path
  $ext  = [IO.Path]::GetExtension($Path)
  for ($i=1; $i -le 99; $i++) {
    $p = Join-Path $dir ("{0}_{1:D2}{2}" -f $base,$i,$ext)
    if (!(Test-Path -LiteralPath $p)) { return $p }
  }
  Fail "Too many collisions for $Path" 3
}

function Write-Safe([string]$Path, [string]$Content) {
  $out = Get-AvailablePath $Path
  $Content | Out-File -LiteralPath $out -Encoding utf8 -NoNewline
  Write-Host "✅ Wrote: $out"
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

$sentinel = Join-Path $repoRoot 'RH_MIGRATION_2026_V2.SENTINEL'
if (!(Test-Path -LiteralPath $sentinel)) { Fail "Sentinel missing. Wrong folder." 2 }

if ($repoRoot.Path -match [regex]::Escape('C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026')) {
  Fail "Legacy path detected. Refusing to run in the wrong universe." 42
}

$contractsDir = Join-Path $repoRoot 'CONTRACTS'
$srcDir       = Join-Path $repoRoot 'SRC'
$phasesDir    = Join-Path $srcDir   'phases'
Ensure-Dir $contractsDir
Ensure-Dir $srcDir
Ensure-Dir $phasesDir

# ---- CONTRACT doc (Phase 03)
$phase03Doc = @'
# Phase 03 — Control Plane (Runner + DryRun enforcement)

This phase creates a single entrypoint that:
- refuses to run outside repo root (sentinel required)
- runs tools/preflight.ps1 before anything else
- writes all run artifacts to OUTPUTS\phase_XX\run_MM-DD-YYYY_HHMMSS\
- executes exactly one phase script: SRC\phases\phase_XX.ps1

Completion proof lives in:
OUTPUTS\phase_03\run_*\evidence\
- run_interface_*.md
- dryrun_validation_checklist_*.md
- canonical_paths_proof_*.txt
- runner_used_runps1_hash_*.txt
- runner_used_config_hash_*.txt
'@
Write-Safe (Join-Path $contractsDir 'phase_03_control_plane.md') $phase03Doc

# ---- SRC\run.ps1 (Runner)
$runPs1 = @'
[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidateSet('00','01','02','03','04','05','06','07','08')] [string]$Phase,
  [Parameter(Mandatory)][ValidateSet('DryRun','Execute')] [string]$Mode,
  [string]$RunId
)

$ErrorActionPreference = 'Stop'
function Fail($msg,$code=1){ Write-Error $msg; exit $code }

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

$sentinel = Join-Path $repoRoot 'RH_MIGRATION_2026_V2.SENTINEL'
if (!(Test-Path $sentinel)) { Fail "FAIL: Missing sentinel: $sentinel" 2 }

if ($repoRoot.Path -match [regex]::Escape('C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026')) {
  Fail "FAIL: Legacy migration path detected. Wrong universe." 42
}

& pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot 'tools\preflight.ps1')
if ($LASTEXITCODE -ne 0) { Fail "FAIL: preflight.ps1 failed" 3 }

$phaseDir = Join-Path $repoRoot ("OUTPUTS\phase_{0}" -f $Phase)
if (!(Test-Path $phaseDir)) { New-Item -ItemType Directory -Force -Path $phaseDir | Out-Null }

if ([string]::IsNullOrWhiteSpace($RunId)) {
  $RunId = "run_{0}" -f (Get-Date -Format "MM-dd-yyyy_HHmmss")
}

$runRoot = Join-Path $phaseDir $RunId
$evidenceDir = Join-Path $runRoot 'evidence'
New-Item -ItemType Directory -Force -Path $evidenceDir | Out-Null

# audit spine placeholders (phase scripts can extend)
$plan     = Join-Path $runRoot 'plan.csv'
$runlog   = Join-Path $runRoot 'runlog.txt'
$metrics  = Join-Path $runRoot 'metrics.json'
$rollback = Join-Path $runRoot 'rollback.ps1'
$summary  = Join-Path $runRoot ("summary_{0}.md" -f (Get-Date -Format "MM-dd-yyyy"))

if (!(Test-Path $plan))     { "action_id,op,src_path,dst_path,notes" | Out-File -Encoding utf8 -NoNewline $plan }
if (!(Test-Path $runlog))   { "" | Out-File -Encoding utf8 -NoNewline $runlog }
if (!(Test-Path $rollback)) { "# rollback placeholder" | Out-File -Encoding utf8 -NoNewline $rollback }

@{
  phase=$Phase; mode=$Mode; run_id=$RunId; repo_root=$repoRoot.Path;
  started_utc=(Get-Date).ToUniversalTime().ToString("o")
} | ConvertTo-Json -Depth 5 | Out-File -Encoding utf8 -NoNewline $metrics

@"
# Run Summary
- Phase: $Phase
- Mode: $Mode
- RunId: $RunId
- RepoRoot: $($repoRoot.Path)
- Started: $((Get-Date).ToString("MM-dd-yyyy HH:mm:ss"))
"@ | Out-File -Encoding utf8 -NoNewline $summary

Add-Content $runlog ("START {0} Phase={1} Mode={2} RunId={3}" -f (Get-Date), $Phase, $Mode, $RunId)

$phaseScript = Join-Path $repoRoot ("SRC\phases\phase_{0}.ps1" -f $Phase)
if (!(Test-Path $phaseScript)) { Fail "FAIL: Missing phase script: $phaseScript" 4 }

& pwsh -NoProfile -ExecutionPolicy Bypass -File $phaseScript -RepoRoot $repoRoot.Path -RunRoot $runRoot -EvidenceDir $evidenceDir -Mode $Mode
if ($LASTEXITCODE -ne 0) { Fail "FAIL: phase script failed ($LASTEXITCODE)" $LASTEXITCODE }

Add-Content $runlog ("END {0} OK" -f (Get-Date))
exit 0
'@
Write-Safe (Join-Path $srcDir 'run.ps1') $runPs1

# ---- SRC\phases\phase_03.ps1 (Phase 03 evidence generator)
$phase03Ps1 = @'
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$RepoRoot,
  [Parameter(Mandatory)][string]$RunRoot,
  [Parameter(Mandatory)][string]$EvidenceDir,
  [Parameter(Mandatory)][ValidateSet('DryRun','Execute')][string]$Mode
)

$ErrorActionPreference = 'Stop'
$today = Get-Date -Format "MM-dd-yyyy"

@"
# Runner Interface (Phase 03)
Date: $today

Canonical entrypoint:
pwsh -NoProfile -ExecutionPolicy Bypass -File SRC\run.ps1 -Phase <00-08> -Mode <DryRun|Execute> [-RunId run_MM-dd-yyyy_HHmmss]

Hard stops:
- missing RH_MIGRATION_2026_V2.SENTINEL
- preflight failure
- legacy path detected
- missing phase script
"@ | Out-File -Encoding utf8 -NoNewline (Join-Path $EvidenceDir "run_interface_$today.md")

@"
# DryRun Validation Checklist (Phase 03)
Date: $today
RepoRoot: $RepoRoot
RunRoot:  $RunRoot
Evidence: $EvidenceDir
Mode:     $Mode
"@ | Out-File -Encoding utf8 -NoNewline (Join-Path $EvidenceDir "dryrun_validation_checklist_$today.md")

@"
RepoRoot: $RepoRoot
RunRoot:  $RunRoot
EvidenceDir: $EvidenceDir
SentinelPresent: $(Test-Path (Join-Path $RepoRoot 'RH_MIGRATION_2026_V2.SENTINEL'))
"@ | Out-File -Encoding utf8 -NoNewline (Join-Path $EvidenceDir "canonical_paths_proof_$today.txt")

$runps1 = Join-Path $RepoRoot 'SRC\run.ps1'
$config = Join-Path $RepoRoot 'project_config.json'

if (Test-Path $runps1) {
  (Get-FileHash $runps1 -Algorithm SHA256 | ForEach-Object { "$($_.Algorithm) $($_.Hash) $runps1" }) |
    Out-File -Encoding utf8 -NoNewline (Join-Path $EvidenceDir "runner_used_runps1_hash_$today.txt")
}

if (Test-Path $config) {
  (Get-FileHash $config -Algorithm SHA256 | ForEach-Object { "$($_.Algorithm) $($_.Hash) $config" }) |
    Out-File -Encoding utf8 -NoNewline (Join-Path $EvidenceDir "runner_used_config_hash_$today.txt")
}

exit 0
'@
Write-Safe (Join-Path $phasesDir 'phase_03.ps1') $phase03Ps1

Write-Host "`nPhase 03 bootstrap done. Now run:"
Write-Host "  pwsh -NoProfile -ExecutionPolicy Bypass -File tools\preflight.ps1"
Write-Host "  pwsh -NoProfile -ExecutionPolicy Bypass -File SRC\run.ps1 -Phase 03 -Mode DryRun"
Write-Host "  pwsh -NoProfile -ExecutionPolicy Bypass -File tools\audit_phase.ps1 -Phase 03"
