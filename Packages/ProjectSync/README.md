# ProjectSync

ProjectSync는 연결된 원본 프로젝트를 이 워크벤치 안으로만 복제해 오는 **단방향 미러**입니다.

크로스 리뷰가 원본을 무단 수정하지 못하게 하는 것이 목적입니다. 원본은 읽기 전용으로 두고,
`Projects/<name>/baseline/`(참고용 읽기전용 사본)과 `Projects/<name>/edit/Claud`,
`edit/Codex`(에이전트별 수정용 사본)를 만듭니다. 원본으로 되돌려 쓰는 경로는 없습니다.

`Packages/` 의 다른 두 도구(AgentSessionSync, WorkbenchStateSync)와 달리 외부 Vault가
없습니다. 나를 개인 데이터가 없기 때문입니다 — 미러는 이미 그 머신에 있는 원본에서 파생된
로컬 사본이라 공유할 것도 개인화할 것도 없습니다. 그래서 **내장·필수**이고, 도구 본체가
이 패키지 안에 있습니다.

`Start`/`Finish` 가 아니라 **`Sync`** 명령을 노출하므로, 루트의 폴더 순회 원클릭
(`Start.ps1`/`Finish.ps1`)에는 자연히 빠집니다. 미러가 필요할 때만 수동으로 실행합니다.

## 읽는 파일 두 개

성격이 다릅니다. 하나는 이 머신의 것이고, 하나는 프로젝트의 것입니다.

| 파일 | 동기화 | 담는 것 |
|---|---|---|
| `Projects/projects.json` | **안 함** | `name` + `sourceRepoRoot`. 원본이 이 머신 어디에 있는가 |
| `Projects/<name>/MirrorTargets.json` | 함 | `engineSubdir` + 미러 대상·제외. 그 루트 밑에서 무엇을 뜰 것인가 |

`projects.json` 은 절대경로라 머신마다 다릅니다(랩탑 `D:`, 데스크탑 `F:`). 그래서 로컬에서
직접 설정하고 동기화하지 않습니다.

`MirrorTargets.json` 은 전부 원본 루트 기준 **상대경로**입니다. 어느 머신에서 풀려도 자기
프로젝트 밖을 가리키지 못하므로 WorkbenchStateSync가 `RULES.md` 와 함께 운반합니다.
형식은 `Common/MIRROR_SPEC.md`. 없으면 내장 기본 프리셋(C++/Visual Studio)이 쓰입니다.

**쓸 위치를 정하는 절대경로는 운반하지 않습니다.** 틀린 머신에서 풀리면 `robocopy /MIR` 이
엉뚱한 실제 디렉터리를 대상으로 잡고 그 안을 지웁니다.

## 미러할 프로젝트가 없는 워크벤치

등록된 프로젝트가 없으면 아무 일도 하지 않고 정상 종료합니다. 미러할 원본이 연결되지 않은
워크벤치도 이 패키지를 똑같이 가집니다. 구조는 통일하고, 참여 여부는 등록으로 정합니다.

## 사용법

```powershell
.\Packages\ProjectSync\Sync.ps1
.\Packages\ProjectSync\Sync.ps1 -Project ExampleProject
.\Packages\ProjectSync\Sync.ps1 -ResetEdit All
.\Packages\ProjectSync\Sync.ps1 -DryRun
```

최초 설정(`Projects/projects.example.json` → `Projects/projects.json`):

```powershell
.\Packages\ProjectSync\Startup.ps1
```

작업표시줄 바로가기(`Project-Sync`, `Project-Startup`)는 루트의
`Launchers/Create-Shortcuts.ps1` 에서 한곳에서 생성합니다.
