## 1) Thread ID + Scope

- **Thread title:** Phase 4 Discovery Engine stabilization + triage reduction (PowerShell + YAML rules)
    
- **Date range covered:** **Feb 6–Feb 7, 2026** (based on run stamps/log output in-thread)
    
- **What this thread contributed:**
    
    - Stabilized the Phase 4 pipeline to run end-to-end (dry-run) and cleaned the “OUTPUTS multiverse” down to one canonical set.
        
    - Enabled **Random sampling** and produced a high-signal **Random 5000** baseline run with metrics.
        
    - Identified triage root causes and proposed minimal YAML fixes (classification mismatch + bucket routing) to push triage under threshold.
        

---

## 2) Original intent (as stated in this thread)

- **Goal**
    
    - Get Phase 4 “Discovery Engine” reliably reconstructing **PROOF_PACK work units** from `C:\RH` / `C:\RH\OPS\QUARANTINE\FROM_2026` without anchor explosions, nondeterminism, or unsafe moves.
        
- **What “done” would have meant**
    
    - Dry-run produces stable, auditable outputs: inventory → unit candidates → membership → classification → move plan + rollback → summary, with reasonable triage and correct routing.
        
- **Explicit success criteria / acceptance tests mentioned**
    
    - From summary acceptance checks:
        
        - **Tier1 anchors:** 50–500 (PASS expected)
            
        - **Units produced:** 20–200 (PASS expected)
            
        - **Assigned ≥ 60%:** PASS expected
            
        - **TRIAGE_LOWCONF + SCRATCH_INTAKE < 30%:** PASS target (initially failing)
            
        - Guards seen: abort if triage > configured threshold; abort if anchors > 800 (mentioned in validation plan)
            

---

## 3) What we actually accomplished (high signal only)

- **Concrete deliverables produced**
    
    - Canonical Phase 4 script set confirmed via orchestrator call chain in `...\OUTPUTS\Execute-Phase4_FIXED.ps1`.
        
    - Patched robustness issues around `.Count` / scalar-vs-array handling via `As-Array` semantics across risky scripts (done prior; validated by successful end-to-end runs).
        
    - Added **Random** sampling support by updating `ValidateSet` in multiple scripts (at least orchestrator + inventory script).
        
    - Created and ran a cleanup script **`Cleanup-Outputs.ps1`** that moved duplicates/old runs into `_TRASH` and kept a single canonical set.
        
    - Created a research bundling script **`Build-Phase4ResearchBundle.ps1`** (but discovered a bug: missing `[void]$includeSet.Add(...)` in run-stamp inclusion block; required patch).
        
- **Progress quantified**
    
    - Early dry-run baseline (Newest 300): **Triage 98%** due to Tier1 anchors = 0 (sample bias) + orphans, guardrail abort triggered.
        
    - Post-fix Random run (MaxFiles 5000):
        
        - Inventory: **5000 files** (4998 small, 2 large)
            
        - Tier1 anchors found: **436**
            
        - Folder seed roots found: **3**
            
        - Repo roots found: **7**
            
        - Orphans: **1828** (bucketed into triage units)
            
        - Move plan rows: **5025**
            
        - Triage rows: **1827/5025 = 36.36%**
            
        - Summary checks: anchors PASS, units PASS, assigned PASS, triage threshold FAIL
            
- **What changed from the start**
    
    - Shifted from “scripts crash” to “scripts run; rules tuning needed.”
        
    - Identified that “Newest 300” sampling was misleading; Random sampling revealed anchors exist and units can be reconstructed.
        

---

## 4) Current state at end of thread

- **What is working now**
    
    - Phase 4 pipeline runs end-to-end in **DRY-RUN**:
        
        - Inventory → Work unit reconstruction → Classification → Move plan + rollback → Summary.
            
    - Random sampling mode works (`-SampleMode Random`).
        
    - OUTPUTS directory is de-duplicated/canonical (old runs moved to `_TRASH`).
        
- **What is partially working**
    
    - Triage reduction: improved from 98% (Newest 300) to 36% (Random 5000), but still failing target <30%.
        
    - Research-bundle zip automation exists but had a logic gap (run-stamp inclusion missing add).
        
- **What is broken / blocked**
    
    - **Acceptance test still failing:** TRIAGE_LOWCONF + SCRATCH_INTAKE remains **36.36%** (>30%).
        
    - Build-Phase4ResearchBundle script: run-stamp inclusion block incomplete in the version shown (no includeSet add), risking incoherent bundle.
        
- **What remains UNKNOWN (and why)**
    
    - UNKNOWN: Exact YAML semantics of `source_root_contains` and what field it is matched against (RootGroup vs SourcePath) without opening the rule parser/classifier code in this thread.
        
    - UNKNOWN: Whether Tier2 signals are fully unused in membership logic (claimed by one model output; not proven by code inspection in-thread).
        
    - UNKNOWN: Whether proposed folder seeds would create overlapping unit ownership without testing on full dataset.
        

---

## 5) Errors + failures encountered

### A) Random sampling rejected

- **Symptom**
    
    - `Cannot validate argument on parameter 'SampleMode'. The argument "Random" does not belong to the set "Newest,Path" specified by the ValidateSet attribute.`
        
- **Root cause**
    
    - `ValidateSet('Newest','Path')` existed in called script(s) (not just orchestrator). Random wasn’t allowed.
        
- **Fix attempted**
    
    - Patch ValidateSet to include `'Random'` in **all scripts that define SampleMode** (at least `Build-QuarantineInventory.ps1` + `Execute-Phase4_FIXED.ps1`).
        
- **Outcome**
    
    - Fixed. Random 5000 run succeeded.
        
- **Prevention**
    
    - Centralize shared parameter enums in `Phase4_Common.ps1` or remove ValidateSet in sub-scripts; add preflight self-test that asserts supported SampleModes across invoked scripts.
        

### B) `.Count` missing / scalar-vs-array failures

- **Symptom**
    
    - `The property 'Count' cannot be found on this object. Verify that the property exists.`
        
    - Also seen: `Argument types do not match` pointing at `return @(As-Array $x).Count` (bug in helper).
        
- **Root cause**
    
    - PowerShell pipeline returns `$null`/scalar/array unpredictably; calling `.Count` directly on non-array objects fails; incorrect `As-Array` implementation or recursion caused type mismatch.
        
- **Fix attempted**
    
    - Implement/propagate `As-Array` helper and wrap pipeline results / Import-Csv outputs; replace risky `.Count` and indexing usage.
        
- **Outcome**
    
    - Mitigated: later runs completed end-to-end; no `.Count` crash in final Random 5000 run.
        
- **Prevention**
    
    - Standardize `As-Array` in a single common module and enforce via lint-like search/replace; add preflight “shape tests” before running inventory.
        

### C) Triage abort guardrail firing

- **Symptom**
    
    - `ABORT: triage percentage too high (98% > 50%). Fix anchors/membership before continuing.`
        
- **Root cause**
    
    - Sampling bias (Newest 300) yielded 0 Tier1 anchor hits and massive orphans; guardrail intentionally prevented continuing.
        
- **Fix attempted**
    
    - Increased abort threshold for testing (`-AbortIfTriagePctGreaterThan 99/100`); switched to Random sampling; fixed SampleMode validation.
        
- **Outcome**
    
    - Mitigated: Random 5000 produced 36% triage and completed.
        
- **Prevention**
    
    - Default to Random sampling during tuning; only use Newest for “recent-work triage,” not global quality assessment.
        

### D) Research-bundle script logic gap

- **Symptom**
    
    - In `Build-Phase4ResearchBundle.ps1`, run-stamp inclusion loop had an empty body (no files added), meaning stamp-based bundling didn’t work.
        
- **Root cause**
    
    - Generated code missing `[void]$includeSet.Add($f.FullName)` (likely an LLM omission).
        
- **Fix attempted**
    
    - Proposed patch: add includeSet add + `break`; add sanity checks.
        
- **Outcome**
    
    - Not confirmed executed in-thread (patch instruction provided).
        
- **Prevention**
    
    - Add unit tests: verify zip contains one file per prefix + coherent run set; enforce “min file count” and “prefix uniqueness” checks.
        

---

## 6) Decisions + tradeoffs (with reasoning)

- **Decision:** Keep Phase 4 in **DRY-RUN** until metrics stabilize
    
    - **Why:** Prevent unsafe moves while rules/anchors are still tuning; preserve rollback integrity.
        
    - **Alternatives rejected:** Immediate `-Execute` moves.
        
    - **Impact:** Safer, slower visual progress.
        
- **Decision:** Add a global normalization approach (`As-Array`) rather than whack-a-mole `.Count` patches
    
    - **Why:** Scalar-vs-array is systemic in PowerShell; one helper reduces recurring crashes.
        
    - **Alternatives rejected:** Ad hoc `@(...)` patches at each crash site.
        
    - **Impact:** Reduced repeated failures; enabled pipeline completion.
        
- **Decision:** Use **Random sampling** for coverage during tuning
    
    - **Why:** Newest sampling is biased and masked anchors, causing false “Tier1 broken” conclusions.
        
    - **Alternatives rejected:** Newest-only or small sample sizes as primary truth.
        
    - **Impact:** Anchors appeared (436) and triage dropped dramatically.
        
- **Decision:** Clean OUTPUTS to a single canonical set (move duplicates to `_TRASH`)
    
    - **Why:** Reduce version drift and “which run is current” confusion; enforce single truth.
        
    - **Alternatives rejected:** Keep everything and manually choose files.
        
    - **Impact:** Reduced chaos; easier reproducibility; preserved recovery via trash.
        
- **Decision:** Triage reduction via **classification/folder seed rules**, not loosening Tier1 anchors
    
    - **Why:** Loosening Tier1 risks anchor explosion and misclustering.
        
    - **Alternatives rejected:** “Match more” Tier1 patterns.
        
    - **Impact:** Safer path to reduce triage, maintain precision.
        

---

## 7) Recruiter-proof evidence pack (VERY IMPORTANT)

### A) End-to-end Phase 4 dry-run outputs (Random 5000 baseline)

- **Artifact**
    
    - `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\5.2RESEARCH_MIGRATE\OUTPUTS\PHASE4_SUMMARY_02-07-2026__ceaae1e5.txt`
        
- **Demonstrates**
    
    - Pipeline engineering, reproducibility, metrics-driven validation, safe planning.
        
- **Validate quickly**
    
    - Screenshot summary “PASS/FAIL” block; rerun Random 5000 and compare triage %.
        
- **Redaction**
    
    - Paths are OK; do not include file contents from secrets-flagged items.
        

### B) Inventory + unit reconstruction artifacts

- **Artifacts**
    
    - `...\FULL_INVENTORY_02-07-2026__9b938465.csv`
        
    - `...\WORK_UNIT_CANDIDATES_02-07-2026__482a0b48.csv`
        
    - `...\UNIT_MEMBERS_02-07-2026__ad05bb0e.csv`
        
    - `...\CLASSIFIED_UNITS_02-07-2026__797253bf.csv`
        
- **Demonstrates**
    
    - Data pipeline creation, clustering/unitization, classification scaffolding.
        
- **Validate quickly**
    
    - `Import-Csv` and count rows; check Tier1 anchors; compute triage rate.
        
- **Redaction**
    
    - Paths may contain personal names; avoid publishing raw path lists publicly; redact PII-like folder names.
        

### C) Move plan + rollback plan (safety engineering)

- **Artifacts**
    
    - `...\PHASE4_MOVE_PLAN_02-07-2026__e5efe19c.csv`
        
    - `...\ROLLBACK_PLAN_02-07-2026__61c1b4dc.csv`
        
- **Demonstrates**
    
    - Safe migration planning, rollback discipline, collision handling intent.
        
- **Validate quickly**
    
    - Check row counts match summary; run dupe-source check (Group-Object SourcePath).
        
- **Redaction**
    
    - Same path/PII caution; never publish anything from secrets destinations.
        

### D) Canonical orchestrator + invoked scripts

- **Artifacts**
    
    - `...\Execute-Phase4_FIXED.ps1` (call chain lines shown: 90/96/115/121/139)
        
    - `...\Build-QuarantineInventory.ps1`
        
    - `...\Find-WorkUnits_FIXED.ps1`
        
    - `...\Classify-Units_FIXED.ps1`
        
    - `...\Build-MovePlan_FIXED.ps1`
        
    - `...\Write-Phase4Summary.ps1`
        
    - `...\Phase4_Common.ps1`
        
- **Demonstrates**
    
    - Modular script orchestration, maintainability, parameter passing.
        
- **Validate quickly**
    
    - `Select-String` in orchestrator for invoked scripts; run dry-run command.
        
- **Redaction**
    
    - Ensure scripts don’t contain tokens/keys; replace with `[REDACTED]` if present.
        

### E) OUTPUTS cleanup evidence

- **Artifact**
    
    - Cleanup report text showing kept vs moved files (19 kept, 34 moved, ~1.6MB moved)
        
    - `...\Cleanup-Outputs.ps1`
        
- **Demonstrates**
    
    - Operational hygiene, reproducibility, version control discipline.
        
- **Validate quickly**
    
    - Show `_TRASH` folder with moved artifacts; verify only latest set remains.
        
- **Redaction**
    
    - None beyond path/PII caution.
        

### F) Research bundle tooling (optional evidence)

- **Artifact**
    
    - `...\Build-Phase4ResearchBundle.ps1` (note: requires patch/fix)
        
- **Demonstrates**
    
    - Packaging outputs for offline review/model analysis; automation.
        
- **Validate quickly**
    
    - Run script; list zip contents; assert one-per-prefix.
        
- **Redaction**
    
    - Ensure no secrets in bundled scripts/logs; scan for “token/apikey/password”.
        

---

## 8) Signal vs noise

### Signal (top bullets)

- Random sampling unlocked true anchor coverage: **Tier1=436**, triage reduced to **36%**.
    
- Pipeline runs end-to-end in dry-run producing inventory/candidates/members/classified/move/rollback/summary.
    
- Major failure mode: PowerShell scalar-vs-array `.Count` issues; mitigated via `As-Array`.
    
- Major procedural fix: eliminate OUTPUTS duplication multiverse via cleanup to one canonical set.
    
- Current blocker is rule-driven triage, not script stability.
    
- Proposed minimal YAML change: classification string mismatch (RootGroup vs SourcePath) likely causing LIFE buckets to fall into SCRATCH.
    
- Proposed broader triage reduction: add classification for known buckets + optional folder seeds with overlap checks.
    

### Noise (ignore when merging)

- Repeated frustration/recaps about “why scripts won’t work.”
    
- Debates about whether to use Codex vs research model (resolved: use tight loop for patching; research for tuning after stable run).
    
- Duplicate output filenames and older run artifacts moved to `_TRASH`.
    
- Speculative model claims not verified by code (Tier2 unused, exact field matched by `source_root_contains`) unless later validated.
    

---

## 9) Next actions (thread-local)

### Immediate next steps (3–10)

1. **Apply the smallest YAML fix first**: update `LIFE_PERSONAL.conditions.source_root_contains` to match RootGroup semantics (likely `['LIFE\']`).
    
2. Rerun: `-SampleMode Random -MaxFiles 5000 -AbortIfTriagePctGreaterThan 100`.
    
3. Compare triage % in new `PHASE4_SUMMARY_*`: target **<30%**.
    
4. If triage still >30%, add **classification rules** (not seeds) for:
    
    - `ROOT_MISC\_INBOX` → OPS inbox import
        
    - `OPS\RESEARCH` → OPS research import
        
    - `ROOT_MISC\.obsidian` → configs holding
        
5. Rerun Random 5000; re-check triage % and unit counts; ensure anchors remain in-range.
    
6. Only if still needed, add **folder seeds** one at a time; after each run:
    
    - check duplicate SourcePath assignments in move plan (`Group-Object SourcePath | Where Count -gt 1`).
        
7. Fix `Build-Phase4ResearchBundle.ps1` run-stamp inclusion bug (if still used): add `[void]$includeSet.Add(...)` + sanity checks; validate zip contents.
    
8. Once triage passes consistently, plan **controlled execute** (repos-only first, then high-confidence proof packs).
    

### Dependencies / prerequisites

- Need consistent YAML parsing and clear definition of what `source_root_contains` matches (RootGroup vs SourcePath) in classifier code (verify in scripts).
    
- Maintain OUTPUTS as canonical single-truth folder to avoid drift.
    
- Secrets policy must remain “flag-only,” no auto-moving sensitive content into normal destinations.
    

### Risks if delayed

- Drift returns: duplicate runs/scripts proliferate, reintroducing “which file ran?” confusion.
    
- Premature move execution risks context loss and collision chaos.
    
- Triage stays high, blocking move plan confidence and slowing the rename/dedup phases.