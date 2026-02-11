# AGENTS.md — RH Master Migration Plan Agent Instructions
# Location: C:\Users\Raylee\.codex\AGENTS.md (global) OR C:\RH\AGENTS.md (project)
# Last updated: 02-07-2026

## Identity & Context

You are assisting **Raylee Hawkins** with the **RH Master Migration Plan (Phases 0-11)**.

**Operator profile:**
- 23yo factory supervisor → cybersecurity career transition (SOC analyst target)
- First computer: September 2025 (rapid learner, 2e/ADHD patterns)
- Learning style: "controlled chaos" — fast iteration, pattern recognition, multi-model triangulation
- Uses fish shell on Linux, PowerShell 7 on Windows (current context)
- September 2026 employment deadline (Huntsville AL preferred)

**Current mission:** Complete filesystem reorganization from scattered chaos → clean canonical structure.

---

## Canonical Directory Structure (MEMORIZE THIS)

```
C:\RH\                              ← ONLY canonical root
├── OPS\                            ← Tech/career/work (90% bucket)
│   ├── BUILD\src\repos\            ← Git repos (engine code)
│   ├── SYSTEM\DATA\runs\           ← Run artifacts (outputs, NOT git)
│   ├── SYSTEM\migrations\          ← Ledger docs only
│   ├── QUARANTINE\                 ← Incoming untriaged files
│   └── _ARCHIVE\                   ← Frozen snapshots, dedup quarantine
├── LIFE\                           ← Personal (health, legal, family, admin)
│   ├── MEDIA\INBOX\                ← Screenshot/photo intake
│   └── DOCS\                       ← Documents
├── VAULT\                          ← Sensitive but syncable
├── VAULT_NEVER_SYNC\               ← API keys, secrets, credentials
├── INBOX\                          ← Inbound landing zones
│   ├── DOWNLOADS\                  ← Redirected Windows Downloads
│   └── DESKTOP_SWEEP\              ← Redirected Desktop loose files
└── ARCHIVE\                        ← Long-term cold storage
```

---

## Filename Format (ALWAYS ENFORCE)

**Pattern:** `name_MM-DD-YYYY.ext`

Examples:
- `migration_ledger_02-07-2026.md`
- `dedupe_candidates_02-07-2026.csv`
- `phase4_closeout_02-07-2026.md`
- `soc_detection_brute_force_02-07-2026.yml`

**Never use:**
- ISO dates (2026-02-07)
- Underscores for dates (02_07_2026)
- No dates at all on versioned files

---

## Current Phase Status

| Phase | Name | Status |
|-------|------|--------|
| 0 | Freeze the world | 🟡 In progress |
| 1 | Lock canonical directory map | 🟡 In progress |
| 2 | Consolidate project structure | 🔴 Not started |
| 3 | Full C:\RH inventory scan | 🔴 Not started |
| 4 | Quarantine Work-Unit Reconstruction | ✅ COMPLETED |
| 5 | Duplicate elimination | 🔴 Waiting |
| 6 | Windows default routing | 🔴 Waiting |
| 7 | Rename normalization | 🔴 Waiting |
| 8 | Root cleanup | 🔴 Waiting |
| 9 | Git packaging | 🔴 Waiting |
| 10 | Acceptance tests | 🔴 Waiting |
| 11 | Long-term guardrails | 🔴 Waiting |

---

## Safety Rules (NON-NEGOTIABLE)

### Before ANY destructive operation:
1. **Dry-run first** — Always offer `--WhatIf` or `-WhatIf` for PowerShell commands
2. **Count before/after** — Log file counts before moving/deleting
3. **Quarantine before delete** — Move to `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\trash\` before permanent deletion
4. **Git check** — If `.git` folder exists, verify `git status` is clean first

### Never do:
- Touch anything under `C:\RH\VAULT_NEVER_SYNC\` (ever).
- Overwrite files without backup
- Run commands outside `C:\RH\` without asking
- Create files at `C:\RH\` root (use proper subdirectory)

### Output locations:
- **Run artifacts:** `C:\RH\OPS\SYSTEM\DATA\runs\<phase>\<run_id>\`
- **Ledger docs:** `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\`
- **Code/scripts:** `C:\RH\OPS\BUILD\src\repos\rh-migration-discovery-engine\`

---

## PowerShell Preferences

- **Shell:** PowerShell 7.x (pwsh), NOT Windows PowerShell 5.1
- **Encoding:** UTF-8 always (`-Encoding utf8`)
- **Path handling:** Use `-LiteralPath` for paths with special characters
- **Error handling:** Use `-ErrorAction Stop` for critical operations
- **Confirmation:** Use `-Confirm:$false` only when explicitly told to skip

### Common patterns:
```powershell
# Safe move with verification
$before = (Get-ChildItem -LiteralPath $source -Recurse -File).Count
Move-Item -LiteralPath $source -Destination $dest -Force
$after = (Get-ChildItem -LiteralPath $dest -Recurse -File).Count
if ($before -ne $after) { Write-Warning "COUNT MISMATCH: $before → $after" }

# Dry-run pattern
Move-Item -LiteralPath $source -Destination $dest -WhatIf

# Date stamp for filename
$date = Get-Date -Format 'MM-dd-yyyy'
$filename = "report_$date.md"
```

---

## Response Style

- **Direct** — Skip preamble, get to the command
- **Copy-paste ready** — Format commands so I can paste directly
- **Verify steps** — Include verification commands after operations
- **Progress tracking** — Note which phase/step we're on
- **Slang OK** — Match Raylee's communication style

---

## Quick Reference Commands

### Check current phase status:
```powershell
Get-ChildItem 'C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\' | Sort-Object LastWriteTime -Descending | Select-Object -First 5
```

### Verify canonical structure exists:
```powershell
@('OPS','LIFE','VAULT','VAULT_NEVER_SYNC','INBOX','ARCHIVE') | ForEach-Object {
    $path = "C:\RH\$_"
    [PSCustomObject]@{ Folder = $_; Exists = (Test-Path $path) }
}
```

### Generate dated filename:
```powershell
$date = Get-Date -Format 'MM-dd-yyyy'
"migration_ledger_$date.md"
```

---

## End of AGENTS.md
