#Requires -Version 7.0

<#
.SYNOPSIS
    Promotes curated artifacts from OUTPUTS to PROOF_PACK

.DESCRIPTION
    Implements the two-lane artifact model:
    - Reads from OUTPUTS\phase_XX\run_* (source, read-only)
    - Copies selected files to PROOF_PACK\phase_XX\run_<run_id>\ (destination)
    - Appends promotion record to PROOF_PACK/INDEX.md
    - No overwrites: uses suffix _01.._99 for collisions

.PARAMETER Phase
    Phase number (00-08)

.PARAMETER RunId
    Specific run ID (e.g., "run_02-08-2026_153039"). If not specified, uses newest run.

.PARAMETER PromoteList
    Array of relative file paths to promote from the run directory.
    If not specified, promotes default artifacts: plan.csv, metrics.json, summary_*.md

.PARAMETER ProjectRoot
    Project root path (defaults to script's grandparent directory)

.EXAMPLE
    .\tools\promote_to_proof_pack.ps1 -Phase 01
    Promotes default artifacts from newest Phase 01 run

.EXAMPLE
    .\tools\promote_to_proof_pack.ps1 -Phase 01 -PromoteList @('plan.csv', 'metrics.json', 'evidence\rh_tree_folders_only.txt')
    Promotes specific files from newest Phase 01 run

.EXAMPLE
    .\tools\promote_to_proof_pack.ps1 -Phase 01 -RunId "run_02-08-2026_153039"
    Promotes from a specific run

.NOTES
    This script is READ-ONLY for OUTPUTS (no modifications to source).
    Destination files use collision suffix if needed: file_01.ext, file_02.ext, etc.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(0, 8)]
    [int]$Phase,

    [string]$RunId,

    [string[]]$PromoteList,

    [string]$ProjectRoot = "$PSScriptRoot\.."
)

$ErrorActionPreference = 'Stop'

function Write-InfoMessage {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Cyan
}

function Write-SuccessMessage {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-ErrorMessage {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Get-UniqueDestinationPath {
    param(
        [string]$DestinationPath
    )

    if (-not (Test-Path -LiteralPath $DestinationPath)) {
        return $DestinationPath
    }

    # File exists, need to add suffix
    $directory = Split-Path -Parent $DestinationPath
    $fileName = Split-Path -Leaf $DestinationPath
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
    $extension = [System.IO.Path]::GetExtension($fileName)

    for ($i = 1; $i -le 99; $i++) {
        $newName = "${baseName}_$($i.ToString('00'))${extension}"
        $newPath = Join-Path $directory $newName

        if (-not (Test-Path -LiteralPath $newPath)) {
            return $newPath
        }
    }

    throw "Could not find unique destination path after 99 attempts: $DestinationPath"
}

# Header
Write-Host ""
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor White
Write-Host "Promote to PROOF_PACK" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor White
Write-Host ""

# Validate project root
$configPath = Join-Path $ProjectRoot "project_config.json"
if (-not (Test-Path -LiteralPath $configPath)) {
    Write-ErrorMessage "Project root invalid: project_config.json not found"
    exit 1
}

# Locate source directory (OUTPUTS)
$phaseFormatted = $Phase.ToString('00')
$outputsPhasePath = Join-Path $ProjectRoot "OUTPUTS\phase_$phaseFormatted"

if (-not (Test-Path -LiteralPath $outputsPhasePath)) {
    Write-ErrorMessage "Phase $phaseFormatted outputs not found: $outputsPhasePath"
    exit 1
}

Write-InfoMessage "Source: $outputsPhasePath"

# Find run directory
if ($RunId) {
    $sourceRunPath = Join-Path $outputsPhasePath $RunId
    if (-not (Test-Path -LiteralPath $sourceRunPath)) {
        Write-ErrorMessage "Specified run not found: $RunId"
        exit 1
    }
} else {
    # Find newest run
    $runFolders = Get-ChildItem -LiteralPath $outputsPhasePath -Directory -Filter "run_*" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending

    if ($runFolders.Count -eq 0) {
        Write-ErrorMessage "No run_* folders found in phase_$phaseFormatted"
        exit 1
    }

    $sourceRunPath = $runFolders[0].FullName
    $RunId = $runFolders[0].Name
}

Write-InfoMessage "Run: $RunId"
Write-Host ""

# Determine files to promote
if (-not $PromoteList) {
    # Default: plan.csv, metrics.json, summary_*.md
    $defaultFiles = @('plan.csv', 'metrics.json')
    $summaryFiles = Get-ChildItem -LiteralPath $sourceRunPath -Filter "summary_*.md" -File -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty Name

    $PromoteList = $defaultFiles + $summaryFiles
}

Write-InfoMessage "Files to promote:"
foreach ($file in $PromoteList) {
    Write-Host "  - $file" -ForegroundColor Gray
}
Write-Host ""

# Create destination directory
$proofPackPhasePath = Join-Path $ProjectRoot "PROOF_PACK\phase_$phaseFormatted"
$destRunPath = Join-Path $proofPackPhasePath $RunId

if (-not (Test-Path -LiteralPath $destRunPath)) {
    New-Item -Path $destRunPath -ItemType Directory -Force | Out-Null
    Write-InfoMessage "Created: $destRunPath"
}

# Promote files
$promotedFiles = @()
$errors = @()

foreach ($relPath in $PromoteList) {
    $sourcePath = Join-Path $sourceRunPath $relPath

    if (-not (Test-Path -LiteralPath $sourcePath)) {
        Write-Host "⚠️  SKIP: $relPath (not found in source)" -ForegroundColor Yellow
        continue
    }

    # Handle directories vs files
    if (Test-Path -LiteralPath $sourcePath -PathType Container) {
        # Copy directory recursively
        $destPath = Join-Path $destRunPath $relPath

        try {
            Copy-Item -LiteralPath $sourcePath -Destination $destPath -Recurse -Force
            Write-SuccessMessage "Promoted: $relPath\ (directory)"
            $promotedFiles += "$relPath\"
        } catch {
            Write-ErrorMessage "Failed: $relPath - $_"
            $errors += $relPath
        }
    } else {
        # Copy file with collision handling
        $destPath = Join-Path $destRunPath $relPath
        $destDir = Split-Path -Parent $destPath

        # Create destination directory if needed
        if (-not (Test-Path -LiteralPath $destDir)) {
            New-Item -Path $destDir -ItemType Directory -Force | Out-Null
        }

        # Get unique destination path
        $finalDestPath = Get-UniqueDestinationPath -DestinationPath $destPath

        try {
            Copy-Item -LiteralPath $sourcePath -Destination $finalDestPath -Force
            $finalName = Split-Path -Leaf $finalDestPath
            if ($finalName -ne (Split-Path -Leaf $destPath)) {
                Write-SuccessMessage "Promoted: $relPath → $finalName (collision suffix)"
            } else {
                Write-SuccessMessage "Promoted: $relPath"
            }
            $promotedFiles += $relPath
        } catch {
            Write-ErrorMessage "Failed: $relPath - $_"
            $errors += $relPath
        }
    }
}

# Update INDEX.md
Write-Host ""
Write-InfoMessage "Updating PROOF_PACK/INDEX.md..."

$indexPath = Join-Path $ProjectRoot "PROOF_PACK\INDEX.md"
$promotedOn = Get-Date -Format 'MM-dd-yyyy HH:mm:ss'
$sourcePathRel = "OUTPUTS\phase_$phaseFormatted\$RunId"
$promotedFilesStr = $promotedFiles -join ', '

# Read existing index
$indexContent = Get-Content -LiteralPath $indexPath -Raw -Encoding UTF8

# Find the table and replace the placeholder row if it exists
if ($indexContent -match '\|\s*_\(no promotions yet\)_') {
    # First promotion - replace placeholder
    $newRow = "| $phaseFormatted | $RunId | $promotedOn | $sourcePathRel | $promotedFilesStr |"
    $indexContent = $indexContent -replace '\|\s*_\(no promotions yet\)_\s*\|.*?\|.*?\|.*?\|.*?\|', $newRow
} else {
    # Append new row after the header
    $lines = $indexContent -split "`r?`n"
    $tableEndIndex = -1

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\|.*\|.*\|.*\|.*\|.*\|$' -and $lines[$i] -notmatch '^-+$') {
            $tableEndIndex = $i
        }
    }

    if ($tableEndIndex -ge 0) {
        $newRow = "| $phaseFormatted | $RunId | $promotedOn | $sourcePathRel | $promotedFilesStr |"
        $lines = $lines[0..$tableEndIndex] + $newRow + $lines[($tableEndIndex + 1)..($lines.Count - 1)]
        $indexContent = $lines -join "`n"
    }
}

# Write updated index
Set-Content -LiteralPath $indexPath -Value $indexContent -Encoding UTF8 -NoNewline
Write-SuccessMessage "INDEX.md updated"

# Summary
Write-Host ""
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor White

if ($errors.Count -eq 0) {
    Write-Host "✅ PROMOTION COMPLETE" -ForegroundColor Green -BackgroundColor Black
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor White
    Write-Host ""
    Write-InfoMessage "Promoted $($promotedFiles.Count) items from phase_$phaseFormatted"
    Write-InfoMessage "Destination: PROOF_PACK\phase_$phaseFormatted\$RunId"
    Write-Host ""
    Write-InfoMessage "Next steps:"
    Write-Host "  1. Review promoted artifacts in PROOF_PACK/" -ForegroundColor Gray
    Write-Host "  2. Commit to git: git add PROOF_PACK && git commit" -ForegroundColor Gray
    Write-Host ""
    exit 0
} else {
    Write-Host "⚠️  PROMOTION COMPLETED WITH ERRORS" -ForegroundColor Yellow -BackgroundColor Black
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor White
    Write-Host ""
    Write-InfoMessage "Promoted: $($promotedFiles.Count) items"
    Write-InfoMessage "Failed: $($errors.Count) items"
    Write-Host ""
    exit 1
}
