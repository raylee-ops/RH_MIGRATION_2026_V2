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