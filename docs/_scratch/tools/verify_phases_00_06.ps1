$ErrorActionPreference = 'Continue'

Set-Location -LiteralPath 'C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2'

$verificationOutput = Join-Path -Path (Get-Location) -ChildPath 'verification_full_output.txt'
$statusOutput = Join-Path -Path (Get-Location) -ChildPath 'verification_status_output.txt'
$reportPath = Join-Path -Path (Get-Location) -ChildPath 'verification_report.txt'
$statusScript = Join-Path -Path (Get-Location) -ChildPath 'tools\status.ps1'

if (Test-Path -LiteralPath $verificationOutput) { Remove-Item -LiteralPath $verificationOutput -Force }
if (Test-Path -LiteralPath $statusOutput) { Remove-Item -LiteralPath $statusOutput -Force }
if (Test-Path -LiteralPath $reportPath) { Remove-Item -LiteralPath $reportPath -Force }

function Get-LatestRunDir {
    param(
        [Parameter(Mandatory)]
        [string]$PhasePath
    )

    if (-not (Test-Path -LiteralPath $PhasePath)) { return $null }
    return (Get-ChildItem -LiteralPath $PhasePath -Directory -Filter 'run_*' -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        Select-Object -First 1)
}

$phase00Run = $null
$phase02Run = $null
$phase04Run = $null
$phase05Run = $null
$phase06Run = $null
$phase06Metrics = $null
$hashMismatches = @()

& {
    Write-Output '=== 1. Environment Check ==='
    Set-Location -LiteralPath 'C:\RH\OPS\PROJECTS\RH_MIGRATION_2026_V2'
    Write-Output "PWD: $((Get-Location).Path)"
    Write-Output "Sentinel exists: $(Test-Path -LiteralPath '.\RH_MIGRATION_2026_V2.SENTINEL')"
    if (Test-Path -LiteralPath '.\project_config.json') {
        Get-Content -LiteralPath '.\project_config.json' -Encoding utf8 |
            ConvertFrom-Json |
            Select-Object project_name, project_root |
            Format-List |
            Out-String |
            Write-Output
    } else {
        Write-Output 'WARNING: project_config.json not found'
    }

    Write-Output '=== 2. Status Tool Output ==='
    if (Test-Path -LiteralPath $statusScript) {
        & pwsh -NoProfile -File $statusScript 2>&1 | Tee-Object -FilePath $statusOutput -Encoding utf8
    } else {
        $msg = "ERROR: status tool missing at $statusScript"
        Write-Output $msg
        $msg | Out-File -LiteralPath $statusOutput -Encoding utf8
    }

    Write-Output '=== 3. Phase 00 Evidence Verification ==='
    $phase00Run = Get-LatestRunDir -PhasePath '.\OUTPUTS\phase_00'
    if ($null -eq $phase00Run) {
        Write-Output 'ERROR: No Phase 00 run folder found'
    } else {
        Write-Output "Phase 00 Latest Run: $($phase00Run.FullName)"
        $phase00EvidencePath = Join-Path -Path $phase00Run.FullName -ChildPath 'evidence'
        if (Test-Path -LiteralPath $phase00EvidencePath) {
            Get-ChildItem -LiteralPath $phase00EvidencePath -File |
                Select-Object Name, Length, LastWriteTime |
                Format-Table -AutoSize |
                Out-String |
                Write-Output
        } else {
            Write-Output 'WARNING: Phase 00 evidence folder missing'
        }

        $phase00MetricsPath = Join-Path -Path $phase00Run.FullName -ChildPath 'metrics.json'
        if (Test-Path -LiteralPath $phase00MetricsPath) {
            Get-Content -LiteralPath $phase00MetricsPath -Encoding utf8 |
                ConvertFrom-Json |
                ConvertTo-Json -Depth 8 |
                Write-Output
        } else {
            Write-Output 'WARNING: Phase 00 metrics.json missing'
        }
    }

    Write-Output '=== 4. Phase 02 Canonical Manifest Verification ==='
    $phase02Run = Get-LatestRunDir -PhasePath '.\OUTPUTS\phase_02'
    if ($null -eq $phase02Run) {
        Write-Output 'ERROR: No Phase 02 run folder found'
    } else {
        Write-Output "Phase 02 Latest Run: $($phase02Run.FullName)"
        $phase02Evidence = Join-Path -Path $phase02Run.FullName -ChildPath 'evidence'
        $canonicalManifest = Get-ChildItem -LiteralPath $phase02Evidence -File -Filter 'canonical_script_manifest*.csv' -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($canonicalManifest) {
            $manifestRows = Import-Csv -LiteralPath $canonicalManifest.FullName
            Write-Output "Canonical manifest rows: $($manifestRows.Count)"
            $manifestRows |
                Select-Object -First 50 |
                Format-Table -AutoSize |
                Out-String |
                Write-Output
        } else {
            Write-Output 'WARNING: canonical_script_manifest not found'
        }

        $scriptHashes = Get-ChildItem -LiteralPath $phase02Evidence -File -Filter 'script_hashes*.csv' -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($scriptHashes) {
            $hashRows = Import-Csv -LiteralPath $scriptHashes.FullName
            Write-Output "Script hash rows: $($hashRows.Count)"
            $hashRows |
                Select-Object -First 10 path, sha256, hash_status |
                Format-Table -AutoSize |
                Out-String |
                Write-Output
        } else {
            Write-Output 'WARNING: script_hashes not found'
        }
    }

    Write-Output '=== 5. Phase 04 Classification Results Verification ==='
    $phase04Run = Get-LatestRunDir -PhasePath '.\OUTPUTS\phase_04'
    if ($null -eq $phase04Run) {
        Write-Output 'ERROR: No Phase 04 run folder found'
    } else {
        Write-Output "Phase 04 Latest Run: $($phase04Run.FullName)"
        $phase04MetricsPath = Join-Path -Path $phase04Run.FullName -ChildPath 'metrics.json'
        if (Test-Path -LiteralPath $phase04MetricsPath) {
            $phase04Metrics = Get-Content -LiteralPath $phase04MetricsPath -Encoding utf8 | ConvertFrom-Json
            if ($null -ne $phase04Metrics.PSObject.Properties['classification']) {
                Write-Output "Total files classified: $($phase04Metrics.classification.total_files)"
                Write-Output "Low confidence ratio: $($phase04Metrics.classification.low_confidence_ratio)"
            } else {
                $keys = ($phase04Metrics.PSObject.Properties.Name -join ', ')
                Write-Output "WARNING: classification node missing in phase 04 metrics. Available keys: $keys"
            }
        } else {
            Write-Output 'WARNING: Phase 04 metrics.json missing'
        }

        $phase04Evidence = Join-Path -Path $phase04Run.FullName -ChildPath 'evidence'
        $classificationFile = Get-ChildItem -LiteralPath $phase04Evidence -File -Filter 'classification_results*.csv' -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($classificationFile) {
            $classData = Import-Csv -LiteralPath $classificationFile.FullName
            $classData |
                Select-Object -First 20 path, label, confidence |
                Format-Table -AutoSize |
                Out-String |
                Write-Output
            Write-Output "Total classifications: $($classData.Count)"
        } else {
            Write-Output 'WARNING: classification_results not found'
        }
    }

    Write-Output '=== 6. Phase 05 Move Plan Verification ==='
    $phase05Run = Get-LatestRunDir -PhasePath '.\OUTPUTS\phase_05'
    if ($null -eq $phase05Run) {
        Write-Output 'ERROR: No Phase 05 run folder found'
    } else {
        Write-Output "Phase 05 Latest Run: $($phase05Run.FullName)"
        $phase05Evidence = Join-Path -Path $phase05Run.FullName -ChildPath 'evidence'
        $movePlanFile = Get-ChildItem -LiteralPath $phase05Evidence -File -Filter 'move_plan*.csv' -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($movePlanFile) {
            $movePlan = Import-Csv -LiteralPath $movePlanFile.FullName
            Write-Output "Total planned moves: $($movePlan.Count)"
            Write-Output 'Sample planned moves:'
            $movePlan |
                Select-Object -First 10 source, destination, action |
                Format-Table -AutoSize |
                Out-String |
                Write-Output
        } else {
            Write-Output 'WARNING: move_plan not found'
        }

        $collisionsFile = Get-ChildItem -LiteralPath $phase05Evidence -File -Filter 'collisions*.csv' -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($collisionsFile) {
            $collisions = Import-Csv -LiteralPath $collisionsFile.FullName
            Write-Output "Total collisions detected: $($collisions.Count)"
        } else {
            Write-Output 'No collisions file (may be normal if no collisions)'
        }
    }

    Write-Output '=== 7. Phase 06 ACTUAL EXECUTION PROOF ==='
    $phase06Run = Get-LatestRunDir -PhasePath '.\OUTPUTS\phase_06'
    if ($null -eq $phase06Run) {
        Write-Output 'ERROR: No Phase 06 run folder found'
    } else {
        Write-Output "Phase 06 Latest Run: $($phase06Run.FullName)"
        $phase06MetricsPath = Join-Path -Path $phase06Run.FullName -ChildPath 'metrics.json'
        if (Test-Path -LiteralPath $phase06MetricsPath) {
            $phase06Metrics = Get-Content -LiteralPath $phase06MetricsPath -Encoding utf8 | ConvertFrom-Json
            Write-Output '=== PHASE 06 EXECUTION METRICS ==='
            if ($null -ne $phase06Metrics.PSObject.Properties['moves']) {
                Write-Output "Files moved successfully: $($phase06Metrics.moves.files_moved_success)"
                Write-Output "Files moved failed: $($phase06Metrics.moves.files_moved_failed)"
                Write-Output "Files moved skipped: $($phase06Metrics.moves.files_moved_skipped)"
                Write-Output "Success rate: $($phase06Metrics.moves.success_rate)"
            } else {
                Write-Output 'WARNING: moves node missing in phase 06 metrics.json'
            }
            if ($null -ne $phase06Metrics.PSObject.Properties['operations']) {
                Write-Output "Mutating operations count: $($phase06Metrics.operations.mutating_count)"
            } else {
                Write-Output 'WARNING: operations node missing in phase 06 metrics.json'
            }
        } else {
            Write-Output 'ERROR: Phase 06 metrics.json not found'
        }

        $phase06Evidence = Join-Path -Path $phase06Run.FullName -ChildPath 'evidence'
        $movesExecutedFile = Get-ChildItem -LiteralPath $phase06Evidence -File -Filter 'moves_executed*.csv' -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($movesExecutedFile) {
            $executed = Import-Csv -LiteralPath $movesExecutedFile.FullName
            Write-Output "Total executed move records: $($executed.Count)"
            Write-Output 'Sample executed moves with hash verification:'
            $executed |
                Select-Object -First 10 source, destination, hash_before, hash_after, status |
                Format-Table -AutoSize |
                Out-String |
                Write-Output

            $hashMismatches = $executed | Where-Object { $_.status -eq 'success' -and $_.hash_before -ne $_.hash_after }
            if ($hashMismatches.Count -gt 0) {
                Write-Output "ERROR: Found $($hashMismatches.Count) hash mismatches!"
                $hashMismatches |
                    Select-Object source, destination, hash_before, hash_after, status |
                    Format-Table -AutoSize |
                    Out-String |
                    Write-Output
            } else {
                Write-Output 'PASS: All successful moves have matching hashes (integrity verified)'
            }
        } else {
            Write-Output 'ERROR: moves_executed.csv not found - Phase 06 may not have actually executed'
        }

        $errorsFile = Get-ChildItem -LiteralPath $phase06Evidence -File -Filter 'errors*.csv' -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($errorsFile) {
            $errors = Import-Csv -LiteralPath $errorsFile.FullName
            Write-Output "Total errors during execution: $($errors.Count)"
            if ($errors.Count -gt 0) {
                Write-Output 'Sample errors:'
                $errors |
                    Select-Object -First 10 source, error_type, error_message |
                    Format-Table -AutoSize |
                    Out-String |
                    Write-Output
            }
        } else {
            Write-Output 'No errors file present'
        }

        $rollbackPath = Join-Path -Path $phase06Run.FullName -ChildPath 'rollback.ps1'
        if (Test-Path -LiteralPath $rollbackPath) {
            $rollbackLines = (Get-Content -LiteralPath $rollbackPath -Encoding utf8).Count
            Write-Output "Rollback script exists: $rollbackLines lines"
            Write-Output 'First 20 lines of rollback.ps1:'
            Get-Content -LiteralPath $rollbackPath -Encoding utf8 -TotalCount 20 | ForEach-Object { Write-Output $_ }
        } else {
            Write-Output 'WARNING: rollback.ps1 not found'
        }
    }

    Write-Output '=== 8. Filesystem Before/After Comparison ==='
    $phase00Tree = Get-ChildItem -LiteralPath '.\OUTPUTS\phase_00' -Recurse -File -Filter '*tree*.txt' -ErrorAction SilentlyContinue |
        Select-Object -First 1
    $phase06Tree = Get-ChildItem -LiteralPath '.\OUTPUTS\phase_06' -Recurse -File -Filter 'state_tree_after*.txt' -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($phase00Tree -and $phase06Tree) {
        Write-Output '=== FILESYSTEM STRUCTURE CHANGES ==='
        Write-Output "Before (Phase 00): $((Get-Content -LiteralPath $phase00Tree.FullName -Encoding utf8).Count) folders"
        Write-Output "After (Phase 06): $((Get-Content -LiteralPath $phase06Tree.FullName -Encoding utf8).Count) folders"
    } else {
        Write-Output 'State tree files not available for comparison'
    }

    Write-Output '=== 9. Generate Verification Report ==='
    if (Test-Path -LiteralPath $statusOutput) {
        $statusSummary = Get-Content -LiteralPath $statusOutput -Encoding utf8 | Out-String
    } else {
        $statusSummary = 'No status output file generated.'
    }

    $filesMoved = 'N/A'
    $successRate = 'N/A'
    if ($phase06Metrics -and $null -ne $phase06Metrics.PSObject.Properties['moves']) {
        $filesMoved = $phase06Metrics.moves.files_moved_success
        $successRate = $phase06Metrics.moves.success_rate
    }

    $report = @"
# RH_MIGRATION_2026_V2 Verification Report
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Phase Status Summary
$statusSummary

## Phase 06 Execution Evidence
- Files moved: $filesMoved
- Success rate: $successRate
- Hash verification: $(if ($hashMismatches.Count -eq 0) { 'PASS' } else { 'FAIL' })
- Rollback generated: $(if ($phase06Run) { Test-Path -LiteralPath (Join-Path $phase06Run.FullName 'rollback.ps1') } else { $false })

## Evidence Artifacts Located
- Phase 00: $(if ($phase00Run) { Test-Path -LiteralPath (Join-Path $phase00Run.FullName 'evidence') } else { $false })
- Phase 02: $(if ($phase02Run) { Test-Path -LiteralPath (Join-Path $phase02Run.FullName 'evidence') } else { $false })
- Phase 04: $(if ($phase04Run) { Test-Path -LiteralPath (Join-Path $phase04Run.FullName 'evidence') } else { $false })
- Phase 05: $(if ($phase05Run) { Test-Path -LiteralPath (Join-Path $phase05Run.FullName 'evidence') } else { $false })
- Phase 06: $(if ($phase06Run) { Test-Path -LiteralPath (Join-Path $phase06Run.FullName 'evidence') } else { $false })
"@
    $report | Out-File -LiteralPath $reportPath -Encoding utf8
    Write-Output $report
} | Tee-Object -FilePath $verificationOutput -Encoding utf8
