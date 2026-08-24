#requires -Version 5.1
# ProjectSync - registered source projects -> local Workbench mirrors.
# Sources are read-only. A complete staging baseline replaces the live baseline
# only after validation and every copy operation succeed.

[CmdletBinding()]
param(
    [string] $Project = '',
    [ValidateSet('', 'Claud', 'Codex', 'All')]
    [string] $ResetEdit = '',
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'
$PackageRoot  = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot     = Split-Path -Parent (Split-Path -Parent $PackageRoot)
$projectsDir  = Join-Path $repoRoot 'Projects'
$manifestPath = Join-Path $projectsDir 'projects.json'
$SpecFileName = 'MirrorTargets.json'

function Normalize-FullPath([string] $path) {
    $full = [IO.Path]::GetFullPath($path)
    $root = [IO.Path]::GetPathRoot($full)
    if ($full.Length -eq $root.Length) { return $root }
    return $full.TrimEnd('\', '/')
}

function Test-IsUnderOrEqual([string] $path, [string] $root) {
    $pathFull = Normalize-FullPath $path
    $rootFull = Normalize-FullPath $root
    if ($pathFull.Equals($rootFull, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    return $pathFull.StartsWith($rootFull.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)
}

function Test-PathsOverlap([string] $left, [string] $right) {
    return (Test-IsUnderOrEqual $left $right) -or (Test-IsUnderOrEqual $right $left)
}

function Resolve-UnderRoot([string] $root, [string] $relative, [string] $label) {
    $rootFull = Normalize-FullPath $root
    if (-not $relative -or $relative -eq '.') { return $rootFull }
    if ([IO.Path]::IsPathRooted($relative)) { throw "$label 경로는 상대경로여야 합니다: '$relative'" }
    $full = Normalize-FullPath (Join-Path $rootFull $relative)
    if (-not (Test-IsUnderOrEqual $full $rootFull)) {
        throw "$label 경로가 루트를 벗어났습니다: '$relative' -> $full (루트: $rootFull)"
    }
    return $full
}

function Assert-SafeProjectName([string] $name) {
    if ([string]::IsNullOrWhiteSpace($name) -or $name -ne $name.Trim()) {
        throw "프로젝트 이름이 비어 있거나 앞뒤 공백이 있습니다: '$name'"
    }
    if ($name -eq '.' -or $name -eq '..' -or [IO.Path]::IsPathRooted($name) -or
        $name.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0 -or
        $name.EndsWith('.') -or $name.EndsWith(' ')) {
        throw "프로젝트 이름은 Projects 바로 아래의 단일 디렉터리 이름이어야 합니다: '$name'"
    }
}

function Remove-SafeDirectory([string] $path, [string] $projectRoot, [string] $expectedPrefix) {
    $pathFull = Normalize-FullPath $path
    $projectFull = Normalize-FullPath $projectRoot
    $parent = Normalize-FullPath (Split-Path -Parent $pathFull)
    $leaf = Split-Path -Leaf $pathFull
    if (-not $parent.Equals($projectFull, [StringComparison]::OrdinalIgnoreCase) -or
        -not $leaf.StartsWith($expectedPrefix, [StringComparison]::Ordinal)) {
        throw "안전하지 않은 임시 디렉터리 삭제를 거부했습니다: $pathFull"
    }
    if (Test-Path -LiteralPath $pathFull) { Remove-Item -LiteralPath $pathFull -Recurse -Force }
}

function Clear-StaleSyncTempDirectories($context) {
    # 교체 도중 프로세스가 죽으면(Ctrl+C·강제 종료·전원) catch 가 돌지 않아
    # .baseline-staging-* / .baseline-backup-* 가 남는다. 다음 실행은 새 토큰을 쓰므로
    # 스스로는 절대 치우지 않는다. 각각 baseline 전체 크기라 그냥 두면 계속 쌓인다.
    $projectRoot = Normalize-FullPath $context.ProjectRoot
    if (-not (Test-Path -LiteralPath $projectRoot -PathType Container)) { return }
    $staging = @(Get-ChildItem -LiteralPath $projectRoot -Directory -Filter '.baseline-staging-*' -ErrorAction SilentlyContinue)
    $backups = @(Get-ChildItem -LiteralPath $projectRoot -Directory -Filter '.baseline-backup-*' -ErrorAction SilentlyContinue)
    if ($staging.Count -eq 0 -and $backups.Count -eq 0) { return }

    # staging 은 항상 미완성 산출물이므로 무조건 버린다.
    foreach ($item in $staging) { Remove-SafeDirectory $item.FullName $projectRoot '.baseline-staging-' }

    if ($backups.Count -eq 0) { return }
    if (Test-Path -LiteralPath $context.Baseline) {
        # baseline 이 제자리에 있으면 backup 은 역할이 끝난 사본이다.
        foreach ($item in $backups) { Remove-SafeDirectory $item.FullName $projectRoot '.baseline-backup-' }
        Write-Host "[$($context.Name)] 이전 실행이 남긴 임시 디렉터리를 정리했습니다." -ForegroundColor DarkGray
        return
    }
    if ($backups.Count -eq 1) {
        # baseline 이 없고 backup 이 하나면 교체 중간에 끊긴 것이다. 되돌린다.
        [IO.Directory]::Move((Normalize-FullPath $backups[0].FullName), (Normalize-FullPath $context.Baseline))
        Write-Host "[$($context.Name)] 중단된 교체를 되돌려 이전 baseline 을 복구했습니다." -ForegroundColor Yellow
        return
    }
    # 어느 것이 진짜인지 판단할 근거가 없다. 추측해서 고르지 않는다.
    throw "[$($context.Name)] baseline 이 없는데 backup 이 $($backups.Count) 개입니다. 수동으로 확인하세요: $projectRoot"
}

function Get-SourceSha([string] $repo) {
    $safeRepo = $repo.Replace('\', '/')
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & git -c "safe.directory=$safeRepo" -C $repo rev-parse --short HEAD 2>&1
        $code = $LASTEXITCODE
    } catch { return @{ Sha = ''; Error = $_.Exception.Message } }
    finally { $ErrorActionPreference = $previous }
    $text = (($output | ForEach-Object { $_.ToString() }) -join ' ').Trim()
    if ($code -eq 0 -and $text -match '^[0-9a-f]{7,40}$') { return @{ Sha = $text; Error = '' } }
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
    } catch { return 'unknown' }
    finally { $ErrorActionPreference = $previous }
    if ($code -ne 0) { return 'unknown' }
    if ($output.Count -eq 0) { return 'clean' }
    return 'dirty'
}

function Get-DefaultMirrorTargets {
    return [pscustomobject]@{
        version = 1; description = 'built-in default: C++ / Visual Studio engine repository'
        engineSubdir = ''; sourceCountPath = '${engineSubdir}/Source'
        items = @(
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

function Get-MirrorTargets([string] $specPath, [string] $name) {
    if (-not (Test-Path -LiteralPath $specPath)) {
        Write-Host "[$name] $SpecFileName 없음 - 내장 기본 프리셋(cpp-vs) 사용" -ForegroundColor DarkGray
        return Get-DefaultMirrorTargets
    }
    try { $spec = Get-Content -LiteralPath $specPath -Raw -Encoding UTF8 | ConvertFrom-Json }
    catch { throw "[$name] $SpecFileName 을 읽지 못했습니다: $specPath`n  $($_.Exception.Message)" }
    if ($null -eq $spec.version -or [int] $spec.version -ne 1) {
        throw "[$name] 지원하지 않는 $SpecFileName version 입니다: '$($spec.version)' (지원: 1)"
    }
    if (@($spec.items).Count -eq 0) { throw "[$name] $SpecFileName 의 items 가 비어 있습니다: $specPath" }
    return $spec
}

function Expand-SpecPath([string] $path, [string] $name, [string] $engineSub) {
    if (-not $path) { return '' }
    $expanded = $path.Replace('${engineSubdir}', $engineSub).Replace('${name}', $name).Replace('/', '\')
    # Only remove the separator introduced by an empty engineSubdir token.
    # An explicitly rooted path must remain rooted so Resolve-UnderRoot rejects it.
    if (-not $engineSub -and ($path.StartsWith('${engineSubdir}/') -or $path.StartsWith('${engineSubdir}\'))) {
        $expanded = $expanded.TrimStart('\')
    }
    return $expanded
}

function New-MirrorPlan($spec, [string] $name, [string] $sourceRoot, [string] $baselineRoot) {
    $engineSub = if ($spec.PSObject.Properties.Name -contains 'engineSubdir' -and $spec.engineSubdir) {
        Expand-SpecPath ([string] $spec.engineSubdir) $name ''
    } else { '' }
    if ($engineSub) { [void](Resolve-UnderRoot $sourceRoot $engineSub "[$name] engineSubdir") }
    $plan = @(); $copyDestinations = @(); $index = 0
    foreach ($item in @($spec.items)) {
        $index++
        if ($null -eq $item) { throw "[$name] items[$index] 가 비어 있습니다." }
        $kind = [string] $item.kind
        if ($kind -notin @('tree', 'file', 'require')) { throw "[$name] items[$index]의 kind가 올바르지 않습니다: '$kind'" }
        $fromSpec = [string] $item.from
        if ([string]::IsNullOrWhiteSpace($fromSpec)) { throw "[$name] items[$index]의 from이 비어 있습니다." }
        $fromRel = Expand-SpecPath $fromSpec $name $engineSub
        $source = Resolve-UnderRoot $sourceRoot $fromRel "[$name] 원본"
        $exists = Test-Path -LiteralPath $source
        $required = ($kind -eq 'require') -or [bool] $item.required
        if ($required -and -not $exists) { throw "[$name] 필수 미러 항목이 원본에 없습니다: $fromRel ($source)" }
        if ($exists -and $kind -eq 'tree' -and -not (Test-Path -LiteralPath $source -PathType Container)) {
            throw "[$name] tree 항목의 원본이 디렉터리가 아닙니다: $fromRel"
        }
        if ($exists -and $kind -eq 'file' -and -not (Test-Path -LiteralPath $source -PathType Leaf)) {
            throw "[$name] file 항목의 원본이 파일이 아닙니다: $fromRel"
        }
        $toRel = ''; $destination = ''
        if ($kind -ne 'require') {
            $toSpec = if ($item.PSObject.Properties.Name -contains 'to' -and $item.to) { [string] $item.to } else { $fromSpec }
            $toRel = Expand-SpecPath $toSpec $name $engineSub
            $destination = Resolve-UnderRoot $baselineRoot $toRel "[$name] baseline"
            foreach ($other in $copyDestinations) {
                if (Test-PathsOverlap $destination $other.Destination) {
                    throw "[$name] 미러 대상 경로가 겹칩니다: '$toRel' <-> '$($other.ToRelative)'"
                }
            }
            $copyDestinations += [pscustomobject]@{ Destination = $destination; ToRelative = $toRel }
        }
        $plan += [pscustomobject]@{
            Kind = $kind; FromRelative = $fromRel; ToRelative = $toRel; Source = $source
            Exists = $exists; Required = $required
            ExcludeDirs = @($item.excludeDirs); ExcludeFiles = @($item.excludeFiles)
        }
    }
    $countRel = if ($spec.PSObject.Properties.Name -contains 'sourceCountPath' -and $spec.sourceCountPath) {
        Expand-SpecPath ([string] $spec.sourceCountPath) $name $engineSub
    } else { '' }
    if (-not $countRel) {
        $countItem = @($plan | Where-Object { $_.Kind -eq 'tree' -and $_.Required })[0]
        if (-not $countItem) { $countItem = @($plan | Where-Object { $_.Kind -eq 'tree' })[0] }
        if ($countItem) { $countRel = $countItem.ToRelative }
    }
    if ($countRel) { [void](Resolve-UnderRoot $baselineRoot $countRel "[$name] sourceCountPath") }
    return [pscustomobject]@{ Items = $plan; SourceCountRelative = $countRel }
}

function New-ProjectContext($entry) {
    if ($null -eq $entry) { throw 'projects.json에 빈 프로젝트 항목이 있습니다.' }
    $name = [string] $entry.name
    $sourceValue = [string] $entry.sourceRepoRoot
    Assert-SafeProjectName $name
    if ([string]::IsNullOrWhiteSpace($sourceValue) -or -not [IO.Path]::IsPathRooted($sourceValue)) {
        throw "[$name] sourceRepoRoot는 절대경로여야 합니다: '$sourceValue'"
    }
    $sourceRoot = Normalize-FullPath $sourceValue
    if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) { throw "[$name] 원본 저장소 루트가 없습니다: $sourceRoot" }
    $projectRoot = Resolve-UnderRoot $projectsDir $name "[$name] 프로젝트"
    if (Test-PathsOverlap $sourceRoot $projectRoot) {
        throw "[$name] 원본과 Workbench 프로젝트 경로가 겹칩니다: source=$sourceRoot project=$projectRoot"
    }
    $baseline = Join-Path $projectRoot 'baseline'
    $specPath = Join-Path $projectRoot $SpecFileName
    $spec = Get-MirrorTargets $specPath $name
    return [pscustomobject]@{
        Name = $name; SourceRoot = $sourceRoot; ProjectRoot = $projectRoot; Baseline = $baseline
        SpecPath = $specPath; Spec = $spec; Plan = (New-MirrorPlan $spec $name $sourceRoot $baseline)
    }
}

function Seed-Edit([string] $baseline, [string] $editRoot, [string] $agent, [bool] $force) {
    $editRootFull = Normalize-FullPath $editRoot
    $editPath = Resolve-UnderRoot $editRootFull $agent '편집 사본'
    if ($force -and (Test-Path -LiteralPath $editPath)) { Remove-Item -LiteralPath $editPath -Recurse -Force }
    if (-not (Test-Path -LiteralPath $editPath)) {
        New-Item -ItemType Directory -Path $editPath -Force | Out-Null
        robocopy $baseline $editPath /MIR /NFL /NDL /NJH /NP /R:1 /W:1 | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "편집 사본 시드 실패: $baseline -> $editPath (robocopy=$LASTEXITCODE)" }
        return 'seeded'
    }
    return 'kept'
}

function Copy-PlanToStaging($context, [string] $staging) {
    New-Item -ItemType Directory -Path $staging -Force | Out-Null
    foreach ($item in @($context.Plan.Items)) {
        if ($item.Kind -eq 'require' -or -not $item.Exists) { continue }
        if (-not (Test-Path -LiteralPath $item.Source)) {
            throw "[$($context.Name)] 검증 후 원본 항목이 사라졌습니다: $($item.FromRelative)"
        }
        $destination = Resolve-UnderRoot $staging $item.ToRelative "[$($context.Name)] staging"
        if ($item.Kind -eq 'file') {
            New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
            Copy-Item -LiteralPath $item.Source -Destination $destination -Force
            continue
        }
        $roboArgs = @($item.Source, $destination, '/MIR')
        if ($item.ExcludeDirs.Count -gt 0) { $roboArgs += '/XD'; $roboArgs += @($item.ExcludeDirs) }
        if ($item.ExcludeFiles.Count -gt 0) { $roboArgs += '/XF'; $roboArgs += @($item.ExcludeFiles) }
        $roboArgs += @('/NFL', '/NDL', '/NJH', '/NP', '/R:1', '/W:1')
        & robocopy @roboArgs | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "[$($context.Name)] tree 복사 실패: $($item.FromRelative) (robocopy=$LASTEXITCODE)" }
    }
}

function Install-StagedBaseline($context, [string] $staging, [string] $backup) {
    $oldMoved = $false; $newMoved = $false
    try {
        if (Test-Path -LiteralPath $context.Baseline) {
            [IO.Directory]::Move((Normalize-FullPath $context.Baseline), (Normalize-FullPath $backup))
            $oldMoved = $true
        }
        [IO.Directory]::Move((Normalize-FullPath $staging), (Normalize-FullPath $context.Baseline))
        $newMoved = $true
    } catch {
        if (-not $newMoved -and $oldMoved -and -not (Test-Path -LiteralPath $context.Baseline) -and (Test-Path -LiteralPath $backup)) {
            [IO.Directory]::Move((Normalize-FullPath $backup), (Normalize-FullPath $context.Baseline))
        }
        throw
    }
    if ($oldMoved) { Remove-SafeDirectory $backup $context.ProjectRoot '.baseline-backup-' }
}

function Sync-Project($context) {
    $name = $context.Name
    if ($DryRun) {
        Write-Host "[$name] dry-run  source=$($context.SourceRoot)  items=$(@($context.Plan.Items).Count)" -ForegroundColor DarkGray
        foreach ($item in @($context.Plan.Items)) {
            $action = if ($item.Kind -eq 'require') { 'require' } elseif ($item.Exists) { "$($item.Kind) -> $($item.ToRelative)" } else { 'optional missing (skip)' }
            Write-Host "  $($item.FromRelative)  [$action]" -ForegroundColor DarkGray
        }
        return
    }
    New-Item -ItemType Directory -Path $context.ProjectRoot -Force | Out-Null
    Clear-StaleSyncTempDirectories $context
    $token = [guid]::NewGuid().ToString('N')
    $staging = Join-Path $context.ProjectRoot ".baseline-staging-$token"
    $backup = Join-Path $context.ProjectRoot ".baseline-backup-$token"
    Write-Host "[$name] baseline <- $($context.SourceRoot)" -ForegroundColor Cyan
    try {
        Copy-PlanToStaging $context $staging
        $shaInfo = Get-SourceSha $context.SourceRoot
        $sha = if ($shaInfo.Sha) { $shaInfo.Sha } else { 'unknown' }
        $worktreeState = Get-SourceWorktreeState $context.SourceRoot
        $countPath = if ($context.Plan.SourceCountRelative) {
            Resolve-UnderRoot $staging $context.Plan.SourceCountRelative "[$name] sourceCountPath"
        } else { $staging }
        $sourceCount = (Get-ChildItem -LiteralPath $countPath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
        $stamp = Get-Date -Format 'yyyy-MM-ddTHH:mm'
        "$stamp sync | snapshot=local-worktree commit=$sha worktree=$worktreeState Source=$sourceCount" |
            Set-Content -LiteralPath (Join-Path $staging '.baseline') -Encoding utf8
        Install-StagedBaseline $context $staging $backup
    } catch {
        if (Test-Path -LiteralPath $staging) { Remove-SafeDirectory $staging $context.ProjectRoot '.baseline-staging-' }
        if (Test-Path -LiteralPath $backup) {
            if (-not (Test-Path -LiteralPath $context.Baseline)) {
                [IO.Directory]::Move((Normalize-FullPath $backup), (Normalize-FullPath $context.Baseline))
            } else { Write-Warning "[$name] 이전 baseline 백업이 남았습니다: $backup" }
        }
        throw
    }
    $editRoot = Join-Path $context.ProjectRoot 'edit'
    $sClaud = Seed-Edit $context.Baseline $editRoot 'Claud' ($ResetEdit -eq 'Claud' -or $ResetEdit -eq 'All')
    $sCodex = Seed-Edit $context.Baseline $editRoot 'Codex' ($ResetEdit -eq 'Codex' -or $ResetEdit -eq 'All')
    if (-not $shaInfo.Sha) { Write-Warning "[$name] 파일 미러는 갱신했지만 출처 커밋 SHA를 읽지 못했습니다: $($shaInfo.Error)" }
    Write-Host "[$name] OK  snapshot=local-worktree  commit=$sha  worktree=$worktreeState  Source=$sourceCount  edit/Claud=$sClaud  edit/Codex=$sCodex" -ForegroundColor Green
}

if (-not (Test-Path -LiteralPath $manifestPath)) {
    Write-Host "ProjectSync: 등록부가 없어 미러할 프로젝트가 없습니다 ($manifestPath)" -ForegroundColor DarkGray
    exit 0
}
try { $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json }
catch { Write-Error "프로젝트 등록부를 읽지 못했습니다: $manifestPath`n  $($_.Exception.Message)"; exit 1 }
if ($null -eq $manifest -or -not ($manifest.PSObject.Properties.Name -contains 'projects')) {
    Write-Error "프로젝트 등록부에 projects 배열이 없습니다: $manifestPath"; exit 1
}
$entries = @($manifest.projects)
if ($entries.Count -eq 0) {
    Write-Host "ProjectSync: 등록된 프로젝트가 없습니다 ($manifestPath)" -ForegroundColor DarkGray; exit 0
}
try {
    $seenNames = @{}
    foreach ($entry in $entries) {
        $entryName = if ($null -ne $entry) { [string] $entry.name } else { '' }
        Assert-SafeProjectName $entryName
        $key = $entryName.ToUpperInvariant()
        if ($seenNames.ContainsKey($key)) { throw "중복 프로젝트 이름입니다: '$entryName'" }
        $seenNames[$key] = $true
    }
    if ($Project) {
        $entries = @($entries | Where-Object { ([string] $_.name).Equals($Project, [StringComparison]::OrdinalIgnoreCase) })
        if ($entries.Count -eq 0) { throw "등록되지 않은 프로젝트입니다: '$Project' ($manifestPath)" }
    }
    # Validate every selected project before modifying any baseline.
    $contexts = @($entries | ForEach-Object { New-ProjectContext $_ })
} catch { Write-Error $_.Exception.Message; exit 1 }

Write-Host 'ProjectSync' -ForegroundColor Cyan
Write-Host "  workbench: $repoRoot"
if ($DryRun) { Write-Host '  mode:      dry-run (아무것도 쓰지 않음)' -ForegroundColor DarkGray }
Write-Host '  source writes: disabled'
try { foreach ($context in $contexts) { Sync-Project $context } }
catch { Write-Error $_.Exception.Message; exit 1 }
Write-Host 'ProjectSync complete.' -ForegroundColor Green
exit 0
