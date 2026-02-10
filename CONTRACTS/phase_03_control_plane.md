# Phase 03 — Control Plane (Runner + DryRun enforcement)

This phase creates a single entrypoint that:
- refuses to run outside repo root (sentinel required)
- runs tools/preflight.ps1 before anything else
- writes all run artifacts to OUTPUTS\phase_XX\run_MM-DD-YYYY_HHMMSS\
- executes exactly one phase script: SRC\phases\phase_XX.ps1

Completion proof lives in:
OUTPUTS\phase_03\run_*\evidence\
- run_interface_*.md
- dryrun_validation_checklist_*.md
- canonical_paths_proof_*.txt
- runner_used_runps1_hash_*.txt
- runner_used_config_hash_*.txt