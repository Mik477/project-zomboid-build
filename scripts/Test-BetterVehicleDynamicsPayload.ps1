[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'BetterVehicleDynamicsPayload.ps1')

function Assert-ThrowsLike {
    param(
        [Parameter(Mandatory)] [scriptblock]$Action,
        [Parameter(Mandatory)] [string]$Pattern
    )

    try {
        & $Action
    }
    catch {
        if ($_.Exception.Message -notlike $Pattern) {
            throw "Expected error like '$Pattern', got '$($_.Exception.Message)'."
        }
        return
    }
    throw "Expected error like '$Pattern', but the action succeeded."
}

$pinnedHashes = Get-BetterVehicleDynamicsExpectedPayloadHashes
if ($pinnedHashes.Count -ne 18) {
    throw "Expected 18 pinned BVD classes, found $($pinnedHashes.Count)."
}
foreach ($entry in $pinnedHashes.GetEnumerator()) {
    if ($entry.Key -notlike '*.class' -or $entry.Value -notmatch '^[0-9A-F]{64}$') {
        throw "Invalid pinned BVD payload entry: $($entry.Key)"
    }
}

$testRoot = Join-Path $env:LOCALAPPDATA "project-zomboid-build\tests\BVDPayload-$PID"
$validRoot = Join-Path $testRoot 'valid'
try {
    New-Item -ItemType Directory -Path (Join-Path $validRoot 'core\physics') -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $validRoot 'core\physics\One.class'), 'one')
    [IO.File]::WriteAllText((Join-Path $validRoot 'core\physics\Two.class'), 'two')
    $fixtureHashes = [ordered]@{
        'core/physics/One.class' = (Get-FileHash -LiteralPath (Join-Path $validRoot 'core\physics\One.class') -Algorithm SHA256).Hash
        'core/physics/Two.class' = (Get-FileHash -LiteralPath (Join-Path $validRoot 'core\physics\Two.class') -Algorithm SHA256).Hash
    }
    $validatedFiles = @(Assert-BetterVehicleDynamicsPayload -SourceRoot $validRoot -ExpectedPayloadHashes $fixtureHashes)
    if ($validatedFiles.Count -ne 2) {
        throw "Expected two validated fixture files, found $($validatedFiles.Count)."
    }
    $snapshotRoot = Join-Path $testRoot 'snapshot'
    $snapshotFiles = @(New-BetterVehicleDynamicsPayloadSnapshot -SourceRoot $validRoot -SnapshotRoot $snapshotRoot -ExpectedPayloadHashes $fixtureHashes)
    if ($snapshotFiles.Count -ne 2) {
        throw "Expected two validated snapshot files, found $($snapshotFiles.Count)."
    }
    $whatIfSnapshotRoot = Join-Path $testRoot 'whatif-snapshot'
    $whatIfSnapshotFiles = @(& {
        $WhatIfPreference = $true
        New-BetterVehicleDynamicsPayloadSnapshot -SourceRoot $validRoot -SnapshotRoot $whatIfSnapshotRoot -ExpectedPayloadHashes $fixtureHashes
    })
    if ($whatIfSnapshotFiles.Count -ne 2) {
        throw "Expected two validated WhatIf snapshot files, found $($whatIfSnapshotFiles.Count)."
    }

    $addedRoot = Join-Path $testRoot 'added'
    Copy-Item -LiteralPath $validRoot -Destination $addedRoot -Recurse
    [IO.File]::WriteAllText((Join-Path $addedRoot 'Extra.class'), 'extra')
    Assert-ThrowsLike -Pattern '*unreviewed class: Extra.class*' -Action {
        Assert-BetterVehicleDynamicsPayload -SourceRoot $addedRoot -ExpectedPayloadHashes $fixtureHashes
    }

    $removedRoot = Join-Path $testRoot 'removed'
    Copy-Item -LiteralPath $validRoot -Destination $removedRoot -Recurse
    Remove-Item -LiteralPath (Join-Path $removedRoot 'core\physics\Two.class')
    Assert-ThrowsLike -Pattern '*missing reviewed classes: core/physics/Two.class*' -Action {
        Assert-BetterVehicleDynamicsPayload -SourceRoot $removedRoot -ExpectedPayloadHashes $fixtureHashes
    }

    $changedRoot = Join-Path $testRoot 'changed'
    Copy-Item -LiteralPath $validRoot -Destination $changedRoot -Recurse
    [IO.File]::WriteAllText((Join-Path $changedRoot 'core\physics\One.class'), 'changed')
    Assert-ThrowsLike -Pattern '*Reviewed BVD class changed: core/physics/One.class*' -Action {
        Assert-BetterVehicleDynamicsPayload -SourceRoot $changedRoot -ExpectedPayloadHashes $fixtureHashes
    }

    $mutatedAfterValidationRoot = Join-Path $testRoot 'mutated-after-validation'
    Copy-Item -LiteralPath $validRoot -Destination $mutatedAfterValidationRoot -Recurse
    $rejectedSnapshotRoot = Join-Path $testRoot 'rejected-snapshot'
    Assert-ThrowsLike -Pattern '*Reviewed BVD class changed: core/physics/Two.class*' -Action {
        New-BetterVehicleDynamicsPayloadSnapshot `
            -SourceRoot $mutatedAfterValidationRoot `
            -SnapshotRoot $rejectedSnapshotRoot `
            -ExpectedPayloadHashes $fixtureHashes `
            -AfterInitialValidation {
                [IO.File]::WriteAllText((Join-Path $mutatedAfterValidationRoot 'core\physics\Two.class'), 'changed after validation')
            }
    }
    if (Test-Path -LiteralPath $rejectedSnapshotRoot) {
        throw 'Rejected BVD snapshot was not cleaned up.'
    }

    Write-Output 'Better Vehicle Dynamics payload validation passed.'
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
