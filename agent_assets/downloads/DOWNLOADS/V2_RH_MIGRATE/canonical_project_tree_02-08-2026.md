# RH_MIGRATION_2026_V2 — Canonical Project Tree (02-08-2026)

**Root:** `C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2\`

> Note: Many files under `SRC\` and `agent_assets\` are created across phases; the directory scaffold must exist from day 1.

```
C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2\
  AGENTS_PROJECT.md
  CLAUDE.md
  CODEX.md
  PROJECT_SUMMARY.md
  project_config.json
  MIGRATION_GUIDE_V1_TO_V2_MM-DD-YYYY.md
  FILES_CREATED_MM-DD-YYYY.md

  SRC\
    run.ps1
    modules\
    rules\
    templates\

  agent_assets\
    prompts\
    policies\
    notes\

  OUTPUTS\
    phase_00\
      run_MM-DD-YYYY_HHMMSS\
        plan.csv
        runlog.txt
        summary_MM-DD-YYYY.md
        metrics.json
        rollback.ps1
        evidence\
          rh_tree_folders_only.txt
          rh_inventory.csv
          script_files_list.csv
          rules_and_config_list.csv
          duplicate_filenames_top.csv
          allowed_roots.txt
          excluded_roots.txt
    phase_01\
    phase_02\
    phase_03\
    phase_04\
    phase_05\
    phase_06\
    phase_07\
    phase_08\

  PROOF_PACK\
    evidence\
      contracts\
      manifests\
      logs\
      before_after\
      plans\
    results\
    code_excerpt\
```
