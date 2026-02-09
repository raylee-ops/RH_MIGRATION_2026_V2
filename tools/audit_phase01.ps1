#Requires -Version 7.0

<#
.SYNOPSIS
    Audits Phase 01 run outputs for completeness

.DESCRIPTION
    Read-only audit script that verifies Phase 01 run artifacts:
    - Finds newest run_* folder under OUTPUTS\phase_01\
    - Verifies required files exist and are non-empty
    - Reports PASS/UNKNOWN status with missing/empty items

.PARAMETER ProjectRoot
    Path to project root (defaults to script's grandparent directory)

.EXAMPLE
    .\tools\audit_phase01.ps1
    pwsh -NoProfile -ExecutionPolicy Bypass -File "tools\audit_phase01.ps1"

.NOTES
    This script is READ-ONLY and does not modify any files.
    Only scans OUTPUTS\phase_01\ directory.

    Exit codes:
    0 = PASS (all required artifacts present and valid)
    1 = UNKNOWN (missing artifacts or empty files)
    2 = No phase_01 runs found
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

function Write-UnknownMessage {
    param([string]$Message)
    Write-Host "⚠️  UNKNOWN: $Message" -ForegroundColor Yellow
}

function Write-InfoMessage {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Cyan
}

function Test-FileNotEmpty {
    param([string]$FilePath)

    if (-not (Test-Path -LiteralPath $FilePath)) {
        return $false
    }

    $size = (Get-Item -LiteralPath $FilePath).Length
    return $size -gt 0
}

# Header
Write-Host ""
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor White
Write-Host "Phase 01 Audit" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor White
Write-Host ""

# Locate phase_01 directory
$phase01Path = Join-Path $ProjectRoot "OUTPUTS\phase_01"
Write-InfoMessage "Scanning: $phase01Path"

if (-not (Test-Path -LiteralPath $phase01Path)) {
    Write-UnknownMessage "Phase 01 outputs directory not found: $phase01Path"
    Write-Host ""
    exit 2
}

# Find newest run_* folder
$runFolders = Get-ChildItem -LiteralPath $phase01Path -Directory -Filter "run_*" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending

if ($runFolders.Count -eq 0) {
    Write-UnknownMessage "No run_* folders found in phase_01"
    Write-Host ""
    exit 2
}

$newestRun = $runFolders[0]
$runPath = $newestRun.FullName

Write-Host ""
Write-InfoMessage "Selected run: $($newestRun.Name)"
Write-InfoMessage "Path: $runPath"
Write-InfoMessage "Last modified: $($newestRun.LastWriteTime)"
Write-Host ""

# Define required artifacts
$requiredFiles = @(
    @{ Name = 'plan.csv'; Path = Join-Path $runPath 'plan.csv' }
    @{ Name = 'runlog.txt'; Path = Join-Path $runPath 'runlog.txt' }
    @{ Name = 'metrics.json'; Path = Join-Path $runPath 'metrics.json' }
    @{ Name = 'rollback.ps1'; Path = Join-Path $runPath 'rollback.ps1' }
)

$evidencePath = Join-Path $runPath 'evidence'

# Track validation results
$missingItems = @()
$emptyItems = @()
$allPassed = $true

# Check required files
Write-InfoMessage "Checking required files..."
Write-Host ""

foreach ($file in $requiredFiles) {
    $exists = Test-Path -LiteralPath $file.Path
    $notEmpty = $exists -and (Test-FileNotEmpty -FilePath $file.Path)

    if (-not $exists) {
        Write-UnknownMessage "$($file.Name) - MISSING"
        $missingItems += $file.Name
        $allPassed = $false
    } elseif (-not $notEmpty) {
        Write-UnknownMessage "$($file.Name) - EMPTY (0 bytes)"
        $emptyItems += $file.Name
        $allPassed = $false
    } else {
        $size = (Get-Item -LiteralPath $file.Path).Length
        Write-PassMessage "$($file.Name) - OK ($size bytes)"
    }
}

# Check evidence directory
$evidenceExists = Test-Path -LiteralPath $evidencePath
if (-not $evidenceExists) {
    Write-UnknownMessage "evidence\ - MISSING"
    $missingItems += 'evidence\'
    $allPassed = $false
} else {
    $evidenceFiles = Get-ChildItem -LiteralPath $evidencePath -File -ErrorAction SilentlyContinue
    $evidenceCount = $evidenceFiles.Count

    if ($evidenceCount -eq 0) {
        Write-UnknownMessage "evidence\ - EMPTY (no files)"
        $emptyItems += 'evidence\'
        $allPassed = $false
    } else {
        Write-PassMessage "evidence\ - OK ($evidenceCount files)"
    }
}

# Summary
Write-Host ""
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor White

if ($allPassed) {
    Write-Host "✅ PASS - All required artifacts present" -ForegroundColor Green -BackgroundColor Black
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor White
    Write-Host ""
    Write-InfoMessage "Phase 01 audit completed successfully."
    Write-Host ""
    exit 0
} else {
    Write-Host "⚠️  UNKNOWN - Missing or empty artifacts" -ForegroundColor Yellow -BackgroundColor Black
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor White
    Write-Host ""

    if ($missingItems.Count -gt 0) {
        Write-InfoMessage "Missing items:"
        foreach ($item in $missingItems) {
            Write-Host "  - $item" -ForegroundColor Yellow
        }
        Write-Host ""
    }

    if ($emptyItems.Count -gt 0) {
        Write-InfoMessage "Empty items:"
        foreach ($item in $emptyItems) {
            Write-Host "  - $item" -ForegroundColor Yellow
        }
        Write-Host ""
    }

    Write-InfoMessage "Phase 01 may be incomplete or pending execution."
    Write-Host ""
    exit 1
}
