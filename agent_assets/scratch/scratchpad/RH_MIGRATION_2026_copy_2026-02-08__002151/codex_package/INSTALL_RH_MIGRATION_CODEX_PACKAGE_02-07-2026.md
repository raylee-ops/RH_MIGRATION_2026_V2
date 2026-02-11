# RH_MIGRATION_2026 Codex Package — Install + Verify

This package contains:
- `codex_setup/` → optional installer + Codex config + skills
- `_INPUTS/` → canonical project inputs (prompts/templates/rules)
- `AGENTS_PROJECT.md` + `PHASE_STATUS.md` → project-scoped control files

## Where files belong (final)
### Project control-plane
- `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\codex\AGENTS_PROJECT.md`
- `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\codex\PHASE_STATUS.md`
- `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\codex\_INPUTS\...` (this entire folder)

### Installer (optional)
- `C:\RH\OPS\SYSTEM\codex_setup\...` (keep as “installer archive”)

## Install steps (safe, minimal)
1) Extract this zip to a temporary staging folder:
   - `C:\RH\OPS\SYSTEM\_staging\rh_migration_codex_package_02-07-2026\`

2) Copy project inputs into place (overwrite allowed ONLY for identical filenames, otherwise dupe-suffix):
   - From: `<staging>\_INPUTS\`
   - To: `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\codex\_INPUTS\`

3) Copy project agent + status file:
   - From: `<staging>\AGENTS_PROJECT.md` → `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\codex\AGENTS_PROJECT.md`
   - From: `<staging>\PHASE_STATUS.md` → `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\codex\PHASE_STATUS.md`

4) (Optional) Install Codex setup (skills/config):
   - Keep `codex_setup\` at: `C:\RH\OPS\SYSTEM\codex_setup\`
   - If you choose to apply config globally, copy:
     - `codex_setup\config.toml` → `C:\Users\Raylee\.codex\config.toml`
     - `codex_setup\AGENTS.md` → `C:\Users\Raylee\.codex\AGENTS.md`
   - Then restart Codex.

## How to “point Codex” at the project
Codex reads (a) the global AGENTS, and (b) whatever you paste into the session.

**Session start ritual (copy/paste into Codex):**
- “Read `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\codex\AGENTS_PROJECT.md` and all referenced `_INPUTS` files before doing anything.”
- “Confirm output routing: write outputs only under `phase_XX\...`.”

**Working directory rule:** launch Codex from the phase folder you’re working in:
- `cd C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_06` then `codex`

## Verify we’re all aligned (you + me + Codex)
Run these checks:
1) File existence:
   - `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\codex\AGENTS_PROJECT.md`
   - `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\codex\PHASE_STATUS.md`
   - `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\codex\_INPUTS\00_README_FIRST.md`

2) “No-sprawl” test:
   - Start Codex from: `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_06`
   - Ask it to create a dummy file: `phase_06\artifacts\codex_output_test_02-07-2026.txt`
   - Confirm NOTHING new appeared under `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\codex\`.

3) Output policy acknowledgement:
   - In Codex, ask: “Where are you allowed to write outputs for this project?” It must answer: `phase_XX\...` only.

## What to document now
- In `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\codex\PHASE_STATUS.md`: set Phase 06 to COMPLETE only once Purpose+Proof+runnable verify exist.
- In `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_06\docs\`: create `PHASE_06_PURPOSE.md` using the template.
- In `C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_06\artifacts\`: create `PHASE_06_PROOF.md` referencing run folders and rollback artifacts.
