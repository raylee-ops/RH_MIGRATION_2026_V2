# Non-Negotiables — RH_MIGRATION_2026_V2
**Date:** 02-09-2026

These rules override everything else.

## Safety
- **No deletes.**
- **No overwrites.**
- Collisions resolved by suffix or quarantine, never overwrite.

## Scope
- Scan/read ONLY: `C:\RH\INBOX`, `C:\RH\OPS`
- Quarantine (destination-only): `C:\RH\TEMPORARY` (never scanned)
- Excluded roots (minimum): `C:\RH\VAULT`, `C:\RH\LIFE`, `C:\RH\VAULT_NEVER_SYNC`, `C:\RH\ARCHIVE`, `C:\LEGACY`, `C:\Windows`, `C:\Program Files`, `C:\Users`

## Artifact lanes
- `OUTPUTS/` is generated and **ignored by git**.
- `PROOF_PACK/` is curated and **committed**.

## Wrong-repo guard
- **Never write to:** `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026` (archived V1)
