# CyphenEngine 참고용 복사본 재동기화
# 원본 저장소(C:\Project\CyphenEngine)에서 Engine 소스/문서/리소스와
# 저장소 루트의 Modules 트리에 속한 DLL 프로젝트, 그리고 repo root의
# CyphenBuild.props(공유 빌드 설정)를 미러합니다.
# git 이력 / IDE 사용자 설정 / 빌드 산출물(BuildArtifacts)은 동기화 대상이 아닙니다.
# 사용법: PowerShell에서  .\sync.ps1 [-SourceRepoRoot <path>]

param(
    [string] $SourceRepoRoot = "C:\Project\CyphenEngine"
)

$srcRepoRoot = $SourceRepoRoot
$srcRoot     = Join-Path $srcRepoRoot "CyphenEngine"
$srcModules  = Join-Path $srcRepoRoot "Modules"
$dstRoot     = Split-Path -Parent $MyInvocation.MyCommand.Path
$dst         = Join-Path $dstRoot "CyphenEngine"
$dstModules  = Join-Path $dstRoot "Modules"

if (-not (Test-Path "$srcRoot\Source")) {
    Write-Error "원본 Source를 찾을 수 없습니다: $srcRoot\Source"
    exit 1
}

if (-not (Test-Path "$srcRoot\DevLog")) {
    Write-Error "원본 DevLog를 찾을 수 없습니다: $srcRoot\DevLog"
    exit 1
}

if (-not (Test-Path "$srcRoot\Resources")) {
    Write-Error "원본 Resources를 찾을 수 없습니다: $srcRoot\Resources"
    exit 1
}

if (-not (Test-Path "$srcRoot\CyphenEngine.vcxproj")) {
    Write-Error "원본 CyphenEngine.vcxproj를 찾을 수 없습니다: $srcRoot\CyphenEngine.vcxproj"
    exit 1
}

$moduleProjectCount = 0
if (Test-Path $srcModules) {
    $moduleProjectCount = @(
        Get-ChildItem -LiteralPath $srcModules -Filter "*.vcxproj" -File -Recurse
    ).Count
}

Write-Host "재동기화: Engine + Modules  ->  $dstRoot" -ForegroundColor Cyan

robocopy "$srcRoot\Source" "$dst\Source" /MIR /XD ".vs" "x64" "Debug" "Release" /NFL /NDL /NJH /NP /R:1 /W:1
$rcSource = $LASTEXITCODE
robocopy "$srcRoot\DevLog" "$dst\DevLog" /MIR /NFL /NDL /NJH /NP /R:1 /W:1
$rcDevLog = $LASTEXITCODE
robocopy "$srcRoot\Resources" "$dst\Resources" /MIR /NFL /NDL /NJH /NP /R:1 /W:1
$rcResources = $LASTEXITCODE

Copy-Item -LiteralPath "$srcRoot\CyphenEngine.vcxproj" -Destination "$dst\CyphenEngine.vcxproj" -Force
$rcProject = if ($?) { 0 } else { 8 }

$rcSolution = 0
if (Test-Path "$srcRoot\CyphenEngine.sln") {
    Copy-Item -LiteralPath "$srcRoot\CyphenEngine.sln" -Destination "$dst\CyphenEngine.sln" -Force
    $rcSolution = if ($?) { 0 } else { 8 }
}

# repo root의 공유 빌드 설정 (CyphenBuild.props) 미러.
# 복사본도 같은 상대구조(repo root)에 둬야 vcxproj의 ..\ 경로가 맞는다.
$rcCyphenBuildProps = 0
if (Test-Path "$srcRepoRoot\CyphenBuild.props") {
    Copy-Item -LiteralPath "$srcRepoRoot\CyphenBuild.props" -Destination "$dstRoot\CyphenBuild.props" -Force
    $rcCyphenBuildProps = if ($?) { 0 } else { 8 }
}

$rcModules = 0
if (Test-Path $srcModules) {
    robocopy $srcModules $dstModules /MIR `
        /XD ".vs" "x64" "Debug" "Release" `
        /XF "*.vcxproj.user" `
        /NFL /NDL /NJH /NP /R:1 /W:1

    $rcModules = $LASTEXITCODE
}

if ($rcSource -ge 8 -or $rcDevLog -ge 8 -or $rcResources -ge 8 -or
    $rcProject -ge 8 -or $rcSolution -ge 8 -or $rcModules -ge 8 -or
    $rcCyphenBuildProps -ge 8) {
    Write-Error "동기화 실패 (Source=$rcSource, DevLog=$rcDevLog, Resources=$rcResources, EngineProject=$rcProject, Solution=$rcSolution, Modules=$rcModules, BuildProps=$rcCyphenBuildProps)"
    exit 1
}

# baseline 마커 기록 (실제 동기화 시점). run-review.ps1 이 이 값을 기록 Baseline으로 사용.
$srcCount = (Get-ChildItem "$dst\Source" -Recurse -File | Measure-Object).Count
$logCount = (Get-ChildItem "$dst\DevLog" -Recurse -File | Measure-Object).Count
$resourceCount = (Get-ChildItem "$dst\Resources" -Recurse -File | Measure-Object).Count
$stamp = Get-Date -Format 'yyyy-MM-ddTHH:mm'

"$stamp sync | Source=$srcCount DevLog=$logCount Resources=$resourceCount EngineProject=CyphenEngine.vcxproj ModuleProjects=$moduleProjectCount" |
    Set-Content -Path "$dst\.baseline" -Encoding utf8

Write-Host "재동기화 완료 (Source=$rcSource, DevLog=$rcDevLog, Resources=$rcResources, EngineProject=$rcProject, Solution=$rcSolution, Modules=$rcModules, BuildProps=$rcCyphenBuildProps, ModuleProjects=$moduleProjectCount)" -ForegroundColor Green
Write-Host "baseline 기록: $stamp sync (Source=$srcCount, DevLog=$logCount, Resources=$resourceCount, ModuleProjects=$moduleProjectCount)" -ForegroundColor Green
exit 0
