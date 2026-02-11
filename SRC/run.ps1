[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidateSet('00','01','02','03','04','05','06','07','07b','08')] [string]$Phase,
  [Parameter(Mandatory)][ValidateSet('DryRun','Execute')] [string]$Mode,
  [string]$RunId,
  [switch]$AllowExternalWrites
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string]$Msg, [int]$Code=1) { Write-Error $Msg; exit $Code }
function Normalize-Path([string]$Path) {
  return [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
}
function Test-IsUnderRoot([string]$Path, [string]$Root) {
  try {
    $p = (Normalize-Path $Path).ToLowerInvariant()
    $r = (Normalize-Path $Root).ToLowerInvariant()
    return ($p -eq $r -or $p.StartsWith($r + '\'))
  } catch {
    return $false
  }
}
function Assert-AllowedWritePath([string]$Path, [string]$What = 'path') {
  if ($AllowExternalWrites) { return }
  foreach ($root in $script:AllowedWriteRoots) {
    if (Test-IsUnderRoot -Path $Path -Root $root) { return }
  }
  $allowed = ($script:AllowedWriteRoots -join '; ')
  Fail "FAIL: blocked write target for ${What}: $Path. Allowed roots: $allowed. Re-run with -AllowExternalWrites to bypass." 44
}

$launchCwd = (Get-Location).Path
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not (Test-IsUnderRoot -Path $launchCwd -Root $repoRoot)) {
  Fail "FAIL: launch CWD must be inside repo root. launch=$launchCwd repo=$repoRoot" 43
}
Set-Location -LiteralPath $repoRoot

$sentinel = Join-Path $repoRoot 'RH_MIGRATION_2026_V2.SENTINEL'
if (!(Test-Path -LiteralPath $sentinel)) { Fail "FAIL: Missing sentinel: $sentinel" 2 }

$script:AllowedWriteRoots = @(
  (Join-Path $repoRoot 'OUTPUTS'),
  (Join-Path $repoRoot 'agent_assets')
)

# Hard stop: wrong universe
if ($repoRoot -match [regex]::Escape('C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026')) {
  Fail "FAIL: Legacy path detected. Wrong universe." 42
}

# External write guard: only explicitly permitted phases may bypass OUTPUTS/agent_assets boundaries.
if (($Mode -eq 'Execute') -and ($Phase -in @('06','07','07b')) -and (-not $AllowExternalWrites)) {
  Fail "FAIL: Phase $Phase Execute can write outside OUTPUTS/agent_assets and requires explicit -AllowExternalWrites." 45
}

$env:RH_ALLOW_EXTERNAL_WRITES = if ($AllowExternalWrites) { '1' } else { '0' }
$env:RH_ALLOWED_WRITE_ROOTS = ($script:AllowedWriteRoots -join ';')

# Phase 08 scope guard: block known pollution roots from semantic labeling scope.
if ($Phase -eq '08') {
  $semanticPolicy = Join-Path $repoRoot 'SRC\rules\semantic_policy_v1.yaml'
  if (!(Test-Path -LiteralPath $semanticPolicy)) {
    Fail "FAIL: Missing semantic policy for phase 08 scope: $semanticPolicy" 46
  }
  $policyText = Get-Content -LiteralPath $semanticPolicy -Raw
  $requiredExclusions = @('\agent_assets\', '\scratchpad\', '\staging\', '\downloads\')
  $missing = @()
  foreach ($needle in $requiredExclusions) {
    if ($policyText -notmatch [regex]::Escape($needle)) {
      $missing += $needle
    }
  }
  if ($missing.Count -gt 0) {
    Fail "FAIL: Phase 08 semantic policy missing required exclusions: $($missing -join ', ')" 47
  }
}

# Preflight first
& pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot 'tools\preflight.ps1')
if ($LASTEXITCODE -ne 0) { Fail "FAIL: preflight.ps1 failed" 3 }

$phaseDir = Join-Path $repoRoot "OUTPUTS\phase_$Phase"
Assert-AllowedWritePath -Path $phaseDir -What 'phaseDir'
if (!(Test-Path -LiteralPath $phaseDir)) { New-Item -ItemType Directory -Force -Path $phaseDir | Out-Null }

if ([string]::IsNullOrWhiteSpace($RunId)) {
  $RunId = "run_$(Get-Date -Format 'MM-dd-yyyy_HHmmss')"
}

$runRoot = Join-Path $phaseDir $RunId
$evidenceDir = Join-Path $runRoot 'evidence'
Assert-AllowedWritePath -Path $runRoot -What 'runRoot'
New-Item -ItemType Directory -Force -Path $evidenceDir | Out-Null

# ---- Audit spine (minimum contract)
$plan     = Join-Path $runRoot 'plan.csv'
$runlog   = Join-Path $runRoot 'runlog.txt'
$metrics  = Join-Path $runRoot 'metrics.json'
$rollback = Join-Path $runRoot 'rollback.ps1'
$summary  = Join-Path $runRoot "summary_$(Get-Date -Format 'MM-dd-yyyy').md"

Assert-AllowedWritePath -Path $plan -What 'plan'
Assert-AllowedWritePath -Path $runlog -What 'runlog'
Assert-AllowedWritePath -Path $metrics -What 'metrics'
Assert-AllowedWritePath -Path $rollback -What 'rollback'
Assert-AllowedWritePath -Path $summary -What 'summary'

if (!(Test-Path -LiteralPath $plan))     { "action_id,op,src_path,dst_path,notes" | Out-File -LiteralPath $plan -Encoding utf8 -NoNewline }
if (!(Test-Path -LiteralPath $runlog))   { "" | Out-File -LiteralPath $runlog -Encoding utf8 -NoNewline }
if (!(Test-Path -LiteralPath $rollback)) { "# rollback placeholder (Phase $Phase)" | Out-File -LiteralPath $rollback -Encoding utf8 -NoNewline }

@{
  phase=$Phase
  mode=$Mode
  run_id=$RunId
  repo_root=$repoRoot
  run_root=$runRoot
  started_utc=(Get-Date).ToUniversalTime().ToString("o")
} | ConvertTo-Json -Depth 6 | Out-File -LiteralPath $metrics -Encoding utf8 -NoNewline

@"
# Run Summary
- Phase: $Phase
- Mode: $Mode
- RunId: $RunId
- RepoRoot: $repoRoot
- RunRoot: $runRoot
- Started: $((Get-Date).ToString("MM-dd-yyyy HH:mm:ss"))
"@ | Out-File -LiteralPath $summary -Encoding utf8 -NoNewline

Add-Content -LiteralPath $runlog "START $(Get-Date) Phase=$Phase Mode=$Mode RunId=$RunId"

$phaseScript = Join-Path $repoRoot "SRC\phases\phase_$Phase.ps1"
if (!(Test-Path -LiteralPath $phaseScript)) { Fail "FAIL: Missing phase script: $phaseScript" 4 }

& pwsh -NoProfile -ExecutionPolicy Bypass -File $phaseScript -RepoRoot $repoRoot -RunRoot $runRoot -EvidenceDir $evidenceDir -Mode $Mode
if ($LASTEXITCODE -ne 0) { Fail "FAIL: phase script failed ($LASTEXITCODE)" $LASTEXITCODE }

Add-Content -LiteralPath $runlog "END $(Get-Date) OK"
exit 0
