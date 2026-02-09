param()

$ErrorActionPreference = "Stop"

function SafeCount($path) {
  if (!(Test-Path $path)) { return 0 }
  return (Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
}

$root = (Get-Location).Path
$phases = @("00","01","02","03","04","05","06","07","08")

Write-Host ""
Write-Host "RH_MIGRATION_2026_V2 — Status" -ForegroundColor Cyan
Write-Host "Root: $root" -ForegroundColor Gray
Write-Host ""

$rows = @()

foreach ($ph in $phases) {
  $phaseDir = Join-Path $root ("OUTPUTS\phase_{0}" -f $ph)
  $latestRun = ""
  $runOk = $false
  $promoted = $false
  $notes = ""

  if (Test-Path $phaseDir) {
    $runs = Get-ChildItem -Path $phaseDir -Directory -Filter "run_*" | Sort-Object LastWriteTime -Descending
    if ($runs -and $runs.Count -gt 0) {
      $latestRun = $runs[0].Name

      # audit
      $auditCmd = "pwsh -NoProfile -ExecutionPolicy Bypass -File `"$root\tools\audit_phase.ps1`" -Phase $ph -RunId `"$latestRun`""
      $p = Start-Process -FilePath "pwsh" -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-File", "$root\tools\audit_phase.ps1", "-Phase", $ph, "-RunId", $latestRun) -NoNewWindow -PassThru -Wait
      if ($p.ExitCode -eq 0) { $runOk = $true } else { $notes = "audit_fail" }

      # promoted check
      $proofDir = Join-Path $root ("PROOF_PACK\phase_{0}\{1}" -f $ph, $latestRun)
      if (Test-Path $proofDir) {
        $havePlan = Test-Path (Join-Path $proofDir "plan.csv")
        $haveMetrics = Test-Path (Join-Path $proofDir "metrics.json")
        $haveSummary = (Get-ChildItem -Path $proofDir -Filter "summary_*.md" -File -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0
        if ($havePlan -and $haveMetrics -and $haveSummary) { $promoted = $true } else { $notes = ($notes + " proof_incomplete").Trim() }
      } else {
        $notes = ($notes + " not_promoted").Trim()
      }
    } else {
      $notes = "no_runs"
    }
  } else {
    $notes = "missing_phase_dir"
  }

  $status = "PENDING"
  if ($runOk -and $promoted) { $status = "COMPLETE" }
  elseif ($runOk -and -not $promoted) { $status = "RUN_OK_NOT_PROMOTED" }
  elseif ($latestRun -ne "") { $status = "RUN_EXISTS_BUT_INCOMPLETE" }

  $rows += [pscustomobject]@{
    Phase = $ph
    LatestRun = $latestRun
    Status = $status
    Notes = $notes
  }
}

$rows | Format-Table -AutoSize
