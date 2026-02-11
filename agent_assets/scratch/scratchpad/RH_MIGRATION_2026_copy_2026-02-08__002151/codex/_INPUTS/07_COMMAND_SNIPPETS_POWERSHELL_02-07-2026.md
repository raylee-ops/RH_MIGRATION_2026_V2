# Command Snippets PowerShell (02-07-2026)

## Phase 6 Canonical Invocation
- DryRun:
pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_06\scripts\Phase6-CanonicalInbox.ps1" -Mode DryRun
- Execute:
pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_06\scripts\Phase6-CanonicalInbox.ps1" -Mode Execute

## Engine / Run Separation Notes (from engine_run.txt)
The One Structure That Won’t Betray You
1) “Engine” vs “Runs” separation (non-negotiable)
Engine (Git repo)

Lives here:
C:\RH\OPS\BUILD\src\repos\rh-migration-discovery-engine\

Contains only:

scripts\ (all .ps1)

rules\ (phase4_rules_FIXED.yml + future rules)

docs\ (runbook + postmortem + architecture)

examples\ (sanitized sample CSVs if you want, optional)

.gitignore, README.md

Never store real run CSVs/logs here. Those leak personal paths and explode the repo.

Runs (Outputs, logs, manifests)

Lives here:
C:\RH\OPS\SYSTEM\DATA\runs\

This is where all generated files go.

2) Recommended folder tree (copy this)
Repo

C:\RH\OPS\BUILD\src\repos\rh-migration-discovery-engine\

rh-migration-discovery-engine\
  scripts\
    Execute-Phase4_FIXED.ps1
    Phase4_Common.ps1
    Build-QuarantineInventory.ps1
    Find-WorkUnits_FIXED.ps1
    Classify-Units_FIXED.ps1
    Build-MovePlan_FIXED.ps1
    Execute-MovePlan.ps1
    Write-Phase4Summary.ps1
  rules\
    phase4_rules_FIXED.yml
    rules_changelog_02-07-2026.md
  docs\
    README.md
    runbook_02-07-2026.md
    postmortem_02-07-2026.md
    architecture_02-07-2026.md
  examples\
    sanitized_summary_example_02-07-2026.txt
  .gitignore

Runs

C:\RH\OPS\SYSTEM\DATA\runs\

runs\
  phase4\
    02-07-2026__<run_id>\
      inputs\
        phase4_rules_FIXED_02-07-2026.yml
        run_params_02-07-2026.json
      outputs\
        full_inventory_02-07-2026__<hash>.csv
        work_unit_candidates_02-07-2026__<hash>.csv
        unit_members_02-07-2026__<hash>.csv
        classified_units_02-07-2026__<hash>.csv
        phase4_move_plan_02-07-2026__<hash>.csv
        rollback_plan_02-07-2026__<hash>.csv
      execute\
        move_manifest_02-07-2026__<hash>.csv
        move_errors_02-07-2026__<hash>.log
      summary\
        phase4_summary_02-07-2026__<hash>.txt
      debug\
        inventory_debug_02-07-2026__<hash>.txt
      notes\
        run_notes_02-07-2026.md
Phase 6 Canonical Invocation
- DryRun: pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_06\scripts\Phase6-CanonicalInbox.ps1" -Mode DryRun
- Execute: pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_06\scripts\Phase6-CanonicalInbox.ps1" -Mode Execute
- Legacy Phase 6 script paths under C:\RH\OPS\BUILD\scripts are deprecated.

