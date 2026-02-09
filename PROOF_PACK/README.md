# PROOF_PACK — Curated Artifacts

**Location:** `C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2\PROOF_PACK\`
**Purpose:** Recruiter-safe, curated evidence from RH_MIGRATION_2026_V2
**Status:** Committed to git (this is what recruiters and hiring managers see)

---

## Two-Lane Artifact Model

This project uses a two-lane system for generated artifacts:

### Lane 1: OUTPUTS/ (Messy Generated)
- **Purpose:** All execution outputs (verbose, timestamped, complete)
- **Git status:** NOT committed (in .gitignore)
- **Location:** `OUTPUTS\phase_XX\run_MM-DD-YYYY_HHMMSS\`
- **Contents:** plan.csv, runlog.txt, metrics.json, rollback.ps1, evidence\*
- **Usage:** Execution artifacts only — NOT treated as source/input

### Lane 2: PROOF_PACK/ (Curated Recruiter-Safe)
- **Purpose:** Polished artifacts for portfolio/interviews
- **Git status:** ALWAYS committed
- **Location:** `PROOF_PACK\phase_XX\run_<run_id>\`
- **Contents:** Intentionally promoted files from OUTPUTS
- **Usage:** This is the recruiter entry point

---

## Promotion Process

**Rule:** Only curated artifacts are copied from OUTPUTS → PROOF_PACK.

**How to promote:**
```powershell
# Promote Phase 01 artifacts
pwsh -NoProfile -ExecutionPolicy Bypass -File "tools\promote_to_proof_pack.ps1" -Phase 01

# Promote specific files from Phase 01
pwsh -NoProfile -ExecutionPolicy Bypass -File "tools\promote_to_proof_pack.ps1" -Phase 01 -PromoteList @('plan.csv', 'summary_02-08-2026.md')

# Promote from a specific run
pwsh -NoProfile -ExecutionPolicy Bypass -File "tools\promote_to_proof_pack.ps1" -Phase 01 -RunId "run_02-08-2026_153039"
```

---

## What Belongs Here

**Include:**
- Clean summary reports (summary_MM-DD-YYYY.md)
- Key metrics (metrics.json)
- Evidence files demonstrating outcomes
- Code excerpts showing implementation quality
- Before/after comparisons

**Exclude:**
- Verbose logs (runlog.txt stays in OUTPUTS)
- Rollback scripts (operational, not recruiter-facing)
- Raw intermediate data
- Debugging artifacts

---

## Directory Structure

```
PROOF_PACK\
├── README.md               ← This file (start here)
├── INDEX.md                ← Promotion history (auto-maintained)
└── phase_XX\               ← Promoted artifacts by phase
    └── run_<run_id>\       ← Timestamped run artifacts
        ├── summary_MM-DD-YYYY.md
        ├── metrics.json
        └── evidence\
            └── <curated files>
```

---

## Promotion History

See [INDEX.md](INDEX.md) for a complete record of all promotions.

---

## For Recruiters

**Start here:** This PROOF_PACK directory contains curated evidence of a systematic filesystem migration project.

**What you'll find:**
- Phased approach with clear deliverables
- Metrics demonstrating automation and scale
- Evidence of planning, execution, and validation
- PowerShell scripting for Windows automation
- Config-driven architecture with safety contracts

**Key phases:**
- Phase 00: Baseline snapshot (before state)
- Phase 01: Contract freeze (directory structure, naming, safety rules)
- Phase 02-08: Progressive classification, planning, and execution

**Project context:** This is a real-world migration of 9,883 files across scattered directories into a clean, deterministic structure using PowerShell automation and config-driven design.

---

**Last Updated:** 2026-02-09
