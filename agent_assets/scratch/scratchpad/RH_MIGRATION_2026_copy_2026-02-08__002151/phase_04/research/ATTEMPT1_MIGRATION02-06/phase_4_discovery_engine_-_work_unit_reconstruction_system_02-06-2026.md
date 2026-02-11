# Phase 4 Discovery Engine - Work Unit Reconstruction System

**Created:** 2026-02-06  
**For:** Raylee / HawkinsOps  
**Purpose:** Sort 4,905 quarantined files into proof packs and projects

---

## What This Does

Reconstructs your scattered work (Wazuh rules, playbooks, screenshots, configs) into coherent **work units** (primarily Proof Packs) so you can prove what you've done and stop losing work.

**This is NOT "sort by extension" bullshit.** This uses:
- Anchor detection (Wazuh rules, Sigma detections, playbooks, evidence files)
- Neighbor clustering (files that belong together)
- Token analysis (meaningful keywords from paths/filenames)
- Content feature extraction (MITRE refs, rule IDs, KQL patterns)
- Deterministic unit keys (idempotent reruns)

---

## Quick Start

### 1. DryRun (Review Mode - SAFE)

```powershell
.\Execute-Phase4.ps1
```

This generates all reports but **doesn't move anything**. You get:
- `FULL_INVENTORY.csv` - Complete file scan with features
- `WORK_UNIT_CANDIDATES.csv` - Discovered clusters
- `CLASSIFIED_UNITS.csv` - Type assignments
- `PHASE4_MOVE_PLAN.csv` - **What will happen** (review this!)
- `ROLLBACK_PLAN.csv` - Safety net
- `DUPLICATES_REPORT.csv` - Space wasters
- `PHASE4_SUMMARY.txt` - Human-readable overview

### 2. Review Outputs

**CRITICAL - Check these files:**
1. `PHASE4_MOVE_PLAN.csv` - Where everything goes
2. `COLLISIONS_REVIEW.csv` - Any naming conflicts
3. `SECRETS_FLAGGED.csv` - Credentials being routed to vault

### 3. Execute (if approved)

```powershell
.\Execute-Phase4.ps1 -Execute
```

**WARNING:** This actually moves files. Make sure you reviewed step 2.

---

## File Manifest

### Core Scripts (run in order, or use orchestrator)

1. **Build-QuarantineInventory.ps1** - Safe inventory with feature flags
   - Scans quarantine
   - Computes SHA256 hashes (staged for performance)
   - Extracts features (HasMITRE, HasKQL, HasWazuh, etc.)
   - Flags secrets (NO content preview by default)
   - Output: `FULL_INVENTORY.csv`

2. **Find-WorkUnits.ps1** - Deterministic clustering
   - Detects anchor files (rules, queries, evidence, playbooks)
   - Clusters neighbors around anchors
   - Uses deterministic unit keys
   - Maintains registry for idempotent reruns
   - Output: `WORK_UNIT_CANDIDATES.csv`, `UNIT_REGISTRY.json`

3. **Classify-Units.ps1** - YAML-driven classification
   - Applies rules from `phase4_rules.yml`
   - **Biases toward PROOF_PACK** when confidence ≥0.6
   - Assigns unit types (PROOF_PACK_SOC, PROOF_PACK_IR, LAB_ENV, etc.)
   - Output: `CLASSIFIED_UNITS.csv`

4. **Invoke-DedupeScan.ps1** - Hash-based deduplication
   - Finds duplicates by SHA256
   - Keeps newest by LastWriteTime
   - Proposes move to archive (never deletes)
   - Output: `DUPLICATES_REPORT.csv`

5. **Build-MovePlan.ps1** - Collision-safe planning
   - Generates move plan with collision handling
   - **Minimal renaming** (garbage + collisions only)
   - Git repo protection (never rename files in repos)
   - Creates rollback plan
   - Output: `PHASE4_MOVE_PLAN.csv`, `ROLLBACK_PLAN.csv`

6. **Execute-Phase4.ps1** - Master orchestrator
   - Runs full pipeline
   - **DryRun by default** (no moves without `-Execute`)
   - Generates summary report
   - Checks acceptance criteria

### Configuration

- **phase4_rules.yml** - Classification rules (edit this to tune behavior)
  - Anchor patterns
  - Classification rules
  - Secrets patterns
  - Garbage filename patterns
  - Feature extraction patterns

---

## Acceptance Criteria (What "Success" Looks Like)

✅ **60-80% of files** assigned to non-triage destinations at confidence ≥0.6  
✅ **Triage folder < 20-30%** of total files  
✅ **Secrets flagged** if credentials exist (sanity check)  
✅ **Zero overwrites** - all collisions logged  
✅ **Every execution** generates rollback plan + manifest  
✅ **No raw content** in CSV logs (feature flags only)

---

## Safety Features

### Locked Constraints

1. **Vault path:** `C:\RH\VAULT\_SECRETS_TRIAGE\` (canonical, no alternatives)
2. **No content in CSVs** - Feature flags only, debug preview opt-in separate file
3. **Deterministic units** - `UNIT_REGISTRY.json` persists IDs across reruns
4. **Git repos atomic** - Upward `.git` detection, no renames inside repos
5. **Dedupe safety** - Staged hashing, numeric length filtering, no placeholder hash grouping
6. **Execution safety** - DryRun default, `-Execute` required, always generates rollback
7. **Classification consistency** - Unit type matches ID prefix and destination
8. **Anchor precedence** - Deterministic (rules > queries > evidence > playbooks > configs)

### What Won't Happen

- ❌ No silent overwrites (collisions get unique hash suffix)
- ❌ No content leaks in logs (secrets flagged but not stored)
- ❌ No deletes (dupes moved to archive)
- ❌ No git repo file renames (repos stay atomic)
- ❌ No unnecessary renaming (keep original names when safe)

---

## Outputs You'll Get

### After DryRun

All in: `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\`

1. **FULL_INVENTORY_YYYY-MM-DD_HH-MM-SS.csv**
   - Complete file scan
   - SHA256 hashes
   - Feature flags (HasMITRE, HasKQL, etc.)
   - Sensitive flags
   - Top tokens

2. **WORK_UNIT_CANDIDATES_YYYY-MM-DD_HH-MM-SS.csv**
   - Discovered work units
   - Confidence scores
   - Anchor types
   - Member counts

3. **CLASSIFIED_UNITS_YYYY-MM-DD_HH-MM-SS.csv**
   - Unit type assignments
   - Destination roots
   - Matched rules

4. **PHASE4_MOVE_PLAN_YYYY-MM-DD_HH-MM-SS.csv** ⚠️ **REVIEW THIS**
   - Source → Destination mappings
   - Rename decisions
   - Collision strategies

5. **ROLLBACK_PLAN_YYYY-MM-DD_HH-MM-SS.csv**
   - Undo instructions
   - Generated before any move

6. **DUPLICATES_REPORT_YYYY-MM-DD_HH-MM-SS.csv**
   - Duplicate file groups
   - Size wasted
   - Keep vs archive decisions

7. **COLLISIONS_REVIEW_YYYY-MM-DD_HH-MM-SS.csv** (if collisions exist)
   - Naming conflicts
   - Resolution strategies

8. **PHASE4_SUMMARY_YYYY-MM-DD_HH-MM-SS.txt**
   - Human-readable overview
   - Acceptance criteria check
   - Next steps

9. **UNIT_REGISTRY.json**
   - Unit key → Unit ID mappings
   - Enables idempotent reruns

---

## Example Workflow

```powershell
# Step 1: Generate reports (DryRun)
.\Execute-Phase4.ps1

# Step 2: Review outputs
code "C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\PHASE4_MOVE_PLAN_*.csv"
code "C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\PHASE4_SUMMARY_*.txt"

# Step 3: If tweaking rules
code .\phase4_rules.yml
.\Execute-Phase4.ps1 -Force  # Regenerate with new rules

# Step 4: Execute (if approved)
.\Execute-Phase4.ps1 -Execute

# Step 5: Verify
Get-ChildItem C:\RH\OPS\PROOF_PACKS -Recurse -Directory
```

---

## Tuning Behavior

Edit `phase4_rules.yml` to adjust:

### Add/Remove Anchor Types
```yaml
anchors:
  your_custom_anchor:
    priority: 3
    extensions: ['.custom']
    tokens: ['special', 'keyword']
```

### Adjust Classification Rules
```yaml
classification_rules:
  - type: YOUR_CUSTOM_TYPE
    priority: 10
    conditions:
      tokens_include: ['your', 'keywords']
      min_confidence: 0.7
    destination_template: 'C:\RH\OPS\YOUR_FOLDER\{topic_slug}'
```

### Add Secrets Patterns
```yaml
secrets_patterns:
  content:
    - 'your_api_key_pattern_here'
```

---

## Troubleshooting

### "No anchors found"
- Check `phase4_rules.yml` anchor patterns
- Verify file extensions match
- Look at inventory to see what extensions you actually have

### "Low confidence units"
- Expected for orphaned files
- Review `TRIAGE_LOWCONF.csv`
- Manually classify or adjust rules

### "Secrets sweep empty"
- Could be good (no secrets) or patterns too weak
- Check `phase4_rules.yml` secrets patterns
- Run with `-DebugPreview` to inspect content

### "Too many collisions"
- Review `COLLISIONS_REVIEW.csv`
- Files with identical names get hash suffix
- This is safe - prevents overwrites

---

## What Happens During Execution

When you run with `-Execute`:

1. **Creates destination folders**
   - Including proof pack scaffolding (writeup.md, evidence/, artifacts/)

2. **Moves files per plan**
   - Respects collision strategies
   - Never overwrites

3. **Moves duplicates to archive**
   - `C:\RH\OPS\_ARCHIVE\DUPES\<hash_prefix>/`

4. **Generates manifest**
   - `move_manifest.csv` - What actually happened

5. **Creates rollback plan**
   - `ROLLBACK_PLAN.csv` - How to undo

6. **Verifies moves**
   - File counts match

---

## Evidence for Recruiters

After execution, take screenshots:
1. `C:\RH\OPS\PROOF_PACKS\` structure
2. Example proof pack contents
3. `PHASE4_SUMMARY.txt` showing acceptance criteria

Save these with your portfolio artifacts.

---

## Notes

- **Idempotent:** Rerunning with same inputs produces same unit IDs
- **Rerunnable:** Can tweak rules and regenerate without starting over
- **Safe by default:** DryRun unless explicitly told to execute
- **Auditable:** Every decision logged with reasoning
- **Rollback-capable:** Every move has an undo plan

---

**Total Line Count:** ~2,000 lines across 6 scripts + 1 config  
**Estimated Runtime:** 10-20 minutes for 5,000 files (DryRun), 20-40 minutes (Execute)

**Next:** Run `.\Execute-Phase4.ps1` and review the outputs.
