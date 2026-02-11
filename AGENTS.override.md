# AGENTS.override.md — Launch-Folder-First Overrides
# Last updated: 02-11-2026

This file intentionally overrides broader/global guidance for this repo.

## Instruction Priority (for this project)
- Treat this file as highest-priority project instruction in this directory.
- If this file conflicts with global `C:\Users\Raylee\.codex\AGENTS.md`, this file wins.

## Input Resolution Order (MUST)
1. Launch folder (session-start `Get-Location`)
2. Project root (`C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2`)
3. Global/system locations only when explicitly requested

## Hard Rule
- Never read from `C:\RH\OPS\SYSTEM\...` if a same-named input exists in the launch folder.

## Output Rule
- Write outputs to the launch folder first unless the operator explicitly requests a different destination.
- If a mirror copy is requested, write launch-folder copy first, then mirror.

## Artifact Routing (Required)
- Phase-run outputs MUST be written only under `OUTPUTS\phase_XX\run_MM-DD-YYYY_HHMMSS\`.
- Non-run human/agent artifacts MUST be written only under `agent_assets\` (`notes\`, `downloads\`, `scratch\`, `exports\`).
- Never create new top-level folders directly under `C:\RH\OPS\` other than `PROJECTS\...`.

## Session Check (required before file operations)
```powershell
Get-Location
Test-Path -LiteralPath .\RH_MIGRATION_2026_V2.SENTINEL
```

## Safety
- No delete, no overwrite.
- Dry-run first for move/copy/rename operations.
- Never touch `C:\RH\VAULT_NEVER_SYNC\`.
