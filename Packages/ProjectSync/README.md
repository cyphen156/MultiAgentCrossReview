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

ProjectSync에는 원본으로 되돌려 쓰는 경로가 없습니다. `tree` 항목은 대상 사본 안에서 `robocopy /MIR`을 사용하므로, 실행 전에 등록 경로와 미러 스펙을 확인해야 합니다.

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

Windows 바로가기는 Workbench 루트에서 생성합니다.

```powershell
.\Launchers\Create-Shortcuts.ps1
```
