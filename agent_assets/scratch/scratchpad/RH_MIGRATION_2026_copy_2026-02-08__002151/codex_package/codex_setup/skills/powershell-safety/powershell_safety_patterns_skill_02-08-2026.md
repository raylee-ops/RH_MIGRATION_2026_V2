---
name: powershell-safety
description: "Use this skill for any PowerShell file operations, especially moves, copies, renames, or batch operations. Enforces dry-run patterns, count verification, LiteralPath usage, dupe-suffix on conflicts, and MOVE-TO-PROJECT-TRASH instead of remove. Triggers on: Move-Item, Copy-Item, Rename-Item, batch operations, -Recurse flags, or 'move', 'rename', 'copy', 'remove' in prompts."
---

# PowerShell Safety Patterns Skill

## Core Principles

1. **Dry-run first** — Always show `-WhatIf` before execution
2. **Count before/after** — Verify no files lost
3. **Never remove** — interpret any “remove/remove/cleanup” request as MOVE-TO-PROJECT-TRASH (timestamped)
4. **LiteralPath always** — Handle special characters in paths
5. **UTF-8 encoding** — Explicitly set for file outputs

## Safe Move Pattern

```powershell
function Move-SafeWithVerify {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination,
        [switch]$Execute
    )
    
    if (-not (Test-Path -LiteralPath $Source)) {
        Write-Error "Source not found: $Source"
        return
    }
    
    $beforeCount = (Get-ChildItem -LiteralPath $Source -Recurse -File -ErrorAction SilentlyContinue).Count
    Write-Host "Source contains $beforeCount files" -ForegroundColor Cyan
    
    if (-not $Execute) {
        Write-Host "`nDRY RUN — What would happen:" -ForegroundColor Yellow
        Move-Item -LiteralPath $Source -Destination $Destination -WhatIf
        Write-Host "`nRe-run with -Execute to perform the move" -ForegroundColor Yellow
        return
    }
    
    # Create destination if needed
    $destParent = Split-Path $Destination -Parent
    if ($destParent -and -not (Test-Path -LiteralPath $destParent)) {
        New-Item -ItemType Directory -Path $destParent -Force | Out-Null
    }
    
    # Perform move
    Move-Item -LiteralPath $Source -Destination $Destination -Force
    
    # Verify
    $afterCount = (Get-ChildItem -LiteralPath $Destination -Recurse -File -ErrorAction SilentlyContinue).Count
    
    if ($beforeCount -eq $afterCount) {
        Write-Host "✓ Move verified: $beforeCount files" -ForegroundColor Green
    } else {
        Write-Warning "COUNT MISMATCH: Before=$beforeCount After=$afterCount"
    }
}
```

## Safe remove Pattern (Quarantine First)

```powershell
function Move-ToProjectTrash {
    param(
        [Parameter(Mandatory)][string]$Target,
        [Parameter(Mandatory)][string]$Category,
        [string]$ProjectTrashRoot = "C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\trash",
        [switch]$Execute
    )

    if (-not (Test-Path -LiteralPath $Target)) {
        Write-Error "Target not found: $Target"
        return
    }

    $stamp = Get-Date -Format 'MM-dd-yyyy__HHmmss'
    $leaf  = Split-Path $Target -Leaf
    $destRoot = Join-Path $ProjectTrashRoot (Join-Path $Category $stamp)
    New-Item -ItemType Directory -Path $destRoot -Force | Out-Null

    $dest = Join-Path $destRoot $leaf

    if (Test-Path -LiteralPath $dest) {
        $i = 1
        do {
            $suffix = " (dupe-{0:d4})" -f $i
            $dest = Join-Path $destRoot ($leaf + $suffix)
            $i++
        } while (Test-Path -LiteralPath $dest)
    }

    Write-Host "Will MOVE to project trash:" -ForegroundColor Cyan
    Write-Host "  Source: $Target" -ForegroundColor Cyan
    Write-Host "  Dest:   $dest" -ForegroundColor Cyan

    if (-not $Execute) {
        Write-Host "`nDRY RUN — re-run with -Execute to perform the move." -ForegroundColor Yellow
        return
    }

    Move-Item -LiteralPath $Target -Destination $dest
    if (Test-Path -LiteralPath $dest) {
        Write-Host "✓ Moved to trash: $dest" -ForegroundColor Green
    } else {
        Write-Error "Move failed: $dest"
    }
}
```

## Batch Operation Pattern

```powershell
function Invoke-BatchOperation {
    param(
        [Parameter(Mandatory)][string[]]$Items,
        [Parameter(Mandatory)][scriptblock]$Action,
        [switch]$Execute
    )
    
    $total = $Items.Count
    $success = 0
    $failed = 0
    
    Write-Host "Processing $total items..." -ForegroundColor Cyan
    
    if (-not $Execute) {
        Write-Host "`nDRY RUN MODE — Actions will be shown but not executed" -ForegroundColor Yellow
    }
    
    foreach ($item in $Items) {
        try {
            if ($Execute) {
                & $Action $item
            } else {
                Write-Host "Would process: $item"
            }
            $success++
        } catch {
            Write-Warning "Failed: $item — $($_.Exception.Message)"
            $failed++
        }
    }
    
    Write-Host "`nResults: $success success, $failed failed, $total total" -ForegroundColor $(if ($failed -eq 0) { 'Green' } else { 'Yellow' })
}
```

## Common Dangerous Patterns to AVOID

```powershell
# ❌ NEVER do this:
Remove-Item 'C:\RH\*' -Recurse -Force
Get-ChildItem | Remove-Item -Recurse
rm -rf equivalent

# ❌ NEVER remove without counting first:
Remove-Item $path -Force

# ❌ NEVER use wildcards without filtering:
Move-Item 'C:\RH\*' $dest

# ✓ ALWAYS quarantine instead:
Move-Item -LiteralPath $target -Destination "C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\trash\$(Get-Date -Format 'MM-dd-yyyy')"
```

## Path Handling

```powershell
# ✓ ALWAYS use -LiteralPath for paths with special characters
Get-ChildItem -LiteralPath 'C:\RH\[folder]' 

# ✓ For paths from variables, use -LiteralPath
$path = "C:\RH\file[1].txt"
Test-Path -LiteralPath $path

# ✓ Join paths safely
$full = Join-Path -Path $root -ChildPath $relative
```

## Output Encoding

```powershell
# ✓ ALWAYS specify UTF-8 for exports
Export-Csv -Path $out -Encoding utf8 -NoTypeInformation
Out-File -Path $out -Encoding utf8
Set-Content -Path $out -Encoding utf8
```

## End of Skill
