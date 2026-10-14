# INARI_LOST_SHRINE — Quick join handler for Quake III Arena / Quake III Team Arena (Windows).
#
# Links on the site look like:
#   q3join://ioquake3/q3a/quake3a.inari-lost-shrine.net:18485     ioquake3, Q3 Arena
#   q3join://ioquake3/q3ta/quake3ta.inari-lost-shrine.net:7093    ioquake3, Team Arena
#   q3join://steam/q3a/quake3a.inari-lost-shrine.net:18485        Steam copy (app 2200), Q3 Arena
#   q3join://steam/q3ta/quake3ta.inari-lost-shrine.net:7093       Steam copy (app 2200), Team Arena
#
# The client part picks the game binary, so vanilla (Steam) and ioquake3 are two
# separate buttons rather than one link that guesses. "q3join://<game>/<addr>"
# without a client is still accepted: ioquake3 if installed, Steam otherwise.
#
# Team Arena always gets "+set fs_game missionpack" first.
#
# Usage (no administrator rights needed — it only writes HKCU):
#   powershell -ExecutionPolicy Bypass -File .\quickjoin.ps1 -Install
#   powershell -ExecutionPolicy Bypass -File .\quickjoin.ps1 -Uninstall

param(
    [Parameter(Position = 0)][string]$Url,
    [switch]$Install,
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
$Scheme   = 'q3join'
$Clients  = @('ioquake3', 'steam')
$Games    = @('q3a', 'q3ta')
$SteamApp = '2200'
$Site     = 'https://www.inari-lost-shrine.net/gameserver'

function Get-GameExe {
    foreach ($name in @('ioquake3.exe', 'ioq3.exe', 'quake3.exe')) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cmd) { return $cmd.Source }
    }
    return $null
}

function Get-SteamExe {
    $cmd = Get-Command steam.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Source }
    foreach ($key in @('HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam')) {
        try {
            $path = (Get-ItemProperty -Path $key -ErrorAction Stop).SteamExe
            if ($path -and (Test-Path $path)) { return $path }
        }
        catch { }
    }
    return $null
}

function Start-GameClient([string[]]$gameArgs) {
    $exe = Get-GameExe
    if (-not $exe) {
        throw "ioquake3 was not found. Install ioquake3, or use the Steam quick join button instead ($Site)"
    }
    Start-Process -FilePath $exe -ArgumentList $gameArgs
}

function Start-SteamClient([string[]]$gameArgs) {
    $steam = Get-SteamExe
    if (-not $steam) {
        throw "Steam was not found. Install Steam, or use the ioquake3 quick join button instead ($Site)"
    }
    Start-Process -FilePath $steam -ArgumentList (@('-applaunch', $SteamApp) + $gameArgs)
}

function Invoke-Join([string]$link) {
    $rest = $link -replace "^${Scheme}:", '' -replace '^//', ''
    $parts = @($rest.Split('/'))

    if ($Clients -contains $parts[0]) {
        if ($parts.Count -ne 3) { throw "Malformed link: $link" }
        $client = $parts[0]
        $game = $parts[1]
        $addr = $parts[2]
    }
    else {
        if ($parts.Count -ne 2) { throw "Malformed link: $link" }
        $client = 'auto'
        $game = $parts[0]
        $addr = $parts[1]
    }

    if ($Games -notcontains $game) { throw "Unknown game in link: $game" }
    if ($addr -notmatch '^[A-Za-z0-9.\-:\[\]]+$') { throw "Malformed address in link: $addr" }
    if ($addr -notmatch ':') { throw "Missing port in link: $addr" }

    $gameArgs = @()
    if ($game -eq 'q3ta') { $gameArgs += @('+set', 'fs_game', 'missionpack') }
    $gameArgs += @('+connect', $addr)

    switch ($client) {
        'ioquake3' { Start-GameClient $gameArgs }
        'steam' { Start-SteamClient $gameArgs }
        default {
            if (Get-GameExe) { Start-GameClient $gameArgs } else { Start-SteamClient $gameArgs }
        }
    }
}

function Install-Handler {
    $script = (Resolve-Path $PSCommandPath).Path
    $base = "HKCU:\Software\Classes\$Scheme"
    New-Item -Path $base -Force | Out-Null
    Set-ItemProperty -Path $base -Name '(Default)' -Value "URL:Quick join protocol"
    New-ItemProperty -Path $base -Name 'URL Protocol' -Value '' -PropertyType String -Force | Out-Null
    $commandKey = Join-Path $base 'shell\open\command'
    New-Item -Path $commandKey -Force | Out-Null
    $command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`" `"%1`""
    Set-ItemProperty -Path $commandKey -Name '(Default)' -Value $command
    Write-Host "quickjoin: installed"
    Write-Host "  command:  $command"
    $exe = Get-GameExe
    if ($exe) { Write-Host "  ioquake3: $exe" }
    else { Write-Host "  ioquake3: not found - the ioquake3 buttons will tell you, the Steam buttons still work" }
    $steam = Get-SteamExe
    if ($steam) { Write-Host "  steam:    $steam" }
    else { Write-Host "  steam:    not found - the Steam buttons will tell you" }
}

function Uninstall-Handler {
    Remove-Item -Path "HKCU:\Software\Classes\$Scheme" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "quickjoin: uninstalled"
}

if ($Install) {
    Install-Handler
}
elseif ($Uninstall) {
    Uninstall-Handler
}
elseif ($Url) {
    try {
        Invoke-Join $Url
    }
    catch {
        try {
            Add-Type -AssemblyName PresentationFramework
            [System.Windows.MessageBox]::Show($_.Exception.Message, 'Quick join') | Out-Null
        }
        catch {
            Write-Error $_
        }
        exit 1
    }
}
else {
    Write-Host "usage: powershell -ExecutionPolicy Bypass -File $($MyInvocation.MyCommand.Name) -Install"
    exit 1
}
