# RH Migration Lane Repair Report
**Date:** 02-11-2026  
**Project:** `C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2`

## Scope
- Diagnose phase-run artifact leakage outside `OUTPUTS\phase_XX\run_MM-DD-YYYY_HHMMSS\`
- Copy loose lane folders from `C:\RH\OPS\` into repo-local `agent_assets\...`
- Preserve originals for rollback/audit; no move or delete performed
- Add prevention guardrails in project instructions and runner

## 1) Diagnosis Results
- Scan roots: `C:\RH\OPS`, `C:\RH\INBOX`, `C:\RH\TEMPORARY`
- Artifact patterns searched: `plan.csv`, `metrics.json`, `runlog.txt`, `rollback.ps1`, `*_executed.csv`
- Matches found (all roots): **167**
- Matches outside any `\OUTPUTS\` path: **48**
- Matches in specified loose lanes (`RH_AI_MIGRATION_SUMMARY`, `RH_STRUCTURE`, `STAGING`, `scratchpad`, `DOWNLOADS`) outside OUTPUTS: **0**

### Lane Leakage Finding
- No phase-run artifact files were found in the five loose lane folders.
- No lane-specific leaked run IDs were detected.

### Notable Non-Lane Outside-OUTPUTS Matches (awareness only)
- `C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2\PROOF_PACK\phase_00\run_02-08-2026_140111\metrics.json` (run_id=`run_02-08-2026_140111`)
- `C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2\PROOF_PACK\phase_00\run_02-08-2026_140111\plan.csv` (run_id=`run_02-08-2026_140111`)
- `C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2\PROOF_PACK\phase_01\run_02-08-2026_153039\metrics.json` (run_id=`run_02-08-2026_153039`)
- `C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2\PROOF_PACK\phase_01\run_02-08-2026_153039\plan.csv` (run_id=`run_02-08-2026_153039`)
- `C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2\PROOF_PACK\phase_02\run_02-09-2026_055901\metrics.json` (run_id=`run_02-09-2026_055901`)
- `C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2\PROOF_PACK\phase_02\run_02-09-2026_055901\plan.csv` (run_id=`run_02-09-2026_055901`)
- `C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2\PROOF_PACK\phase_03\run_02-09-2026_XXXXXX\metrics.json` (run_id=`<none>`)
- `C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2\PROOF_PACK\phase_03\run_02-09-2026_XXXXXX\plan.csv` (run_id=`<none>`)

## 2) Safe Repair (COPY-only)
Created or verified destination folders:
- `agent_assets\notes`
- `agent_assets\downloads`
- `agent_assets\scratch`
- `agent_assets\exports`

Copy mapping executed:
- `C:\RH\OPS\RH_AI_MIGRATION_SUMMARY` -> `agent_assets\notes\RH_AI_MIGRATION_SUMMARY`
- `C:\RH\OPS\RH_STRUCTURE` -> `agent_assets\exports\RH_STRUCTURE`
- `C:\RH\OPS\STAGING` -> `agent_assets\scratch\STAGING`
- `C:\RH\OPS\scratchpad` -> `agent_assets\scratch\scratchpad`
- `C:\RH\OPS\DOWNLOADS` -> `agent_assets\downloads\DOWNLOADS`

Dry-run (`-WhatIf`) completed before actual copy.

Copy verification summary:

| Source | Destination | Source files | Dest files | Status |
|---|---|---:|---:|---|
| `C:\RH\OPS\RH_AI_MIGRATION_SUMMARY` | `C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2\agent_assets\notes\RH_AI_MIGRATION_SUMMARY` | 9 | 9 | `count_match` |
| `C:\RH\OPS\RH_STRUCTURE` | `C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2\agent_assets\exports\RH_STRUCTURE` | 1 | 1 | `count_match` |
| `C:\RH\OPS\STAGING` | `C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2\agent_assets\scratch\STAGING` | 2 | 2 | `count_match` |
| `C:\RH\OPS\scratchpad` | `C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2\agent_assets\scratch\scratchpad` | 184 | 184 | `count_match` |
| `C:\RH\OPS\DOWNLOADS` | `C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2\agent_assets\downloads\DOWNLOADS` | 16 | 16 | `count_match` |

Manifest generated:
- `agent_assets\copy_manifest_02-11-2026.csv`
- Columns: `source_path,dest_path,sha256,size,mtime`
- Rows: **212**

Original source lanes were not moved or deleted.

## 3) Prevention Changes Applied
- Updated `AGENTS.override.md` with explicit artifact routing rules:
- Phase-run outputs only under `OUTPUTS\phase_XX\run_MM-DD-YYYY_HHMMSS\`
- Non-run notes/downloads/scratch/exports only under `agent_assets\...`
- Never create new top-level folders under `C:\RH\OPS` except `PROJECTS\...`
- Updated `SRC\run.ps1`:
- Launch CWD must be inside repo root
- Default write boundary is `OUTPUTS\` and `agent_assets\`
- External writes require explicit `-AllowExternalWrites`
- Execute for phases `06`/`07`/`07b` now requires explicit `-AllowExternalWrites`
- Phase `08` now validates semantic scope exclusions before running
- Added `SRC\rules\semantic_policy_v1.yaml` with Phase 08 pollution exclusions including:
- `\agent_assets\`
- `\scratchpad\`
- `\STAGING\`
- `\DOWNLOADS\`

## 4) Optional Cleanup (NOT EXECUTED)
Run only after verifying `copy_manifest_02-11-2026.csv` and sampled hashes.

### Step A: Dry-run delete preview
```powershell
$lanes = @(
  'C:\RH\OPS\RH_AI_MIGRATION_SUMMARY',
  'C:\RH\OPS\RH_STRUCTURE',
  'C:\RH\OPS\STAGING',
  'C:\RH\OPS\scratchpad',
  'C:\RH\OPS\DOWNLOADS'
)
foreach ($p in $lanes) {
  if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -WhatIf }
}
```

### Step B: Actual delete (manual, after explicit approval)
```powershell
$lanes = @(
  'C:\RH\OPS\RH_AI_MIGRATION_SUMMARY',
  'C:\RH\OPS\RH_STRUCTURE',
  'C:\RH\OPS\STAGING',
  'C:\RH\OPS\scratchpad',
  'C:\RH\OPS\DOWNLOADS'
)
foreach ($p in $lanes) {
  if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force }
}
```

## 5) Commands Run (high level)
- `Get-Location`
- `Test-Path -LiteralPath .\RH_MIGRATION_2026_V2.SENTINEL`
- Recursive `Get-ChildItem` scan with artifact filename filters and CSV exports under `agent_assets\_tmp_*`
- `Copy-Item ... -WhatIf` (logged in `agent_assets\_tmp_copy_whatif.log`)
- `Copy-Item` for actual copy (no move/delete)
- `Get-FileHash -Algorithm SHA256` for every copied file in manifest
