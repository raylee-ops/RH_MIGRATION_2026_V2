# Agent Paste Block — RH_MIGRATION_2026_V2 (Copy/Paste This First)

You are working **ONLY** in:
- `C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2`

Hard stop if you are in:
- `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026` (archived V1)

## First checks (must do)
1. Run `Get-Location` and confirm it is the V2 path.
2. Confirm file exists: `RH_MIGRATION_2026_V2.SENTINEL`
3. Read these files before any edits:
   - `AGENTS_PROJECT.md` (authoritative)
   - `project_config.json` (runtime config)
   - `CONTRACTS\phase_requirements.json` (phase completion requirements)

## Scope rules
- Scan/read ONLY: `C:\RH\INBOX`, `C:\RH\OPS`
- Quarantine destination-only: `C:\RH\TEMPORARY` (never scanned)
- Never touch excluded roots (VAULT/LIFE/Users/Windows/etc).

## Artifact lanes (mandatory)
- All messy run artifacts go to: `OUTPUTS\phase_XX\run_MM-DD-YYYY_HHMMSS\`
- `OUTPUTS/` is **ignored by git** (never commit)
- Only curated artifacts go to: `PROOF_PACK/` (committed)

## Definition of “done”
A phase is NOT done unless:
- Audit spine exists in OUTPUTS run folder (plan/runlog/metrics/rollback/summary/evidence)
- Required evidence exists per `CONTRACTS\phase_requirements.json`
- Curated artifacts promoted into `PROOF_PACK/` (and indexed)

## Safety
- No deletes. No overwrites. Use suffix or quarantine for collisions.
