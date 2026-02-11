# Codex Entry (RH_MIGRATION_2026_V2)

Codex: you only get one job: **don’t write to the wrong folder**.

## Hard requirements
- Working directory MUST be: `C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2`
- File MUST exist: `RH_MIGRATION_2026_V2.SENTINEL`
- Read and obey: `AGENTS_PROJECT.md` + `project_config.json`

## Forbidden (archived V1)
- `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026`
If you see this path, stop and refuse.

## Outputs contract
- Default output target is the launch folder (current working directory where Codex was started) unless you explicitly request another path.
- If multiple valid destinations exist, write to launch folder first, then optionally mirror elsewhere only if requested.
- Generated run artifacts → `OUTPUTS\phase_XX\run_MM-DD-YYYY_HHMMSS\` (ignored by git)
- Curated artifacts → `PROOF_PACK/` (committed)

Verification tools:
- `tools\preflight.ps1`
- `tools\audit_phase.ps1 -Phase XX`
- `tools\status.ps1`
