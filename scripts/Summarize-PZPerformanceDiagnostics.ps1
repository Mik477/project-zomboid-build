[CmdletBinding()]
param(
    [string]$Path,
    [string]$LocalConfigurationPath,
    [ValidateRange(1, 100)] [int]$Top = 15
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
if (-not $LocalConfigurationPath) {
    $LocalConfigurationPath = Join-Path $repositoryRoot 'config\local.json'
}

if (-not $Path) {
    if (-not (Test-Path -LiteralPath $LocalConfigurationPath -PathType Leaf)) {
        throw 'Local configuration is missing. Pass -Path or run scripts/Initialize-LocalEnvironment.ps1 first.'
    }
    $localConfiguration = Get-Content -LiteralPath $LocalConfigurationPath -Raw | ConvertFrom-Json
    $logRoot = Join-Path ([string]$localConfiguration.projectZomboid.userPath) 'Logs\PZPerformanceDiagnostics'
    if (-not (Test-Path -LiteralPath $logRoot -PathType Container)) {
        throw "Diagnostics log directory does not exist: $logRoot"
    }
    $latest = Get-ChildItem -LiteralPath $logRoot -File -Filter 'perf-*.jsonl' |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1
    if (-not $latest) { throw "No diagnostics logs were found under $logRoot" }
    $Path = $latest.FullName
}

$Path = [IO.Path]::GetFullPath($Path)
if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Diagnostics log does not exist: $Path"
}

$events = [Collections.Generic.List[object]]::new()
$invalidLines = 0
foreach ($line in [IO.File]::ReadLines($Path)) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    try {
        $events.Add(($line | ConvertFrom-Json))
    }
    catch {
        $invalidLines++
    }
}
if ($events.Count -eq 0) {
    throw "Diagnostics log contains no valid JSON events: $Path"
}

$session = $events | Select-Object -First 1 -ExpandProperty session
$durationMs = ($events | Measure-Object -Property elapsedMs -Maximum).Maximum
Write-Output "PZ Performance Diagnostics summary"
Write-Output "Log: $Path"
Write-Output "Session: $session"
Write-Output ("Events: {0}; invalid lines: {1}; captured duration: {2:N1}s" -f $events.Count, $invalidLines, ([double]$durationMs / 1000.0))
Write-Output ''

$frameSpikes = @($events | Where-Object { $_.category -eq 'frame' } | ForEach-Object {
    $wall = if ($null -ne $_.wallMs) { [double]$_.wallMs } else { 0.0 }
    $interval = if ($null -ne $_.intervalMs) { [double]$_.intervalMs } else { 0.0 }
    [pscustomobject]@{
        ElapsedMs = [double]$_.elapsedMs
        Phase = [string]$_.event
        SpikeMs = [Math]::Max($wall, $interval)
        WallMs = $wall
        IntervalMs = $interval
        CpuMs = [double]$_.cpuMs
        GCms = [long]$_.gcMsDelta
        Mode = [string]$_.playerMode
        SpeedKph = [double]$_.vehicleSpeedKph
        PlayerChunk = [string]$_.playerChunk
        ChunkEvent = [string]$_.nearestChunkEvent
        Chunk = [string]$_.nearestChunk
        ChunkAgeMs = [long]$_.chunkEventAgeMs
    }
} | Sort-Object SpikeMs -Descending | Select-Object -First $Top)
Write-Output 'Worst frame/update/render spikes:'
if ($frameSpikes.Count -eq 0) { Write-Output '  None recorded above the runtime threshold.' }
else { $frameSpikes | Format-Table -AutoSize | Out-String -Width 260 | Write-Output }

$luaGroups = @($events | Where-Object { $_.category -eq 'lua' -and $_.event -eq 'slow-callback' } |
    Group-Object eventName,file,function,line |
    ForEach-Object {
        $durations = @($_.Group | ForEach-Object { [double]$_.durationMs })
        [pscustomobject]@{
            Event = [string]$_.Group[0].eventName
            File = [string]$_.Group[0].file
            Function = [string]$_.Group[0].function
            Line = [int]$_.Group[0].line
            Count = $_.Count
            TotalMs = [Math]::Round(($durations | Measure-Object -Sum).Sum, 3)
            MaxMs = [Math]::Round(($durations | Measure-Object -Maximum).Maximum, 3)
        }
    } | Sort-Object TotalMs -Descending | Select-Object -First $Top)
Write-Output 'Historical slow Lua callbacks by total captured time:'
if ($luaGroups.Count -eq 0) { Write-Output '  None recorded above the runtime threshold.' }
else { $luaGroups | Format-Table -AutoSize | Out-String -Width 300 | Write-Output }

$chunkGroups = @($events | Where-Object { $_.category -eq 'chunk' } |
    Group-Object event,chunk,source |
    ForEach-Object {
        $durations = @($_.Group | ForEach-Object { if ($null -ne $_.durationMs) { [double]$_.durationMs } else { 0.0 } })
        $errors = @($_.Group | Where-Object { $_.error -and $_.error -ne 'none' -or $_.loaded -eq $false -or $_.blam -eq $true })
        [pscustomobject]@{
            Event = [string]$_.Group[0].event
            Chunk = [string]$_.Group[0].chunk
            Source = [string]$_.Group[0].source
            Count = $_.Count
            TotalMs = [Math]::Round(($durations | Measure-Object -Sum).Sum, 3)
            MaxMs = [Math]::Round(($durations | Measure-Object -Maximum).Maximum, 3)
            Failures = $errors.Count
        }
    } | Sort-Object @{Expression='Failures';Descending=$true}, @{Expression='MaxMs';Descending=$true} | Select-Object -First $Top)
Write-Output 'Chunk streaming/integration outliers:'
if ($chunkGroups.Count -eq 0) { Write-Output '  None recorded.' }
else { $chunkGroups | Format-Table -AutoSize | Out-String -Width 240 | Write-Output }

$attemptGroups = @($events | Where-Object { $_.category -eq 'vehicle' -and $_.attempt -and $_.attempt -ne 'unmatched' } | Group-Object attempt)
Write-Output 'Vehicle-entry attempt timelines:'
if ($attemptGroups.Count -eq 0) {
    Write-Output '  None recorded.'
}
else {
    foreach ($attemptGroup in $attemptGroups | Sort-Object { ($_.Group | Measure-Object -Property elapsedMs -Maximum).Maximum } -Descending) {
        $timeline = @($attemptGroup.Group | Sort-Object elapsedMs)
        $minimum = ($timeline | Measure-Object -Property elapsedMs -Minimum).Minimum
        $maximum = ($timeline | Measure-Object -Property elapsedMs -Maximum).Maximum
        $vehicle = $timeline | Where-Object { $_.vehicleScript -and $_.vehicleScript -ne 'none' } | Select-Object -First 1
        Write-Output ("  {0}: {1:N1} ms; vehicle={2}; seat={3}; terminal={4}" -f
            $attemptGroup.Name,
            ([double]$maximum - [double]$minimum),
            [string]$vehicle.vehicleScript,
            [string]$vehicle.seat,
            [string]$timeline[-1].event)
        $timeline | Select-Object elapsedMs,attemptElapsedMs,event,action,details,bEnteringVehicle,enterAnimationFinished |
            Format-Table -AutoSize | Out-String -Width 260 | Write-Output
    }
}

$passiveVehicleEvents = @($events | Where-Object {
    $_.category -eq 'vehicle' -and (-not $_.attempt -or $_.attempt -eq 'unmatched')
} | Sort-Object elapsedMs)
Write-Output 'Passive vehicle observations:'
if ($passiveVehicleEvents.Count -eq 0) {
    Write-Output '  None recorded.'
}
else {
    $passiveVehicleEvents |
        Select-Object elapsedMs,event,vehicleScript,seat,durationMs,entered,animation,part,error |
        Format-Table -AutoSize | Out-String -Width 260 | Write-Output
}

$actionGroups = @($events | Where-Object { $_.category -eq 'action' } |
    Group-Object { if ($_.traceId) { [string]$_.traceId } elseif ($_.trace) { [string]$_.trace } else { 'unmatched' } })
Write-Output 'Action trace timelines:'
if ($actionGroups.Count -eq 0) {
    Write-Output '  None recorded.'
}
else {
    foreach ($actionGroup in $actionGroups |
            Sort-Object { ($_.Group | Measure-Object -Property elapsedMs -Maximum).Maximum } -Descending |
            Select-Object -First $Top) {
        $timeline = @($actionGroup.Group | Sort-Object elapsedMs)
        $minimum = ($timeline | Measure-Object -Property elapsedMs -Minimum).Minimum
        $maximum = ($timeline | Measure-Object -Property elapsedMs -Maximum).Maximum
        Write-Output ("  {0}: {1:N1} ms; events={2}; terminal={3}" -f
            $actionGroup.Name,
            ([double]$maximum - [double]$minimum),
            $timeline.Count,
            [string]$timeline[-1].event)
        $timeline | Select-Object elapsedMs,event,actionType,details |
            Format-Table -AutoSize | Out-String -Width 300 | Write-Output
    }
}

$markers = @($events | Where-Object { $_.category -eq 'marker' })
if ($markers.Count -gt 0) {
    Write-Output 'Manual markers:'
    $markers | Select-Object elapsedMs,label,playerMode,playerChunk,vehicleScript,vehicleSpeedKph |
        Format-Table -AutoSize | Out-String -Width 220 | Write-Output
}

$sessionEnd = $events | Where-Object { $_.category -eq 'summary' } | Select-Object -Last 1
if ($sessionEnd) {
    Write-Output 'Last rolling window:'
    $sessionEnd | Select-Object elapsedMs,update,render,updateStuff,heapUsedBytes,integrationQueue,frameSpikes,chunkOutliers,vehicleEvents,actionEvents |
        Format-List | Out-String -Width 240 | Write-Output
}
