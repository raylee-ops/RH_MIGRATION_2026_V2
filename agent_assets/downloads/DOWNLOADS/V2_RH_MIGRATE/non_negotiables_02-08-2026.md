# RH_MIGRATION_2026_V2 — Non‑Negotiable Rules (02-08-2026)

## Absolute rules
1) **No deletes. No overwrites.**
2) **DryRun is default.** Execute requires explicit approval.
3) **No move/rename/dedup without a reviewed `plan.csv`.**
4) **Allowed roots only:** `C:\RH\INBOX`, `C:\RH\OPS`
5) **Excluded roots always:** `C:\RH\VAULT`, `C:\RH\LIFE`, `C:\LEGACY`, `C:\Windows`, `C:\Program Files`, `C:\Users`
6) **Single quarantine:** `C:\RH\TEMPORARY`
7) **Outputs only:** `...\OUTPUTS\phase_0X\run_MM-DD-YYYY_HHMMSS\`
8) **Naming**
   - Files: `name_MM-DD-YYYY.ext` (never year-first)
   - Run folders: `run_MM-DD-YYYY_HHMMSS`
9) **Single execution doorway:** run scripts only from `...\SRC\`
10) **One variable per run.** Never change structure+config+rules+behavior in one go.

## Stop conditions (if any occurs, stop immediately)
- Any attempt to touch excluded roots
- Missing audit spine files after a run
- Duplicate scripts without canonical manifest (Phase 02 not done)
- Any proposal to “clean up” by deleting duplicates
