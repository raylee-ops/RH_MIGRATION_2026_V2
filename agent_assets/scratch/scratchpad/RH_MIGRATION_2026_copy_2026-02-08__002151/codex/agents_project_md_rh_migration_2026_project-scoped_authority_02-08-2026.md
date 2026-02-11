# AGENTS_PROJECT.md — RH_MIGRATION_2026 (Project-Scoped Authority)
# Location (authoritative): C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\codex\AGENTS_PROJECT.md
# Date: 02-07-2026

## 0) Read-first inputs (must read before doing anything)
Codex MUST read these before any work on this project:
- C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\codex\_INPUTS\00_README_FIRST.md
- C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\codex\_INPUTS\01_PROJECT_CHARTER_PROMPT.txt
- C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\codex\_INPUTS\02_OUTPUT_ROUTING_POLICY_02-07-2026.md
- C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\codex\_INPUTS\06_CANONICAL_ROOT_RULES_02-07-2026.md
- C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\codex\_INPUTS\07_COMMAND_SNIPPETS_POWERSHELL_02-07-2026.md

## 1) Output routing (hard rule)
Codex is FORBIDDEN from writing operational outputs into:
- C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\codex\
- C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\codex\_INPUTS\

Allowed writes in C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\codex\ only:
- PHASE_STATUS.md (status table updates)
- DECISIONS_LOG.md (append-only, only when explicitly asked)
- BASELINE_* anchors (only if missing, or if user explicitly asks)

All operational outputs MUST be written phase-scoped under:
C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_XX\
  - runs\
  - artifacts\
  - docs\
  - scripts\

## 2) Safety governance
- Default to DryRun.
- Execute only on explicit operator phrase: EXECUTE <task name>.
- Never delete. If removal is required: MOVE to project trash only.
- Never touch: C:\RH\VAULT_NEVER_SYNC\ (read-only at most).

## 3) Phase completion definition (non-negotiable)
A phase is NOT COMPLETE unless these exist:
- C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_XX\docs\PHASE_XX_PURPOSE.md
- C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_XX\artifacts\PHASE_XX_PROOF.md
- C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_XX\scripts\ (at least one runnable verify or dryrun script)

## 4) Filename rule
Use: name_MM-DD-YYYY.ext (name first, date last)
