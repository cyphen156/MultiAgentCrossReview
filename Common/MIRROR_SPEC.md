# 프로젝트 미러 스펙

`Projects/<name>/MirrorTargets.json`은 ProjectSync가 원본 프로젝트에서 무엇을 baseline으로 복사할지 정하는 파일입니다. 프로젝트마다 다른 미러 범위를 스크립트에 하드코딩하지 않고 데이터로 관리합니다.

## 저장 위치와 안전 경계

- 파일 경로: `Projects/<name>/MirrorTargets.json`
- 스펙에 적는 경로는 모두 `sourceRepoRoot` 기준 상대경로입니다. 절대경로와 프로젝트 밖으로 나가는 경로는 허용하지 않습니다.
- 이 파일은 프로젝트 규칙과 함께 WorkbenchStateSync가 운반합니다.
- `Projects/projects.json`은 머신별 `sourceRepoRoot` 절대경로를 담으므로 동기화하지 않습니다.
- ProjectSync는 원본을 읽기만 하며 원본으로 되돌려 쓰는 경로를 제공하지 않습니다.
- `MirrorTargets.json`이 없으면 내장 `cpp-vs` 프리셋을 사용합니다.

쓰기 대상을 정하는 절대경로와 복사 범위를 정하는 상대경로를 분리해야 다른 머신의 잘못된 경로에 `robocopy /MIR`이 적용되는 사고를 막을 수 있습니다.

## 스키마

```json
{
  "version": 1,
  "description": "사람이 읽는 설명. 동작에는 영향이 없습니다.",
  "engineSubdir": "EngineFolderName",
  "sourceCountPath": "${engineSubdir}/Source",
  "items": [
    {
      "kind": "tree",
      "from": "${engineSubdir}/Source",
      "to": "${engineSubdir}/Source",
      "required": true,
      "excludeDirs": [".vs", "x64", "Debug", "Release"],
      "excludeFiles": ["*.vcxproj.user"]
    },
    {
      "kind": "file",
      "from": "README.md"
    }
  ]
}
```

### 최상위 필드

| 필드 | 필수 | 설명 |
|---|---|---|
| `version` | 예 | 스펙 버전입니다. 현재는 `1`만 지원하며 다른 값은 실패합니다. |
| `description` | 아니요 | 사람이 읽는 설명입니다. 동작에는 영향이 없습니다. |
| `engineSubdir` | 아니요 | 원본 루트 아래의 주 디렉터리입니다. `${engineSubdir}` 치환자에 사용하며, 비우면 원본 루트가 기준입니다. |
| `items` | 예 | 복사 또는 검증할 항목 배열입니다. 비어 있으면 실패합니다. |
| `sourceCountPath` | 아니요 | `.baseline` 마커의 `Source=N`을 계산할 baseline 상대경로입니다. 생략하면 첫 번째 필수 tree, 그마저 없으면 첫 번째 tree를 사용합니다. |

### `items[]` 필드

| 필드 | 필수 | 설명 |
|---|---|---|
| `kind` | 예 | `tree`는 디렉터리 미러, `file`은 단일 파일 복사, `require`는 복사 없이 원본 존재 여부만 확인합니다. |
| `from` | 예 | 원본 저장소 루트 기준 상대경로입니다. |
| `to` | 아니요 | baseline 루트 기준 상대경로입니다. 생략하면 `from`과 같습니다. |
| `required` | 아니요 | `true`인 원본이 없으면 실패합니다. 기본값은 `false`이며, `require` 항목은 항상 필수입니다. |
| `excludeDirs` | 아니요 | `tree`에서 제외할 디렉터리이며 robocopy `/XD`로 전달합니다. |
| `excludeFiles` | 아니요 | `tree`에서 제외할 파일이며 robocopy `/XF`로 전달합니다. |

### 경로 치환자

- `${engineSubdir}`: 이 스펙의 `engineSubdir`
- `${name}`: `projects.json`에 등록한 프로젝트 이름

### 경계 규칙

- `from`은 `sourceRepoRoot` 밖으로, `to`는 baseline 루트 밖으로 나갈 수 없습니다. `..` 등으로 경계를 벗어나면 실패합니다.
- `tree` 항목은 robocopy `/MIR`로 대상 경로를 원본과 같게 정리합니다.
- `to`를 baseline 루트인 `.`로 지정하면 그 항목이 baseline 전체를 관리합니다. 다른 항목과 경로가 겹치지 않게 구성해야 합니다.

## 미러 구성 예시

필요한 트리만 고르는 화이트리스트 방식:

```json
{
  "items": [
    {
      "kind": "tree",
      "from": "${engineSubdir}/Source",
      "required": true
    }
  ]
}
```

저장소 전체를 복사하고 생성물만 제외하는 방식:

```json
{
  "items": [
    {
      "kind": "require",
      "from": "Client/ProjectSettings/ProjectVersion.txt"
    },
    {
      "kind": "tree",
      "from": ".",
      "to": ".",
      "required": true,
      "excludeDirs": [".git", ".vs", "Library", "Logs", "obj", "Temp"],
      "excludeFiles": ["*.csproj", "*.sln", "*.user"]
    }
  ]
}
```

`require`는 아무것도 복사하지 않고 예상한 파일이 원본에 있는지만 확인합니다. 잘못된 프로젝트 경로를 등록했을 때 미러를 시작하기 전에 실패시키는 용도로 사용할 수 있습니다.

## 내장 기본 프리셋: `cpp-vs`

`MirrorTargets.json`이 없을 때 다음 프리셋을 사용합니다.

```json
{
  "version": 1,
  "description": "built-in default: C++ / Visual Studio engine repository",
  "engineSubdir": "",
  "sourceCountPath": "${engineSubdir}/Source",
  "items": [
    { "kind": "tree", "from": "${engineSubdir}/Source", "required": true,
      "excludeDirs": [".vs", "x64", "Debug", "Release"] },
    { "kind": "tree", "from": "${engineSubdir}/DevLog" },
    { "kind": "tree", "from": "${engineSubdir}/Resources" },
    { "kind": "file", "from": "${engineSubdir}/${engineSubdir}.vcxproj" },
    { "kind": "file", "from": "${engineSubdir}/${engineSubdir}.sln" },
    { "kind": "file", "from": "${engineSubdir}/CMakeLists.txt" },
    { "kind": "file", "from": "CyphenBuild.props", "to": "CyphenBuild.props" },
    { "kind": "tree", "from": "Docs" },
    { "kind": "file", "from": "README.md" },
    { "kind": "tree", "from": "Modules",
      "excludeDirs": [".vs", "x64", "Debug", "Release"],
      "excludeFiles": ["*.vcxproj.user"] }
  ]
}
```

## baseline을 해석할 때

baseline은 선언된 미러 범위 안에서 복사한 원본 로컬 파일의 스냅숏입니다. 스펙 밖의 파일은 baseline에 나타나지 않습니다. 파일을 찾지 못했다면 원본에 없다고 결론 내리기 전에 이 스펙의 범위를 먼저 확인합니다.
