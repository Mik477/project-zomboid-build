[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path ([IO.Path]::GetTempPath()) "project-zomboid-build-bootstrap-$PID-$([Guid]::NewGuid().ToString('N'))"
$previousUserProfile = $env:USERPROFILE

try {
    $manifest = Get-Content -LiteralPath (Join-Path $repositoryRoot 'config\modpack.json') -Raw | ConvertFrom-Json
    $packageRoot = Join-Path $testRoot "Downloads\project-zomboid-build-$($manifest.package.version)"
    $otherWorkingDirectory = Join-Path $testRoot 'Elsewhere'
    $syntheticUserProfile = Join-Path $testRoot 'Profile'
    New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $otherWorkingDirectory -Force | Out-Null
    New-Item -ItemType Directory -Path $syntheticUserProfile -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repositoryRoot 'config\modpack.json') -Destination (Join-Path $packageRoot 'manifest.json')
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Install-Package.ps1') -Destination (Join-Path $packageRoot 'Install.ps1')
    $env:USERPROFILE = $syntheticUserProfile

    $caughtError = $null
    Push-Location -LiteralPath $otherWorkingDirectory
    try {
        try {
            & (Join-Path $packageRoot 'Install.ps1') `
                -PackageRoot ([string]::Empty) `
                -ZomboidUserPath ([string]::Empty) `
                -GamePath (Join-Path $testRoot 'missing-game') `
                -WorkshopPath (Join-Path $testRoot 'missing-workshop') `
                -WhatIf
        }
        catch {
            $caughtError = $_
        }
    }
    finally {
        Pop-Location
    }

    if (-not $caughtError) {
        throw 'Empty-user-path probe unexpectedly completed the installer.'
    }
    if ($caughtError.FullyQualifiedErrorId -like 'ParameterArgumentValidationErrorEmptyStringNotAllowed*' -or
        $caughtError.Exception.Message -match "parameter 'Path'.*empty string") {
        throw "Installer passed an empty package/profile path to Join-Path: $($caughtError.Exception.Message)"
    }
    if ($caughtError.Exception.Message -notmatch 'Project Zomboid game directory does not exist|Project Zomboid \(Steam app 108600\) was not found') {
        throw "Downloads-folder bootstrap stopped at an unexpected boundary: $($caughtError.Exception.Message)"
    }

    Push-Location -LiteralPath $otherWorkingDirectory
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $nativeOutput = (& powershell.exe `
            -NoLogo `
            -NoProfile `
            -ExecutionPolicy Bypass `
            -File (Join-Path $packageRoot 'Install.ps1') `
            -GamePath (Join-Path $testRoot 'missing-game') `
            -WorkshopPath (Join-Path $testRoot 'missing-workshop') `
            -WhatIf 2>&1 | Out-String)
        $nativeExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
        Pop-Location
    }
    if ($nativeExitCode -eq 0) {
        throw 'powershell.exe -File Downloads-folder probe unexpectedly completed the installer.'
    }
    if ($nativeOutput -match "parameter 'Path'.*empty string") {
        throw "powershell.exe -File passed an empty path to Join-Path: $nativeOutput"
    }
    if ($nativeOutput -notmatch 'Project Zomboid game directory does not exist|Project Zomboid \(Steam app 108600\) was not found') {
        throw "powershell.exe -File Downloads-folder probe stopped at an unexpected boundary: $nativeOutput"
    }

    Write-Output 'Friend installer Downloads-folder, powershell.exe -File, and empty-path bootstrap validation passed.'
}
finally {
    $env:USERPROFILE = $previousUserProfile
    if (Test-Path -LiteralPath $testRoot -PathType Container) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
