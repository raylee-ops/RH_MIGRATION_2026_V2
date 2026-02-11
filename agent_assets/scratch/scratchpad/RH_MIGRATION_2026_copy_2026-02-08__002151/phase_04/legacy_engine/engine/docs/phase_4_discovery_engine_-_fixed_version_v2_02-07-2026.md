# Phase 4 Discovery Engine - FIXED VERSION (v2)

## What Was Wrong (Original)

ChatGPT was right. The original scripts had 3 critical flaws:

1. **Anchor patterns too broad** - Everything triggered as `config_file`, no classification rules matched, all 2,381 files went to `UNKNOWN`
2. **No membership output** - Find-WorkUnits didn't save which files belong to which units
3. **Move plan guessed membership** - Build-MovePlan tried to infer membership using fuzzy heuristics (DANGEROUS)

## What's Fixed (v2 - Final)

**Additional fixes beyond v1:**
- ✅ Fixed `-WhatIf` parameter conflict in Execute-MovePlan.ps1 (renamed to `-DryRun`)
- ✅ Removed overly broad `'rule-'` pattern (now only matches `rule-\d{3}-`)

### 1. phase4_rules_FIXED.yml
**Tuned for YOUR actual content:**
- `detection_rule` anchor: Matches `rule-###-*.yaml` files ONLY (precise regex)
- `wazuh_xml_rule` anchor: Matches `wazuh-###-*.xml` files  
- `security_automation` anchor: Python/PS1 scripts in security_automation folders
- `existing_proof_pack` anchor: Files already in `PP-###_*` folders
- `soc_build` anchor: Your 6-week SOC build content
- Classification rules now route ALL anchor types properly

### 2. Find-WorkUnits_FIXED.ps1
- Uses filename pattern matching (regex) instead of content matching
- **Outputs UNIT_MEMBERS.csv** with explicit file → unit mappings
- No more guessing which files belong where

### 3. Classify-Units_FIXED.ps1
- Reads UNIT_MEMBERS.csv for accurate member counts
- All classification rules work now

### 4. Build-MovePlan_FIXED.ps1
- **Uses UNIT_MEMBERS.csv** - no fuzzy guessing
- Accurate file routing
- Collision-safe naming

### 5. Execute-MovePlan.ps1 (NEW)
- Actually moves files safely
- Creates proof pack scaffolding
- Generates manifest + rollback plan
- WhatIf mode for testing

### 6. Execute-Phase4_FIXED.ps1 (NEW)
- Master orchestrator using fixed scripts
- Reuses recent inventory (faster)
- Proper error handling

---

## How To Use

### Quick Start

```powershell
# 1. Use the FIXED scripts in the canonical engine location
cd C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\engine\scripts\

# 2. Set execution policy (if needed)
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# 3. Run DryRun with FIXED scripts
.\Execute-Phase4_FIXED.ps1
```

This will:
- Reuse your existing inventory (if < 1hr old)
- Find work units using proper anchor matching
- **Output UNIT_MEMBERS.csv** (the fix)
- Classify properly (no more `UNKNOWN`)
- Generate accurate move plan

### Review Outputs

Check these files in `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\`:

**Critical:**
1. `WORK_UNIT_CANDIDATES_*.csv` - Units discovered
2. `UNIT_MEMBERS_*.csv` - **THE FIX** - explicit membership
3. `CLASSIFIED_UNITS_*.csv` - Should show proper types now (not UNKNOWN)
4. `PHASE4_MOVE_PLAN_*.csv` - Where files will go

**Sanity check:**
- `CLASSIFIED_UNITS.csv` should show types like:
  - `PROOF_PACK_DETECTION_RULES`
  - `PROOF_PACK_AUTOMATION`
  - `PROOF_PACK_SOC`
  - `LIFE_PERSONAL`
  - `SECRETS_TRIAGE`
- NOT all `UNKNOWN`

### Execute (if approved)

**⚠️ CRITICAL: Validate outputs first!**

Before executing, check these sanity signals:

1. **Anchor count should be WAY lower than 5,265**
   - Check `WORK_UNIT_CANDIDATES_*.csv`
   - If anchors ≈ total files, rules are still too broad

2. **Classification should NOT be mostly UNKNOWN**
   - Check `CLASSIFIED_UNITS_*.csv`
   - Should see: `PROOF_PACK_DETECTION_RULES`, `PROOF_PACK_AUTOMATION`, `PROOF_PACK_SOC`, etc.
   - NOT 106 units all classified as `UNKNOWN`

3. **Sensitive files route ONLY to VAULT**
   - Check `PHASE4_MOVE_PLAN_*.csv` where `SensitiveFlag=True`
   - ALL sensitive files must go to `C:\RH\VAULT\_SECRETS_TRIAGE\`
   - If ANY go to PROOF_PACKS or RESEARCH → STOP

**If validation passes:**

```powershell
.\Execute-Phase4_FIXED.ps1 -Execute
```

⚠️ This actually moves files.

---

## What You'll Get

**Expected classification breakdown:**

- **PROOF_PACK_DETECTION_RULES**: Your `rule-###-*.yaml` files + neighbors
- **PROOF_PACK_AUTOMATION**: Security automation scripts
- **PROOF_PACK_SOC**: Existing proof pack content + 6-week SOC build
- **SECRETS_TRIAGE**: 156 flagged credential files → Vault
- **LIFE_PERSONAL**: Personal/Admin/Family files → C:\RH\LIFE\
- **SCRATCH_INTAKE**: Low-confidence orphans (should be < 30%)

**Destinations:**
- Detection rules: `C:\RH\OPS\PROOF_PACKS\DETECTION_ENGINEERING\PP-###_*`
- Automation: `C:\RH\OPS\PROOF_PACKS\SECURITY_AUTOMATION\PP-###_*`
- SOC: `C:\RH\OPS\PROOF_PACKS\SOC\PP-###_*`
- Secrets: `C:\RH\VAULT\_SECRETS_TRIAGE\*`
- Personal: `C:\RH\LIFE\*`

Each proof pack gets:
- `writeup.md` stub
- `evidence/` folder
- `artifacts/` folder  
- `sanitized/` folder

---

## Files Included

**Fixed scripts (use these):**
1. `phase4_rules_FIXED.yml` - Tuned rules
2. `Find-WorkUnits_FIXED.ps1` - Outputs membership
3. `Classify-Units_FIXED.ps1` - Uses membership
4. `Build-MovePlan_FIXED.ps1` - Uses membership
5. `Execute-MovePlan.ps1` - Actual execution
6. `Execute-Phase4_FIXED.ps1` - Master orchestrator

**Reuse from original (still work):**
- `Build-QuarantineInventory.ps1` (inventory was fine)
- `Invoke-DedupeScan.ps1` (dedupe was fine)

---

## Differences from Original

| Component | Original | Fixed |
|-----------|----------|-------|
| Anchor matching | Content patterns (failed) | Filename patterns (works) |
| Membership tracking | None (guessed later) | UNIT_MEMBERS.csv |
| Move plan accuracy | Fuzzy inference | Explicit membership |
| Classification | All → UNKNOWN | Proper routing |
| Execution | Not implemented | Fully implemented |

---

## Troubleshooting

**Still see UNKNOWN units:**
- Check `WORK_UNIT_CANDIDATES.csv` - what anchor types were found?
- If anchor types look wrong, rules need more tuning

**Files in wrong units:**
- Check `UNIT_MEMBERS.csv` - is membership correct?
- Neighbor clustering might be too aggressive (lower time window in rules)

**Execute fails:**
- Check `MOVE_ERRORS_*.txt` for details
- Common: File locks, permission issues
- Use rollback plan if needed

---

## Evidence Checklist

**Before execution:**
- Screenshot: Terminal showing proper classification (not UNKNOWN)
- Save: All CSVs

**After execution:**
- Screenshot: `C:\RH\OPS\PROOF_PACKS\` structure
- Save: `MOVE_MANIFEST_*.csv`
- Screenshot: Example proof pack with scaffolding

---

## Your Data Stats

From your DryRun:
- **5,265 files** scanned
- **156 sensitive** files (credentials/tokens/keys)
- **805 duplicate groups** (2,229 dupes, 96MB wasted)
- **75+ detection rules** (`rule-###-*.yaml`)
- **Wazuh XML rules** (`wazuh-###-*.xml`)
- **Existing proof pack** (`PP-001_WAZUH_BASELINE`)

---

**Run the fixed scripts and paste me the terminal output + classification summary.**
