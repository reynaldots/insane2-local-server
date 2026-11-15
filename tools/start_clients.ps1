<#
.SYNOPSIS
    Opens extra Insane 2 copies (clients) to join your local bot server.
    Abre cópias extras do Insane 2 (clientes) para entrar no seu servidor local.

.DESCRIPTION
    Uses two hidden i2.exe options found by reverse engineering:
      -multiCopies  disables the single-instance lock (mutex)
      -dev          enables the in-game console (F11)
    Each copy starts with light settings (640x480 windowed, no sound/music,
    no MSAA, low shaders, no vsync) to reduce CPU/GPU usage.

    Automatic "connect" at startup does NOT work (the network system is not
    ready yet), so after each copy reaches the main menu, open its console (F11)
    and type:  sys.concmd("connect 127.0.0.1")

    Usa duas opções escondidas do i2.exe: -multiCopies (várias cópias) e -dev (console F11).
    O "connect" automático não funciona; em cada cópia, no menu principal, abra o console
    e digite: sys.concmd("connect 127.0.0.1")

.PARAMETER Clients
    Number of extra copies to open (7 = 8 humans with your main game).

.PARAMETER GameDir
    Insane 2 folder. Auto-detected from the Steam registry when omitted.

.PARAMETER FullSettings
    Do not force the light settings on the extra copies.

.EXAMPLE
    .\start_clients.ps1 -Clients 7

.EXAMPLE
    .\start_clients.ps1 -StopAll
#>
param(
    [int]$Clients = 0,
    [string]$GameDir,
    [int]$DelaySeconds = 5,
    [switch]$FullSettings,
    [switch]$StopAll
)

$ErrorActionPreference = 'Stop'

#region Caminhos

$pidFile = Join-Path $PSScriptRoot 'instances.pid'

function Find-GameDir {
    # Procura a pasta do jogo nas bibliotecas da Steam
    $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    if (-not $steam) { return $null }

    $libs = @(Join-Path $steam 'steamapps')
    $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
    if (Test-Path $vdf) {
        # Lê as bibliotecas extras ("path" "D:\\SteamLibrary")
        Select-String -Path $vdf -Pattern '"path"\s+"([^"]+)"' | ForEach-Object {
            $libs += ($_.Matches[0].Groups[1].Value -replace '\\\\', '\') + '\steamapps'
        }
    }
    foreach ($lib in $libs) {
        $dir = "$lib\common\Insane2"
        if (Test-Path "$dir\i2.exe") { return $dir }
    }
    return $null
}

#endregion

#region Encerrar cópias

if ($StopAll) {
    if (Test-Path $pidFile) {
        # Fecha só os processos abertos por este script
        Get-Content $pidFile | ForEach-Object {
            Stop-Process -Id ([int]$_) -ErrorAction SilentlyContinue
        }
        Remove-Item $pidFile
    }
    Write-Host 'Extra copies closed. / Cópias extras encerradas.'
    return
}

#endregion

#region Pré-requisitos

if ($Clients -le 0) {
    Get-Help $MyInvocation.MyCommand.Path -Detailed
    return
}

if (-not $GameDir) { $GameDir = Find-GameDir }
if (-not $GameDir -or -not (Test-Path (Join-Path $GameDir 'i2.exe'))) {
    throw 'Insane 2 folder not found. Use -GameDir "<path to Insane2>".'
}
$exe = Join-Path $GameDir 'i2.exe'

# Sem este arquivo, abrir o i2.exe direto faz a Steam reiniciar o jogo pelo cliente
# (e a Steam bloqueia uma segunda cópia). A Steam continua precisando estar aberta.
$appIdFile = Join-Path $GameDir 'steam_appid.txt'
if (-not (Test-Path $appIdFile)) {
    Set-Content -Path $appIdFile -Value '35320' -NoNewline -Encoding ASCII
    Write-Host 'Created steam_appid.txt (35320).'
}

#endregion

#region Abrir cópias

# Configurações leves para as cópias extras (gravadas no user_config.cfg compartilhado:
# feche as cópias extras ANTES da janela principal para não perder suas configurações)
$light = @(
    'resolution 640 480 0',
    'set s_soundEnable 0',
    'set s_musicEnable 0',
    'set r_msaa 0',
    'set r_shadersQuality 0',
    'set r_vsync 0'
) -join '; '

for ($i = 1; $i -le $Clients; $i++) {
    # -multiCopies libera várias cópias; -dev habilita o console
    $argLine = '-multiCopies -dev'
    if (-not $FullSettings) { $argLine += " -concmd `"$light`"" }

    $proc = Start-Process -FilePath $exe -ArgumentList $argLine -WorkingDirectory $GameDir -PassThru
    Add-Content -Path $pidFile -Value $proc.Id
    Write-Host "[client $i] PID $($proc.Id)"
    Start-Sleep -Seconds $DelaySeconds
}

Write-Host ''
Write-Host 'In EACH extra copy, at the main menu, press F11 and type:'
Write-Host '  sys.concmd("connect 127.0.0.1")'
Write-Host 'Then mark yourself as ready in the lobby.'
Write-Host ''
Write-Host 'Close all extra copies: .\start_clients.ps1 -StopAll'

#endregion
