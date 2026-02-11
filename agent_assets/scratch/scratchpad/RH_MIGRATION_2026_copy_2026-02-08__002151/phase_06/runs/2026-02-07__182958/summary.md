Phase 6 Canonical INBOX - DryRun
Run: 2026-02-07__182958
Run Folder: C:\RH\OPS\SYSTEM\DATA\runs\phase6\2026-02-07__182958

Plan counts by category:
- docs: 13
- inbox_root: 4
- ops_inbox: 8
- pictures: 407
- registry: 10
- screenshots: 6
- targets: 3

OPS inboxes found:
- C:\RH\INBOX
- C:\RH\OPS\PROOF_PACKS\_TEMPLATES\TEMPLATE_AUTOMATION_PACK\EVIDENCE\_INBOX
- C:\RH\OPS\PROOF_PACKS\_TEMPLATES\TEMPLATE_DETECTION_PACK\EVIDENCE\_INBOX
- C:\RH\OPS\PROOF_PACKS\_TEMPLATES\TEMPLATE_IR_PACK\EVIDENCE\_INBOX
- C:\RH\OPS\PROOF_PACKS\SOC\PP-001_WAZUH_BASELINE\EVIDENCE\_INBOX
- C:\RH\OPS\PROOF_PACKS\SOC\PP-002_SPLUNK_FAILED_LOGON\EVIDENCE\_INBOX
- C:\RH\OPS\PROOF_PACKS\SOC\PP-003_ENDPOINT_TRIAGE\EVIDENCE\_INBOX
- C:\RH\OPS\QUARANTINE\FROM_2026\ROOT_MISC\_INBOX

Docs to update:
- C:\RH\INBOX\downloads\PRO_VS_THINKING.md
- C:\RH\INBOX\imports\2026-02-07\root_misc_inbox\notes\COMPLETE_RH_MIGRATION_PLAN.md
- C:\RH\INBOX\imports\2026-02-07\root_misc_inbox\notes\RH_MIGRATION_STRATEGY (1).md
- C:\RH\INBOX\imports\2026-02-07\root_misc_inbox\notes\RH_MIGRATION_STRATEGY.md
- C:\RH\INBOX\imports\2026-02-07\root_misc_inbox\notes\Untitled.txt
- C:\RH\INBOX\imports\TRIAGE_LOWCONF_2026-02-07\notes\FINAL_RH_MIGRATION_PLAN.md
- C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\canonical_directory_map_02-07-2026.md
- C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\codex\phase_4_Debug.txt
- C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\codex\phase_4_Debug.txt
- C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\runs\phase4\02-06-2026__claude\raw\CLAUDE_MIGRATE_02-06-2026\OUTPUTS\audit\RH_MIGRATION_PLAN02-06.txt
- C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\runs\phase4\02-06-2026__claude\raw\CLAUDE_MIGRATE_02-06-2026\OUTPUTS\audit\RH_MIGRATION_PLAN02-06.txt
- C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\trash\5.2RESEARCH_MIGRATE\INPUTS\RH_MIGRATION_PLAN02-06.txt
- C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\trash\5.2RESEARCH_MIGRATE\INPUTS\RH_MIGRATION_PLAN02-06.txt

Rollback script: C:\RH\OPS\SYSTEM\DATA\runs\phase6\2026-02-07__182958\rollback_phase6_registry.ps1

Verification steps:
- New downloads land in C:\RH\INBOX\DOWNLOADS\
- New screenshots land in C:\RH\INBOX\SCREENSHOTS\
- Docs updated to reference C:\RH\INBOX\


Change Log
- Date/Time: 2026-02-07 19:13:40
- Change: INBOX canonical root moved from OPS to RH root
- Why: aligns with Phase 6 + long-term guardrails

