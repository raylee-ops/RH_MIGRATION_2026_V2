# RUNBOOK_CANONICAL

## Canonical Top-Level
- `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_01`
- `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_02`
- `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_03`
- `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_04`
- `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_05`
- `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_06`
- `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_07`
- `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_08`
- `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_09`
- `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_10`
- `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_11`
- `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\codex`
- `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\trash`

## Execution Rule
- Run scripts only from `phase_XX\scripts\`.
- Never execute from `C:\RH\OPS\BUILD\`.
- Never execute from `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\trash\`.

## Phase 6 Canonical Commands
- DryRun:
`pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_06\scripts\Phase6-CanonicalInbox.ps1" -Mode DryRun`
- Execute:
`pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_06\scripts\Phase6-CanonicalInbox.ps1" -Mode Execute`
- Known Folder fix:
`pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_06\scripts\Fix-KnownFolders.ps1" -Mode DryRun`
`pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_06\scripts\Fix-KnownFolders.ps1" -Mode Execute -RestartExplorer`

## Rollback Locations
- Phase 6 rollback:
`C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_06\runs\phase6\2026-02-07__191339\rollback_phase6_registry.ps1`
- Known Folders rollback:
`C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_06\runs\phase6b2_knownfolders\2026-02-07__195533\rollback_knownfolders_2026-02-07__195533.ps1`
`C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_06\runs\phase6b2_knownfolders\2026-02-07__195533\rollback_knownfolders_2026-02-07__195533.reg`

## Phase 4 Location Note
- Research:
`C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_04\research\`
- Legacy engine snapshot:
`C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_04\legacy_engine\`
- Patch backups:
`C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_04\patch_backups\`

## BUILD Deprecation
- BUILD is legacy source material only.
- Deprecation stubs:
`C:\RH\OPS\BUILD\scripts\phase6\README_DEPRECATED.md`
`C:\RH\OPS\SYSTEM\DATA\runs\phase6\README_DEPRECATED.md`
