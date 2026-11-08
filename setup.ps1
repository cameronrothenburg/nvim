param(
    [string]$ConfigDir = (Join-Path $env:LOCALAPPDATA 'nvim'),
    [switch]$SkipUpdate,
    [switch]$SkipPlugins
)
$ErrorActionPreference = 'Stop'
$repoUrl = 'https://github.com/cameronrothenburg/nvim.git'

function Invoke-Checked {
    param([string]$Program, [string[]]$Arguments)
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Program failed (exit $LASTEXITCODE)." }
}
function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
        [Environment]::GetEnvironmentVariable('Path', 'User') + ';' + $env:Path
}
function Ensure-Tool {
    param([string]$Name, [string]$Package)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
            throw "Install $Package and run this script again (winget is unavailable)."
        }
        Invoke-Checked winget.exe @('install', '--id', $Package, '--exact', '--source', 'winget', '--accept-package-agreements', '--accept-source-agreements')
        Refresh-Path
    }
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) { throw "Restart your terminal after installing $Package, then retry." }
}
function Add-UserPath {
    param([string]$Directory)
    $entries = @([Environment]::GetEnvironmentVariable('Path', 'User') -split ';' |
        Where-Object { $_ -and $_.TrimEnd('\') -ne $Directory.TrimEnd('\') })
    [Environment]::SetEnvironmentVariable('Path', (@($Directory) + $entries -join ';'), 'User')
    $env:Path = "$Directory;$env:Path"
}

Ensure-Tool git.exe Git.Git
$ConfigDir = [IO.Path]::GetFullPath($ConfigDir)
if (Test-Path -LiteralPath $ConfigDir) {
    if (-not (Test-Path -LiteralPath (Join-Path $ConfigDir '.git'))) {
        throw "Config already exists at $ConfigDir. Move it aside first; nothing was overwritten."
    }
    $origin = & git.exe -C $ConfigDir remote get-url origin
    if ($LASTEXITCODE -ne 0 -or $origin -notin @($repoUrl, $repoUrl.Replace('.git', ''), 'git@github.com:cameronrothenburg/nvim.git')) {
        throw "Existing config belongs to a different repository: $origin"
    }
    if (-not $SkipUpdate) {
        $changes = & git.exe -C $ConfigDir status --porcelain
        if ($LASTEXITCODE -ne 0) { throw 'Cannot read config status.' }
        if ($changes) { throw 'Config has local changes. Commit or stash them before updating.' }
        $branch = & git.exe -C $ConfigDir branch --show-current
        if ($branch -ne 'master') { throw 'Switch the config to master before updating.' }
        Invoke-Checked git.exe @('-C', $ConfigDir, 'pull', '--ff-only', 'origin', 'master')
    }
} else {
    New-Item -ItemType Directory -Path (Split-Path $ConfigDir) -Force | Out-Null
    Invoke-Checked git.exe @('clone', '--branch', 'master', $repoUrl, $ConfigDir)
}

Ensure-Tool node.exe OpenJS.NodeJS.LTS
$nodeMajor = [int](& node.exe -p 'process.versions.node.split(".")[0]')
if ($nodeMajor -lt 22) { throw 'Node.js 22+ is required. Upgrade Node.js LTS, then run setup again.' }
Ensure-Tool rg.exe BurntSushi.ripgrep.MSVC
Ensure-Tool fd.exe sharkdp.fd
Ensure-Tool fzf.exe junegunn.fzf
Ensure-Tool tree-sitter.exe tree-sitter.tree-sitter-cli
if (-not (Get-Command gcc.exe, clang.exe, cl.exe -ErrorAction SilentlyContinue)) {
    if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { throw 'Install a native ARM64 C compiler before running setup.' }
    Ensure-Tool gcc.exe BrechtSanders.WinLibs.POSIX.UCRT
}

Refresh-Path
$release = Invoke-RestMethod -Uri 'https://api.github.com/repos/neovim/neovim/releases/latest'
$latestVersion = $release.tag_name
if ($latestVersion -notmatch '^v\d+\.\d+\.\d+$') { throw "Invalid stable Neovim release: $latestVersion" }
Write-Host "Installing latest stable Neovim: $latestVersion"
$nvimCommand = Get-Command nvim.exe -ErrorAction SilentlyContinue
$nvimExe = if ($nvimCommand) { $nvimCommand.Source } else { Join-Path $env:ProgramFiles 'Neovim\bin\nvim.exe' }
$supported = $false
if (Test-Path -LiteralPath $nvimExe) {
    $version = (& $nvimExe --version | Select-Object -First 1)
    $supported = $version -eq "NVIM $latestVersion"
    # A machine PATH entry precedes user PATH in new terminals. Upgrade the
    # standard system install so it cannot shadow a newer per-user copy.
    $systemInstall = Join-Path $env:ProgramFiles 'Neovim\bin\nvim.exe'
    if (-not $supported -and $nvimExe -eq $systemInstall) {
        Invoke-Checked winget.exe @('install', '--id', 'Neovim.Neovim', '--exact', '--version', $latestVersion.TrimStart('v'), '--source', 'winget', '--force', '--accept-package-agreements', '--accept-source-agreements')
        $supported = ((& $nvimExe --version | Select-Object -First 1) -eq "NVIM $latestVersion")
        if (-not $supported) { throw "The system Neovim install could not be upgraded to $latestVersion." }
    }
}
if (-not $supported) {
    $archiveName = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'nvim-win-arm64' } else { 'nvim-win64' }
    $installRoot = Join-Path $env:LOCALAPPDATA "Programs\CameronNvim\$latestVersion"
    $nvimExe = Join-Path $installRoot "$archiveName\bin\nvim.exe"
    if (-not (Test-Path -LiteralPath $nvimExe)) {
        New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
        $zipPath = Join-Path $installRoot "$archiveName.zip"
        Invoke-WebRequest -Uri "https://github.com/neovim/neovim/releases/download/$latestVersion/$archiveName.zip" -OutFile $zipPath
        Expand-Archive -LiteralPath $zipPath -DestinationPath $installRoot -Force
        Remove-Item -LiteralPath $zipPath
    }
}
$nvimBin = Split-Path $nvimExe
Add-UserPath $nvimBin
Invoke-Checked npm.cmd @('ci', '--prefix', (Join-Path $ConfigDir 'tools'), '--no-fund', '--no-audit')
Add-UserPath (Join-Path $ConfigDir 'tools\node_modules\.bin')
foreach ($tool in @('nvim.exe', 'node.exe', 'npm.cmd', 'git.exe', 'curl.exe', 'tar.exe', 'rg.exe', 'fd.exe', 'fzf.exe', 'tree-sitter.exe', 'codex-acp.cmd')) {
    $resolved = Get-Command $tool -ErrorAction SilentlyContinue
    if (-not $resolved) { throw "Required command missing from PATH: $tool" }
    Add-UserPath (Split-Path $resolved.Source)
}
$compiler = Get-Command gcc.exe, clang.exe, cl.exe -ErrorAction SilentlyContinue | Select-Object -First 1
Add-UserPath (Split-Path $compiler.Source)
# Keep the chosen Neovim ahead of other user-level installations.
Add-UserPath $nvimBin
if (-not $SkipPlugins) {
    # The normal install uses stdpath(config). Custom paths are for isolated testing.
    $previousXdg = $env:XDG_CONFIG_HOME
    $previousApp = $env:NVIM_APPNAME
    try {
        $env:XDG_CONFIG_HOME = Split-Path $ConfigDir
        $env:NVIM_APPNAME = Split-Path $ConfigDir -Leaf
        Invoke-Checked $nvimExe @('--headless', '+Lazy! restore', '+qa')
    } finally {
        $env:XDG_CONFIG_HOME = $previousXdg
        $env:NVIM_APPNAME = $previousApp
    }
}
Write-Host "Ready. Config: $ConfigDir"
Write-Host 'Restart your terminal, then run nvim.'
Write-Host "Sign in once: node `"$ConfigDir\tools\node_modules\@agentclientprotocol\codex-acp\dist\index.js`" login"
Write-Host 'Space aa: discuss. Select code, Space ae: edit. README.md has the workflow.'
