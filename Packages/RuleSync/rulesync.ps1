#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Pull', 'Push')]
    [string] $Direction,

    [string] $VaultRoot = '',
    [string] $WorktreeRoot = '',
    [switch] $Force,
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'

$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PackageRoot)
if (-not $WorktreeRoot) { $WorktreeRoot = $RepoRoot }
if (-not $VaultRoot) { throw 'VaultRoot is required. Example: -VaultRoot C:\MultiAgentRulesVault' }

$WorktreeRoot = [IO.Path]::GetFullPath($WorktreeRoot).TrimEnd('\', '/')
$VaultRoot = [IO.Path]::GetFullPath($VaultRoot).TrimEnd('\', '/')

$SecretPatterns = @(
    @{ Name = 'GitHub token'; Regex = '(?<![A-Za-z0-9_])gh[pousr]_[A-Za-z0-9]{36}(?![A-Za-z0-9_])' },
    @{ Name = 'GitHub fine-grained token'; Regex = '(?<![A-Za-z0-9_])github_pat_[A-Za-z0-9_]{20,}(?![A-Za-z0-9_])' },
    @{ Name = 'Anthropic API key'; Regex = '(?<![A-Za-z0-9_-])sk-ant-[A-Za-z0-9_-]{20,}(?![A-Za-z0-9_-])' },
    @{ Name = 'OpenAI API key'; Regex = '(?<![A-Za-z0-9_-])sk-(?!ant-)[A-Za-z0-9_-]{20,}(?![A-Za-z0-9_-])' }
)

function Get-RelativePath([string] $Base, [string] $Path) {
    $baseUri = [Uri](([IO.Path]::GetFullPath($Base).TrimEnd('\', '/') + '\'))
    $pathUri = [Uri][IO.Path]::GetFullPath($Path)
    return [Uri]::UnescapeDataString($baseUri.MakeRelativeUri($pathUri).ToString()).Replace('/', '\')
}

function Test-BlockedPath([string] $RelativePath) {
    $norm = $RelativePath.Replace('/', '\')
    if ($norm -match '(^|\\)baseline(\\|$)') { return $true }
    if ($norm -match '(^|\\)edit(\\|$)') { return $true }
    if ($norm -match '\.(jsonl|db|sqlite|sqlite3|key|pem|pfx|env|user|log)$') { return $true }
    if ($norm -match '(^|\\)(auth\.json|config\.toml)$') { return $true }
    return $false
}

function Assert-NoSecrets([IO.FileInfo[]] $Files) {
    $findings = @()
    foreach ($file in $Files) {
        if (-not $file.Exists) { continue }
        $text = [IO.File]::ReadAllText($file.FullName)
        foreach ($pattern in $SecretPatterns) {
            if ([regex]::IsMatch($text, $pattern.Regex)) {
                $findings += [pscustomobject]@{ Type = $pattern.Name; File = $file.FullName }
            }
        }
    }
    if ($findings) {
        $findings | Sort-Object Type, File -Unique | Format-Table -AutoSize | Out-String | Write-Host
        throw 'RuleSync secret scan found token-like content. Values were not printed.'
    }
}

function Get-RuleFiles([string] $Root) {
    $files = @()
    $userSettings = Join-Path $Root 'UserSettings'
    if (Test-Path -LiteralPath $userSettings) {
        $files += Get-ChildItem -LiteralPath $userSettings -Filter '*.md' -Recurse -File
    }

    $projects = Join-Path $Root 'Projects'
    if (Test-Path -LiteralPath $projects) {
        $files += Get-ChildItem -LiteralPath $projects -Directory -ErrorAction SilentlyContinue |
            ForEach-Object {
                $rule = Join-Path $_.FullName 'RULES.md'
                if (Test-Path -LiteralPath $rule) { Get-Item -LiteralPath $rule }
            }
    }

    return @($files | Where-Object {
        $rel = Get-RelativePath $Root $_.FullName
        -not (Test-BlockedPath $rel)
    })
}

function Get-FileHashText([string] $Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Copy-RuleFile([string] $SourceRoot, [string] $DestinationRoot, [IO.FileInfo] $SourceFile) {
    $rel = Get-RelativePath $SourceRoot $SourceFile.FullName
    if (Test-BlockedPath $rel) {
        Write-Warning "Blocked path skipped: $rel"
        return
    }

    $destination = Join-Path $DestinationRoot $rel
    $destinationDir = Split-Path -Parent $destination
    $srcHash = Get-FileHashText $SourceFile.FullName
    $dstHash = Get-FileHashText $destination

    if ($dstHash -and $srcHash -ne $dstHash) {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmssfff'
        $backup = "$destination.bak-$stamp"
        Write-Warning "Divergent file: $rel"
        if (-not $DryRun) {
            New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null
            Copy-Item -LiteralPath $destination -Destination $backup -Force
        }
        Write-Warning "Backup created: $backup"
        if (-not $Force) {
            Write-Warning "Skipped without -Force: $rel"
            return
        }
    }
    elseif ($dstHash -and $srcHash -eq $dstHash) {
        Write-Host "unchanged: $rel" -ForegroundColor DarkGray
        return
    }

    if ($DryRun) {
        Write-Host "copy: $rel" -ForegroundColor Cyan
        return
    }

    New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null
    Copy-Item -LiteralPath $SourceFile.FullName -Destination $destination -Force
    Write-Host "copied: $rel" -ForegroundColor Green
}

if ($Direction -eq 'Pull') {
    $sourceRoot = $VaultRoot
    $destinationRoot = $WorktreeRoot
}
else {
    $sourceRoot = $WorktreeRoot
    $destinationRoot = $VaultRoot
}

if (-not (Test-Path -LiteralPath $sourceRoot)) {
    if ($Direction -eq 'Push') {
        if (-not $DryRun) { New-Item -ItemType Directory -Force -Path $sourceRoot | Out-Null }
    }
    else {
        throw "Source root does not exist: $sourceRoot"
    }
}
if (-not (Test-Path -LiteralPath $destinationRoot) -and -not $DryRun) {
    New-Item -ItemType Directory -Force -Path $destinationRoot | Out-Null
}

$files = @(Get-RuleFiles $sourceRoot)
if ($Direction -eq 'Push') { Assert-NoSecrets $files }

if (-not $files) {
    Write-Host "No rule files found under $sourceRoot" -ForegroundColor Yellow
    return
}

Write-Host "RuleSync $Direction" -ForegroundColor Cyan
Write-Host "  source:      $sourceRoot"
Write-Host "  destination: $destinationRoot"

foreach ($file in $files) {
    Copy-RuleFile $sourceRoot $destinationRoot $file
}

$global:LASTEXITCODE = 0

