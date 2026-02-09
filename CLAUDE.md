# Claude Code Entry (RH_MIGRATION_2026_V2)

If you do *one* thing correctly today, make it this:

1. Confirm you are in:
   - `C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2`
2. Confirm file exists:
   - `RH_MIGRATION_2026_V2.SENTINEL`
3. Read:
   - `AGENTS_PROJECT.md` (authoritative)
   - `project_config.json`
   - `CONTRACTS\phase_requirements.json`

🚫 Never write to:
- `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026` (archived V1)

Default workflow:
- `tools\preflight.ps1` → run phase → `tools\audit_phase.ps1` → `tools\promote_to_proof_pack.ps1` → commit PROOF_PACK
