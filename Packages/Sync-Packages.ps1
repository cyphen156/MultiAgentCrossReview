#requires -Version 5.1
<#
  Sync-Packages.ps1 - 이 워크벤치의 Packages/ 를 다른 로컬 워크벤치로 전파한다.

  왜 필요한가
  -----------
  예전에는 새 워크벤치를 만들 때 이 워크벤치의 Packages/ 를 Copy-Item 으로 한 번
  복사했다. 그것은 복사 시점의 스냅샷일 뿐 이후 연결이 없어서, 원본이 고쳐져도
  사본은 그대로 남았다. 그래서 같은 도구가 워크벤치마다, 나아가 같은 워크벤치의
  머신 두 대 사이에서도 서로 다른 버전으로 갈라졌다.

  이 스크립트는 그 일회성 복사를 반복 가능한 갱신으로 바꾼다. 이 워크벤치의
  Packages/ 가 SSOT 이고, 대상 워크벤치는 언제든 다시 받을 수 있다.

  무엇을 보내는가
  ---------------
  Packages/packages.manifest.json  : 각 패키지의 구성과 '덮지 말 것' 목록 (공개, 추적됨)
  UserSettings/package-targets.json : 어디로 보낼지 (머신 로컬, gitignore)

  머신 로컬 설정 파일(keepLocal)은 절대 덮지 않는다. 대상 워크벤치의 VaultRoot 나
  SourceRoot 설정을 이 스크립트가 날려버리면 안 된다.

  사용법:
    .\Packages\Sync-Packages.ps1 -List
    .\Packages\Sync-Packages.ps1 -DryRun
    .\Packages\Sync-Packages.ps1
    .\Packages\Sync-Packages.ps1 -Target 'C:\Project\SomeWorkbench'
#>
[CmdletBinding()]
param(
    [string] $Target = '',
    [switch] $DryRun,
    [switch] $List
)

$ErrorActionPreference = 'Stop'

$PackagesRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot     = Split-Path -Parent $PackagesRoot
$ManifestPath = Join-Path $PackagesRoot 'packages.manifest.json'
$TargetsPath  = Join-Path $RepoRoot 'UserSettings\package-targets.json'

if (-not (Test-Path -LiteralPath $ManifestPath)) {
    throw "패키지 매니페스트가 없습니다: $ManifestPath"
}
$manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($null -eq $manifest.version -or [int] $manifest.version -ne 1) {
    throw "지원하지 않는 packages.manifest.json version: '$($manifest.version)' (지원: 1)"
}

function Get-Targets {
    # -Target 은 "이 대상만 처리한다"는 필터이지, "전부 보낸다"는 뜻이 아니다.
    # 예전에는 명시 대상에 매니페스트의 모든 패키지와 루트 파일을 보냈는데,
    # 그러면 그 워크벤치가 의도적으로 받지 않기로 한 것까지 밀어 넣게 된다.
    # 실제로 그렇게 해서 계약이 다른 동명 스크립트를 덮어쓴 적이 있다.
    # 무엇을 받을지는 언제나 package-targets.json 이 정한다.
    if (-not (Test-Path -LiteralPath $TargetsPath)) {
        throw @"
전파 대상이 없습니다: $TargetsPath

UserSettings/package-targets.json 을 만드세요. 예:
{
  "version": 1,
  "targets": [
    { "root": "C:\\Project\\SomeWorkbench", "packages": ["AgentSessionSync", "WorkbenchStateSync"] }
  ]
}
"@
    }

    $doc = Get-Content -LiteralPath $TargetsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -eq $doc.version -or [int] $doc.version -ne 1) {
        throw "지원하지 않는 package-targets.json version: '$($doc.version)' (지원: 1)"
    }
    $targets = @($doc.targets)
    if (-not $Target) { return $targets }

    $wanted = [IO.Path]::GetFullPath($Target).TrimEnd('\', '/')
    $match = @($targets | Where-Object {
        [IO.Path]::GetFullPath([string] $_.root).TrimEnd('\', '/') -ieq $wanted
    })
    if ($match.Count -eq 0) {
        throw "package-targets.json 에 등록되지 않은 대상입니다: $wanted`n먼저 $TargetsPath 에 받을 항목과 함께 등록하세요."
    }
    return $match
}

function Copy-Package([string] $packageName, [string] $targetRoot, [string[]] $keepLocal) {
    $source = Join-Path $PackagesRoot $packageName
    if (-not (Test-Path -LiteralPath $source -PathType Container)) {
        throw "패키지가 이 워크벤치에 없습니다: $packageName ($source)"
    }

    $destination = Join-Path (Join-Path $targetRoot 'Packages') $packageName
    $sourceFiles = Get-ChildItem -LiteralPath $source -Recurse -File

    foreach ($file in $sourceFiles) {
        $rel = $file.FullName.Substring($source.Length).TrimStart('\')

        # 머신 로컬 설정은 대상 워크벤치의 것이다. 존재하면 건드리지 않는다.
        if ($keepLocal -contains $rel) {
            $existing = Join-Path $destination $rel
            if (Test-Path -LiteralPath $existing) {
                Write-Host "    keep-local: $packageName\$rel" -ForegroundColor DarkGray
                continue
            }
        }

        $target = Join-Path $destination $rel
        $same = $false
        if (Test-Path -LiteralPath $target) {
            $same = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash -eq
                    (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
        }

        if ($same) {
            Write-Host "    unchanged:  $packageName\$rel" -ForegroundColor DarkGray
            continue
        }

        if ($DryRun) {
            Write-Host "    would copy: $packageName\$rel" -ForegroundColor Cyan
            continue
        }

        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $target -Force
        Write-Host "    copied:     $packageName\$rel" -ForegroundColor Green
    }
}

function Copy-SharedFile([string] $fileName, [string] $targetRoot, [string] $sourceDir, [string] $targetDir) {
    $source = Join-Path $sourceDir $fileName
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "공용 파일이 이 워크벤치에 없습니다: $fileName ($source)"
    }
    $target = Join-Path $targetDir $fileName

    if (Test-Path -LiteralPath $target) {
        $same = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -eq
                (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
        if ($same) { Write-Host "    unchanged:  $fileName" -ForegroundColor DarkGray; return }
    }

    if ($DryRun) { Write-Host "    would copy: $fileName" -ForegroundColor Cyan; return }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    Copy-Item -LiteralPath $source -Destination $target -Force
    Write-Host "    copied:     $fileName" -ForegroundColor Green
}

if ($List) {
    Write-Host 'Sync-Packages - source of truth' -ForegroundColor Cyan
    Write-Host "  workbench: $RepoRoot"
    Write-Host '  packages:'
    foreach ($property in $manifest.packages.PSObject.Properties) {
        Write-Host ("    {0,-20} {1}" -f $property.Name, $property.Value.description)
    }
    Write-Host '  shared files:'
    foreach ($shared in @($manifest.sharedFiles)) { Write-Host "    $shared" }
    Write-Host '  root files:'
    foreach ($property in $manifest.rootFiles.PSObject.Properties) {
        Write-Host ("    {0,-20} {1}" -f $property.Name, $property.Value)
    }
    Write-Host '  targets:'
    if (Test-Path -LiteralPath $TargetsPath) {
        foreach ($entry in (Get-Targets)) {
            $rootList = if (@($entry.rootFiles).Count -gt 0) { ' + root: ' + (@($entry.rootFiles) -join ', ') } else { '' }
            Write-Host ("    {0}  [{1}]{2}" -f $entry.root, (@($entry.packages) -join ', '), $rootList)
        }
    }
    else {
        Write-Host "    (none - $TargetsPath 없음)" -ForegroundColor Yellow
    }
    exit 0
}

$targets = @(Get-Targets)
if ($targets.Count -eq 0) { throw '전파 대상이 비어 있습니다.' }

$repoFull = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')

Write-Host 'Sync-Packages' -ForegroundColor Cyan
Write-Host "  source: $repoFull\Packages"
if ($DryRun) { Write-Host '  mode:   dry-run (아무것도 쓰지 않음)' -ForegroundColor DarkGray }

foreach ($entry in $targets) {
    $root = [IO.Path]::GetFullPath([string] $entry.root).TrimEnd('\', '/')

    # 자기 자신을 대상으로 삼으면 원본을 원본 위에 덮게 된다. 무해해 보이지만
    # keepLocal 판정이 뒤집혀 로컬 설정을 잃을 수 있다.
    if ($root -eq $repoFull) {
        throw "전파 대상이 이 워크벤치 자신입니다: $root"
    }
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        Write-Warning "대상 워크벤치가 없습니다, 건너뜁니다: $root"
        continue
    }

    Write-Host "  target: $root" -ForegroundColor Cyan

    foreach ($packageName in @($entry.packages)) {
        $definition = $manifest.packages.PSObject.Properties[$packageName]
        if (-not $definition) {
            throw "매니페스트에 없는 패키지를 대상이 요구합니다: '$packageName' ($root)"
        }
        Copy-Package $packageName $root @($definition.Value.keepLocal)
    }

    $sharedFiles = if ($null -ne $entry.files) { @($entry.files) } else { @($manifest.sharedFiles) }
    foreach ($shared in $sharedFiles) {
        Copy-SharedFile $shared $root $PackagesRoot (Join-Path $root 'Packages')
    }

    # 워크벤치 루트에 놓이는 공용 스크립트. 패키지 계층을 쓰지 않는 워크벤치도
    # 미러 스크립트만은 포크하지 않고 이 워크벤치에서 받아 가게 한다.
    foreach ($rootFile in @($entry.rootFiles)) {
        if (-not $rootFile) { continue }
        if (-not $manifest.rootFiles.PSObject.Properties[$rootFile]) {
            throw "매니페스트에 없는 루트 파일을 대상이 요구합니다: '$rootFile' ($root)"
        }
        Copy-SharedFile $rootFile $root $RepoRoot $root
    }
}

Write-Host 'Sync-Packages complete.' -ForegroundColor Green
