# Canonical Root Rules (02-07-2026)

## Authoritative Roots
- C:\RH\
- C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\ (project root)

## Canonical RH structure
- C:\RH\INBOX\
- C:\RH\OPS\
- C:\RH\LIFE\
- C:\RH\VAULT\

## Governance Rules
- DryRun by default.
- Execute only on explicit approval.
- Never delete; move to project trash.
- Use -LiteralPath for file operations.
- Use deterministic dupe suffix (dupe-0001) when destination conflicts.

## Reference Notes (from refrence.txt)
Got it. We keep **what you just finished** as **Phase 4** in the *new* master plan. Everything else gets renumbered around it so you’re not mentally context-switching between “old plan Phase 4” and “new plan Phase 4.” Minimal confusion. ✅

Below is the **full 0 → finished plan** with **exact `C:\RH\...` paths** and your **filename rule**: `name_MM-DD-YYYY.ext`.

---

# RH Master Plan v2 (0 → Finished)

## Global standards

* **Canonical root:** `C:\RH\`
* **Filename format always:** `name_MM-DD-YYYY.ext`
* **Run artifacts (not git):** `C:\RH\OPS\SYSTEM\DATA\runs\`
* **Code/docs (git):** `C:\RH\OPS\BUILD\src\repos\`

---

## Phase 0 — Freeze the world (stop new chaos)

**Goal:** prevent new junk while you clean.

* [ ] Confirm `C:\RH\` is the only canonical root
* [ ] Ensure these exist:

  * [ ] `C:\RH\OPS\_ARCHIVE\root_quarantine\`
  * [ ] `C:\RH\OPS\_ARCHIVE\phase4_snapshots\mini\`
  * [ ] `C:\RH\OPS\SYSTEM\DATA\runs\`
* [ ] Define “no-output zones”:

  * [ ] nothing should dump into random folders under `C:\RH\OPS\SYSTEM\migrations\...`
* [ ] Create a single “ledger” doc location:

  * [ ] `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\migration_ledger_02-07-2026.md`

**Deliverable:** `system_freeze_notes_02-07-2026.md`

---

## Phase 1 — Lock the canonical directory map

**Goal:** every file has exactly one correct lane.

* [ ] Canonical roots exist:

  * [ ] `C:\RH\OPS\`
  * [ ] `C:\RH\LIFE\`
  * [ ] `C:\RH\VAULT\`
  * [ ] `C:\RH\VAULT_NEVER_SYNC\`
  * [ ] `C:\RH\INBOX\`
  * [ ] `C:\RH\ARCHIVE\`
* [ ] Inbound landing zones exist:

  * [ ] `C:\RH\INBOX\DOWNLOADS\`
  * [ ] `C:\RH\INBOX\DESKTOP_SWEEP\`
  * [ ] `C:\RH\LIFE\MEDIA\INBOX\`
* [ ] Migration zones exist:

  * [ ] `C:\RH\OPS\QUARANTINE\FROM_2026\`
  * [ ] `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\`

**Deliverable:** `canonical_directory_map_02-07-2026.md`

---

## Phase 2 — Consolidate project structure (engine vs runs)

**Goal:** stop output sprawl; make it recruiter-clean.

### 2A: Repo (engine) lives here

* [ ] `C:\RH\OPS\BUILD\src\repos\rh-migration-discovery-engine\`

  * [ ] `scripts\`
  * [ ] `rules\`
  * [ ] `docs\`
  * [ ] `.gitignore`
  * [ ] `README.md`

### 2B: Runs (outputs) live here

* [ ] `C:\RH\OPS\SYSTEM\DATA\runs\phase4\<run_id>\` (and later other phases)

### 2C: Migrations folder becomes “ledger only”

Keep in:
`C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\`

* [ ] `migration_ledger_02-07-2026.md`
* [ ] `latest_run_pointer_02-07-2026.txt`
* [ ] canonical rules snapshot(s) if needed

**Deliverable:** `migration_folder_hygiene_02-07-2026.md`

---

## Phase 3 — Full `C:\RH` inventory scan (baseline truth)

**Goal:** one authoritative inventory for dedupe + rename + routing.

* [ ] Inventory all of `C:\RH`:

  * paths, size, created/modified, extension
* [ ] Summaries:

  * biggest folders
  * largest files
  * extension distribution

**Run folder:**
`C:\RH\OPS\SYSTEM\DATA\runs\inventory\02-07-2026\`

**Outputs:**

* `full_inventory_02-07-2026.csv`
* `inventory_summary_02-07-2026.md`

---

## ✅ Phase 4 — Quarantine Work-Unit Reconstruction Engine (COMPLETED)

**Goal:** classify and migrate quarantine into correct RH lanes safely.

**What was done (this thread):**

* [x] Dry-run iteration reduced triage from ~36% → ~10%
* [x] Execute run processed ~5290 rows
* [x] Quarantine drained to 0 files
* [x] Root-cause fixes applied:

  * metrics reporting mismatch addressed
  * file-as-folder bug fixed (`Get-OriginalSubfolder`)
  * wildcard/path handling fixed (`-LiteralPath`)
* [x] Run artifacts archived under `C:\RH\OPS\SYSTEM\DATA\runs\phase4\...`
* [x] Repo skeleton created under `C:\RH\OPS\BUILD\src\repos\rh-migration-discovery-engine\`

**Deliverable:** `phase4_closeout_02-07-2026.md`

---

## Phase 5 — Duplicate elimination across `C:\RH`

**Goal:** no duplicates (with explicit exclusions).

### 5A: Candidate pass (name+size)

* [ ] Find candidate duplicates by `(filename + size)` across `C:\RH`

### 5B: Confirm pass (hash)

* [ ] Hash-confirm candidates
* [ ] Generate dedupe actions:

  * keep-path (canonical lane)
  * remove-path (duplicate lane)
  * action: move to quarantine first

### 5C: Execute safely

* [ ] Move duplicates to:

  * `C:\RH\OPS\_ARCHIVE\dedupe_quarantine\02-07-2026\`
* [ ] Delete only after verifying nothing broke

**Hard exclusions (manual only):**

* `C:\RH\VAULT_NEVER_SYNC\`
* `.git\` folders (repos)
* caches (`node_modules`, `venv`) unless targeted

**Outputs:**

* `dedupe_candidates_02-07-2026.csv`
* `dedupe_confirmed_02-07-2026.csv`
* `dedupe_actions_02-07-2026.csv`

---

## Phase 6 — Windows default routing (stop recontamination)

**Goal:** downloads/screenshots stop landing in random Windows defaults.

### 6A: Move existing piles

* [ ] `%USERPROFILE%\Downloads` → `C:\RH\INBOX\DOWNLOADS\`
* [ ] Desktop loose files → `C:\RH\INBOX\DESKTOP_SWEEP\`
* [ ] Screenshots/Pictures intake → `C:\RH\LIFE\MEDIA\INBOX\`

### 6B: Redirect Known Folders

* [ ] Downloads → `C:\RH\INBOX\DOWNLOADS\`
* [ ] Desktop → `C:\RH\INBOX\DESKTOP_SWEEP\` (or `C:\RH\LIFE\DESKTOP\`)
* [ ] Documents → `C:\RH\LIFE\DOCS\`
* [ ] Pictures → `C:\RH\LIFE\MEDIA\PHOTOS\`
* [ ] Videos → `C:\RH\LIFE\MEDIA\VIDEOS\`

**Deliverable:** `windows_folder_redirects_02-07-2026.md`

---

## Phase 7 — Rename normalization (context + your date format)

**Goal:** filenames are predictable and meaningful.

**Rule:** `name_MM-DD-YYYY.ext` always.

### 7A: Naming taxonomy (context keywords)

* OPS/SOC: `soc_detection_...`, `wazuh_rule_...`, `automation_...`
* Migration: `migration_phase4_...`, `migration_inventory_...`
* Life: `life_medical_...`, `life_finance_...`, `amahirah_school_...`
* Media: `photo_...`, `screenshot_...`

### 7B: Rename waves

1. `C:\RH\INBOX\DOWNLOADS\`
2. `C:\RH\LIFE\MEDIA\INBOX\`
3. loose docs at top of lanes
4. deep archive last

**Outputs:**

* `rename_rules_02-07-2026.md`
* `rename_plan_02-07-2026.csv`
* `rename_actions_02-07-2026.csv`

---

## Phase 8 — Root cleanup (no mystery folders under `C:\RH`)

**Goal:** top-level is clean and intentional.

* [ ] List folders directly under `C:\RH\`
* [ ] Anything outside the canonical roots:

  * move to correct lane, or
  * park in `C:\RH\OPS\_ARCHIVE\root_quarantine\02-07-2026\`

**Deliverable:** `root_cleanup_log_02-07-2026.md`

---

## Phase 9 — Git packaging (recruiter-facing)

**Goal:** publish the engine without leaking personal paths.

* [ ] In `C:\RH\OPS\BUILD\src\repos\rh-migration-discovery-engine\`:

  * [ ] `git init`
  * [ ] `.gitignore` blocks all run outputs/logs/CSVs
  * [ ] Commit scripts + rules + docs only
* [ ] README includes:

  * what it does
  * safety model (dry-run, rollback, secrets)
  * before/after metrics (triage reduction)
  * how to run

**Repo docs:**

* `readme_02-07-2026.md`
* `postmortem_02-07-2026.md`

---

## Phase 10 — Acceptance tests (prove “done”)

**Goal:** measurable completion.

* [ ] Inventory shows:

  * no unexpected `C:\RH` top-level folders
  * duplicates report empty or documented waivers
* [ ] Windows routing verified:

  * new downloads land in `C:\RH\INBOX\DOWNLOADS\`
  * new screenshots land in `C:\RH\LIFE\MEDIA\INBOX\`
* [ ] Phase 4 engine stable:

  * repo exists, documented, reproducible
  * run archives exist outside git

**Deliverable:** `final_acceptance_report_02-07-2026.md`

---

## Phase 11 — Long-term guardrails (so you don’t redo this)

**Goal:** keep it clean automatically.

* [ ] Monthly run:

  * inventory + duplicate scan (report-only)
  * outputs to:

    * `C:\RH\OPS\SYSTEM\DATA\runs\maintenance\MM-DD-YYYY\`
* [ ] Rule: all incoming goes through `C:\RH\INBOX\...`
* [ ] Rule: sensitive stays in `C:\RH\VAULT_NEVER_SYNC\`

**Deliverable:** `maintenance_guardrails_02-07-2026.md`

---

## Where you are right now

* **Phase 4 is done.**
* You’re somewhere between **Phase 2 (structure consolidation)** and starting **Phase 3 (full inventory)**, depending on whether you’ve fully moved outputs into `SYSTEM\DATA\runs\...` and cleaned the migrations folder down to ledger+pointer.

If you want the next move to be maximally high ROI: **finish Phase 2 (engine vs runs separation)** and then do Phase 6 (Windows routing) so new junk stops accumulating while you scan/dedupe/rename.

Phase 6 Canonical Invocation
- DryRun: pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_06\scripts\Phase6-CanonicalInbox.ps1" -Mode DryRun
- Execute: pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_06\scripts\Phase6-CanonicalInbox.ps1" -Mode Execute
- Legacy Phase 6 script paths under C:\RH\OPS\BUILD\scripts are deprecated.


## Supplemental Notes (from RH-OPS.txt)
C:RH/OPS/
├─ SYSTEM/
│  ├─ obsidian/
│  └─ ai_context/
│
├─ CAPTURE/                      # tired-day dump (sort later, don’t lose work)
│  ├─ screenshots/
│  ├─ logs/
│  ├─ exports/
│  └─ tmp/
│
├─ PROOF_PACKS/                  # recruiter-proof outputs live here
│  ├─ SOC/
│  │  ├─ PP-000_DRAFTS/
│  │  ├─ PP-001_WAZUH_BASELINE/
│  │  │  ├─ README.md
│  │  │  ├─ DETECTION/
│  │  │  ├─ PLAYBOOK/
│  │  │  ├─ EVIDENCE/
│  │  │  │  └─ _INBOX/          # quick drop if you’re exhausted
│  │  │  └─ AUTOMATION/         # optional
│  │  ├─ PP-002_SPLUNK_FAILED_LOGON/
│  │  │  ├─ README.md
│  │  │  ├─ DETECTION/
│  │  │  ├─ PLAYBOOK/
│  │  │  ├─ EVIDENCE/
│  │  │  │  └─ _INBOX/
│  │  │  └─ AUTOMATION/
│  │  └─ PP-003_ENDPOINT_TRIAGE/
│  │     ├─ README.md
│  │     ├─ DETECTION/
│  │     ├─ PLAYBOOK/
│  │     ├─ EVIDENCE/
│  │     │  └─ _INBOX/
│  │     └─ AUTOMATION/
│  │
│  ├─ DETECTION_ENGINEERING/
│  │  ├─ PP-000_DRAFTS/
│  │  └─ PP-0XX_<OUTCOME>/
│  │     ├─ README.md
│  │     ├─ DETECTION/
│  │     ├─ EVIDENCE/
│  │     │  └─ _INBOX/
│  │     └─ AUTOMATION/
│  │
│  ├─ INCIDENT_RESPONSE/
│  │  ├─ PP-000_DRAFTS/
│  │  └─ PP-0XX_<OUTCOME>/
│  │     ├─ README.md
│  │     ├─ PLAYBOOK/
│  │     ├─ EVIDENCE/
│  │     │  └─ _INBOX/
│  │     └─ NOTES.md            # optional
│  │
│  ├─ SECURITY_AUTOMATION/
│  │  ├─ PP-000_DRAFTS/
│  │  └─ PP-0XX_<OUTCOME>/
│  │     ├─ README.md
│  │     ├─ AUTOMATION/
│  │     ├─ EVIDENCE/
│  │     │  └─ _INBOX/
│  │     └─ RUNBOOK.md          # optional but nice
│  │
│  └─ NETWORK/
│     ├─ PP-000_DRAFTS/
│     └─ PP-0XX_<OUTCOME>/
│        ├─ README.md
│        ├─ DETECTION/
│        ├─ EVIDENCE/
│        │  └─ _INBOX/
│        └─ AUTOMATION/
│
├─ BUILD/                        # tools, code, pipelines (allowed to be messy)
│  ├─ src/
│  ├─ scripts/
│  ├─ security_automation/
│  │  ├─ configs/
│  │  ├─ pipelines/
│  │  └─ libs/
│  └─ lab_infra/
│
├─ RESEARCH/                     # thinking, learning, experiments (not proof)
│  ├─ notes/
│  ├─ ai/
│  ├─ experiments/
│  ├─ operators_manual/
│  └─ job_market/
│
├─ PUBLISH/                     # publishing surfaces
│  ├─ website/
│  ├─ portfolio_upload/
│  └─ case_studies/
│
├─ _QUARANTINE/                  # cursed / unstable / nested repos / test junk
│  ├─ nested_repos/
│  ├─ github_bits/
│  └─ copilot_tests/
│
└─ _ARCHIVE/                     # read-only forever (snapshots, old packs)
   ├─ old_repo_snapshot/
   ├─ day1_audit_pack/
   └─ pack_v1/
