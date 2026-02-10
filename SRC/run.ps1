[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidateSet('00','01','02','03','04','05','06','07','08')] [string]$Phase,
  [Parameter(Mandatory)][ValidateSet('DryRun','Execute')] [string]$Mode,
  [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string]$Msg, [int]$Code=1) { Write-Error $Msg; exit $Code }

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

$sentinel = Join-Path $repoRoot 'RH_MIGRATION_2026_V2.SENTINEL'
if (!(Test-Path -LiteralPath $sentinel)) { Fail "FAIL: Missing sentinel: $sentinel" 2 }

# Hard stop: wrong universe
if ($repoRoot.Path -match [regex]::Escape('C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026')) {
  Fail "FAIL: Legacy path detected. Wrong universe." 42
}

# Preflight first
& pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot 'tools\preflight.ps1')
if ($LASTEXITCODE -ne 0) { Fail "FAIL: preflight.ps1 failed" 3 }

$phaseDir = Join-Path $repoRoot "OUTPUTS\phase_$Phase"
if (!(Test-Path -LiteralPath $phaseDir)) { New-Item -ItemType Directory -Force -Path $phaseDir | Out-Null }

if ([string]::IsNullOrWhiteSpace($RunId)) {
  $RunId = "run_$(Get-Date -Format 'MM-dd-yyyy_HHmmss')"
}

$runRoot = Join-Path $phaseDir $RunId
$evidenceDir = Join-Path $runRoot 'evidence'
New-Item -ItemType Directory -Force -Path $evidenceDir | Out-Null

# ---- Audit spine (minimum contract)
$plan     = Join-Path $runRoot 'plan.csv'
$runlog   = Join-Path $runRoot 'runlog.txt'
$metrics  = Join-Path $runRoot 'metrics.json'
$rollback = Join-Path $runRoot 'rollback.ps1'
$summary  = Join-Path $runRoot "summary_$(Get-Date -Format 'MM-dd-yyyy').md"

if (!(Test-Path -LiteralPath $plan))     { "action_id,op,src_path,dst_path,notes" | Out-File -LiteralPath $plan -Encoding utf8 -NoNewline }
if (!(Test-Path -LiteralPath $runlog))   { "" | Out-File -LiteralPath $runlog -Encoding utf8 -NoNewline }
if (!(Test-Path -LiteralPath $rollback)) { "# rollback placeholder (Phase $Phase)" | Out-File -LiteralPath $rollback -Encoding utf8 -NoNewline }

@{
  phase=$Phase
  mode=$Mode
  run_id=$RunId
  repo_root=$repoRoot.Path
  run_root=$runRoot
  started_utc=(Get-Date).ToUniversalTime().ToString("o")
} | ConvertTo-Json -Depth 6 | Out-File -LiteralPath $metrics -Encoding utf8 -NoNewline

@"
# Run Summary
- Phase: $Phase
- Mode: $Mode
- RunId: $RunId
- RepoRoot: $($repoRoot.Path)
- RunRoot: $runRoot
- Started: $((Get-Date).ToString("MM-dd-yyyy HH:mm:ss"))
"@ | Out-File -LiteralPath $summary -Encoding utf8 -NoNewline

Add-Content -LiteralPath $runlog "START $(Get-Date) Phase=$Phase Mode=$Mode RunId=$RunId"

$phaseScript = Join-Path $repoRoot "SRC\phases\phase_$Phase.ps1"
if (!(Test-Path -LiteralPath $phaseScript)) { Fail "FAIL: Missing phase script: $phaseScript" 4 }

& pwsh -NoProfile -ExecutionPolicy Bypass -File $phaseScript -RepoRoot $repoRoot.Path -RunRoot $runRoot -EvidenceDir $evidenceDir -Mode $Mode
if ($LASTEXITCODE -ne 0) { Fail "FAIL: phase script failed ($LASTEXITCODE)" $LASTEXITCODE }

Add-Content -LiteralPath $runlog "END $(Get-Date) OK"
exit 0
