# RH_MIGRATION_2026_V2 — Phase Gates (00–08) (02-08-2026)
A phase is **NOT COMPLETE** until its run folder contains the **audit spine** and the phase-specific evidence deliverables are present and non-empty.

---

## Universal Audit Spine (required for every phase run)
Each run folder must contain:
- `plan.csv`
- `runlog.txt`
- `summary_MM-DD-YYYY.md`
- `metrics.json`
- `rollback.ps1`
- `evidence\` folder

If any is missing → **phase run invalid**.

---

## Phase 00 — Baseline Snapshot (read-only)
**Done when:**
- Evidence includes: tree, inventory, scripts list, configs list, duplicates, allow/exclude
- No files moved/renamed/deleted

---

## Phase 01 — Contracts
**Evidence deliverables:**
- `directory_contract.md`
- `naming_contract.md`
- `no_delete_contract.md`
- `scope_allowlist.md`
- `execution_doorway_rules.md`
**Done when:**
- Contracts exist AND are treated as frozen for phases 02–08.

---

## Phase 02 — Inventory + Canonicalization
**Evidence deliverables:**
- `duplicate_scripts_report.csv`
- `script_hashes.csv`
- `canonical_script_manifest.csv`
- `rules_inventory.csv`
**Done when:**
- Every runnable script has exactly one canonical path + hash.

---

## Phase 03 — Runner + Config + DryRun Validation
**Evidence deliverables:**
- `project_config.json`
- `run.ps1` (or runner)
- `run_interface.md`
- `dryrun_validation_checklist.md`
**Done when:**
- DryRun writes only to OUTPUTS and prints/logs canonical script+config+output paths.

---

## Phase 04 — Classification v1 (label-only)
**Evidence deliverables:**
- `classification_rules_v1.yaml`
- `classification_results.csv` (confidence + reason)
- `misclass_queue.csv`
- `bucket_taxonomy.md`
**Done when:**
- Low confidence items are queued, not moved.

---

## Phase 05 — Routing plan (plan-only)
**Evidence deliverables:**
- `move_plan.csv`
- `collisions.csv`
- `exclusions_applied.txt`
**Done when:**
- Plan is reviewable and collisions are visible.

---

## Phase 06 — Execute moves (with rollback)
**Evidence deliverables:**
- `moves_executed.csv`
- `errors.csv`
- `state_tree_after_moves.txt`
**Done when:**
- Executed moves match the plan and rollback exists.

---

## Phase 07 — Rename engine
**Evidence deliverables:**
- `rename_rules_v1.yaml`
- `rename_plan.csv`
- `rename_executed.csv`
- `rename_collisions.csv`
**Done when:**
- Naming rule enforced, no overwrites, rollback exists.

---

## Phase 08 — Semantic labeling (Tier 2.5)
**Evidence deliverables:**
- `training_examples_manifest.csv`
- `semantic_labels.csv`
- `merge_logic.md` (deterministic overrides)
- `semantic_misclass_queue.csv`
- optional: `classification_rules_v2.yaml` (only after review)
**Done when:**
- Semantic improves confidence but never moves files directly.
