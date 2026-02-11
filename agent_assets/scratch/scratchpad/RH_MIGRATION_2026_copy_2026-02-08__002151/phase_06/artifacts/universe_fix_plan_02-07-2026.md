# Universe Fix Plan (02-07-2026)

## Scope
- Enforce final universe model:
  - C:\ARCHIVE\
  - C:\BACKUPS\
  - C:\RH\INBOX\
  - C:\RH\OPS\
  - C:\RH\LIFE\
  - C:\RH\VAULT\
- Target RH root post-state: only INBOX, OPS, LIFE, VAULT.
- Mode for this deliverable: PLAN/DRY-RUN ONLY. No move execution performed.

## Artifacts
- Manifest: C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_06\artifacts\universe_fix_manifest_02-07-2026.csv
- BEFORE root listing: C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_06\artifacts\rh_root_before_02-07-2026.txt
- AFTER target root listing: C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_06\artifacts\rh_root_after_target_02-07-2026.txt

## A) Inventory of inbox-like folders under OPS
- Source inventory is captured in manifest category inbox_consolidation.
- Match rule used: folder name INBOX, _INBOX, or *_INBOX.

## B) Deterministic mapping to C:\RH\INBOX
- downloads* -> C:\RH\INBOX\DOWNLOADS
- screenshots* -> C:\RH\INBOX\SCREENSHOTS
- import/triage/quarantine inboxes -> C:\RH\INBOX\IMPORTS or C:\RH\INBOX\QUARANTINE\...
- proof-pack evidence inboxes -> C:\RH\INBOX\PROOF_PACKS\... (or ...\QUARANTINE\PROOF_PACKS\...)
- ambiguous roots -> C:\RH\INBOX\STAGING or C:\RH\INBOX\MISC
- Conflict policy for all moves: deterministic suffix (dupe-0001), (dupe-0002), ...

## C) Routing of extra RH root items
- C:\RH\ARCHIVE -> C:\ARCHIVE
- C:\BACKUPS -> create if missing (no content move in this task)
- C:\RH\.codex -> C:\RH\OPS\SYSTEM\ai_context\codex\.codex
- C:\RH\.agents -> C:\RH\OPS\SYSTEM\ai_context\codex\.agents
- C:\RH\AGENTS.md -> C:\RH\OPS\SYSTEM\ai_context\codex\AGENTS.md
- C:\RH\desktop.ini -> C:\RH\OPS\SYSTEM\ai_context\codex\root_meta\desktop.ini
- C:\RH\VAULT_NEVER_SYNC -> pending decision (A/B/C)

## D) Commands (DryRun now, Execute later)

### DryRun command block (safe preview)
`powershell
$manifest = 'C:\RH\OPS\SYSTEM\migrations\RH_MIGRATION_2026\phase_06\artifacts\universe_fix_manifest_02-07-2026.csv'

function Get-DupePath {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return $Path }
  $dir = Split-Path -Parent $Path
  $leaf = Split-Path -Leaf $Path
  $base = [System.IO.Path]::GetFileNameWithoutExtension($leaf)
  $ext = [System.IO.Path]::GetExtension($leaf)
  $i = 1
  do {
    $cand = if ($ext) { Join-Path $dir ("$base (dupe-{0:d4})$ext" -f $i) } else { Join-Path $dir ("$leaf (dupe-{0:d4})" -f $i) }
    $i++
  } while (Test-Path -LiteralPath $cand)
  return $cand
}

Import-Csv -LiteralPath $manifest | ForEach-Object {
  if ($_.move_scope -eq 'create_if_missing') {
    New-Item -ItemType Directory -Path $_.destination_path -WhatIf | Out-Null
    return
  }
  if ($_.destination_path -eq 'TBD_OPTION_A_B_C') { return }

  $dest = Get-DupePath -Path $_.destination_path
  $destParent = Split-Path -Parent $dest
  if ($destParent) { New-Item -ItemType Directory -Path $destParent -Force -WhatIf | Out-Null }

  if ($_.move_scope -eq 'children_recursive') {
    Move-Item -Path (Join-Path $_.source_path '*') -Destination $dest -WhatIf
  } else {
    Move-Item -Path $_.source_path -Destination $dest -WhatIf
  }
}
`

### Execute command block (gated)
- Do not run until explicit approval phrase: EXECUTE UNIVERSE FIX
- After approval, run the same block with -WhatIf removed.
- Vault route requires explicit option included in approval.

## E) Post-move verification (target)
`powershell
(Get-ChildItem -LiteralPath 'C:\RH' -Directory -Force | Select-Object -ExpandProperty Name | Sort-Object) -join ', '
# Expected exactly: INBOX, LIFE, OPS, VAULT
`

## Open Decision Required
- VAULT_NEVER_SYNC destination option must be selected before execution:
  - A -> C:\RH\VAULT\VAULT_NEVER_SYNC
  - B -> C:\VAULT_NEVER_SYNC
  - C -> leave in place (not preferred)
