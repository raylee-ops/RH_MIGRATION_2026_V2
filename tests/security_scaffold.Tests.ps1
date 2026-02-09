BeforeAll {
    $RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
}

Describe "Security automation scaffold" {
    It "has pinned pre-commit gitleaks config" {
        $path = Join-Path $RepoRoot ".pre-commit-config.yaml"
        Test-Path -LiteralPath $path | Should -BeTrue

        $content = Get-Content -LiteralPath $path -Raw
        $content | Should -Match "gitleaks"
        $content | Should -Match "v8\.24\.2"
    }

    It "has local CI runner script" {
        $path = Join-Path $RepoRoot "scripts\ci.ps1"
        Test-Path -LiteralPath $path | Should -BeTrue
    }

    It "has required workflow files" {
        $workflows = @(
            ".github\workflows\gitleaks.yml",
            ".github\workflows\trivy.yml",
            ".github\workflows\codeql.yml",
            ".github\workflows\scorecard.yml"
        )

        foreach ($workflow in $workflows) {
            $fullPath = Join-Path $RepoRoot $workflow
            Test-Path -LiteralPath $fullPath | Should -BeTrue
        }
    }
}
