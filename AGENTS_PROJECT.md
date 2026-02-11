# RH_MIGRATION_2026_V2 — Unified Agent Contract (Single Source of Truth)

**Date:** 02-09-2026  
**Scope:** This contract governs *all* agent work (Claude Code, Codex, manual runs) for this project.  
**If anything else contradicts this file:** this file wins.

---

## 0) Stop the “wrong folder” disaster (V1 is archived)

### ✅ You are in the right place ONLY if:

- Your current working directory is:
  - `C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2`
- AND this file exists:
  - `RH_MIGRATION_2026_V2.SENTINEL`
- Output default:
  - Write first to the folder the session was launched from (`Get-Location`), unless the operator explicitly asks for a different destination.

### 🚫 If you see this path anywhere, STOP:

- `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026`  
That is **V1**. It is **abandoned**. Agents writing there is how you get “it worked” while your real repo stays empty.

**Required pre-step (humans + agents):**
- Run: `Get-Location`
- If it’s not the V2 path above, you **must** `cd` into V2 before doing anything else.

---

## 1) Canonical paths and invariants (the rules you keep tripping over)

### 1.1 Scan roots (INPUTS)
Agents may scan/read **ONLY**:

- `C:\RH\INBOX`
- `C:\RH\OPS`

### 1.2 Quarantine (DESTINATION-ONLY)
Agents may write/move into **ONLY**:

- `C:\RH\TEMPORARY`

**TEMPORARY is NEVER scanned.** It is **destination-only**.

### 1.3 Excluded roots (absolute “no touch”)
At minimum, all agents must treat these families as excluded unless a phase explicitly says otherwise:

- `C:\RH\VAULT`
- `C:\RH\LIFE`
- `C:\RH\VAULT_NEVER_SYNC`
- `C:\RH\ARCHIVE`
- `C:\LEGACY`
- `C:\Windows`
- `C:\Program Files`
- `C:\Users`

### 1.4 “No deletes, no overwrites” (non-negotiable safety)
- **NO deletes** (ever).
- **NO overwrites** (ever).
- Collisions must be handled via **suffix policy** or **quarantine**, never overwrite.

---

## 2) Two-lane artifact model (this is why OUTPUTS is ignored by git)

### Lane A: `OUTPUTS/` = messy, generated, untrusted, **NEVER committed**
- All runs write to:
  - `OUTPUTS\phase_XX\run_MM-DD-YYYY_HHMMSS\`
- Run folder must contain the **audit spine** (see §3).
- `OUTPUTS/` is in `.gitignore` by design.

### Lane B: `PROOF_PACK/` = curated, recruiter-safe, **always committed**
- Only *promoted* artifacts live here.
- Promotion is **copy-only** (OUTPUTS is read-only source).

✅ Tool: `tools\promote_to_proof_pack.ps1`  
✅ Index: `PROOF_PACK\INDEX.md` tracks promotions

**Rule:** if it matters to a recruiter (scope control, safety, determinism, reproducibility), it must be promoted.

---

## 3) What “a phase is DONE” actually means (no more vibes)

A phase is **NOT complete** unless all of the following are true:

### 3.1 Audit spine exists in OUTPUTS run folder
Every phase run folder MUST contain:

- `plan.csv`
- `runlog.txt`
- `metrics.json`
- `rollback.ps1` (no-op allowed for read-only phases)
- `summary_MM-DD-YYYY.md` (or equivalent `summary_*.md`)
- `evidence\` (must contain required phase evidence; see §3.2)

### 3.2 Phase evidence requirements are satisfied
Phase-specific evidence requirements are defined in:

- `CONTRACTS\phase_requirements.json`

### 3.3 Curated proof exists in PROOF_PACK
At minimum, promote (per phase run):

- `plan.csv`
- `metrics.json`
- `summary_*.md`

…and whatever phase-specific evidence proves your gates passed.

### 3.4 Verification is objective
You don’t “feel” done. You run:

- `tools\preflight.ps1`
- `tools\audit_phase.ps1 -Phase XX`
- `tools\status.ps1`

---

## 4) Required operator workflow (the boring part that prevents disasters)

### Step 0 — Preflight (every time)
```powershell
cd C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2
pwsh -NoProfile -ExecutionPolicy Bypass -File "tools\preflight.ps1"
```

### Step 1 — Run the phase (DryRun first)
If you have a runner, it must write to `OUTPUTS\phase_XX\run_*`.  
If you don’t have a runner yet, agents must still create a compliant run folder + audit spine.

### Step 2 — Audit the phase
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "tools\audit_phase.ps1" -Phase 01
```

### Step 3 — Promote to PROOF_PACK
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "tools\promote_to_proof_pack.ps1" -Phase 01
```

### Step 4 — Commit ONLY proof pack + source
```powershell
git status
git add PROOF_PACK docs tools SRC project_config.json AGENTS_PROJECT.md
git commit -m "proof: phase 01 promoted artifacts"
git push
```

---

## 5) Agent behavior contract (Claude Code + Codex)

### 5.1 Before doing anything, agents MUST:
- Confirm `Get-Location` is V2 path
- Confirm `RH_MIGRATION_2026_V2.SENTINEL` exists
- Read:
  - `AGENTS_PROJECT.md` (this file)
  - `project_config.json`
  - `CONTRACTS\phase_requirements.json`

### 5.2 Agents MUST NOT:
- Write to: `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026` (V1)
- Commit `OUTPUTS/`
- Scan TEMPORARY
- Touch excluded roots
- Delete or overwrite

### 5.3 If anything conflicts:
- **This file** + `project_config.json` win.
- Everything else is documentation or generated guidance.

---

## 6) “Important clarification” (what NOT to do yet)

- Do **NOT** attempt Phase 06 or 07 Execute until:
  - Phase 05 plan exists, is reviewed, and has an approval record
  - Rollback DryRun is PASS
- Do **NOT** “clean up” old attempts by deleting anything.
- Do **NOT** change scan roots to include TEMPORARY “for convenience”.
  That is literally how quarantines become trash fires.

---

## Appendices

### A) Paste block for agents
See: `CONTRACTS\agent_paste_block.md`

### B) Operator playbook
See: `CONTRACTS\operator_playbook.md`

### C) Phase gate definitions (02–08)
See: `CONTRACTS\phase_gates.md`

### D) Canonical trees
See: `CONTRACTS\expected_final_tree.md`
