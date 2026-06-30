# HANDOFF — 현재 구조 + 새 머신 부트스트랩

> 갱신: 2026-06-30. 여러 머신에서 이 워크벤치를 이어 쓸 때의 현재 구조와 새 머신 설정 절차.
> 공개 레포 문서이므로 사용자의 private vault 실명·절대경로·토큰은 적지 않는다.

## 현재 상태 (요약)

- 규칙 3층: **범용 워크벤치(공개)** / **프로젝트별 `Projects/<name>/RULES.md`(로컬)** / **개인 `UserSettings/`(로컬)**.
- 작고 항상 읽는 라우터 `Common/ROUTING.md`가 세 층 진입점을 분리. 진입점(`AGENTS.md`/`CLAUDE.md`/`Claud`·`Codex/ROLE.md`)은 얇은 포인터.
- 커밋/DevLog **read-before-write 게이트**: 대화형 초안은 활성 프로젝트 `RULES.md`가 없으면 기억으로 쓰지 않고 누락을 보고(fail-closed). 헤드리스 `run-review.ps1`은 경고 후 generic으로 진행(fail-open).
- `Packages/RuleSync/` = 로컬 룰(`UserSettings/**/*.md`, `Projects/<name>/RULES.md`)을 사용자 private rules vault와 동기화하는 **공개 엔진**.
  - 단순 사용: `Start.ps1`(pull→materialize) / `Finish.ps1`(워크트리→vault commit/push). 저수준: `rulesync.ps1 -Direction Pull|Push`.
- 세션(대화 JSONL) 동기화는 **별도 공개 도구 `AgentSessionSync`**(선택).
- **RuleSync·세션 동기화는 둘 다 선택 기능.** 단일 머신만 쓰면 불필요.

## 레포 구성

| 종류 | 공개/비공개 | 역할 |
|---|---|---|
| `MultiAgentCrossReview` | 공개 MIT | 워크벤치 엔진·범용 규칙·템플릿·RuleSync·Reviews |
| `MultiAgentPrivateRulesSync` | 공개 MIT | private rules vault 예시 구조 |
| `AgentSessionSync` | 공개 MIT | 세션 동기화 도구(템플릿) |
| 사용자 private rules vault | 비공개 | 실제 `UserSettings/`·`Projects/<name>/RULES.md` (RuleSync 대상) |
| 사용자 private session vault | 비공개 | 실제 세션 JSONL (AgentSessionSync 대상) |

## 새 머신 부트스트랩 (머신별 로컬 — 동기화되지 않음)

경로가 머신마다 달라 아래는 새 머신에서 직접 만든다.

1. 공개 레포 clone + 사용자 private vault 2개(rules / session) clone.
2. `Packages/RuleSync/rulesync.config.psd1` 생성(`rulesync.config.example.psd1` 복사) → `VaultRoot`를 이 머신의 rules vault clone 경로로. (gitignore)
3. `Projects/projects.json` 생성(`projects.example.json` 복사) → 이 머신의 실제 `sourceRepoRoot` 경로로 수정. (gitignore)
4. 세션 동기화를 쓰면 `AgentSessionSync.config.psd1` 생성(`Initialize-AgentSessionSync.ps1`). (gitignore)
5. 원본 대상 프로젝트가 이 머신 경로에 존재해야 `sync.ps1`이 baseline을 재생성.

그다음:

```powershell
.\Packages\RuleSync\Start.ps1   # private rules vault -> 워크트리 materialize (룰 복원)
.\sync.ps1                       # 원본 프로젝트 -> baseline/edit 미러
```

작업 종료 시 룰 변경을 vault로 돌릴 때:

```powershell
.\Packages\RuleSync\Finish.ps1  # 워크트리 룰 -> private rules vault commit/push
```

vault에 원격이 없으면 `Start.ps1`/`Finish.ps1`에 `-SkipGitPull`/`-SkipGitPush`로 로컬만 동기화.

## 검증 상태 (2026-06-30)

- 테스트 통과: RuleSync 라운드트립·충돌가드·시크릿스캔, `Start/Finish -DryRun`, `run-review.ps1 -DryRun`, AgentSessionSync 2-clone 왕복·AgentLauncher·SessionSecrets.
- 5개 레포 전부 `main` 원격 동기.
- **아직 미실행**: 실제 `codex`/`claude` CLI를 부르는 `run-review.ps1` end-to-end 1바퀴(현재 `-DryRun`까지만).

## 깨지면 안 되는 것

- 한글 포함 워크벤치 PowerShell(`sync.ps1`, `Reviews/run-review.ps1`, `rulesync.ps1`)은 **UTF-8 BOM** 유지 — PS 5.1 한글 파서 보호. 워크벤치 마크다운은 **CRLF / no-BOM**.
- `LF`/`no-BOM`은 대상 프로젝트(예: CyphenEngine) 소스/DevLog 규칙이지 워크벤치 규칙이 아니다 — 워크벤치 md에 끌어오지 않는다.
- RuleSync 동기화 대상은 `UserSettings/**/*.md`·`Projects/<name>/RULES.md`만. **`README.md`·`baseline/**`·`edit/**`·시크릿·세션 JSONL은 제외.** 충돌 시 `.bak` 백업+경고+skip, `-Force`일 때만 덮어쓴다.
- private vault 실명·절대경로·토큰·세션 JSONL은 공개 레포에 커밋하지 않는다. 대상 프로젝트 원본은 읽기 전용(미러는 `Projects/<name>/baseline/`).
- 2026-06-28 이전 `Reviews/` 토픽은 레거시(옛 번호파일) 동결.
