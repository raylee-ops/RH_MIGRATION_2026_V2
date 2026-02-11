# 5.2\_PRO\_VS\_THINKING

INPUTS FOR BOTH MODELS:(2 FILES \+ PROMPT))  
	"C:\\RH\\OPS\\SYSTEM\\migrations\\RH\_MIGRATION\_2026\\5.2RESEARCH\_MIGRATE\\RESEARCH\_BUNDLE\\Phase4\_ResearchBundle\_20260207\_124436.zip"  
"C:\\RH\\OPS\\SYSTEM\\migrations\\RH\_MIGRATION\_2026\\5.2RESEARCH\_MIGRATE\\INPUTS\\RH\_MIGRATION\_PLAN02-06.txt"

You are analyzing a Phase 4 “work unit reconstruction” pipeline (PowerShell) that inventories a quarantine folder and reconstructs PROOF\_PACK-style work units.

Inputs in the zip:  
\- phase4\_rules\_FIXED.yml (anchors, tier rules, folder seeds, ignore rules)  
\- scripts: Execute-Phase4\_FIXED.ps1, Phase4\_Common.ps1, Build-QuarantineInventory.ps1, Find-WorkUnits\_FIXED.ps1, Classify-Units\_FIXED.ps1, Build-MovePlan\_FIXED.ps1, Write-Phase4Summary.ps1, Execute-MovePlan.ps1  
\- outputs from a successful Random 5000 dry-run: FULL\_INVENTORY, WORK\_UNIT\_CANDIDATES, UNIT\_MEMBERS, CLASSIFIED\_UNITS, MOVE\_PLAN, ROLLBACK\_PLAN, SUMMARY, and INVENTORY\_DEBUG.

Current results: Tier1 anchors found=436, folder seeds=3, repo roots=7, triage=36.36% (1827/5025). Assigned\>=0.6 is passing but triage is still too high.

Task:  
1\) Propose the smallest safe changes to phase4\_rules\_FIXED.yml to reduce triage from 36.36% to \<30% WITHOUT loosening Tier1 anchors into match-everything.  
2\) Prefer adding/adjusting folder seeds \+ Tier2 signals that promote membership into existing units (not create new units).  
3\) Identify top 5 causes of triage using the CSVs (paths, extensions, common tokens) and map each cause to a rule change.  
4\) Output:  
   \- concrete YAML edits (diff style)  
   \- a short validation plan (exact rerun command and acceptance metrics)  
   \- a patch checklist naming the exact YAML keys/sections to change  
   \- redaction/secrets safety notes  
Do not refactor scripts unless absolutely necessary.

# PRO

### **What your pipeline is *actually* doing (and why triage is high)**

Your goal is clear: **reconstruct coherent work-units (PROOF\_PACK-first) from disk reality**, not dumb file-type sorting, with **plan-first \+ rollback \+ secrets-safe** behavior. 👍

From the **02-07-2026 Random 5000** outputs, the failure mode is *not* “Tier1 anchor explosion” (Tier1 sum \= **436**, in-range). The triage problem is this:

* **Most “SCRATCH\_INTAKE” rows are coming from orphan buckets**, not from misfiring Tier1 anchors.  
* Orphans are grouped by the **major/minor folder under `FROM_2026`** (e.g., `ROOT_MISC\_INBOX`, `LIFE\Personal`), then assigned **confidence 0.45**, which **guarantees** they match the `SCRATCH_INTAKE` rule (`confidence_below: 0.6`).  
* Result: **1827/5025 \= 36.36%** triage, even though anchors/units are healthy.

So the fix is not “loosen Tier1.” The fix is **seed more of the “known big buckets”** (folder seeds), and add **non-triage classification rules** for the buckets that should never be treated as low-confidence mystery meat.

Also: Tier2 signals don’t currently affect membership or unit creation in the scripts you shipped (they’re parsed, but not used for assignment). So YAML-only triage reduction comes from **folder seeds \+ classification rules**.

---

## **Top 5 causes of triage (from your CSVs) → targeted YAML rule changes**

These 5 buckets account for **1591 / 1827 (87%)** of SCRATCH\_INTAKE. Fixing them alone should drop triage to \~**4–10%**, comfortably \<30%.

### **1\) `ROOT_MISC\_INBOX` (900 files)**

* Dominant extensions: **.png (747)**, **.md**, **.txt**, **.ico**  
* Pattern: staged inbox content (screenshots, buffers, codex outputs), not “unknown.”

**Change:** add a **folder seed** so it stops being an orphan bucket (and preserves subfolders), plus a classification rule to route it to an inbox import destination.

---

### **2\) `LIFE\Personal` (515 files)**

* Dominant extensions: **.jpg (274)**, **.png (108)**, plus personal-media patterns.  
* This should never go to OPS triage by default.

**Change:** add a **folder seed** for `FROM_2026\LIFE\Personal`, and broaden the existing `LIFE_PERSONAL` classifier so it also catches orphan-bucket strings like `LIFE\Personal`.

---

### **3\) `LIFE\Admin` (68 files)**

* Dominant extensions: **.ps1 (15)**, **.ini (9)**, **.psd1 (7)**, **.xml**  
* Looks like PowerShell profile/module/admin docs.

**Change:** same as above: **folder seed** for `FROM_2026\LIFE\Admin`, and rely on the broadened `LIFE_PERSONAL` classifier.

---

### **4\) `ROOT_MISC\.obsidian` (54 files)**

* Dominant extensions: **.json (25)**, **.css (17)**, **.js (10)**  
* This is Obsidian config/plugin stuff. Not triage, but also not a proof pack.

**Change:** add a **classification rule** routing it into a safe system config holding area.

*(Note: you currently ignore `\.obsidian\` in `ignore_folder_patterns`, so folder seeds won’t pick this up without changing ignores. I’m not touching ignores here because you asked “smallest safe changes.”)*

---

### **5\) `OPS\RESEARCH` (54 files)**

* Dominant extensions: **.md (40)**, **.txt (9)**, some PDFs.  
* These are “known destination” materials, not triage.

**Change:** add a **folder seed** for `FROM_2026\OPS\RESEARCH` \+ a classification rule routing to an imports area under `C:\RH\OPS\RESEARCH`.

---

## **Concrete YAML edits (diff style)**

Below is a minimal patch to **phase4\_rules\_FIXED.yml**.  
It does **not** modify Tier1 file anchors. It only adds folder seeds and classification rules to stop these buckets from being forced into SCRATCH\_INTAKE.

```
--- a/phase4_rules_FIXED.yml
+++ b/phase4_rules_FIXED.yml
@@ anchors:
   soc_build:
     tier: 1
     seed_mode: folder
     priority: 50
     folder_name_patterns:
       - '(?i)^6_week_soc_build$'

+  root_misc_inbox:
+    tier: 1
+    seed_mode: folder
+    priority: 55
+    folder_patterns:
+      - '(?i)\\FROM_2026\\ROOT_MISC\\_INBOX\\'
+    folder_name_patterns:
+      - '(?i)^_INBOX$'
+
+  life_personal_root:
+    tier: 1
+    seed_mode: folder
+    priority: 56
+    folder_patterns:
+      - '(?i)\\FROM_2026\\LIFE\\Personal\\'
+    folder_name_patterns:
+      - '(?i)^Personal$'
+
+  life_admin_root:
+    tier: 1
+    seed_mode: folder
+    priority: 57
+    folder_patterns:
+      - '(?i)\\FROM_2026\\LIFE\\Admin\\'
+    folder_name_patterns:
+      - '(?i)^Admin$'
+
+  ops_research_root:
+    tier: 1
+    seed_mode: folder
+    priority: 58
+    folder_patterns:
+      - '(?i)\\FROM_2026\\OPS\\RESEARCH\\'
+    folder_name_patterns:
+      - '(?i)^RESEARCH$'

@@ classification_rules:
   - type: LIFE_PERSONAL
     priority: 5
     destination_template: 'C:\RH\LIFE\{original_subfolder}'
     unit_prefix: 'LIFE'
     create_scaffold: false
     conditions:
-      source_root_contains: ['\FROM_2026\LIFE\']
+      source_root_contains: ['\FROM_2026\LIFE\', 'LIFE\']

+  - type: OPS_CONFIG_OBSIDIAN
+    priority: 45
+    destination_template: 'C:\RH\OPS\SYSTEM\configs\obsidian\from_quarantine_{date_slug}'
+    unit_prefix: 'CFG'
+    create_scaffold: false
+    conditions:
+      source_root_contains: ['ROOT_MISC\.obsidian', '\.obsidian\']
+
+  - type: OPS_INBOX_IMPORTED
+    priority: 50
+    destination_template: 'C:\RH\INBOX\imports\ROOT_MISC_INBOX_{date_slug}'
+    unit_prefix: 'INBOX'
+    create_scaffold: false
+    conditions:
+      source_root_contains: ['\FROM_2026\ROOT_MISC\_INBOX', 'ROOT_MISC\_INBOX']
+
+  - type: OPS_RESEARCH_IMPORTED
+    priority: 55
+    destination_template: 'C:\RH\OPS\RESEARCH\imports\FROM_2026_{date_slug}'
+    unit_prefix: 'OPS-RES'
+    create_scaffold: false
+    conditions:
+      source_root_contains: ['\FROM_2026\OPS\RESEARCH', 'OPS\RESEARCH']
```

These destinations align with the structure you described in your RH migration plan (OPS `_INBOX`, LIFE, SYSTEM holding areas).

---

## **Why this should drop triage \<30% (without “match everything” anchors)**

* Today, those 5 buckets produce **1591** SCRATCH rows because they’re **orphans** at confidence **0.45**.  
* Folder seeds convert the big ones from **orphan bucket units → folder-root units**, which:  
  * preserves subfolders (so you don’t flatten your inbox or life tree into a junk pile)  
  * assigns **confidence 0.80** (script behavior for folder seeds)  
  * lets classification route them to **non-triage** types  
* Obsidian stays orphaned (by design, due to ignore), but classification routes it out of SCRATCH anyway.

Net effect: triage should fall roughly from **36.36% → \~5–10%** on the same dataset, assuming those bucket sizes are stable.

---

## **Validation plan (minimal reruns, measurable stop conditions)**

### **Run 1: repeat the same test mode (Random 5000, dry-run)**

```
.\Execute-Phase4_FIXED.ps1 `
  -QuarantinePath "C:\RH\OPS\QUARANTINE\FROM_2026" `
  -RulesPath ".\phase4_rules_FIXED.yml" `
  -MaxFiles 5000 `
  -SampleMode Random
```

**Pass/fail checks (look at `PHASE4_SUMMARY_MM-DD-YYYY.txt`):**

* Tier1 file anchors (sum) still **50–500** (should stay near 436\)  
* Units produced **20–200**  
* **TRIAGE \< 30%** ✅ (target)  
* Assigned PROOF\_PACK/PROJECT ≥ 60% (should remain ≥ current)

### **Run 1a: sanity check for overlapping membership (important)**

Folder seeds can theoretically overlap other roots; you want to catch duplicates before any execution:

```
$plan = Import-Csv .\PHASE4_MOVE_PLAN_MM-DD-YYYY*.csv
$dupes = $plan | Group-Object SourcePath | Where-Object Count -gt 1
$dupes.Count
```

**Expected:** `0`  
If not zero, you have overlapping unit roots (that’s a bigger issue than YAML).

### **Run 2: full quarantine dry-run (no file limit)**

```
.\Execute-Phase4_FIXED.ps1 -QuarantinePath "C:\RH\OPS\QUARANTINE\FROM_2026"
```

Stop if:

* Tier1 anchors \> 800 (your built-in guardrail)  
* triage% \> 50 (your built-in guardrail)

### **Run 3: execute only after plan review**

```
.\Execute-Phase4_FIXED.ps1 -Execute
```

(And yes, humans still have to read the plan before they push the big red button. Tragic but necessary. 🙃)

---

## **Redaction \+ secrets safety notes (still enforced)**

* **No rule here logs file contents.** We’re only changing routing rules.  
* **Secrets override remains dominant**: anything flagged `SensitiveFlag=true` should still route to  
  `C:\RH\VAULT_NEVER_SYNC\_SECRETS_TRIAGE\...` (paths only, no content logged).  
* These YAML changes **do not weaken Tier1 file anchors** and **do not create overwrites** (collision hashing is handled downstream).  
* We intentionally **did not remove `\.obsidian\` from ignore\_folder\_patterns**, because that’s how you avoid anchor noise in config folders. The obsidian fix here is routing-only.

---

If you apply just that diff and rerun the same Random 5000, your triage percentage should crater in a satisfying way, and you won’t have to pretend your personal photos are “SCRATCH\_INTAKE” like some kind of tax audit of your own life.

# THINKING

You don’t have a “clustering problem.” You have a **string-matching bug in your rules** that *forces* big, obvious buckets (LIFE) to miss the LIFE classifier and fall into **SCRATCH\_INTAKE**, inflating triage.

The good news: the **smallest safe YAML change** drops triage under 30% without touching Tier1 anchors. Humans accidentally invent problems all the time. 🤝

---

## **1\) Smallest safe YAML change to get triage \< 30%**

### **What’s happening**

Your biggest triage buckets are:

| RootGroup (triage unit) | Members | What it is |
| ----- | ----- | ----- |
| `ROOT_MISC\_INBOX` | 900 | screenshots/downloads dumping ground |
| `LIFE\Personal` | 515 | iCloud photos \+ personal media |
| `LIFE\Admin` | 69 | PS modules/configs/scripts |
| `OPS\RESEARCH` | 54 | notes/docs |
| `ROOT_MISC\.obsidian` | 54 | Obsidian vault config |

Your current `LIFE_PERSONAL` rule checks `source_root_contains: ['\\FROM_2026\\LIFE\\']`, but **the classifier matches against `Unit.RootGroup`** (e.g. `LIFE\Personal`), not the full `SourcePath`. So it never hits. That’s why 613 LIFE files become SCRATCH.

### **Guaranteed impact**

If we correctly classify **all LIFE\*** buckets, triage drops from:

* **1827 / 5025 \= 36.36%**  
  to  
* **(1827 − 613\) / 5025 \= 24.16%** ✅

This aligns with your migration map of LIFE destinations.

---

## **2\) Concrete YAML edits (diff style)**

### **Required (the one change that fixes the FAIL)**

```
--- a/phase4_rules_FIXED.yml
+++ b/phase4_rules_FIXED.yml
@@
 classification_rules:
   - type: LIFE_PERSONAL
     priority: 5
     destination_template: 'C:\RH\LIFE\{original_subfolder}'
     unit_prefix: LIFE
     create_scaffold: false
     conditions:
-      source_root_contains: ['\FROM_2026\LIFE\']
+      # NOTE: classifier matches against Unit.RootGroup (e.g., "LIFE\Personal"),
+      # not full SourcePath. Keep this broad but still scoped to LIFE only.
+      source_root_contains: ['LIFE\']
```

That’s it. No Tier1 anchor loosening, no “match everything,” no script changes.

---

### **Optional (safe add-ons mapped to other top triage causes)**

These are **not needed** to hit \<30%, but they clean up the remaining obvious buckets and match your plan’s intent for `_INBOX` and dotfolders.

```
--- a/phase4_rules_FIXED.yml
+++ b/phase4_rules_FIXED.yml
@@
 classification_rules:
+  - type: OPS_INBOX_SWEEP
+    priority: 6
+    destination_template: 'C:\RH\INBOX\imports\{date_slug}\{topic_slug}'
+    unit_prefix: INBOX
+    create_scaffold: false
+    conditions:
+      source_root_contains: ['ROOT_MISC\_INBOX']
+
+  - type: OPS_SYSTEM_CONFIGS
+    priority: 7
+    destination_template: 'C:\RH\OPS\SYSTEM\configs\imports\{date_slug}\{topic_slug}'
+    unit_prefix: SYS
+    create_scaffold: false
+    conditions:
+      source_root_contains: ['ROOT_MISC\.obsidian', 'ROOT_MISC\.claude']
+
+  - type: OPS_RESEARCH_IMPORT
+    priority: 8
+    destination_template: 'C:\RH\OPS\RESEARCH\imports\{date_slug}\{topic_slug}'
+    unit_prefix: RSRCH
+    create_scaffold: false
+    conditions:
+      source_root_contains: ['OPS\RESEARCH']
```

Why these are “safe”: they **reclassify already-existing triage units** (they don’t create new clusters), and they follow your own destination policy for `_INBOX` \+ config storage.

---

## **3\) Top 5 triage causes (from CSVs) → rule change mapping**

### **Cause 1: LIFE buckets never match LIFE rule (RootGroup mismatch)**

* **Bucket**: `LIFE\Personal` (515), `LIFE\Admin` (69), `LIFE\MIND` (20+)  
* **Extensions**: mostly `.jpg/.png/.mjs` (Personal), `.ps1/.psd1/.ini` (Admin)  
* **Common tokens**: `life`, `personal`, `pictures`, `icloud`, `powershell`, `modules`  
* **Fix**: **Required diff** above (`source_root_contains: ['LIFE\']`)

### **Cause 2: `_INBOX` screenshot pile (mostly images)**

* **Bucket**: `ROOT_MISC\_INBOX` (900)  
* **Extensions**: `.png` dominates (747), plus `.md/.txt/.pdf/.zip`  
* **Tokens**: `screenshots`, `screenshot`, `windows`, `downloads`, duplicate markers  
* **Fix**: optional `OPS_INBOX_SWEEP` rule (routes it where it belongs)

### **Cause 3: Obsidian vault config stranded at root\_misc**

* **Bucket**: `ROOT_MISC\.obsidian` (54)  
* **Extensions**: `.json/.css/.js`  
* **Tokens**: `obsidian`, `plugins`, `manifest`, `snippets`  
* **Fix**: optional `OPS_SYSTEM_CONFIGS` rule (gets dotfolder junk out of triage, matches dotfolder policy)

### **Cause 4: Research notes/documents orphaned as a unit**

* **Bucket**: `OPS\RESEARCH` (54)  
* **Extensions**: mostly `.md` (40), then `.txt/.pdf`  
* **Tokens**: `research`, `market`, `job`, `facts`, `template`  
* **Fix**: optional `OPS_RESEARCH_IMPORT` rule (maps to your RESEARCH destination)

### **Cause 5: “Admin tools” living under LIFE\\Admin (should still be LIFE)**

* This is mostly solved by Cause 1 fix, but worth calling out:  
* **Extensions**: `.ps1/.psd1/.psm1/.sh/.xml/.dll`  
* **Tokens**: `powershell`, `modules`, `psreadline`, `helpers`  
* **Fix**: same as Cause 1 (classify to `C:\RH\LIFE\Admin\...`), which matches your destination spec

---

## **4\) Short validation plan (rerun \+ acceptance metrics)**

### **Exact rerun command (same as your Random 5000 dry-run)**

```
pwsh -File .\Execute-Phase4_FIXED.ps1 `
  -QuarantinePath 'C:\RH\OPS\QUARANTINE\FROM_2026' `
  -RulesPath '.\phase4_rules_FIXED.yml' `
  -SampleMode Random `
  -MaxFiles 5000
```

### **Acceptance metrics**

* **TRIAGE (SCRATCH\_INTAKE \+ TRIAGE\_LOWCONF) \< 30%** ✅ target  
* **Expect**: triage drops to \~**24%** just from LIFE fix  
* **LIFE\_PERSONAL move rows** should jump from **47 → \~613+**  
* **Tier1 anchors** remain \~**436** (should not spike)  
* **Secrets routed** should stay \~**51** and still be “flag-only” behavior

---

## **Patch checklist (exact YAML keys/sections)**

Touch only these, in order:

1. `classification_rules`  
   * `type: LIFE_PERSONAL`  
     * `conditions.source_root_contains` ✅ **required**  
2. (Optional) `classification_rules`  
   * add `type: OPS_INBOX_SWEEP`  
   * add `type: OPS_SYSTEM_CONFIGS`  
   * add `type: OPS_RESEARCH_IMPORT`

Nothing else. Leave `anchors:` alone to avoid Tier1 anchor blast radius.

---

## **Redaction / secrets safety notes**

* **Do not** add any rule that auto-moves suspected credentials into normal destinations.  
* Keep secrets handling as **FLAG ONLY**; manual review to `C:\RH\VAULT\_SECRETS_TRIAGE\...` is explicitly the policy.  
* When sharing logs/CSVs/screenshots as “evidence,” **redact**:  
  * tokens, API keys, SSH config contents, `.env`, browser exports  
  * file bodies of anything secrets-flagged (paths \+ metadata only is fine)

---

### **Important clarification**

* **Do not** loosen Tier1 filename patterns or required features to “catch more.” That’s how you get anchors that match everything and ruin clustering.  
* **Do not** refactor scripts. This is a rules mismatch, not a code architecture crisis.

If you apply only the LIFE rule fix, your triage % stops failing immediately. The rest is cleanup for a world where humans insist on having 900 screenshots of… something. 📸



Change Log
- Date/Time: 2026-02-07 19:13:41
- Change: INBOX canonical root moved from OPS to RH root
- Why: aligns with Phase 6 + long-term guardrails

