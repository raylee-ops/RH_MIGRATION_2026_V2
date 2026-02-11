# RH_MIGRATION_2026_V2 CSV Schema Audit
Generated: 02-11-2026

## Latest Runs Audited
- Phase 04: `OUTPUTS/phase_04/run_02-10-2026_143430`
- Phase 05: `OUTPUTS/phase_05/run_02-10-2026_184442`
- Phase 06: `OUTPUTS/phase_06/run_02-10-2026_184748`

## Root Cause of Blank Tables
The prior verification prompt queried legacy column names:
- Expected: `path`, `label`, `source`, `destination`, `action`, `hash_before`, `hash_after`

Current evidence files use different column names:
- Phase 04 `classification_results*.csv`: `source_path`, `bucket`, `confidence`, `rule_id`, `reason`, `last_modified`, `size_bytes`
- Phase 05 `move_plan*.csv`: `action_id`, `op`, `src_path`, `dst_path`, `label`, `confidence`, `reason`, `notes`
- Phase 06 `moves_executed*.csv`: `action_id`, `op`, `src_path`, `dst_path`, `label`, `confidence`, `reason`, `notes`, `status`, `executed_at`

Result: selecting nonexistent columns produced visually blank rows even though data exists.

## Data Integrity Checks
### Phase 04 classification_results
- Row count: `9685`
- All columns populated on `9685/9685` rows

### Phase 05 move_plan
- Row count: `9685`
- `op` distribution:
  - `MOVE_PLAN`: `5640`
  - `QUARANTINE_PLAN`: `2719`
  - `EXCLUDED`: `1325`
  - `REVIEW_COLLISION`: `1`
- `dst_path` blank rows: `1325`, all from `EXCLUDED` entries

### Phase 06 moves_executed
- Row count: `8359`
- `status` distribution:
  - `EXECUTED`: `6042`
  - `SKIPPED_DEST_EXISTS`: `2317`
- `op` distribution:
  - `MOVE`: `5640`
  - `QUARANTINE`: `2719`
- No hash columns in file (`hash_before`/`hash_after` absent)

### Phase 06 metrics.json reconciliation
- `plan_rows`: `9685`
- `executed_rows`: `6042`
- `skipped_dest_exists`: `2317`
- `skipped_rows`: `1326`
- `error_rows`: `0`
- `rollback_commands`: `6042`

Consistency check:
- `8359` executed-log rows equals `6042 + 2317`
- `1326` skipped plan rows aligns with `1325 EXCLUDED + 1 REVIEW_COLLISION`

## Correct Query Patterns
Use these columns for future verification:
- Phase 04: `source_path`, `bucket`, `confidence`, `rule_id`
- Phase 05: `src_path`, `dst_path`, `op`, `label`, `confidence`
- Phase 06: `src_path`, `dst_path`, `op`, `status`, `executed_at`

## Conclusion
Phases 04-06 evidence files contain populated execution data. The apparent blanks came from schema mismatch in verification queries, not from missing operations.
