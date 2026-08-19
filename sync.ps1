# 대상 프로젝트 참고 미러 재동기화 — 매니페스트 + 프로젝트별 미러 스펙 구동.
#
# Projects/projects.json 에 등록된 각 프로젝트를 읽어:
#   - Projects/<name>/baseline      : 원본 미러 (읽기전용 기준 사본)
#   - Projects/<name>/edit/Claud     : ClaudeCode 전용 편집 사본 (없을 때만 시드)
#   - Projects/<name>/edit/Codex     : Codex 전용 편집 사본 (없을 때만 시드)
# Projects/<name>/** 는 .gitignore 로 커밋되지 않는다 (매니페스트 projects.json 만 추적).
#
# "무엇을 미러할 것인가"는 이 스크립트가 아니라 프로젝트별 데이터에 있다:
#   - Projects/<name>/mirror.json    : 미러 스펙. 형식은 Common/MIRROR_SPEC.md
#   - 없으면 내장 기본 프리셋(cpp-vs)을 쓴다. 예전 하드코딩 동작과 동일하다.
# projects.json 은 머신 로컬 경로 등록부이므로 스펙을 담지 않는다. 스펙은
# WorkbenchStateSync 가 RULES.md 와 함께 운반하므로 머신 사이에서 일치한다.
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

function Seed-Edit([string] $baseline, [string] $editRoot, [string] $agent, [bool] $force) {
    # 편집 슬롯은 반드시 edit 루트 아래여야 한다. $agent 는 코드 상수지만, 경로 결합
    # 결과를 확인하지 않으면 이 함수는 -Recurse -Force 삭제를 임의 경로에 수행할 수 있다.
    # 삭제 직전에 경계를 확인한다.
    $editRootFull = [IO.Path]::GetFullPath($editRoot).TrimEnd('\', '/')
    $editPath     = [IO.Path]::GetFullPath((Join-Path $editRootFull $agent))
    if (-not $editPath.StartsWith($editRootFull + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "편집 사본 경로가 edit 루트를 벗어났습니다: $editPath"
    }

    if ($force -and (Test-Path -LiteralPath $editPath)) {
        Remove-Item -LiteralPath $editPath -Recurse -Force
    }
    if (-not (Test-Path -LiteralPath $editPath)) {
        New-Item -ItemType Directory -Path $editPath -Force | Out-Null
        robocopy $baseline $editPath /MIR /NFL /NDL /NJH /NP /R:1 /W:1 | Out-Null
        if ($LASTEXITCODE -ge 8) {
            throw "편집 사본 시드 실패: $baseline -> $editPath (robocopy=$LASTEXITCODE)"
        }
        return 'seeded'
    }
    return 'kept'
}

# ===== 미러 스펙 =====

function Get-DefaultMirrorSpec {
    # 내장 기본 프리셋 'cpp-vs'. mirror.json 이 없을 때 쓰이며, 스펙 도입 이전의
    # 하드코딩 동작과 동일하다. 형식 문서는 Common/MIRROR_SPEC.md.
    return [pscustomobject]@{
        version         = 1
        description     = 'built-in default: C++ / Visual Studio engine repository'
        sourceCountPath = '${engineSubdir}/Source'
        items           = @(
            [pscustomobject]@{ kind = 'tree'; from = '${engineSubdir}/Source'; required = $true; excludeDirs = @('.vs', 'x64', 'Debug', 'Release') },
            [pscustomobject]@{ kind = 'tree'; from = '${engineSubdir}/DevLog' },
            [pscustomobject]@{ kind = 'tree'; from = '${engineSubdir}/Resources' },
            [pscustomobject]@{ kind = 'file'; from = '${engineSubdir}/${engineSubdir}.vcxproj' },
            [pscustomobject]@{ kind = 'file'; from = '${engineSubdir}/${engineSubdir}.sln' },
            [pscustomobject]@{ kind = 'file'; from = '${engineSubdir}/CMakeLists.txt' },
            [pscustomobject]@{ kind = 'file'; from = 'CyphenBuild.props' },
            [pscustomobject]@{ kind = 'tree'; from = 'Docs' },
            [pscustomobject]@{ kind = 'file'; from = 'README.md' },
            [pscustomobject]@{ kind = 'tree'; from = 'Modules'; excludeDirs = @('.vs', 'x64', 'Debug', 'Release'); excludeFiles = @('*.vcxproj.user') }
        )
    }
}

function Get-MirrorSpec([string] $specPath, [string] $name) {
    if (-not (Test-Path -LiteralPath $specPath)) {
        Write-Host "[$name] mirror.json 없음 - 내장 기본 프리셋(cpp-vs) 사용" -ForegroundColor DarkGray
        return Get-DefaultMirrorSpec
    }

    try {
        $spec = Get-Content -LiteralPath $specPath -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        throw "[$name] mirror.json 을 읽지 못했습니다: $specPath`n  $($_.Exception.Message)"
    }

    # 스펙이 깨졌을 때 조용히 기본값으로 되돌아가면, 선언한 범위와 실제 baseline 이
    # 어긋난 채로 리뷰가 진행된다. 알 수 없는 스펙은 실패시킨다.
    if ($null -eq $spec.version -or [int] $spec.version -ne 1) {
        throw "[$name] 지원하지 않는 mirror.json version 입니다: '$($spec.version)' (지원: 1)"
    }
    $items = @($spec.items)
    if ($items.Count -eq 0) {
        throw "[$name] mirror.json 의 items 가 비어 있습니다: $specPath"
    }
    return $spec
}

function Expand-SpecPath([string] $path, [string] $name, [string] $engineSub) {
    if (-not $path) { return '' }
    return $path.Replace('${engineSubdir}', $engineSub).Replace('${name}', $name).Replace('/', '\')
}

function Resolve-UnderRoot([string] $root, [string] $relative, [string] $label) {
    # '.' 를 루트 자신으로 허용하되, '..' 로 루트 밖을 가리키는 경로는 거부한다.
    $rootFull = [IO.Path]::GetFullPath($root).TrimEnd('\', '/')
    $full     = [IO.Path]::GetFullPath((Join-Path $rootFull $relative)).TrimEnd('\', '/')
    if ($full -ne $rootFull -and -not $full.StartsWith($rootFull + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "$label 경로가 루트를 벗어났습니다: '$relative' -> $full (루트: $rootFull)"
    }
    return $full
}

function Sync-Project($entry) {
    $name        = $entry.name
    $srcRepoRoot = $entry.sourceRepoRoot
    $engineSub   = if ($entry.PSObject.Properties.Name -contains 'engineSubdir' -and $entry.engineSubdir) { $entry.engineSubdir } else { $name }

    $baseline = Join-Path $projectsDir "$name\baseline"
    $specPath = Join-Path $projectsDir "$name\mirror.json"
    $spec     = Get-MirrorSpec $specPath $name

    if (-not (Test-Path -LiteralPath $srcRepoRoot -PathType Container)) {
        Write-Error "[$name] 원본 저장소 루트가 없습니다: $srcRepoRoot"
        return $false
    }

    # 필수 항목은 미러 이전에 전부 검증한다. 절반만 복사된 baseline 을 남기지 않는다.
    $items = @($spec.items)
    foreach ($item in $items) {
        # kind 'require' 는 존재 검증 전용이므로 required 를 따로 적지 않아도 필수다.
        if (-not $item.required -and $item.kind -ne 'require') { continue }
        $rel = Expand-SpecPath $item.from $name $engineSub
        $src = Resolve-UnderRoot $srcRepoRoot $rel "[$name] 원본"
        if (-not (Test-Path -LiteralPath $src)) {
            Write-Error "[$name] 필수 미러 항목이 원본에 없습니다: $rel ($src)"
            return $false
        }
    }

    New-Item -ItemType Directory -Path $baseline -Force | Out-Null
    Write-Host "[$name] baseline <- $srcRepoRoot" -ForegroundColor Cyan

    $failures = @()
    $copied   = 0
    $skipped  = 0

    foreach ($item in $items) {
        $fromRel = Expand-SpecPath $item.from $name $engineSub
        $toRel   = if ($item.to) { Expand-SpecPath $item.to $name $engineSub } else { $fromRel }
        $src     = Resolve-UnderRoot $srcRepoRoot $fromRel "[$name] 원본"
        $dst     = Resolve-UnderRoot $baseline     $toRel   "[$name] baseline"

        # 'require' 는 복사하지 않고 존재만 검증한다. 위 사전 검증에서 이미 확인했다.
        if ($item.kind -eq 'require') { continue }

        if (-not (Test-Path -LiteralPath $src)) { $skipped++; continue }

        if ($item.kind -eq 'file') {
            New-Item -ItemType Directory -Path (Split-Path -Parent $dst) -Force | Out-Null
            Copy-Item -LiteralPath $src -Destination $dst -Force
            $copied++
            continue
        }

        if ($item.kind -ne 'tree') {
            $failures += "$fromRel (알 수 없는 kind '$($item.kind)')"
            continue
        }

        $roboArgs = @($src, $dst, '/MIR')
        if ($item.excludeDirs)  { $roboArgs += '/XD'; $roboArgs += @($item.excludeDirs) }
        if ($item.excludeFiles) { $roboArgs += '/XF'; $roboArgs += @($item.excludeFiles) }
        $roboArgs += @('/NFL', '/NDL', '/NJH', '/NP', '/R:1', '/W:1')

        & robocopy @roboArgs | Out-Null
        # robocopy 는 0..7 이 정상(변경 없음/복사함/추가 파일 있음)이고 8 이상만 실패다.
        if ($LASTEXITCODE -ge 8) { $failures += "$fromRel (robocopy=$LASTEXITCODE)" } else { $copied++ }
    }

    if ($failures.Count -gt 0) {
        Write-Error "[$name] 동기화 실패: $($failures -join ', ')"
        return $false
    }

    # baseline 마커: 로컬 파일 복사 시점 + 출처 보조 SHA/working-tree 상태 + 대표 트리 파일 수.
    # baseline 내용은 commit checkout 이 아니라 현재 로컬 파일에서 오므로 SHA만으로 정의되지 않는다.
    $shaInfo = Get-SourceSha $srcRepoRoot
    $sha     = if ($shaInfo.Sha) { $shaInfo.Sha } else { 'unknown' }
    $worktreeState = Get-SourceWorktreeState $srcRepoRoot

    $countRel = if ($spec.sourceCountPath) { Expand-SpecPath $spec.sourceCountPath $name $engineSub } else { '' }
    if (-not $countRel) {
        $countItem = @($items | Where-Object { $_.kind -eq 'tree' -and $_.required })[0]
        if (-not $countItem) { $countItem = @($items | Where-Object { $_.kind -eq 'tree' })[0] }
        if ($countItem) {
            $countSpec = if ($countItem.to) { $countItem.to } else { $countItem.from }
            $countRel  = Expand-SpecPath $countSpec $name $engineSub
        }
    }
    $countPath = if ($countRel) { Join-Path $baseline $countRel } else { $baseline }
    $srcCnt    = (Get-ChildItem -LiteralPath $countPath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count

    $stamp = Get-Date -Format 'yyyy-MM-ddTHH:mm'
    "$stamp sync | snapshot=local-worktree commit=$sha worktree=$worktreeState Source=$srcCnt" | Set-Content -Path (Join-Path $baseline '.baseline') -Encoding utf8

    # 편집 사본 시드 (없을 때만; -ResetEdit 으로 강제)
    $editRoot = Join-Path $projectsDir "$name\edit"
    $sClaud = Seed-Edit $baseline $editRoot 'Claud' ($ResetEdit -eq 'Claud' -or $ResetEdit -eq 'All')
    $sCodex = Seed-Edit $baseline $editRoot 'Codex' ($ResetEdit -eq 'Codex' -or $ResetEdit -eq 'All')

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
