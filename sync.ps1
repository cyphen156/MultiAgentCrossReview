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
    # 반환: @{ Sha = '<short-sha>'; Error = '<사유>' }
    #
    # 실패를 조용히 삼키지 않는다. commit SHA는 baseline 내용을 정의하지는 않지만
    # 출처 추적에 유용하다. 예전 구현은 빈 catch 로 실패 사유까지 버렸다.
    #
    # git 은 저장소 폴더를 소유한 Windows SID 와 실행 프로세스의 SID 가 다르면
    # dubious ownership 으로 거부한다. 이 경로는 projects.json 이 지정한 것이므로
    # 신뢰를 명시적으로 주입한다(WorkbenchStateSync 런처와 같은 방식).
    $safeRepo = $repo.Replace('\', '/')

    # PS 5.1 에서는 $ErrorActionPreference='Stop' 상태로 네이티브 stderr 를 리다이렉트하면
    # 각 줄이 ErrorRecord 로 감싸여 종료 오류가 된다. 사유를 붙잡기 위해 여기서만 완화한다.
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & git -c "safe.directory=$safeRepo" -C $repo rev-parse --short HEAD 2>&1
        $code   = $LASTEXITCODE
    }
    catch {
        return @{ Sha = ''; Error = $_.Exception.Message }
    }
    finally {
        $ErrorActionPreference = $previous
    }

    $text = (($output | ForEach-Object { $_.ToString() }) -join ' ').Trim()

    if ($code -eq 0 -and $text -match '^[0-9a-f]{7,40}$') {
        return @{ Sha = $text; Error = '' }
    }
    if (-not $text) { $text = "git rev-parse 가 종료 코드 $code 로 실패했습니다." }
    return @{ Sha = ''; Error = $text }
}

function Get-SourceWorktreeState([string] $repo) {
    $safeRepo = $repo.Replace('\', '/')
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = @(& git -c "safe.directory=$safeRepo" -C $repo status --porcelain 2>$null)
        $code = $LASTEXITCODE
    }
    catch {
        return 'unknown'
    }
    finally {
        $ErrorActionPreference = $previous
    }

    if ($code -ne 0) { return 'unknown' }
    if ($output.Count -eq 0) { return 'clean' }
    return 'dirty'
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

    # 저장소 루트 문서. Source/DevLog 어디에도 없는 현재 설계 문서가 여기 있다.
    # run-review 는 baseline 과 DevLog 밖을 읽지 못하므로, 이것이 빠지면 정식 리뷰가
    # 그 문서를 증거로 인용할 수 없다.
    $rc5 = 0
    if (Test-Path "$srcRepoRoot\Docs") {
        robocopy "$srcRepoRoot\Docs" (Join-Path $baseline 'Docs') /MIR /NFL /NDL /NJH /NP /R:1 /W:1 | Out-Null
        $rc5 = $LASTEXITCODE
    }
    if (Test-Path "$srcRepoRoot\README.md") {
        Copy-Item -LiteralPath "$srcRepoRoot\README.md" -Destination (Join-Path $baseline 'README.md') -Force
    }

    $rc4 = 0
    if (Test-Path $srcModules) {
        robocopy $srcModules $dstModules /MIR /XD ".vs" "x64" "Debug" "Release" /XF "*.vcxproj.user" /NFL /NDL /NJH /NP /R:1 /W:1 | Out-Null
        $rc4 = $LASTEXITCODE
    }

    if ($rc1 -ge 8 -or $rc2 -ge 8 -or $rc3 -ge 8 -or $rc4 -ge 8 -or $rc5 -ge 8) {
        Write-Error "[$name] 동기화 실패 (Source=$rc1 DevLog=$rc2 Resources=$rc3 Modules=$rc4 Docs=$rc5)"
        return $false
    }

    # baseline 마커: 로컬 파일 복사 시점 + 출처 보조 SHA/working-tree 상태 + Source 파일 수.
    # baseline 내용은 commit checkout 이 아니라 현재 로컬 파일에서 오므로 SHA만으로 정의되지 않는다.
    $shaInfo = Get-SourceSha $srcRepoRoot
    $sha     = if ($shaInfo.Sha) { $shaInfo.Sha } else { 'unknown' }
    $worktreeState = Get-SourceWorktreeState $srcRepoRoot
    $srcCnt  = (Get-ChildItem "$dstEngine\Source" -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
    $stamp   = Get-Date -Format 'yyyy-MM-ddTHH:mm'
    "$stamp sync | snapshot=local-worktree commit=$sha worktree=$worktreeState Source=$srcCnt" | Set-Content -Path (Join-Path $baseline '.baseline') -Encoding utf8

    # 편집 사본 시드 (없을 때만; -ResetEdit 으로 강제)
    $sClaud = Seed-Edit $baseline (Join-Path $projectsDir "$name\edit\Claud") ($ResetEdit -eq 'Claud' -or $ResetEdit -eq 'All')
    $sCodex = Seed-Edit $baseline (Join-Path $projectsDir "$name\edit\Codex") ($ResetEdit -eq 'Codex' -or $ResetEdit -eq 'All')

    if (-not $shaInfo.Sha) {
        # 파일 미러 자체는 로컬 원본에서 정상 생성됐다. SHA는 출처 보조 정보이므로
        # 읽기 실패를 숨기지는 않되 baseline 생성 실패로 취급하지 않는다.
        Write-Warning "[$name] 파일 미러는 갱신했지만 출처 커밋 SHA 를 읽지 못했습니다."
        Write-Warning "[$name]   사유: $($shaInfo.Error)"
        Write-Warning "[$name]   마커에 commit=unknown 이 기록되었습니다. baseline 내용은 사용할 수 있지만 출처 커밋은 확인할 수 없습니다."
        Write-Warning "[$name]   실행 사용자와 저장소 폴더 소유자가 다르면 git 이 dubious ownership 으로 거부합니다."
    }

    Write-Host "[$name] OK  snapshot=local-worktree  commit=$sha  worktree=$worktreeState  Source=$srcCnt  edit/Claud=$sClaud  edit/Codex=$sCodex" -ForegroundColor Green
    return $true
}

$allOk = $true
foreach ($entry in $entries) {
    if (-not (Sync-Project $entry)) { $allOk = $false }
}
if (-not $allOk) { exit 1 }
Write-Host "재동기화 완료." -ForegroundColor Green
exit 0
