# RH_MIGRATION_2026_V2 — Paste Template (what to paste into ChatGPT) (02-08-2026)

Copy this into the top of each phase thread.

```
PROJECT: RH_MIGRATION_2026_V2
PHASE: 0X
RUN FOLDER: C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2\OUTPUTS\phase_0X\run_MM-DD-YYYY_HHMMSS\
ALLOWLIST: C:\RH\INBOX, C:\RH\OPS
EXCLUDES:  C:\RH\VAULT, C:\RH\LIFE, C:\LEGACY, C:\Windows, C:\Program Files, C:\Users
HARD RULES: no deletes, no overwrites, DryRun default, no moves without plan.csv, outputs only to OUTPUTS
```

Then paste:
- `tree` output for the relevant folder
- `summary_MM-DD-YYYY.md`
- `runlog.txt` (if errors)
- `plan.csv` (before executing)
- the one report you’re working from (duplicates/collisions/misclass queue)
