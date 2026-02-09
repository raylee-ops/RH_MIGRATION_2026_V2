# Expected Final Trees — RH_MIGRATION_2026_V2
**Date:** 02-09-2026

This file is a comparison reference so you can spot “wrong repo / wrong lane” instantly.

---

## A) Repo tree (committed to git)

```
RH_MIGRATION_2026_V2/
├─ AGENTS_PROJECT.md
├─ project_config.json
├─ RH_MIGRATION_2026_V2.SENTINEL
├─ .gitignore
├─ .claude/
│  └─ settings.local.json
├─ CONTRACTS/
│  ├─ agent_paste_block.md
│  ├─ non_negotiables.md
│  ├─ operator_playbook.md
│  ├─ phase_gates.md
│  ├─ phase_requirements.json
│  └─ expected_final_tree.md
├─ tools/
│  ├─ preflight.ps1
│  ├─ validate_config.ps1
│  ├─ audit_phase.ps1
│  ├─ status.ps1
│  └─ promote_to_proof_pack.ps1
├─ SRC/
│  ├─ run.ps1                 (Phase 03 gatekeeper, once implemented)
│  ├─ modules/                (phase modules)
│  └─ rules/                  (classification/rename/semantic policies)
└─ PROOF_PACK/
   ├─ README.md
   ├─ INDEX.md
   └─ phase_XX/
      └─ run_MM-DD-YYYY_HHMMSS/
         ├─ plan.csv
         ├─ metrics.json
         ├─ summary_MM-DD-YYYY.md
         └─ (selected evidence)
```

✅ Repo contains **source + curated proof**  
🚫 Repo does NOT contain `OUTPUTS/`

---

## B) OUTPUTS tree (generated, ignored by git)

```
OUTPUTS/
└─ phase_XX/
   └─ run_MM-DD-YYYY_HHMMSS/
      ├─ plan.csv
      ├─ runlog.txt
      ├─ metrics.json
      ├─ rollback.ps1
      ├─ summary_MM-DD-YYYY.md
      └─ evidence/
         └─ (phase-specific artifacts)
```

---

## C) C:\RH canonical workspace (outside repo)

Minimum expected families (yours may include more):
- `C:\RH\OPS`
- `C:\RH\INBOX`
- `C:\RH\TEMPORARY` (quarantine destination-only)
- `C:\RH\LIFE` (excluded)
- `C:\RH\VAULT` (excluded)
- `C:\RH\VAULT_NEVER_SYNC` (excluded)
- `C:\RH\ARCHIVE` (excluded)

If an agent is scanning outside INBOX/OPS or scanning TEMPORARY, it is violating contract.
