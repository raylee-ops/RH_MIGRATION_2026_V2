# RH_MIGRATION_2026_V2 Project Summary

**Project Root:** `C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2\`
**Owner:** Raylee Hawkins
**Purpose:** Systematic filesystem reorganization using deterministic classification + Tier 2.5 semantic enhancement
**Status:** Phases 00-07 Complete (8/9, 88.9%) | Phase 08 Starting
**Last Updated:** 2026-02-11

---

## Overview

RH_MIGRATION_2026_V2 is a phased, config-driven migration system designed to eliminate the "controlled chaos" of scattered files and establish a clean, deterministic directory structure.

**Key Improvements Over V1:**
- Config-driven (no hardcoded paths)
- Modular architecture (separate classifier, planner, mover modules)
- Single gatekeeper runner with validation
- Standardized audit spine (every run produces same artifacts)
- Tier 2.5 semantic classification (AI-assisted but rules-override)

---

## Project Structure

```
C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2\
├── AGENTS_PROJECT.md          ← Single source of truth for agents
├── CLAUDE.md                  ← Pointer stub
├── CODEX.md                   ← Pointer stub
├── PROJECT_SUMMARY.md         ← This file (human front door)
├── project_config.json        ← Runtime configuration
│
├── SRC\                       ← Runnable scripts/modules ONLY
│   ├── run.ps1                ← Single entry point (gatekeeper)
│   ├── modules\               ← Modular components
│   │   ├── classifier.ps1
│   │   ├── planner.ps1
│   │   ├── mover.ps1
│   │   ├── renamer.ps1
│   │   ├── deduper.ps1
│   │   └── semantic_labeler.ps1
│   ├── rules\                 ← Classification/rename/dedup rules
│   └── templates\             ← Output templates
│
├── OUTPUTS\                   ← All run artifacts (never mix with SRC)
│   └── phase_XX\
│       └── run_MM-DD-YYYY_HHMMSS\
│           ├── plan.csv
│           ├── runlog.txt
│           ├── summary_MM-DD-YYYY.md
│           ├── metrics.json
│           ├── rollback.ps1
│           └── evidence\      ← Phase-specific proof artifacts
│
├── PROOF_PACK\                ← Curated recruiter-ready output
│   ├── README.md
│   ├── runbook.md
│   ├── evidence\
│   ├── results\
│   └── code_excerpt\
│
└── agent_assets\              ← Prompts, policies, notes
    ├── prompts\               ← Phase-specific agent prompts
    ├── policies\              ← Allowlist, exclude, execution rules
    └── notes\                 ← Decision logs
```

---

## Phase Model (00-08)

### Universal Audit Spine

Every phase run produces exactly these files:
1. `plan.csv` - What will happen (or happened)
2. `runlog.txt` - Execution log with timestamps
3. `summary_MM-DD-YYYY.md` - Human-readable summary
4. `metrics.json` - Machine-readable metrics
5. `rollback.ps1` - Undo script (or no-op if read-only)
6. `evidence\` - Phase-specific proof artifacts

### Phase Sequence

| Phase | Name | Purpose | Status |
|-------|------|---------|--------|
| **00** | Baseline Snapshot | Read-only "before" anchor | ✅ Complete |
| **01** | Contract Freeze | Lock directory structure & naming rules | ✅ Complete |
| **02** | Inventory + Canonicalization | Eliminate script ambiguity | ✅ Complete |
| **03** | Runner + Config + Validation | Build gatekeeper with config | ✅ Complete |
| **04** | Classification v1 | Deterministic label-only | ✅ Complete |
| **05** | Routing Plan | Generate move plan (no moves yet) | ✅ Complete |
| **06** | Execute Moves | Perform moves with rollback | ✅ Complete |
| **07** | Rename Engine | Enforce `name_MM-DD-YYYY` format | ✅ Complete |
| **08** | Semantic Labeling (Tier 2.5) | AI-assisted classification | 🚧 Starting |

---

## How to Run

### Prerequisites
1. Read `AGENTS_PROJECT.md` (single source of truth)
2. Verify `project_config.json` exists and is valid
3. Ensure you're in project root: `C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2\`

### Execution

```powershell
# Always run from project root
cd C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2

# DryRun (default, always run first)
pwsh -NoProfile -ExecutionPolicy Bypass -File "SRC\run.ps1" -Phase 04 -Mode DryRun

# Execute (only after DryRun review)
pwsh -NoProfile -ExecutionPolicy Bypass -File "SRC\run.ps1" -Phase 04 -Mode Execute
```

---

## Workflow — Canonical Sequence

**Standard workflow for every phase:**

### Step 1: Pre-Flight
```powershell
# Verify environment is ready
pwsh -NoProfile -ExecutionPolicy Bypass -File "tools\preflight.ps1"
```

**Pre-flight checks:**
- ✅ Confirms repo root (project_config.json + AGENTS_PROJECT.md)
- ✅ Validates config (runs tools/validate_config.ps1)
- ✅ Verifies OUTPUTS is in .gitignore
- ✅ Prints artifact lane contract

### Step 2: Run Phase Tool
```powershell
# DryRun first (always)
pwsh -NoProfile -ExecutionPolicy Bypass -File "SRC\run.ps1" -Phase 04 -Mode DryRun

# Review outputs in OUTPUTS\phase_04\run_MM-DD-YYYY_HHMMSS\

# Execute (after review)
pwsh -NoProfile -ExecutionPolicy Bypass -File "SRC\run.ps1" -Phase 04 -Mode Execute
```

**Outputs go to:** `OUTPUTS\phase_XX\run_MM-DD-YYYY_HHMMSS\`

### Step 3: Promote to PROOF_PACK
```powershell
# Promote default artifacts (plan.csv, metrics.json, summary_*.md)
pwsh -NoProfile -ExecutionPolicy Bypass -File "tools\promote_to_proof_pack.ps1" -Phase 04

# Or promote specific files
pwsh -NoProfile -ExecutionPolicy Bypass -File "tools\promote_to_proof_pack.ps1" -Phase 04 -PromoteList @('plan.csv', 'metrics.json', 'evidence\key_file.txt')
```

**Promoted artifacts go to:** `PROOF_PACK\phase_XX\run_<run_id>\`

### Step 4: Commit PROOF_PACK
```powershell
# Review promoted artifacts
git status

# Commit to git (PROOF_PACK only, OUTPUTS never committed)
git add PROOF_PACK
git commit -m "proof: Phase 04 artifacts"
git push
```

### Two-Lane Model
- **OUTPUTS/** — Messy generated lane (NOT committed, execution outputs only)
- **PROOF_PACK/** — Curated recruiter-safe lane (committed to git, promoted artifacts only)

**Promotion rule:** Only curated artifacts are copied from OUTPUTS → PROOF_PACK.

---

## Core Contracts (DO NOT VIOLATE)

### 1. No Deletes, No Overwrites
- Never delete files permanently
- Never overwrite without backup
- Collision policy: suffix `_01`, `_02`, etc.

### 2. DryRun First (Always)
- Every mutating operation runs DryRun first
- Generate plan files for review
- Require explicit approval before execution

### 3. Scan Roots vs Quarantine
**Scan these (defined in project_config.json allowlist_roots):**
- `C:\RH\INBOX` (Downloads, Desktop, incoming)
- `C:\RH\OPS` (Operations, projects, research)

**Quarantine destination only (NEVER scanned):**
- `C:\RH\TEMPORARY` (low-confidence files)

**NEVER touch:**
- `C:\RH\VAULT` (credentials)
- `C:\RH\LIFE` (personal)
- `C:\LEGACY` (backups)
- `C:\Windows` (system)
- `C:\Program Files` (applications)

### 4. All Outputs to OUTPUTS Only
- NEVER write artifacts to `SRC\`
- NEVER write artifacts to project root
- ALWAYS write to: `OUTPUTS\phase_XX\run_MM-DD-YYYY_HHMMSS\`

### 5. Low Confidence → Review Queue
- Auto-move: confidence >= 0.85
- Review queue: confidence 0.60 - 0.84
- Quarantine: confidence < 0.60

### 6. Rollback Required
- Phases 06-07 MUST generate `rollback.ps1`
- Test rollback in DryRun before execution

---

## Naming Conventions

### Run Directories
Format: `run_MM-DD-YYYY_HHMMSS`

Example: `run_02-08-2026_140111`

### Summary Files
Format: `name_MM-DD-YYYY.md`

Example: `summary_02-08-2026.md`

### General Files
Format: `descriptive-name_MM-DD-YYYY.ext`

**NEVER use:**
- ISO dates (2026-02-08)
- Year-first dates (2026_02_08)

---

## Configuration

Runtime behavior is controlled by `project_config.json`:
- Allowlist/exclude roots
- Confidence thresholds
- Collision handling
- Naming format enforcement
- Log levels

**No hardcoded paths.** All paths come from config.

---

## Phase 00 Results (Baseline)

**Run:** `run_02-08-2026_140111`
**Status:** ✅ Complete

**Findings:**
- **9,883 files** scanned across `C:\RH`
- **643 scripts** identified (.ps1, .py, .sh, .bat, .cmd)
- **88 config files** found (rules, contracts, policies)
- **Top 50 duplicate groups** documented

**Evidence Location:**
```
C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2\OUTPUTS\phase_00\run_02-08-2026_140111\evidence\
```

---

## Next Steps

1. ✅ Phase 00 baseline complete
2. ⏳ Create Phase 01 contracts (directory, naming, no-delete, scope, execution)
3. ⏳ Build Phase 02 canonical script manifest
4. ⏳ Develop Phase 03 runner with validation
5. ⏳ Design Phase 04 classification rules

---

## Support

**Primary Documentation:**
- `AGENTS_PROJECT.md` - Agent instructions
- `PROJECT_SUMMARY.md` - This file (human overview)
- `project_config.json` - Runtime configuration

**Phase Evidence:**
- `OUTPUTS\phase_XX\run_*\` - All run artifacts with audit spine

**Proof Pack:**
- `PROOF_PACK\` - Recruiter-ready curated evidence

---

## Validation

To verify project structure is correct:

```powershell
# Check all required directories exist
$required = @('SRC', 'OUTPUTS', 'PROOF_PACK', 'agent_assets')
foreach ($dir in $required) {
    $path = "C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2\$dir"
    if (Test-Path $path) {
        Write-Output "✅ $dir"
    } else {
        Write-Output "❌ $dir MISSING"
    }
}
```

---

## Phase 01 Audit

To verify Phase 01 run artifacts are complete:

```powershell
# Run Phase 01 audit (read-only)
pwsh -NoProfile -ExecutionPolicy Bypass -File "tools\audit_phase01.ps1"
```

The audit script will:
- Find the newest run_* folder in OUTPUTS\phase_01\
- Verify required files exist and are non-empty (plan.csv, runlog.txt, metrics.json, rollback.ps1)
- Check evidence\ directory contains at least 1 file
- Report PASS or UNKNOWN status with details

**Exit codes:**
- 0 = PASS (all artifacts present)
- 1 = UNKNOWN (missing or empty items)
- 2 = No phase_01 runs found

---

**For detailed agent instructions, read `AGENTS_PROJECT.md`.**
