[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$RepoRoot,
  [Parameter(Mandatory)][string]$RunRoot,
  [Parameter(Mandatory)][string]$EvidenceDir,
  [Parameter(Mandatory)][ValidateSet('DryRun','Execute')][string]$Mode
)

$ErrorActionPreference = 'Stop'
$today = Get-Date -Format "MM-dd-yyyy"

@"
# Runner Interface (Phase 03)
Date: $today

Canonical entrypoint:
pwsh -NoProfile -ExecutionPolicy Bypass -File SRC\run.ps1 -Phase <00-08> -Mode <DryRun|Execute> [-RunId run_MM-dd-yyyy_HHmmss]

Hard stops:
- missing RH_MIGRATION_2026_V2.SENTINEL
- preflight failure
- legacy path detected
- missing phase script
"@ | Out-File -Encoding utf8 -NoNewline (Join-Path $EvidenceDir "run_interface_$today.md")

@"
# DryRun Validation Checklist (Phase 03)
Date: $today
RepoRoot: $RepoRoot
RunRoot:  $RunRoot
Evidence: $EvidenceDir
Mode:     $Mode
"@ | Out-File -Encoding utf8 -NoNewline (Join-Path $EvidenceDir "dryrun_validation_checklist_$today.md")

@"
RepoRoot: $RepoRoot
RunRoot:  $RunRoot
EvidenceDir: $EvidenceDir
SentinelPresent: $(Test-Path (Join-Path $RepoRoot 'RH_MIGRATION_2026_V2.SENTINEL'))
"@ | Out-File -Encoding utf8 -NoNewline (Join-Path $EvidenceDir "canonical_paths_proof_$today.txt")

$runps1 = Join-Path $RepoRoot 'SRC\run.ps1'
$config = Join-Path $RepoRoot 'project_config.json'

if (Test-Path $runps1) {
  (Get-FileHash $runps1 -Algorithm SHA256 | ForEach-Object { "$($_.Algorithm) $($_.Hash) $runps1" }) |
    Out-File -Encoding utf8 -NoNewline (Join-Path $EvidenceDir "runner_used_runps1_hash_$today.txt")
}

if (Test-Path $config) {
  (Get-FileHash $config -Algorithm SHA256 | ForEach-Object { "$($_.Algorithm) $($_.Hash) $config" }) |
    Out-File -Encoding utf8 -NoNewline (Join-Path $EvidenceDir "runner_used_config_hash_$today.txt")
}

exit 0