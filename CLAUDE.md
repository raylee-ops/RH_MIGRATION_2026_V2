# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## ⚠️ STOP — Read This First

**DO NOT proceed without reading:**

```
C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2\AGENTS_PROJECT.md
```

`AGENTS_PROJECT.md` is the **single source of truth** for this project.

All rules, constraints, phase definitions, and operational procedures are defined there.

**This file exists only to ensure you don't miss the instructions.**

---

## Quick Reference

- **Project Root:** `C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2\`
- **Runnable Scripts:** `SRC\` only
- **Outputs:** `OUTPUTS\phase_XX\run_MM-DD-YYYY_HHMMSS\`
- **Entry Point:** `SRC\run.ps1`
- **Config:** `project_config.json` (defines scan roots and quarantine destination)
- **Scan Roots:** `C:\RH\INBOX` and `C:\RH\OPS` only
- **Quarantine:** `C:\RH\TEMPORARY` (never scanned)

## Artifact Lanes (OUTPUTS vs PROOF_PACK)

**Two-lane model:**
- **OUTPUTS/** — Messy generated lane (NOT committed to git, execution outputs only)
- **PROOF_PACK/** — Curated recruiter-safe lane (committed to git, promoted artifacts only)

**Promotion rule:** Only selected artifacts are copied from OUTPUTS → PROOF_PACK using `tools/promote_to_proof_pack.ps1`

**Precedence:** If docs conflict, AGENTS_PROJECT.md + project_config.json win.

---

**Read `AGENTS_PROJECT.md` now.**
