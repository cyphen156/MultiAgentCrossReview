<#
  run-review.ps1 — 반자동 적대적 검토 오케스트레이터 (단일 REVIEW.md 모델)

  Reviews/<topic>/ 의 두 REVIEW.md Status 를 보고 다음 단계를 계산해, 해당 에이전트를
  헤드리스(읽기전용·무도구)로 1스텝 불러 그 REVIEW.md 의 단계 섹션을 채우고 git 커밋한다.
  현재 진실 = 작업트리의 파일, 변경 이력 = git (번호 파일을 쌓지 않는다).

  단계: Codex/Claude 독립 초기판단 → 양방향 교차검증 → 각자 수정 → 각자 증거확인.
  봉인: 초기판단만 상호 비공개(Reads 없음). 이후 단계는 상대의 현재 REVIEW.md 를 읽는다.
  최종 판정(DECISION.md)은 사람이 작성한다.

  사용법:
    .\run-review.ps1 -Topic 2026-06-28_Example            # 다음 단계 1회
    .\run-review.ps1 -Topic 2026-06-28_Example -Steps 8   # 끝까지
    .\run-review.ps1 -Topic 2026-06-28_Example -Status    # 현재 상태만
    .\run-review.ps1 -Topic 2026-06-28_Example -DryRun    # 호출/기록 없이 프롬프트 미리보기
#>

param(
    [Parameter(Mandatory = $true)] [string] $Topic,
    [string] $Project = '',       # 비우면 Projects/projects.json 첫 항목
    [int]    $Steps   = 1,
    [switch] $Yes,
    [switch] $DryRun,
    [switch] $Status,
    [switch] $NoPause          # 종료 전 대기 생략 (자동화/비대화형 호출용)
)

$ErrorActionPreference = 'Stop'
$Root     = Split-Path -Parent $MyInvocation.MyCommand.Path     # Reviews/
$RepoRoot = Split-Path -Parent $Root
$TopicDir = Join-Path $Root $Topic

if (-not (Test-Path $TopicDir)) { throw "주제 폴더 없음: $TopicDir  (먼저 _TEMPLATE 복사 후 README 작성)" }

$claudReview = Join-Path $TopicDir 'Claud\REVIEW.md'
$codexReview = Join-Path $TopicDir 'Codex\REVIEW.md'
$readme      = Join-Path $TopicDir 'README.md'

# ===== 검증된 CLI 실행 파일 =====
$claudeRoot = Join-Path $env:LOCALAPPDATA 'Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude-code'
$claudeExe = Get-ChildItem -LiteralPath $claudeRoot -Filter 'claude.exe' -File -Recurse -ErrorAction SilentlyContinue |
    Sort-Object { try { [version]$_.Directory.Name } catch { [version]'0.0' } } -Descending |
    Select-Object -First 1 -ExpandProperty FullName
$CLI = @{ Codex = "$env:APPDATA\npm\codex.cmd"; Claude = $claudeExe }

# ===== 활성 프로젝트명: -Project 우선, 없으면 projects.json 첫 항목 =====
function Get-ProjectName {
    if ($Project) { return $Project }
    $manifest = Join-Path $RepoRoot 'Projects\projects.json'
    if (Test-Path $manifest) {
        try { return (Get-Content -LiteralPath $manifest -Raw -Encoding UTF8 | ConvertFrom-Json).projects[0].name } catch { }
    }
    return ''
}

# ===== Baseline: Projects/<name>/baseline/.baseline 의 기준 커밋 =====
function Get-Baseline {
    $name = Get-ProjectName
    $marker = Join-Path $RepoRoot "Projects\$name\baseline\.baseline"
    if (Test-Path $marker) { return ((Get-Content -LiteralPath $marker -TotalCount 1).Trim()) }
    Write-Warning "baseline 마커 없음 ($marker). sync.ps1 미실행 → 'unsynced' 로 기록."
    return "$(Get-Date -Format 'yyyy-MM-dd') unsynced"
}

function Read-IfExists([string] $p) {
    if (Test-Path $p) { return Get-Content -LiteralPath $p -Raw -Encoding UTF8 }
    return ''
}

$Rank = @{ 'unstarted' = 0; 'Initial' = 1; 'Cross-reviewed' = 2; 'Revised' = 3; 'Evidence-checked' = 4 }

function Get-ReviewStatus([string] $path) {
    if (-not (Test-Path $path)) { return 'unstarted' }
    $txt = Get-Content -LiteralPath $path -Raw -Encoding UTF8
    if ($txt -match '(?m)^Status:\s*([A-Za-z-]+)') {
        $s = $Matches[1].Trim()
        if ($Rank.ContainsKey($s)) { return $s }
    }
    return 'unstarted'
}

function Get-Body([string] $txt) {
    # frontmatter(--- ... ---) 이후 본문
    if ($txt -match "(?s)^---\s*`r?`n.*?`r?`n---\s*`r?`n(.*)$") { return $Matches[1].Trim() }
    return $txt.Trim()
}

# README 에서 Callback 섹션을 제거한 '주제/질문' 부분만 (초기판단 봉인용)
function Get-Question([string] $readmeTxt) {
    $idx = $readmeTxt.IndexOf('## Callback')
    if ($idx -ge 0) { return $readmeTxt.Substring(0, $idx).Trim() }
    return $readmeTxt.Trim()
}

function Get-NextStep {
    $cx = $Rank[(Get-ReviewStatus $codexReview)]
    $cl = $Rank[(Get-ReviewStatus $claudReview)]

    if ($cx -lt 1) { return @{ Agent = 'Codex';  Phase = 'initial';      Title = '1. 독립 초기판단'; Out = $codexReview; NewStatus = 'Initial';          Reads = @() } }
    if ($cl -lt 1) { return @{ Agent = 'Claude'; Phase = 'initial';      Title = '1. 독립 초기판단'; Out = $claudReview; NewStatus = 'Initial';          Reads = @() } }
    if ($cl -lt 2) { return @{ Agent = 'Claude'; Phase = 'cross-review'; Title = '2. 교차검증';     Out = $claudReview; NewStatus = 'Cross-reviewed';   Reads = @($codexReview) } }
    if ($cx -lt 2) { return @{ Agent = 'Codex';  Phase = 'cross-review'; Title = '2. 교차검증';     Out = $codexReview; NewStatus = 'Cross-reviewed';   Reads = @($claudReview) } }
    if ($cx -lt 3) { return @{ Agent = 'Codex';  Phase = 'revision';     Title = '3. 수정 결론';    Out = $codexReview; NewStatus = 'Revised';          Reads = @($claudReview) } }
    if ($cl -lt 3) { return @{ Agent = 'Claude'; Phase = 'revision';     Title = '3. 수정 결론';    Out = $claudReview; NewStatus = 'Revised';          Reads = @($codexReview) } }
    if ($cx -lt 4) { return @{ Agent = 'Codex';  Phase = 'evidence';     Title = '4. 증거 재확인';  Out = $codexReview; NewStatus = 'Evidence-checked'; Reads = @($claudReview) } }
    if ($cl -lt 4) { return @{ Agent = 'Claude'; Phase = 'evidence';     Title = '4. 증거 재확인';  Out = $claudReview; NewStatus = 'Evidence-checked'; Reads = @($codexReview) } }
    return $null
}

function Build-Prompt($step) {
    $rules     = Read-IfExists (Join-Path $RepoRoot 'Common\SHARED_RULES.md')
    $projName  = Get-ProjectName
    $projRules = ''
    if ($projName) {
        $projPath = Join-Path $RepoRoot "Projects\$projName\RULES.md"
        if (Test-Path $projPath) {
            $projRules = Read-IfExists $projPath
        }
        else {
            Write-Warning "Project rules not found: $projPath — copy Common\PROJECT_RULES.template.md and fill it when project-specific rules are needed. Continuing with generic rules only."
            $projRules = "(The active project '$projName' has no RULES.md. Generic workbench rules only.)"
        }
    }
    $readmeTxt = Read-IfExists $readme
    $roleDesc  = if ($step.Agent -eq 'Codex') {
        'You are Codex, an independent architecture reviewer with an implementation-feasibility prior.'
    } else {
        'You are Claude, an independent architecture reviewer with a conservative boundary-checking prior.'
    }

    # 초기판단은 주제(README 의 Callback 제외)만. 이후 단계는 README 전체 + 상대 REVIEW.
    $topicBlock = ''
    $otherBlock = ''
    if ($step.Phase -eq 'initial') {
        $topicBlock = Get-Question $readmeTxt
    } else {
        $topicBlock = $readmeTxt
        foreach ($r in $step.Reads) {
            $agentName = Split-Path (Split-Path $r -Parent) -Leaf
            $otherBlock += "`n=== 상대 REVIEW ($agentName/REVIEW.md) ===`n" + (Read-IfExists $r)
        }
    }

    @"
$roleDesc

[Shared rules - generic workbench]
$rules

[Project rules - $projName]
$projRules

[Review topic / README]
$topicBlock
$otherBlock

[Task]
- Phase: $($step.Phase). This output becomes the "$($step.Title)" section in REVIEW.md.
- initial: write an independent conclusion without reading the other agent's answer.
- cross-review: compare your initial judgment with the other REVIEW and evaluate the other judgment.
- revision: keep or revise your conclusion after considering the received cross-review.
- evidence: verify whether the conclusion's evidence exists in the baseline mirror (`Projects/<name>/baseline`) or DevLog.
- Read only the provided material and the cited baseline files. Do not modify any file; this script writes the record.
- Cite evidence as 'file path : symbol' plus the DevLog date when relevant. Output markdown body only; the script adds the section heading.
- End initial/revision with exactly one line: `Position: KEEP` or `Position: REVISE`.
- End cross-review with exactly one line: `Verdict: AGREE` or `Verdict: OBJECT`.
- End evidence with exactly one line: `Evidence-Status: CONFIRMED` or `Evidence-Status: INSUFFICIENT`.
"@
}

function Write-Record($step, [string] $body) {
    $existingBody = ''
    if (Test-Path $step.Out) {
        $cur = Get-Content -LiteralPath $step.Out -Raw -Encoding UTF8
        if ($Rank[(Get-ReviewStatus $step.Out)] -ge 1) { $existingBody = Get-Body $cur }
    }

    $section = "## $($step.Title)`n`n$body"
    if ($existingBody) {
        $newBody = "$existingBody`n`n$section"
    } else {
        $newBody = "# $($step.Agent) REVIEW — $Topic`n`n$section"
    }

    $front = @"
---
Review-ID: $Topic
Author: $($step.Agent)
Baseline: $Baseline
Session-Id:
Status: $($step.NewStatus)
---

"@
    $dir = Split-Path $step.Out -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Set-Content -Path $step.Out -Value ($front + $newBody + "`n") -Encoding utf8 -NoNewline

    $rel = $step.Out.Substring($RepoRoot.Length + 1).Replace('\', '/')
    git -C $RepoRoot add -- $rel | Out-Null
    git -C $RepoRoot commit -m "review($Topic): $($step.Agent) $($step.Phase)" | Out-Null
    Write-Host "기록·커밋: $rel  (Status=$($step.NewStatus))" -ForegroundColor Green
}

function Show-Status {
    Write-Host "`n[$Topic 상태]" -ForegroundColor Cyan
    Write-Host ("  Codex/REVIEW.md  : " + (Get-ReviewStatus $codexReview))
    Write-Host ("  Claud/REVIEW.md  : " + (Get-ReviewStatus $claudReview))
    $decision = Join-Path $TopicDir 'DECISION.md'
    $decided = (Test-Path $decision) -and ((Get-Content -LiteralPath $decision -Raw) -match '(?m)^Status:\s*Decided')
    Write-Host ("  DECISION.md      : " + $(if ($decided) { 'Decided' } else { '미작성/미결' }))
    $next = Get-NextStep
    if ($null -eq $next) { Write-Host "  다음 단계        : 없음 → 사용자 DECISION.md 작성 차례" -ForegroundColor Yellow }
    else { Write-Host ("  다음 단계        : {0} {1}" -f $next.Agent, $next.Phase) }
}

function Test-CLI($agent) {
    $exe = $CLI[$agent]
    if ([string]::IsNullOrWhiteSpace($exe)) { throw "$agent CLI 경로가 설정되지 않음." }
    if (-not (Test-Path -LiteralPath $exe)) { throw "$agent CLI 실행 파일을 찾을 수 없음: $exe" }
    try { $null = & $exe --version 2>&1; if ($LASTEXITCODE -ne 0) { throw "exit $LASTEXITCODE" } }
    catch { throw "$agent CLI 실행 probe 실패 ($_): $exe" }
}

function Invoke-Agent($step, [string] $promptFile) {
    $prompt = Get-Content -Raw -Encoding UTF8 -LiteralPath $promptFile
    $stderrFile = Join-Path $env:TEMP ("review_{0}_{1}.stderr.log" -f $Topic, $step.Agent)
    $prevEnc = $OutputEncoding
    $OutputEncoding = [Text.UTF8Encoding]::new($false)
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $exitCode = -1
    try {
        if ($step.Agent -eq 'Codex') {
            $result = $prompt | & $CLI.Codex exec --ephemeral --sandbox read-only --skip-git-repo-check -C $RepoRoot - 2> $stderrFile
        }
        else {
            $systemPrompt = 'You are Claude in a text-only architecture review pipeline. Make an independent judgment first, then cross-review only when the prompt explicitly provides the other answer. Do not use tools, describe tool calls, or modify files. Return only the requested Markdown body.'
            $result = $prompt | & $CLI.Claude -p --safe-mode --system-prompt $systemPrompt --tools "" --permission-mode dontAsk --no-session-persistence --output-format text 2> $stderrFile
        }
        $exitCode = $LASTEXITCODE
    }
    finally {
        $OutputEncoding = $prevEnc
        $ErrorActionPreference = $prevEap
    }
    if ($exitCode -ne 0) {
        throw "$($step.Agent) CLI 호출 실패 (exit $exitCode)`n$(Read-IfExists $stderrFile)"
    }
    return ($result -join "`n").Trim()
}

# 종료 전 대기: 최대 N초, 아무 키나 누르면 즉시 종료. 비대화형/-NoPause 면 생략.
function Wait-BeforeClose([int] $Seconds = 60) {
    if ($NoPause) { return }
    try {
        if (-not [Environment]::UserInteractive) { return }
        Write-Host ("`n{0}초 후 자동 종료 — 아무 키나 누르면 즉시 종료." -f $Seconds) -ForegroundColor DarkGray
        $deadline = (Get-Date).AddSeconds($Seconds)
        while ((Get-Date) -lt $deadline) {
            if ([Console]::KeyAvailable) { [void][Console]::ReadKey($true); break }
            Start-Sleep -Milliseconds 200
        }
    }
    catch { }
}

# ===== main =====
# 콘솔이 바로 닫혀도 기록이 남도록 transcript 로그. *.log 는 .gitignore (로컬 전용).
$logFile = Join-Path $TopicDir 'run-review.log'
try { Start-Transcript -LiteralPath $logFile -Append | Out-Null } catch { }

try {
    $Baseline = Get-Baseline

    if ($Status) {
        Show-Status
    }
    else {
        for ($i = 0; $i -lt $Steps; $i++) {
            $step = Get-NextStep
            if ($null -eq $step) {
                Write-Host "자동 검토 단계 완료 → 사용자 최종 판정 차례. DECISION.md 를 작성하세요." -ForegroundColor Yellow
                break
            }
            Write-Host ("`n[다음 스텝] {0} → {1} (Status -> {2})" -f $step.Agent, $step.Phase, $step.NewStatus) -ForegroundColor Cyan

            $promptFile = Join-Path $env:TEMP ("review_{0}_{1}_{2}.txt" -f $Topic, $step.Agent, $step.Phase)
            Build-Prompt $step | Set-Content -Path $promptFile -Encoding utf8

            if ($DryRun) {
                Write-Host "[DryRun] 프롬프트 생성: $promptFile  (호출/기록 안 함, 1스텝 미리보기)" -ForegroundColor DarkGray
                break
            }

            Test-CLI $step.Agent

            if (-not $Yes) {
                $ans = Read-Host "이 스텝에서 $($step.Agent) 를 호출할까요? (y/N)"
                if ($ans -ne 'y') { Write-Host '중단.'; break }
            }

            Write-Host "실행: $($CLI[$step.Agent])" -ForegroundColor DarkGray
            $out = Invoke-Agent $step $promptFile
            if ([string]::IsNullOrWhiteSpace($out)) { Write-Warning "$($step.Agent) 출력이 비었습니다. 기록 생략(재실행하면 같은 스텝부터)."; break }

            Write-Record $step $out
        }
        Show-Status
    }
}
finally {
    try { Stop-Transcript | Out-Null } catch { }
    Wait-BeforeClose
}
