#Requires -Version 7.0

<#
.SYNOPSIS
    Pre-flight checks before running phase tools

.DESCRIPTION
    Verifies project environment is ready:
    - Confirms we're in repo root (project_config.json + AGENTS_PROJECT.md exist)
    - Runs tools/validate_config.ps1 (must pass)
    - Confirms OUTPUTS is in .gitignore
    - Prints artifact lane contract

.PARAMETER ProjectRoot
    Project root path (defaults to script's grandparent directory)

.EXAMPLE
    .\tools\preflight.ps1
    pwsh -NoProfile -ExecutionPolicy Bypass -File "tools\preflight.ps1"

.NOTES
    Exit codes:
    0 = All checks passed
    1 = One or more checks failed
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = "$PSScriptRoot\.."
)

$ErrorActionPreference = 'Stop'

function Write-PassMessage {
    param([string]$Message)
    Write-Host "✅ PASS: $Message" -ForegroundColor Green
}

function Write-FailMessage {
    param([string]$Message)
    Write-Host "❌ FAIL: $Message" -ForegroundColor Red
}

function Write-InfoMessage {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Cyan
}

# Header
Write-Host ""
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor White
Write-Host "Pre-Flight Checks" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor White
Write-Host ""

$checksFailed = $false

# Check 1: Verify we're in repo root
Write-InfoMessage "Checking repo root..."

$configPath = Join-Path $ProjectRoot "project_config.json"

# --- V2 Root Tripwire ---
$here = (Get-Location).Path
$sentinel = Join-Path $here "RH_MIGRATION_2026_V2.SENTINEL"
if (!(Test-Path $sentinel)) {
  Write-Host "FAIL ❌ Missing sentinel: $sentinel" -ForegroundColor Red
  Write-Host "You are probably in the WRONG folder (common failure: V1 system migrations path)." -ForegroundColor Yellow
  exit 1
}
if ($here -like "*\OPS\SYSTEM\migrations\RH_MIGRATION_2026*") {
  Write-Host "FAIL ❌ You are in archived V1 path: $here" -ForegroundColor Red
  Write-Host "CD into: C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2" -ForegroundColor Yellow
  exit 1
}

# Verify project_root in config matches actual working directory (prevents ghost runs)
try {
  $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
  if ($cfg.project_root -and ($cfg.project_root -ne $here)) {
    Write-Host "FAIL ❌ project_config.json project_root mismatch" -ForegroundColor Red
    Write-Host "  Config project_root: $($cfg.project_root)" -ForegroundColor Yellow
    Write-Host "  Current directory : $here" -ForegroundColor Yellow
    Write-Host "Fix by running from the configured project_root OR updating project_config.json.project_root." -ForegroundColor Yellow
    exit 1
  }
} catch {
  # config validation later will catch parse issues; we don't double-fail here
}
# --- End V2 Root Tripwire ---
$agentsPath = Join-Path $ProjectRoot "AGENTS_PROJECT.md"

if ((Test-Path -LiteralPath $configPath) -and (Test-Path -LiteralPath $agentsPath)) {
    Write-PassMessage "Repo root confirmed (project_config.json + AGENTS_PROJECT.md found)"
    Write-Host "  Location: $ProjectRoot" -ForegroundColor Gray
} else {
    Write-FailMessage "Not in repo root (missing project_config.json or AGENTS_PROJECT.md)"
    $checksFailed = $true
}

Write-Host ""

# Check 2: Run validate_config.ps1
Write-InfoMessage "Running config validation..."

$validateScriptPath = Join-Path $ProjectRoot "tools\validate_config.ps1"
if (-not (Test-Path -LiteralPath $validateScriptPath)) {
    Write-FailMessage "tools/validate_config.ps1 not found"
    $checksFailed = $true
} else {
    try {
        $output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $validateScriptPath 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            Write-PassMessage "Config validation passed"
        } else {
            Write-FailMessage "Config validation failed (exit code: $exitCode)"
            Write-Host ""
            Write-InfoMessage "Validation output:"
            $output | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
            $checksFailed = $true
        }
    } catch {
        Write-FailMessage "Config validation error: $_"
        $checksFailed = $true
    }
}

Write-Host ""

# Check 3: Verify OUTPUTS is in .gitignore
Write-InfoMessage "Checking .gitignore for OUTPUTS..."

$gitignorePath = Join-Path $ProjectRoot ".gitignore"
if (-not (Test-Path -LiteralPath $gitignorePath)) {
    Write-FailMessage ".gitignore not found"
    $checksFailed = $true
} else {
    try {
        # Use git check-ignore to verify
        Push-Location $ProjectRoot
        $checkIgnoreOutput = git check-ignore -v "OUTPUTS" 2>&1
        Pop-Location

        if ($LASTEXITCODE -eq 0) {
            Write-PassMessage "OUTPUTS is ignored by git"
            Write-Host "  Rule: $checkIgnoreOutput" -ForegroundColor Gray
        } else {
            Write-FailMessage "OUTPUTS is NOT ignored by git"
            Write-InfoMessage "Add 'OUTPUTS/' to .gitignore"
            $checksFailed = $true
        }
    } catch {
        Write-FailMessage "Could not verify .gitignore: $_"
        $checksFailed = $true
    }
}

Write-Host ""

# Print artifact lane contract
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor White
Write-Host "Artifact Lane Contract" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor White
Write-Host ""

Write-Host "OUTPUTS/ — Messy Generated Lane" -ForegroundColor Yellow
Write-Host "  • All phase run artifacts (verbose, timestamped)" -ForegroundColor Gray
Write-Host "  • Location: OUTPUTS\phase_XX\run_MM-DD-YYYY_HHMMSS\" -ForegroundColor Gray
Write-Host "  • Git status: NEVER committed (in .gitignore)" -ForegroundColor Gray
Write-Host "  • Usage: Execution outputs only, NOT inputs" -ForegroundColor Gray
Write-Host ""

Write-Host "PROOF_PACK/ — Curated Recruiter-Safe Lane" -ForegroundColor Green
Write-Host "  • Polished artifacts for portfolio/interviews" -ForegroundColor Gray
Write-Host "  • Location: PROOF_PACK\phase_XX\run_<run_id>\" -ForegroundColor Gray
Write-Host "  • Git status: ALWAYS committed" -ForegroundColor Gray
Write-Host "  • Usage: Repo is PROOF_PACK-first" -ForegroundColor Gray
Write-Host ""

Write-Host "Promotion Rule:" -ForegroundColor Cyan
Write-Host "  Only curated artifacts copied from OUTPUTS → PROOF_PACK" -ForegroundColor Gray
Write-Host "  Use: tools/promote_to_proof_pack.ps1" -ForegroundColor Gray
Write-Host ""

# Summary
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor White

if ($checksFailed) {
    Write-Host "❌ PRE-FLIGHT FAILED" -ForegroundColor Red -BackgroundColor Black
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor White
    Write-Host ""
    Write-InfoMessage "Fix the issues above before running phase tools."
    Write-Host ""
    exit 1
} else {
    Write-Host "✅ PRE-FLIGHT PASSED" -ForegroundColor Green -BackgroundColor Black
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor White
    Write-Host ""
    Write-InfoMessage "Environment ready. Safe to run phase tools."
    Write-Host ""
    exit 0
}
