# ProjectSync

ProjectSync는 등록된 원본 프로젝트를 Workbench 안으로 복사하는 내장 단방향 미러입니다. 원본을 직접 수정하지 않고 검토할 수 있도록 `baseline/`과 에이전트별 `edit/` 사본을 만듭니다.

다른 두 Sync 패키지는 외부 Vault를 호출하는 어댑터지만, ProjectSync는 이 패키지 안에 구현되어 있습니다. 미러는 현재 머신의 원본에서 다시 만들 수 있는 로컬 사본이므로 별도 Vault에 보관하지 않습니다.

## 만들어지는 사본

```text
Projects/<name>/
  baseline/       검토와 참조에 사용하는 읽기 전용 사본
  edit/Claud/     Claude의 변경 제안 공간
  edit/Codex/     Codex의 변경 제안 공간
```

ProjectSync에는 원본으로 되돌려 쓰는 경로가 없습니다. 실행할 때는 선택된 모든 프로젝트의 등록 경로와 미러 스펙을 먼저 검증합니다. 검증을 통과하면 새 baseline을 임시 디렉터리에 완성한 뒤 기존 baseline과 교체합니다. 복사 도중 실패하면 기존 baseline은 그대로 남습니다.

강제 종료 등으로 이전 실행의 임시 디렉터리가 남았다면 다음 Sync가 정리합니다. 미완성 staging은 제거하고, 정상 baseline이 있으면 남은 backup을 제거합니다. baseline 없이 backup 하나만 남았으면 중단된 교체로 보고 복구하며, backup이 여러 개면 임의로 고르지 않고 중단합니다.

## 설정 파일

| 파일 | 역할 | 머신 간 동기화 |
|---|---|---|
| `Projects/projects.json` | 프로젝트 이름과 이 머신의 `sourceRepoRoot` 절대경로 | 안 함 |
| `Projects/<name>/MirrorTargets.json` | 원본에서 복사할 상대경로와 제외 항목 | WorkbenchStateSync로 운반 |

처음에는 공개 예시를 복사해 로컬 등록부를 만듭니다.

```powershell
.\Packages\ProjectSync\Startup.ps1
```

`MirrorTargets.json` 형식은 `Common/MIRROR_SPEC.md`에 있습니다. 파일이 없으면 내장 C++/Visual Studio 프리셋을 사용합니다.

## 사용

```powershell
.\Packages\ProjectSync\Sync.ps1
.\Packages\ProjectSync\Sync.ps1 -Project ExampleProject
.\Packages\ProjectSync\Sync.ps1 -ResetEdit All
.\Packages\ProjectSync\Sync.ps1 -DryRun
```

등록 프로젝트가 없으면 아무 작업 없이 정상 종료합니다. ProjectSync는 `Start`·`Finish`가 아닌 수동 `Sync` 명령이므로 루트의 동기화 버튼에는 포함되지 않습니다.

`-DryRun`도 실제 실행과 같은 등록 경로·필수 항목·스펙 경계·대상 경로 중첩 검사를 수행하지만 파일은 쓰지 않습니다. `edit/Claud`와 `edit/Codex`는 처음 생성할 때만 baseline으로 채우며, 이후 Sync에서는 보존합니다. 다시 채우려면 `-ResetEdit`을 명시해야 합니다.

## 안전 경계

- 프로젝트 이름은 `Projects/` 바로 아래의 단일 디렉터리 이름이어야 합니다.
- `sourceRepoRoot`는 존재하는 절대경로여야 하며 해당 Workbench 프로젝트 경로와 겹칠 수 없습니다.
- `from`, `to`, `sourceCountPath`는 각자 지정된 루트 안에 있어야 합니다.
- 둘 이상의 복사 항목이 같은 baseline 경로나 상하위 경로를 함께 관리하면 실행 전에 실패합니다.
- 선택된 프로젝트 중 하나라도 검증에 실패하면 어느 baseline도 갱신하지 않습니다.

## 회귀 테스트

테스트는 임시 Workbench와 합성 원본을 만들며 실제 등록 프로젝트나 원본 저장소를 사용하지 않습니다.

```powershell
.\Packages\ProjectSync\tests\Test-ProjectSync.ps1
```

Windows 바로가기는 Workbench 루트에서 생성합니다.

```powershell
.\Launchers\Create-Shortcuts.ps1
```
