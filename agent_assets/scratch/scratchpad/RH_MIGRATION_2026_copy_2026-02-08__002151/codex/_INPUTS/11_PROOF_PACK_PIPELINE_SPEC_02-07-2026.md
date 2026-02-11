# Proof Pack Pipeline Spec (02-07-2026)

Proof pack root:
C:\RH\OPS\PROOF_PACKS\RH_MIGRATION_2026\

Default behavior:
- Create skeleton only unless explicitly approved to copy artifacts.

Required structure:
- README.md
- PHASE_SUMMARY.md
- TIMELINE.md
- EVIDENCE\phase_XX\
- SCRIPTS\

Sanitization rules:
- No secrets, tokens, or credentials.
- Minimize personal identifiers.
- If uncertain, stop and request approval.
