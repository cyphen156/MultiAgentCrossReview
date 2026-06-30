# 대상 프로젝트 참고 미러 재동기화 — 매니페스트 구동.
#
# Projects/projects.json 에 등록된 각 프로젝트를 읽어:
#   - Projects/<name>/baseline      : 원본 소스/문서/리소스/프로젝트 파일 미러 (읽기전용 기준 사본)
#   - Projects/<name>/edit/Claud     : ClaudeCode 전용 편집 사본 (없을 때만 시드)
#   - Projects/<name>/edit/Codex     : Codex 전용 편집 사본 (없을 때만 시드)
# git 이력 / IDE 설정 / 빌드 산출물은 미러 대상이 아니다.
# Projects/<name>/** 는 .gitignore 로 커밋되지 않는다 (매니페스트 projects.json 만 추적).
#
# 사용법:
#   .\sync.ps1                        # 매니페스트 전체
#   .\sync.ps1 -Project CyphenEngine  # 특정 프로젝트만
#   .\sync.ps1 -ResetEdit All         # 편집 사본 강제 재시드 (Claud|Codex|All)

param(
    [string] $Project = '',
    [ValidateSet('', 'Claud', 'Codex', 'All')]
    [string] $ResetEdit = ''
)

$ErrorActionPreference = 'Stop'
$repoRoot     = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectsDir  = Join-Path $repoRoot 'Projects'
$manifestPath = Join-Path $projectsDir 'projects.json'

if (-not (Test-Path $manifestPath)) {
    Write-Error "프로젝트 매니페스트가 없습니다: $manifestPath`nProjects\projects.example.json 을 Projects\projects.json 으로 복사한 뒤 로컬 경로를 채우세요."
    exit 1
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$entries  = @($manifest.projects)
if ($Project) { $entries = @($entries | Where-Object { $_.name -eq $Project }) }
if (-not $entries -or $entries.Count -eq 0) {
    Write-Error "동기화할 프로젝트가 없습니다 (Project='$Project')."
    exit 1
}

function Get-SourceSha([string] $repo) {
    try {
        $sha = & git -C $repo rev-parse --short HEAD 2>$null
        if ($LASTEXITCODE -eq 0 -and $sha) { return $sha.Trim() }
    }
    catch { }
    return 'unknown'
}

function Seed-Edit([string] $baseline, [string] $editPath, [bool] $force) {
    if ($force -and (Test-Path $editPath)) {
        Remove-Item -LiteralPath $editPath -Recurse -Force
    }
    if (-not (Test-Path $editPath)) {
        New-Item -ItemType Directory -Path $editPath -Force | Out-Null
        robocopy $baseline $editPath /MIR /XD ".vs" "x64" "Debug" "Release" /NFL /NDL /NJH /NP /R:1 /W:1 | Out-Null
        return 'seeded'
    }
    return 'kept'
}

function Sync-Project($entry) {
    $name        = $entry.name
    $srcRepoRoot = $entry.sourceRepoRoot
    $engineSub   = if ($entry.PSObject.Properties.Name -contains 'engineSubdir' -and $entry.engineSubdir) { $entry.engineSubdir } else { $name }

    $srcEngine  = Join-Path $srcRepoRoot $engineSub
    $srcModules = Join-Path $srcRepoRoot 'Modules'

    if (-not (Test-Path "$srcEngine\Source")) {
        Write-Error "[$name] 원본 Source 없음: $srcEngine\Source"
        return $false
    }

    $baseline   = Join-Path $projectsDir "$name\baseline"
    $dstEngine  = Join-Path $baseline $engineSub
    $dstModules = Join-Path $baseline 'Modules'
    New-Item -ItemType Directory -Path $baseline -Force | Out-Null

    Write-Host "[$name] baseline <- $srcRepoRoot" -ForegroundColor Cyan

    robocopy "$srcEngine\Source"    "$dstEngine\Source"    /MIR /XD ".vs" "x64" "Debug" "Release" /NFL /NDL /NJH /NP /R:1 /W:1 | Out-Null
    $rc1 = $LASTEXITCODE
    robocopy "$srcEngine\DevLog"    "$dstEngine\DevLog"    /MIR /NFL /NDL /NJH /NP /R:1 /W:1 | Out-Null
    $rc2 = $LASTEXITCODE
    robocopy "$srcEngine\Resources" "$dstEngine\Resources" /MIR /NFL /NDL /NJH /NP /R:1 /W:1 | Out-Null
    $rc3 = $LASTEXITCODE

    foreach ($file in @("$engineSub.vcxproj", "$engineSub.sln", 'CMakeLists.txt')) {
        $srcFile = Join-Path $srcEngine $file
        if (Test-Path $srcFile) { Copy-Item -LiteralPath $srcFile -Destination (Join-Path $dstEngine $file) -Force }
    }
    if (Test-Path "$srcRepoRoot\CyphenBuild.props") {
        Copy-Item -LiteralPath "$srcRepoRoot\CyphenBuild.props" -Destination (Join-Path $baseline 'CyphenBuild.props') -Force
    }

    $rc4 = 0
    if (Test-Path $srcModules) {
        robocopy $srcModules $dstModules /MIR /XD ".vs" "x64" "Debug" "Release" /XF "*.vcxproj.user" /NFL /NDL /NJH /NP /R:1 /W:1 | Out-Null
        $rc4 = $LASTEXITCODE
    }

    if ($rc1 -ge 8 -or $rc2 -ge 8 -or $rc3 -ge 8 -or $rc4 -ge 8) {
        Write-Error "[$name] 동기화 실패 (Source=$rc1 DevLog=$rc2 Resources=$rc3 Modules=$rc4)"
        return $false
    }

    # baseline 마커: 기준 커밋 SHA + Source 파일 수 + 시점. run-review 가 Baseline 으로 인용.
    $sha    = Get-SourceSha $srcRepoRoot
    $srcCnt = (Get-ChildItem "$dstEngine\Source" -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
    $stamp  = Get-Date -Format 'yyyy-MM-ddTHH:mm'
    "$stamp sync | commit=$sha Source=$srcCnt" | Set-Content -Path (Join-Path $baseline '.baseline') -Encoding utf8

    # 편집 사본 시드 (없을 때만; -ResetEdit 으로 강제)
    $sClaud = Seed-Edit $baseline (Join-Path $projectsDir "$name\edit\Claud") ($ResetEdit -eq 'Claud' -or $ResetEdit -eq 'All')
    $sCodex = Seed-Edit $baseline (Join-Path $projectsDir "$name\edit\Codex") ($ResetEdit -eq 'Codex' -or $ResetEdit -eq 'All')

    Write-Host "[$name] OK  commit=$sha  Source=$srcCnt  edit/Claud=$sClaud  edit/Codex=$sCodex" -ForegroundColor Green
    return $true
}

$allOk = $true
foreach ($entry in $entries) {
    if (-not (Sync-Project $entry)) { $allOk = $false }
}
if (-not $allOk) { exit 1 }
Write-Host "재동기화 완료." -ForegroundColor Green
exit 0
