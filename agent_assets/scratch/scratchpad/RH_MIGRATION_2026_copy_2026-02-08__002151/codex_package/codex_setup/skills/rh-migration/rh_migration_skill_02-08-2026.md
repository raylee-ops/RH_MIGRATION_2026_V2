---
name: rh-migration
description: "Use this skill when working on the RH Master Migration Plan (Phases 0-11). Triggers on: filesystem reorganization, file migration, duplicate detection, Windows folder redirection, inventory scans, or any task mentioning C:\\RH structure. Do NOT use for general coding or unrelated tasks."
---

# RH Migration Skill

## When to Use This Skill

Trigger on:
- "migration", "phase 0-11", "cleanup", "reorganize"
- Paths containing `C:\RH\`
- "inventory", "dedupe", "duplicate"
- "quarantine", "triage", "routing"
- "Windows folders", "Downloads redirect"
- Filename normalization, date format `MM-DD-YYYY`

## Canonical Structure Reference

```
C:\RH\
├── OPS\                            ← Tech/career/work
│   ├── BUILD\src\repos\            ← Git repos (code)
│   ├── SYSTEM\DATA\runs\           ← Run outputs (NOT git)
│   ├── SYSTEM\migrations\          ← Ledger docs only
│   ├── QUARANTINE\                 ← Untriaged files
│   └── _ARCHIVE\                   ← Frozen snapshots
├── LIFE\                           ← Personal
│   ├── MEDIA\INBOX\                ← Screenshots/photos
│   └── DOCS\                       ← Documents
├── VAULT\                          ← Sensitive (syncable)
├── VAULT_NEVER_SYNC\               ← Secrets (never sync)
├── INBOX\                          ← Landing zones
│   ├── DOWNLOADS\                  ← Windows Downloads
│   └── DESKTOP_SWEEP\              ← Desktop files
└── ARCHIVE\                        ← Cold storage
```

## Filename Format

**ALWAYS USE:** `name_MM-DD-YYYY.ext`

```powershell
# Generate proper filename
$date = Get-Date -Format 'MM-dd-yyyy'
$filename = "migration_ledger_$date.md"
```

## Phase Checklist

When working on migration tasks, identify the current phase:

| Phase | Deliverable Location |
|-------|---------------------|
| 0-2 | `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\` |
| 3 | `C:\RH\OPS\SYSTEM\DATA\runs\inventory\MM-DD-YYYY\` |
| 4 | `C:\RH\OPS\SYSTEM\DATA\runs\phase4\<run_id>\` |
| 5 | `C:\RH\OPS\SYSTEM\DATA\runs\dedupe\MM-DD-YYYY\` |
| 6 | `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\` |
| 7 | `C:\RH\OPS\SYSTEM\DATA\runs\rename\MM-DD-YYYY\` |
| 8-11 | `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\` |

## Safety Patterns

### Before moving files:
```powershell
# Count before
$before = (Get-ChildItem -LiteralPath $source -Recurse -File -ErrorAction SilentlyContinue).Count
Write-Host "Source contains $before files"

# Dry run first
Move-Item -LiteralPath $source -Destination $dest -WhatIf

# Actual move (only after dry run approval)
Move-Item -LiteralPath $source -Destination $dest -Force

# Count after
$after = (Get-ChildItem -LiteralPath $dest -Recurse -File -ErrorAction SilentlyContinue).Count
if ($before -ne $after) { Write-Warning "MISMATCH: $before → $after" }
```

### Before deleting:
```powershell
# Move to quarantine first, NEVER direct delete
$quarantine = "C:\RH\OPS\_ARCHIVE\deleted_$(Get-Date -Format 'MM-dd-yyyy')"
New-Item -ItemType Directory -Path $quarantine -Force | Out-Null
Move-Item -LiteralPath $target -Destination $quarantine
```

## Common Operations

### Create run folder with timestamp:
```powershell
$runId = Get-Date -Format 'yyyyMMdd-HHmmss'
$runFolder = "C:\RH\OPS\SYSTEM\DATA\runs\phase4\$runId"
New-Item -ItemType Directory -Path $runFolder -Force | Out-Null
```

### Inventory scan:
```powershell
$date = Get-Date -Format 'MM-dd-yyyy'
$outFolder = "C:\RH\OPS\SYSTEM\DATA\runs\inventory\$date"
New-Item -ItemType Directory -Path $outFolder -Force | Out-Null

Get-ChildItem -LiteralPath 'C:\RH' -Recurse -File -ErrorAction SilentlyContinue |
    Select-Object FullName, Length, LastWriteTime, Extension |
    Export-Csv "$outFolder\full_inventory_$date.csv" -NoTypeInformation -Encoding utf8
```

### Duplicate detection (name+size):
```powershell
Get-ChildItem -LiteralPath 'C:\RH' -Recurse -File -ErrorAction SilentlyContinue |
    Group-Object Name, Length |
    Where-Object { $_.Count -gt 1 } |
    ForEach-Object { $_.Group } |
    Select-Object FullName, Length, LastWriteTime
```

## Output Format

When generating reports, use this structure:
```markdown
# [Phase X] [Operation Name]
**Date:** MM-DD-YYYY
**Run ID:** (if applicable)

## Summary
- Files processed: X
- Actions taken: X
- Errors: X

## Details
[Specifics here]

## Next Steps
[What comes next]
```

## End of Skill
