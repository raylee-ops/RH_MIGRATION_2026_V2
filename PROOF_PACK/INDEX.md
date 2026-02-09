# PROOF_PACK Promotion Index

**Purpose:** Track all promotions from OUTPUTS → PROOF_PACK
**Maintained by:** `tools/promote_to_proof_pack.ps1` (auto-updated)
**Last Updated:** 2026-02-09

---

## Promotion History

| Phase | Run ID | Promoted On | Source Path | Promoted Files |
|-------|--------|-------------|-------------|----------------|
| 01 | run_02-08-2026_153039 | 02-09-2026 01:54:00 | OUTPUTS\phase_01\run_02-08-2026_153039 | plan.csv, metrics.json, summary_02-08-2026.md |
| 01 | run_02-08-2026_153039 | 02-09-2026 03:44:10 | OUTPUTS\phase_01\run_02-08-2026_153039 | plan.csv, metrics.json, summary_02-08-2026.md |
| 00 | run_02-08-2026_140111 | 02-09-2026 05:09:27 | OUTPUTS\phase_00\run_02-08-2026_140111 | plan.csv, metrics.json, summary_02-08-2026.md |

---

## Notes

- Each row is automatically appended by `tools/promote_to_proof_pack.ps1`
- Source Path is the OUTPUTS run directory that artifacts were copied from
- Promoted Files is a comma-separated list of files copied
- Promoted On uses format: MM-DD-YYYY HH:mm:ss

---

## How to Promote

```powershell
# Promote Phase 01 artifacts (newest run)
pwsh -NoProfile -ExecutionPolicy Bypass -File "tools\promote_to_proof_pack.ps1" -Phase 01

# Promote specific files
pwsh -NoProfile -ExecutionPolicy Bypass -File "tools\promote_to_proof_pack.ps1" -Phase 01 -PromoteList @('plan.csv', 'metrics.json')

# Promote from specific run
pwsh -NoProfile -ExecutionPolicy Bypass -File "tools\promote_to_proof_pack.ps1" -Phase 01 -RunId "run_02-08-2026_153039"
```

---

**For details on the two-lane artifact model, see [README.md](README.md)**
