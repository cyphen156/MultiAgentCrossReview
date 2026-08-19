# Mirror Spec - `Projects/<name>/mirror.json`

이 문서는 `sync.ps1` 이 읽는 **프로젝트별 미러 스펙**의 형식을 정의합니다.

## 왜 데이터인가

"무엇을 baseline 으로 복사할 것인가"는 머신의 성질이 아니라 **프로젝트의 성질**입니다.
예전에는 이 규칙이 `sync.ps1` 코드 안에 하드코딩돼 있어서, 다른 성질의 프로젝트를
등록하려면 스크립트를 통째로 복제하는 수밖에 없었습니다. 복제본은 서로 동기화되지 않아
같은 워크벤치의 머신 사이에서도 구성이 어긋났습니다.

스펙을 데이터로 빼면 `sync.ps1` 은 한 벌만 존재하고, 프로젝트 성질의 차이는 스펙 파일이
흡수합니다.

## 위치와 운반

- 경로: `Projects/<name>/mirror.json`
- `Projects/*/` 는 `.gitignore` 대상이므로 공개 저장소에 들어가지 않습니다.
- 대신 **WorkbenchStateSync 가 운반**합니다. `RULES.md` 와 같은 취급입니다.
- 따라서 스펙은 머신 사이에서 자동으로 일치합니다. `projects.json` 은 머신 로컬 경로
  등록부이므로 스펙을 담지 않습니다.

`Projects/<name>/mirror.json` 이 **없으면** `sync.ps1` 은 내장 기본 프리셋
(`cpp-vs`, 아래 참조)을 사용합니다. 기존 C++/Visual Studio 구성은 이 프리셋으로 보존되므로,
스펙 파일을 만들지 않아도 동작은 이전과 같습니다.

## 스키마

```json
{
  "version": 1,
  "description": "사람이 읽는 설명. 동작에 영향 없음.",
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

| 필드 | 필수 | 의미 |
|---|---|---|
| `version` | 예 | 스펙 버전. 현재 `1` 만 지원. 모르는 값이면 실패합니다. |
| `description` | 아니오 | 주석용. 동작에 영향 없음. |
| `items` | 예 | 복사 항목 배열. 비어 있으면 실패합니다. |
| `sourceCountPath` | 아니오 | `.baseline` 마커의 `Source=N` 을 셀 baseline 상대 경로. 생략하면 첫 `required` tree, 그것도 없으면 첫 tree 를 씁니다. |

### `items[]` 필드

| 필드 | 필수 | 의미 |
|---|---|---|
| `kind` | 예 | `"tree"` (폴더 미러), `"file"` (단일 파일 복사), `"require"` (복사하지 않고 원본 존재만 검증) |
| `from` | 예 | **원본 저장소 루트 기준** 상대 경로 |
| `to` | 아니오 | **baseline 루트 기준** 상대 경로. 생략하면 `from` 과 같습니다. |
| `required` | 아니오 | `true` 면 원본에 없을 때 동기화를 **실패**시킵니다. 기본값 `false` (없으면 조용히 건너뜀). `kind: "require"` 는 이 필드와 무관하게 항상 필수입니다. |
| `excludeDirs` | 아니오 | `kind: "tree"` 전용. robocopy `/XD` 로 전달. |
| `excludeFiles` | 아니오 | `kind: "tree"` 전용. robocopy `/XF` 로 전달. |

### 경로 치환자

`from` / `to` / `sourceCountPath` 에서 다음이 치환됩니다.

- `${engineSubdir}` — `projects.json` 의 `engineSubdir` (없으면 `name`)
- `${name}` — `projects.json` 의 `name`

### 경계 규칙

- `from` 은 `sourceRepoRoot` 밖으로, `to` 는 baseline 루트 밖으로 나갈 수 없습니다.
  `..` 등으로 이탈하면 실패합니다.
- 원본은 **읽기만** 합니다. 스펙은 원본에 쓸 수단을 제공하지 않습니다.
- `kind: "tree"` 는 robocopy `/MIR` 이므로 **대상 경로가 원본과 완전히 일치하도록 정리**됩니다.
  `to` 를 baseline 루트(`.`)로 지정하면 baseline 전체가 그 한 항목의 거울이 되므로,
  다른 항목과 겹치지 않게 하십시오.

## 두 가지 모델

이 스키마는 성격이 다른 두 미러 모델을 모두 표현합니다.

**화이트리스트** — 필요한 하위 트리만 고릅니다. 원본이 크고 대부분이 무관할 때.

```json
{ "items": [ { "kind": "tree", "from": "${engineSubdir}/Source", "required": true } ] }
```

**블랙리스트** — 저장소 전체를 뜨고 생성물만 뺍니다. Unity 처럼 루트 전체가 의미 있을 때.

```json
{
  "items": [
    { "kind": "require", "from": "DC_Client/ProjectSettings/ProjectVersion.txt" },
    {
      "kind": "tree", "from": ".", "to": ".", "required": true,
      "excludeDirs": [".git", ".vs", "Library", "Logs", "obj", "Temp", "DNF"],
      "excludeFiles": ["*.csproj", "*.sln", "*.user"]
    }
  ]
}
```

`kind: "require"` 는 아무것도 복사하지 않고 **원본이 기대한 종류의 저장소인지**만 확인합니다.
위 예에서는 Unity 프로젝트 마커가 없으면 미러를 시작하기 전에 실패합니다. 잘못된 경로를
등록해 엉뚱한 트리를 baseline 으로 뜨는 사고를 막습니다.

## 내장 기본 프리셋 `cpp-vs`

`mirror.json` 이 없을 때 적용되는 값입니다. 이전 하드코딩 동작과 동일합니다.

```json
{
  "version": 1,
  "description": "built-in default: C++ / Visual Studio engine repository",
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

## baseline 정의와의 관계

`Common/SHARED_RULES.md` 는 baseline 을 **"선언된 스펙 범위 안에서 뜬 원본 저장소 로컬
파일의 스냅샷"** 으로 정의합니다. 스펙 밖의 파일은 baseline 에 **없습니다.**

이는 실제 결함이었습니다. 문서가 baseline 을 "원본 로컬 파일 스냅샷"이라고만 적어 두면,
스펙에 포함되지 않은 파일(예: 저장소 루트의 `CMake/`, `.gitattributes`)을 두고 에이전트가
**"원본에 그 파일이 없다"고 오판**할 수 있습니다. baseline 에서 무언가를 찾지 못했다면
먼저 이 스펙의 범위를 확인하십시오.
