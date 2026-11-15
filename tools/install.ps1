<#
.SYNOPSIS
    Copies the .cfg files of this repository into the Insane 2 "data" folder.
    Copia os arquivos .cfg deste repositório para a pasta "data" do Insane 2.

.DESCRIPTION
    Never overwrites the game's own config.cfg. Existing files with the same
    name are backed up as <name>.bak before being replaced.

.PARAMETER GameDir
    Insane 2 folder. Auto-detected from the Steam registry when omitted.

.PARAMETER Uninstall
    Removes the files installed by this script (restoring .bak backups).

.EXAMPLE
    .\install.ps1

.EXAMPLE
    .\install.ps1 -GameDir "E:\SteamLibrary\steamapps\common\Insane2"
#>
param(
    [string]$GameDir,
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

#region Localizar o jogo

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

if (-not $GameDir) { $GameDir = Find-GameDir }
if (-not $GameDir -or -not (Test-Path (Join-Path $GameDir 'i2.exe'))) {
    throw 'Insane 2 folder not found. Use -GameDir "<path to Insane2>".'
}

$srcData = Join-Path (Split-Path -Parent $PSScriptRoot) 'data'
$dstData = Join-Path $GameDir 'data'
$files = Get-ChildItem $srcData -Filter *.cfg

#endregion

#region Desinstalar

if ($Uninstall) {
    foreach ($f in $files) {
        $dst = Join-Path $dstData $f.Name
        # Remove o arquivo instalado e restaura o backup, se existir
        if (Test-Path $dst) { Remove-Item $dst }
        if (Test-Path "$dst.bak") { Move-Item "$dst.bak" $dst }
        Write-Host "removed  $($f.Name)"
    }
    return
}

#endregion

#region Instalar

foreach ($f in $files) {
    # Nunca sobrescreve o config.cfg original do jogo
    if ($f.Name -ieq 'config.cfg') { continue }

    $dst = Join-Path $dstData $f.Name
    # Faz backup se já existir um arquivo diferente com o mesmo nome
    if ((Test-Path $dst) -and -not (Test-Path "$dst.bak")) {
        if ((Get-FileHash $dst).Hash -ne (Get-FileHash $f.FullName).Hash) {
            Copy-Item $dst "$dst.bak"
        }
    }
    Copy-Item $f.FullName $dst -Force
    Write-Host "installed $($f.Name) -> $dstData"
}

Write-Host ''
Write-Host 'Next: Steam > Insane 2 > Properties > Launch Options: -dev'
Write-Host 'Then press F11 in the game to open the console.'

#endregion
