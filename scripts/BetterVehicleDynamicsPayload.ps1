function Get-BetterVehicleDynamicsExpectedPayloadHashes {
    return [ordered]@{
        'core/physics/CarController$BulletVariables.class' = 'A458A6FE283B5660C9DBF7EAA76679520C3149FFB29BC5416C6AD2A33CEE4732'
        'core/physics/CarController$ClientControls.class' = 'FB46B1BF67BC410B2B19148367E30819021C9386950D9AA04943A6663F7BABB6'
        'core/physics/CarController$ControlState.class' = '86322F8324EF9320CC18E10AC0B623C9444976434099845C69A367D958D2FA9A'
        'core/physics/CarController$ConverterSpec.class' = '75F8AC8D7862B5C7461DFA43910F404C6A2B6610623ADF29EF79956F0CF61BCE'
        'core/physics/CarController$EngineSpec.class' = '910324B409DB4620A3C0B91599E7135E442A5BE3AA6A451BCFC6483187B708C9'
        'core/physics/CarController$GearboxSpec.class' = 'FEB3503F1DCE231CE187A1A0050293FD2E45CDF29D0F026CEDB84D46106F4232'
        'core/physics/CarController$GearInfo.class' = '1A1783CFE693CCD17CF87A83A75494DE9B28499DF3FEB6B5621DE6728DB2BB03'
        'core/physics/CarController$VehicleSpec.class' = '665EAA10D77B0F52E24396ED2E8E34B43ED58678E9450CCE5A2A6C5FE50854B0'
        'core/physics/CarController.class' = '883713FAB76A6E86C7E8D143DF1DA1C8FBEF9F4C0E63A3DA34C1929FC79E5A6E'
        'core/physics/WorldSimulation$s_performance.class' = '7389794DFAC8528223BE38CCC79C4B6791EBB16B400AFB9B31606C3E71F97FD5'
        'core/physics/WorldSimulation.class' = '6283670D0EA7EE9CD757D1CF71054830935D901BF4AE8447AF5E796D7CD2A3E0'
        'core/textures/Texture$TextureAssetParams.class' = '736DE5E5F43C782161B98760FCDC75A4AAF91ECE1009A72976FA6BE669C587C7'
        'core/textures/Texture.class' = 'C751B4664888113CFE6787151B9F675FA5EE98982FE818ED892593613634161D'
        'iso/IsoChunkMap.class' = 'F530E35398D8F91BE48E909D14BEF92BB524C2BEA1FA7B845A0FBF31F51484F3'
        'iso/IsoFloorBloodSplat.class' = '60F0863BAAD50AA2C17E042F542EBBF0E3DC17BC28B3BE08C5F24270D6F4338B'
        'iso/sprite/IsoSprite$AndThen.class' = '857230EA8DB264328FB68B35771428120BDDDF9649CDB3D46A3B01E4A6B14699'
        'iso/sprite/IsoSprite$l_renderCurrentAnim.class' = 'BFC384844D5E8425C3DEC1B4E3995987C2F2824C869F314B5F43D49F9D878B98'
        'iso/sprite/IsoSprite.class' = '80039527656E6009ED7FCC515ABCA6B17477E3219621D0E6A26580B08BD48B74'
    }
}

function Assert-BetterVehicleDynamicsPayload {
    param(
        [Parameter(Mandatory)] [string]$SourceRoot,
        [Parameter(Mandatory)] [Collections.IDictionary]$ExpectedPayloadHashes
    )

    $sourceFiles = @(Get-ChildItem -LiteralPath $SourceRoot -File -Recurse -Force)
    if ($sourceFiles.Count -eq 0) {
        throw 'The BVD manual-install payload contains no files.'
    }
    if (@($sourceFiles | Where-Object Extension -ne '.class').Count -gt 0) {
        throw 'The BVD manual-install payload contains an unexpected non-class file; review the Workshop update before installing it.'
    }

    $baseUri = [Uri]([IO.Path]::GetFullPath($SourceRoot).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar)
    $reviewedRelativePaths = [Collections.Generic.List[string]]::new()
    foreach ($sourceFile in $sourceFiles) {
        $pathUri = [Uri][IO.Path]::GetFullPath($sourceFile.FullName)
        $relativePath = [Uri]::UnescapeDataString($baseUri.MakeRelativeUri($pathUri).ToString())
        if (-not $ExpectedPayloadHashes.Contains($relativePath)) {
            throw "The BVD manual-install payload contains an unreviewed class: $relativePath"
        }
        $actualHash = (Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256).Hash
        if ($actualHash -ne $ExpectedPayloadHashes[$relativePath]) {
            throw "Reviewed BVD class changed: $relativePath. Expected SHA-256 $($ExpectedPayloadHashes[$relativePath]), got $actualHash."
        }
        $reviewedRelativePaths.Add($relativePath)
    }

    $missingReviewedFiles = @($ExpectedPayloadHashes.Keys | Where-Object { $_ -notin $reviewedRelativePaths })
    if ($missingReviewedFiles.Count -gt 0) {
        throw "The BVD manual-install payload is missing reviewed classes: $($missingReviewedFiles -join ', ')"
    }

    return $sourceFiles
}

function New-BetterVehicleDynamicsPayloadSnapshot {
    param(
        [Parameter(Mandatory)] [string]$SourceRoot,
        [Parameter(Mandatory)] [string]$SnapshotRoot,
        [Parameter(Mandatory)] [Collections.IDictionary]$ExpectedPayloadHashes,
        [Parameter(DontShow)] [scriptblock]$AfterInitialValidation
    )

    try {
        $null = @(Assert-BetterVehicleDynamicsPayload -SourceRoot $SourceRoot -ExpectedPayloadHashes $ExpectedPayloadHashes)
        if ($AfterInitialValidation) {
            & $AfterInitialValidation
        }
        New-Item -ItemType Directory -Path $SnapshotRoot -Force -WhatIf:$false | Out-Null
        foreach ($relativePath in $ExpectedPayloadHashes.Keys) {
            $platformRelativePath = $relativePath.Replace('/', [IO.Path]::DirectorySeparatorChar)
            $sourcePath = Join-Path $SourceRoot $platformRelativePath
            $snapshotPath = Join-Path $SnapshotRoot $platformRelativePath
            New-Item -ItemType Directory -Path (Split-Path -Parent $snapshotPath) -Force -WhatIf:$false | Out-Null
            Copy-Item -LiteralPath $sourcePath -Destination $snapshotPath -Force -WhatIf:$false
        }

        $snapshotFiles = @(Assert-BetterVehicleDynamicsPayload -SourceRoot $SnapshotRoot -ExpectedPayloadHashes $ExpectedPayloadHashes)
        $null = @(Assert-BetterVehicleDynamicsPayload -SourceRoot $SourceRoot -ExpectedPayloadHashes $ExpectedPayloadHashes)
        return $snapshotFiles
    }
    catch {
        if (Test-Path -LiteralPath $SnapshotRoot) {
            Remove-Item -LiteralPath $SnapshotRoot -Recurse -Force -WhatIf:$false
        }
        throw
    }
}
