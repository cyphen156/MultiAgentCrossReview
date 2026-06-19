<#
  run-review.ps1 — 반자동 적대적 검토 오케스트레이터

  Reviews/<주제>/ 의 파일 상태를 보고 다음 차례(Codex/Claude)를 계산해,
  해당 에이전트를 헤드리스로 1스텝 호출하고 출력을 번호 파일로 기록한다.
  반자동: 각 호출 전 사용자 확인(-Yes 로 생략).

  ───────────────────────────────────────────────────────────────
  Codex/Claude CLI를 직접 호출한다.
  프롬프트는 명령줄 인자 길이 문제를 피하기 위해 stdin으로 전달한다.
#>

param(
    [Parameter(Mandatory = $true)] [string] $Topic,         # 예: 2026-06-15_FileSystem
    [string] $Question = 'Q001',                            # 다룰 질문 ID (Q001, Q002 ...)
    [int]    $Steps    = 1,                                 # 한 번에 진행할 스텝 수
    [switch] $Yes,                                          # 확인 생략
    [switch] $DryRun,                                       # 호출 없이 프롬프트만 생성
    [switch] $AddCallback,                                  # 검토 흐름에 사용자 추가 질문/방향 주입
    [string] $CallbackText = '',                            # 추가 질문 또는 새 전제
    [ValidateSet('None','PreferCodex','PreferClaude','Merge','RejectBoth')]
    [string] $Preference = 'None',                          # 현재 사용자 선호
    [string] $PreferenceReason = '',                        # 선호 근거
    [switch] $Status                                        # 현재 질문 상태만 출력
)

# ===== 설정: 검증된 CLI 실행 파일 =====
$claudeRoot = Join-Path $env:LOCALAPPDATA 'Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude-code'
$claudeExe = Get-ChildItem -LiteralPath $claudeRoot -Filter 'claude.exe' -File -Recurse -ErrorAction SilentlyContinue |
    Sort-Object { try { [version]$_.Directory.Name } catch { [version]'0.0' } } -Descending |
    Select-Object -First 1 -ExpandProperty FullName

$CLI = @{
    Codex  = "$env:APPDATA\npm\codex.cmd"
    Claude = $claudeExe
}
# ========================================

$ErrorActionPreference = 'Stop'
$Root     = Split-Path -Parent $MyInvocation.MyCommand.Path
$TopicDir = Join-Path $Root $Topic

if (-not (Test-Path $TopicDir)) { throw "주제 폴더 없음: $TopicDir  (먼저 _TEMPLATE 복사 후 질문 작성)" }
$QFile = Join-Path $TopicDir "Questions\$Question.md"
if (-not (Test-Path $QFile)) { throw "질문 파일 없음: $QFile" }

# Baseline: 실제 동기화 시점 마커를 읽는다 (sync.ps1 이 기록). 없으면 경고 + unsynced 표기.
function Get-Baseline {
    $marker = Join-Path $Root '..\CyphenEngine\.baseline'
    if (Test-Path $marker) { return ((Get-Content $marker -TotalCount 1).Trim()) }
    Write-Warning "baseline 마커 없음 (sync.ps1 미실행). 'unsynced' 로 기록됨."
    return "$(Get-Date -Format 'yyyy-MM-dd') unsynced"
}
$Baseline = Get-Baseline

function Read-IfExists([string]$p) {
    if (Test-Path $p) {
        return Get-Content -LiteralPath $p -Raw -Encoding UTF8
    }
    return ''
}

# 다음 스텝
# 001/002는 서로의 답을 읽지 않는 독립 판단이다.
# 이후 003/004는 양방향 교차검증이며, 사용자는 필요할 때 Callback을 추가할 수 있다.
function Get-NextStep {
    $codex = Join-Path $TopicDir 'Codex'
    $claud = Join-Path $TopicDir 'Claud'

    $f001 = Join-Path $codex "${Question}_001_initial.md"
    $f002 = Join-Path $claud "${Question}_002_initial.md"
    $f003 = Join-Path $claud "${Question}_003_cross_review_codex.md"
    $f004 = Join-Path $codex "${Question}_004_cross_review_claude.md"
    $f005 = Join-Path $codex "${Question}_005_revision.md"
    $f006 = Join-Path $claud "${Question}_006_revision.md"
    $f007 = Join-Path $codex "${Question}_007_evidence_check.md"
    $f008 = Join-Path $claud "${Question}_008_evidence_check.md"

    if (-not (Test-Path $f001)) {
        return @{ Agent='Codex'; Num='001'; Kind='initial'; Out=$f001; RespondsTo='none'; Reads=@() }
    }
    if (-not (Test-Path $f002)) {
        return @{ Agent='Claude'; Num='002'; Kind='initial'; Out=$f002; RespondsTo='none'; Reads=@() }
    }
    if (-not (Test-Path $f003)) {
        return @{
            Agent='Claude'; Num='003'; Kind='cross-review'; Out=$f003
            RespondsTo="${Question}_001_initial.md"; Reads=@($f002,$f001)
        }
    }
    if (-not (Test-Path $f004)) {
        return @{
            Agent='Codex'; Num='004'; Kind='cross-review'; Out=$f004
            RespondsTo="${Question}_002_initial.md"; Reads=@($f001,$f002)
        }
    }
    if (-not (Test-Path $f005)) {
        return @{
            Agent='Codex'; Num='005'; Kind='revision'; Out=$f005
            RespondsTo="${Question}_003_cross_review_codex.md"; Reads=@($f001,$f003)
        }
    }
    if (-not (Test-Path $f006)) {
        return @{
            Agent='Claude'; Num='006'; Kind='revision'; Out=$f006
            RespondsTo="${Question}_004_cross_review_claude.md"; Reads=@($f002,$f004)
        }
    }
    if (-not (Test-Path $f007)) {
        return @{
            Agent='Codex'; Num='007'; Kind='evidence-check'; Out=$f007
            RespondsTo="${Question}_005_revision.md, ${Question}_006_revision.md"; Reads=@($f005,$f006)
        }
    }
    if (-not (Test-Path $f008)) {
        return @{
            Agent='Claude'; Num='008'; Kind='evidence-check'; Out=$f008
            RespondsTo="${Question}_005_revision.md, ${Question}_006_revision.md"; Reads=@($f005,$f006)
        }
    }
    return $null
}

function Build-Prompt($step) {
    $rules    = Read-IfExists (Join-Path $Root '..\Common\SHARED_RULES.md')
    $q        = Read-IfExists $QFile
    $summary  = ''
    $evidence = ''
    $callbacks = ''
    $evDir    = Join-Path $TopicDir 'Evidence'
    $callbackDir = Join-Path $TopicDir 'Callbacks'

    # 독립 초기 판단에는 가변 요약과 에이전트 생성 Evidence를 넣지 않는다.
    # 첫 번째 답변이 간접적으로 두 번째 답변에 노출되는 것을 막기 위함이다.
    if ($step.Kind -ne 'initial') {
        $summary = Read-IfExists (Join-Path $TopicDir 'README.md')
        $evidence = if (Test-Path $evDir) {
            (Get-ChildItem $evDir -Filter "${Question}_*.md" -File | ForEach-Object {
                "--- $($_.Name) ---`n" + (Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8)
            }) -join "`n"
        }
        else {
            ''
        }
        $callbacks = if (Test-Path $callbackDir) {
            (Get-ChildItem $callbackDir -Filter "${Question}_C*.md" -File | Sort-Object Name | ForEach-Object {
                "--- $($_.Name) ---`n" + (Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8)
            }) -join "`n"
        }
        else {
            ''
        }
    }
    $roleDesc = if ($step.Agent -eq 'Codex') {
        'You are Codex, an independent architecture reviewer with an implementation-feasibility prior.'
    }
    else {
        'You are Claude, an independent architecture reviewer with a conservative boundary-checking prior.'
    }
    $respond = ''
    foreach ($r in $step.Reads) { $respond += "`n=== 응답 대상: $(Split-Path $r -Leaf) ===`n" + (Read-IfExists $r) }

    @"
$roleDesc

[공유 규칙]
$rules

[질문 $Question]
$q

[현재 요약(README)]
$summary

[근거 Evidence]
$evidence

[사용자 Callback]
$callbacks
$respond

[작업]
- 단계: $($step.Kind)
- initial 단계에서는 상대 에이전트의 답을 보지 않고 질문에 대한 독립 결론을 작성한다.
- cross-review 단계에서는 자신의 초기 판단과 상대 초기 판단을 비교해 상대 판단을 검증한다.
- revision 단계에서는 자신이 받은 교차검증을 반영해 기존 결론을 유지하거나 수정한다.
- evidence-check 단계에서는 두 수정 결론의 근거가 Source/DevLog/Evidence에 실제로 존재하는지 독립적으로 재확인한다.
- 위 자료만 근거로 작성하고, 인용된 Source 파일만 읽기전용으로 최소 확인한다.
- 어떤 파일도 수정 금지(기록은 스크립트가 한다). 출력은 마크다운 본문만.
- 근거는 '파일경로 : 심볼' + DevLog 날짜로 명시.
- initial/revision 마지막 줄: 'Position: KEEP' 또는 'Position: REVISE'.
- cross-review 마지막 줄: 'Verdict: AGREE' 또는 'Verdict: OBJECT'.
- evidence-check 마지막 줄: 'Evidence-Status: CONFIRMED' 또는 'Evidence-Status: INSUFFICIENT'.
"@
}

function Write-Record($step, [string]$body) {
    if (Test-Path $step.Out) { throw "append-only 위반 방지 — 이미 존재: $($step.Out)" }
    $status = if ($step.Kind -eq 'initial') {
        'Initial-Complete'
    }
    elseif ($step.Kind -eq 'cross-review' -and $body -match 'Verdict:\s*AGREE') {
        'Reviewed'
    }
    elseif ($step.Kind -eq 'cross-review') {
        'Rebutted'
    }
    elseif ($step.Kind -eq 'revision') {
        'Revised'
    }
    elseif ($body -match 'Evidence-Status:\s*CONFIRMED') {
        'Evidence-Confirmed'
    }
    else {
        'Evidence-Insufficient'
    }
    $meta = @"
Date: $(Get-Date -Format 'yyyy-MM-dd')
Question-ID: $Question
Author: $($step.Agent)
Responds-To: $($step.RespondsTo)
Supersedes: none
Status: $status
Baseline: $Baseline

"@
    $dir = Split-Path $step.Out -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Set-Content -Path $step.Out -Value ($meta + $body) -Encoding utf8 -NoNewline
    Write-Host "기록됨: $($step.Out)" -ForegroundColor Green
}

function Write-Callback {
    if ([string]::IsNullOrWhiteSpace($CallbackText) -and
        $Preference -eq 'None' -and
        [string]::IsNullOrWhiteSpace($PreferenceReason)) {
        throw 'CallbackText, Preference, PreferenceReason 중 하나 이상을 입력해야 합니다.'
    }

    $callbackDir = Join-Path $TopicDir 'Callbacks'
    if (-not (Test-Path $callbackDir)) {
        New-Item -ItemType Directory -Path $callbackDir -Force | Out-Null
    }
    $existing = Get-ChildItem $callbackDir -Filter "${Question}_C*.md" -File -ErrorAction SilentlyContinue
    $next = $existing.Count + 1
    $callbackFile = Join-Path $callbackDir ("{0}_C{1:D3}_user.md" -f $Question, $next)
    if (Test-Path $callbackFile) {
        throw "append-only 위반 방지 — 이미 존재: $callbackFile"
    }

    $content = @"
Date: $(Get-Date -Format 'yyyy-MM-dd')
Question-ID: $Question
Author: User
Responds-To: current-review-state
Supersedes: none
Status: User-Callback
Baseline: $Baseline
Preference: $Preference

# 사용자 Callback

## 선호 근거
$PreferenceReason

## 추가 질문 / 새 전제
$CallbackText
"@
    Set-Content -LiteralPath $callbackFile -Value $content -Encoding UTF8 -NoNewline
    Write-Host "사용자 Callback 기록됨: $callbackFile" -ForegroundColor Green
}

function Show-QuestionStatus {
    Write-Host "`n[$Question 상태]" -ForegroundColor Cyan
    $patterns = @(
        "Codex\${Question}_*.md",
        "Claud\${Question}_*.md",
        "Callbacks\${Question}_*.md",
        "Evidence\${Question}_*.md",
        "Decision\${Question}_*.md"
    )
    foreach ($pattern in $patterns) {
        Get-ChildItem -Path (Join-Path $TopicDir $pattern) -File -ErrorAction SilentlyContinue |
            Sort-Object Name |
            ForEach-Object { '  ' + $_.FullName.Substring($TopicDir.Length + 1) }
    }
}

# preflight: 호출에 쓸 CLI 실행 파일이 실제 존재하고 실행되는지 확인
function Test-CLI($agent) {
    $exe = $CLI[$agent]
    if ([string]::IsNullOrWhiteSpace($exe)) {
        throw "$agent CLI 경로가 설정되지 않음."
    }
    if (-not (Test-Path -LiteralPath $exe)) {
        throw "$agent CLI 실행 파일을 찾을 수 없음: $exe"
    }
    try { $null = & $exe --version 2>&1; if ($LASTEXITCODE -ne 0) { throw "exit $LASTEXITCODE" } }
    catch { throw "$agent CLI 실행 probe 실패 ($_): $exe" }
}

function Invoke-Agent($step, [string]$promptFile) {
    $prompt = Get-Content -Raw -Encoding UTF8 -LiteralPath $promptFile
    $stderrFile = Join-Path $env:TEMP ("review_{0}_{1}_{2}.stderr.log" -f $Topic, $Question, $step.Num)
    $previousOutputEncoding = $OutputEncoding
    $previousErrorActionPreference = $ErrorActionPreference
    $OutputEncoding = [Text.UTF8Encoding]::new($false)
    $ErrorActionPreference = 'Continue'
    $exitCode = -1

    try {
        if ($step.Agent -eq 'Codex') {
            # stdout에는 최종 메시지만 출력된다. 진행 로그는 별도 진단 파일에 보관한다.
            $result = $prompt | & $CLI.Codex exec `
                --ephemeral `
                --sandbox read-only `
                --skip-git-repo-check `
                -C (Join-Path $Root '..') `
                - 2> $stderrFile
        }
        else {
            # 텍스트 전용 독립 검토자. 단계별 마지막 상태 줄은 사용자 프롬프트가 지정한다.
            $systemPrompt = 'You are Claude in a text-only architecture review pipeline. Make an independent judgment first, then cross-review only when the prompt explicitly provides the other answer. Do not use tools, describe tool calls, or modify files. Return only the requested Markdown body.'
            $result = $prompt | & $CLI.Claude `
                -p `
                --safe-mode `
                --system-prompt $systemPrompt `
                --tools "" `
                --permission-mode dontAsk `
                --no-session-persistence `
                --output-format text 2> $stderrFile
        }
        $exitCode = $LASTEXITCODE
    }
    finally {
        $OutputEncoding = $previousOutputEncoding
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($exitCode -ne 0) {
        $diagnostic = Read-IfExists $stderrFile
        throw "$($step.Agent) CLI 호출 실패 (exit $exitCode)`n$diagnostic"
    }
    return ($result -join "`n").Trim()
}

if ($Status) {
    Show-QuestionStatus
    return
}

if ($AddCallback) {
    Write-Callback
    Show-QuestionStatus
    return
}

for ($i = 0; $i -lt $Steps; $i++) {
    $step = Get-NextStep
    if ($null -eq $step) {
        Write-Host "자동 검토 8단계 완료 → 사용자 최종 판정 차례. 필요하면 Callback을 추가해 재검토한 뒤 Decision\${Question}_decision.md를 작성하세요." -ForegroundColor Yellow
        break
    }
    Write-Host ("`n[다음 스텝] {0} → {1} ({2}, responds-to {3})" -f $step.Agent, $step.Num, $step.Kind, $step.RespondsTo) -ForegroundColor Cyan

    $promptFile = Join-Path $env:TEMP ("review_{0}_{1}_{2}.txt" -f $Topic, $Question, $step.Num)
    Build-Prompt $step | Set-Content -Path $promptFile -Encoding utf8

    if ($DryRun) { Write-Host "[DryRun] 프롬프트 생성: $promptFile (DryRun은 기록을 안 하므로 1스텝만 미리보기)"; break }

    Test-CLI $step.Agent   # preflight: 진입점 없으면 여기서 중단

    if (-not $Yes) {
        $ans = Read-Host "이 스텝에서 $($step.Agent) 를 호출할까요? (y/N)"
        if ($ans -ne 'y') { Write-Host '중단.'; break }
    }

    Write-Host "실행: $($CLI[$step.Agent])" -ForegroundColor DarkGray
    $out = Invoke-Agent $step $promptFile
    if ([string]::IsNullOrWhiteSpace($out)) { Write-Warning "$($step.Agent) 출력이 비었습니다. 기록 생략(재실행하면 같은 스텝부터 이어짐)."; break }

    Write-Record $step $out
}

Write-Host "`n현재 기록:" -ForegroundColor Cyan
Get-ChildItem $TopicDir -Recurse -File -Filter *.md | ForEach-Object { '  ' + $_.FullName.Substring($TopicDir.Length+1) }
