[CmdletBinding()]
param(
    [switch]$InstallMissingTools
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$outputDir = Join-Path $repoRoot "OUTPUTS"

$gitleaksReport = Join-Path $outputDir "gitleaks.json"
$trivyReport = Join-Path $outputDir "trivy.txt"
$pesterReport = Join-Path $outputDir "pester.xml"
$summaryReport = Join-Path $outputDir "scan_summary.md"
$screenshotsChecklist = Join-Path $outputDir "screenshots_checklist.md"

$toolVersions = [ordered]@{
    Gitleaks = "8.24.2"
    Trivy    = "0.56.2"
    Pester   = "5.6.1"
}

$checkStatus = [ordered]@{
    Gitleaks  = "NOT_RUN"
    Trivy     = "NOT_RUN"
    Pester    = "NOT_RUN"
    CodeQL    = "CI_ONLY"
    Scorecard = "CI_ONLY"
}

$overallFail = $false

function Write-Step {
    param([string]$Message)
    Write-Host "[ci] $Message"
}

function Test-Tool {
    param([string]$Name)
    return $null -ne (Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Ensure-PesterVersion {
    param(
        [string]$Version,
        [switch]$AutoInstall
    )

    $required = [version]$Version
    $installed = Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -eq $required } | Select-Object -First 1

    if (-not $installed) {
        if (-not $AutoInstall) {
            throw "Pester v$Version is required. Re-run with -InstallMissingTools or install manually."
        }

        Write-Step "Installing Pester v$Version (CurrentUser scope)"
        Install-Module -Name Pester -RequiredVersion $Version -Scope CurrentUser -Force -SkipPublisherCheck -AllowClobber
    }

    Import-Module -Name Pester -RequiredVersion $Version -Force
}

New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
@($gitleaksReport, $trivyReport, $pesterReport, $summaryReport, $screenshotsChecklist) | ForEach-Object {
    if (Test-Path -LiteralPath $_) {
        Remove-Item -LiteralPath $_ -Force
    }
}

Write-Step "Repository root: $repoRoot"

Write-Step "Running gitleaks"
if (Test-Tool -Name "gitleaks") {
    Push-Location -Path $repoRoot
    try {
        & gitleaks detect --no-banner --redact --source $repoRoot --report-format json --report-path $gitleaksReport --exit-code 1
        $gitleaksExit = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }

    if ($gitleaksExit -eq 0) {
        $checkStatus.Gitleaks = "PASS"
    }
    else {
        $checkStatus.Gitleaks = "FAIL"
        $overallFail = $true
    }
}
else {
    Set-Content -LiteralPath $gitleaksReport -Value "[]" -Encoding utf8
    $checkStatus.Gitleaks = "ERROR_MISSING_TOOL"
    $overallFail = $true
}

Write-Step "Running trivy filesystem scan"
if (Test-Tool -Name "trivy") {
    Push-Location -Path $repoRoot
    try {
        & trivy fs $repoRoot --scanners vuln,misconfig,secret --severity HIGH,CRITICAL --ignore-unfixed --no-progress --format table --output $trivyReport --exit-code 1
        $trivyExit = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }

    if ($trivyExit -eq 0) {
        $checkStatus.Trivy = "PASS"
    }
    else {
        $checkStatus.Trivy = "FAIL"
        $overallFail = $true
    }
}
else {
    Set-Content -LiteralPath $trivyReport -Value "trivy is not installed. Install v$($toolVersions.Trivy)." -Encoding utf8
    $checkStatus.Trivy = "ERROR_MISSING_TOOL"
    $overallFail = $true
}

Write-Step "Running Pester tests"
try {
    Ensure-PesterVersion -Version $toolVersions.Pester -AutoInstall:$InstallMissingTools

    $testsPath = Join-Path $repoRoot "tests"
    $config = New-PesterConfiguration
    $config.Run.Path = @($testsPath)
    $config.Run.PassThru = $true
    $config.Output.Verbosity = "Detailed"
    $config.TestResult.Enabled = $true
    $config.TestResult.OutputFormat = "NUnitXml"
    $config.TestResult.OutputPath = $pesterReport

    $pesterResult = Invoke-Pester -Configuration $config
    if ($pesterResult.FailedCount -gt 0) {
        $checkStatus.Pester = "FAIL"
        $overallFail = $true
    }
    else {
        $checkStatus.Pester = "PASS"
    }
}
catch {
    Set-Content -LiteralPath $pesterReport -Value "<testsuites></testsuites>" -Encoding utf8
    $checkStatus.Pester = "ERROR"
    $overallFail = $true
}

$gitleaksFindings = 0
if (Test-Path -LiteralPath $gitleaksReport) {
    try {
        $payload = Get-Content -LiteralPath $gitleaksReport -Raw | ConvertFrom-Json
        if ($null -eq $payload) {
            $gitleaksFindings = 0
        }
        elseif ($payload -is [array]) {
            $gitleaksFindings = $payload.Count
        }
        else {
            $gitleaksFindings = 1
        }
    }
    catch {
        $gitleaksFindings = -1
    }
}

$trivyHighCriticalHits = 0
if (Test-Path -LiteralPath $trivyReport) {
    $trivyHighCriticalHits = @(Select-String -LiteralPath $trivyReport -Pattern "\bHIGH\b|\bCRITICAL\b").Count
}

$runTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss zzz")
$summary = @(
    "# Scan Summary"
    ""
    "- Run time: $runTime"
    "- Repository: $repoRoot"
    ""
    "## Pinned Versions"
    "- gitleaks: $($toolVersions["Gitleaks"])"
    "- trivy: $($toolVersions["Trivy"])"
    "- pester: $($toolVersions["Pester"])"
    ""
    "## Status"
    "| Check | Status |"
    "| --- | --- |"
    "| Gitleaks | $($checkStatus["Gitleaks"]) |"
    "| Trivy | $($checkStatus["Trivy"]) |"
    "| Pester | $($checkStatus["Pester"]) |"
    "| CodeQL | $($checkStatus["CodeQL"]) |"
    "| Scorecard | $($checkStatus["Scorecard"]) |"
    ""
    "## Findings Snapshot"
    "- Gitleaks findings: $gitleaksFindings"
    "- Trivy HIGH/CRITICAL line hits: $trivyHighCriticalHits"
    ""
    "## Evidence Files"
    "- OUTPUTS\scan_summary.md"
    "- OUTPUTS\trivy.txt"
    "- OUTPUTS\gitleaks.json"
    "- OUTPUTS\pester.xml"
    "- OUTPUTS\screenshots_checklist.md"
) -join "`n"
Set-Content -LiteralPath $summaryReport -Value $summary -Encoding utf8

$checklist = @(
    "# Recruiter Proof Screenshots Checklist"
    ""
    "- [ ] GitHub Actions run summary (gitleaks workflow)"
    "- [ ] GitHub Actions run summary (trivy workflow)"
    "- [ ] Code scanning alerts page (CodeQL + Scorecard)"
    "- [ ] OUTPUTS\scan_summary.md visible in repo"
    "- [ ] OUTPUTS\gitleaks.json artifact sample"
    "- [ ] OUTPUTS\trivy.txt artifact sample"
    "- [ ] OUTPUTS\pester.xml test result sample"
    "- [ ] Portfolio page showing security automation section"
) -join "`n"
Set-Content -LiteralPath $screenshotsChecklist -Value $checklist -Encoding utf8

Write-Step "Wrote $summaryReport"
Write-Step "Wrote $trivyReport"
Write-Step "Wrote $gitleaksReport"
Write-Step "Wrote $pesterReport"
Write-Step "Wrote $screenshotsChecklist"

if ($overallFail) {
    Write-Step "Completed with failures."
    exit 1
}

Write-Step "Completed successfully."
exit 0
