# RuleSync

RuleSync는 MultiAgentCrossReview의 private markdown rule 동기화 패키지입니다.

`UserSettings/**/*.md`와 `Projects/<name>/RULES.md`처럼 공개 저장소에 커밋하지 않는 로컬 룰을 사용자가 만든 private rules vault와 주고받습니다. 한 대의 머신에서만 작업한다면 필수 기능이 아니며, 여러 머신에서 같은 개인 설정과 프로젝트별 룰을 이어 써야 할 때 사용합니다.

## 역할

- `MultiAgentCrossReview`: 공개 워크벤치. 에이전트가 실제로 읽는 materialized copy를 둡니다.
- private rules vault: 실제 개인/프로젝트별 markdown 룰의 SSOT입니다.
- `Packages/RuleSync`: 두 위치 사이에서 룰 파일을 복사하고 private vault의 Git pull/commit/push를 돕는 공개 패키지입니다.

Claude/Codex memory는 캐시 또는 참고 맥락일 뿐 SSOT가 아닙니다.

## 동기화 대상

동기화함:

```text
UserSettings/**/*.md
Projects/<name>/RULES.md
```

동기화하지 않음:

```text
README.md
Projects/<name>/baseline/**
Projects/<name>/edit/**
auth/token/db/env/key files
build artifacts
session JSONL
```

`README.md`는 공개 안내 문서입니다. private vault에는 실제 룰 데이터만 둡니다.

## 설정

로컬 설정 파일을 만듭니다.

```powershell
Copy-Item .\Packages\RuleSync\rulesync.config.example.psd1 .\Packages\RuleSync\rulesync.config.psd1
```

`rulesync.config.psd1`은 gitignore 대상입니다. 여기에 private rules vault clone 경로를 지정합니다.

```powershell
@{
    VaultRoot = 'D:\Private\MyRulesVault'
    WorktreeRoot = ''
}
```

## 사용

다른 머신이나 원격 private vault의 최신 룰을 현재 워크트리로 가져옵니다.

```powershell
.\Packages\RuleSync\Start.ps1
```

현재 워크트리의 룰 변경을 private vault에 반영하고, vault에서 commit/push까지 수행합니다.

```powershell
.\Packages\RuleSync\Finish.ps1
```

더블클릭/바로가기용 cmd도 제공합니다.

```powershell
.\Packages\RuleSync\Start.cmd
.\Packages\RuleSync\Finish.cmd
```

내부 복사 엔진만 직접 호출할 수도 있습니다.

```powershell
.\Packages\RuleSync\rulesync.ps1 -Direction Pull
.\Packages\RuleSync\rulesync.ps1 -Direction Push
```

`Start.ps1` / `Finish.ps1`는 기본적으로 private vault에서 `git pull --ff-only`를 먼저 실행합니다. `Finish.ps1`는 현재 워크트리의 룰을 private vault에 적용한 뒤, 변경이 있으면 `git add`, `git commit`, `git push`까지 처리합니다.

`Finish.ps1`는 “내 머신 상태를 remote rules vault에 적용”하는 명령이므로 기본적으로 vault 쪽 룰 파일을 갱신합니다. 덮어쓰기 없이 충돌 skip 동작을 보고 싶을 때만 `-NoOverwrite`를 사용합니다.

overwrite 과정에서 만들어지는 `.bak-*` 파일은 로컬 백업이며 private vault commit 대상에 포함하지 않습니다.

유용한 옵션:

```powershell
.\Packages\RuleSync\Start.ps1 -DryRun
.\Packages\RuleSync\Finish.ps1 -DryRun
.\Packages\RuleSync\Finish.ps1 -CommitMessage 'rulesync: update laptop rules'
.\Packages\RuleSync\Start.ps1 -Force
.\Packages\RuleSync\Finish.ps1 -NoOverwrite
.\Packages\RuleSync\Finish.ps1 -SkipGitPush
```

## 충돌 정책

RuleSync는 다른 내용의 대상 파일을 조용히 덮어쓰지 않습니다.

source와 destination에 같은 상대경로 파일이 있고 내용이 다르면:

1. destination 옆에 timestamped `.bak-*` 백업을 만듭니다.
2. 경고를 출력합니다.
3. `-Force`가 없으면 해당 파일을 건너뜁니다.
4. `-Force`가 있으면 백업 후 source로 덮어씁니다.

## 공개/비공개 경계

공개 MIT 저장소에 포함되는 파일:

```text
Packages/RuleSync/rulesync.ps1
Packages/RuleSync/Start.ps1
Packages/RuleSync/Finish.ps1
Packages/RuleSync/Start.cmd
Packages/RuleSync/Finish.cmd
Packages/RuleSync/rulesync.config.example.psd1
Packages/RuleSync/README.md
```

로컬 전용 파일:

```text
Packages/RuleSync/rulesync.config.psd1
RuleSync.local.psd1
```

실제 vault 경로, 개인 markdown 룰, 프로젝트별 비공개 룰은 공개 저장소에 커밋하지 않습니다.

## 예시 private vault

공개 예시 구조는 [MultiAgentPrivateRulesSync](https://github.com/cyphen156/MultiAgentPrivateRulesSync)를 참고하세요. 실제 운용 vault는 이 예시를 바탕으로 사용자가 직접 private repository로 만듭니다.

## 머신별 파일

`UserSettings/machines/<host>.md`는 머신별 설정을 담기 위한 파일입니다. 각 머신은 자기 host 파일만 수정하는 것을 권장합니다.
