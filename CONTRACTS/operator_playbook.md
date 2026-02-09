# Operator Playbook — RH_MIGRATION_2026_V2
**Date:** 02-09-2026

## Canonical sequence (do this every time)
1. **Preflight**
   ```powershell
   cd C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2
   pwsh -NoProfile -ExecutionPolicy Bypass -File tools\preflight.ps1
   ```
2. **Run phase (DryRun first)**
3. **Audit phase**
   ```powershell
   pwsh -NoProfile -ExecutionPolicy Bypass -File tools\audit_phase.ps1 -Phase 01
   ```
4. **Promote to PROOF_PACK**
   ```powershell
   pwsh -NoProfile -ExecutionPolicy Bypass -File tools\promote_to_proof_pack.ps1 -Phase 01
   ```
5. **Commit curated artifacts only**
   - Never commit `OUTPUTS/`

## Quick verification
- Overall status:
  ```powershell
  pwsh -NoProfile -ExecutionPolicy Bypass -File tools\status.ps1
  ```

## “Wrong folder” tripwire
- Run `Get-Location` before spawning agents.
- Must be: `C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2`
- Must contain: `RH_MIGRATION_2026_V2.SENTINEL`
