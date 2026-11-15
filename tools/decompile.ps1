<#
.SYNOPSIS
    (Optional) Extracts the Lua scripts from the game's .pak files and decompiles them.
    (Opcional) Extrai os scripts Lua dos .pak do jogo e descompila.

.DESCRIPTION
    Only needed if you want to study how the game works. Requires:
      - Python 3 (py or python in PATH)
      - Java 8+ (for unluac)
    Output goes to tools\extracted and tools\decompiled (ignored by git:
    those files belong to Targem Games and must not be redistributed).

.EXAMPLE
    .\decompile.ps1

.EXAMPLE
    .\decompile.ps1 -Filter achievements
#>
param(
    [string]$GameDir,
    [string]$Filter = '.lua',
    [string]$UnluacUrl = 'https://sourceforge.net/projects/unluac/files/Unstable/unluac_2023_12_24.jar/download'
)

$ErrorActionPreference = 'Stop'

#region Pré-requisitos

function Find-GameDir {
    # Procura a pasta do jogo nas bibliotecas da Steam
    $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    if (-not $steam) { return $null }

    $libs = @(Join-Path $steam 'steamapps')
    $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
    if (Test-Path $vdf) {
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
if (-not $GameDir) { throw 'Insane 2 folder not found. Use -GameDir "<path to Insane2>".' }

# Python: prefere o launcher "py", senão "python"
$py = Get-Command py -ErrorAction SilentlyContinue
if (-not $py) { $py = Get-Command python -ErrorAction SilentlyContinue }
if (-not $py) { throw 'Python 3 not found.' }
if (-not (Get-Command java -ErrorAction SilentlyContinue)) { throw 'Java not found (needed by unluac).' }

$extracted = Join-Path $PSScriptRoot 'extracted'
$decompiled = Join-Path $PSScriptRoot 'decompiled'
$unluac = Join-Path $PSScriptRoot 'unluac.jar'

# Baixa o unluac só se ainda não existir
if (-not (Test-Path $unluac)) {
    Write-Host 'Downloading unluac...'
    Invoke-WebRequest -Uri $UnluacUrl -OutFile $unluac -UserAgent 'Wget' -MaximumRedirection 10
}

#endregion

#region Extrair

# Extrai os arquivos que batem com o filtro de todos os .pak
Get-ChildItem (Join-Path $GameDir 'data') -Filter *.pak | ForEach-Object {
    & $py.Source (Join-Path $PSScriptRoot 'tpak_extract.py') $_.FullName $extracted --filter $Filter | Out-Null
}

#endregion

#region Descompilar

# Descompila cada .lua (bytecode Lua 5.1) mantendo a estrutura de pastas
$root = (Resolve-Path $extracted).Path
Get-ChildItem $extracted -Recurse -Filter *.lua | ForEach-Object {
    $rel = $_.FullName.Substring($root.Length + 1)
    $dst = Join-Path $decompiled $rel
    New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
    java -jar $unluac $_.FullName 2>$null | Set-Content -Encoding UTF8 $dst
}

Write-Host "Done: $decompiled"

#endregion
