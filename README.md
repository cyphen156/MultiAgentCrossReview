# MultiAgentCrossReview

MultiAgentCrossReview는 여러 AI 에이전트가 같은 질문을 먼저 독립적으로 판단하고, 이후 서로의 주장과 근거를 교차 검증하도록 만드는 공개 검토 워크벤치입니다.

목표는 에이전트 사이의 합의를 빠르게 만드는 것이 아닙니다. 독립 판단 사이의 불일치를 보존하고, 반박·수정·증거 확인·사용자 Callback을 거쳐 설계 결함과 불확실성을 드러내는 것이 목적입니다.

## 두 저장소의 역할

| 저장소 | 역할 | 포함하는 것 |
|---|---|---|
| `MultiAgentCrossReview` | 사람이 읽고 재현하는 공개 검토 프로젝트 | 규칙, 질문, 독립 판단, 교차검증, 증거, Callback, 최종 결정 |
| `AgentSessionSync` | 같은 로컬 대화를 다른 컴퓨터에서 재개하기 위한 운반 저장소 | Codex·Claude 원본 세션 JSONL, baton, 시작·종료 스크립트 |

이 저장소의 `Reviews/`가 공개 검토 기록의 기준입니다. `AgentSessionSync`의 JSONL은 읽기 좋은 대화 원고가 아니라 시스템 지침·도구 출력·절대경로·공유 문맥까지 포함한 실행 로그입니다.

## 검토 흐름

```text
사용자 질문
    ↓
Codex 독립 판단 + Claude 독립 판단
    ↓
양방향 교차 검증
    ↓
각 에이전트의 수정 결론
    ↓
증거 재확인
    ↓
사용자 최종 결정
```

초기 판단은 상대 답변을 읽지 않습니다. 이후 기록은 질문 단위 append-only 파일로 남기며, 결론이 바뀌어도 기존 기록을 수정하거나 삭제하지 않습니다.

## 저장소 구조

```text
Common/                 공유 규칙과 대상 프로젝트 기준
Codex/                  Codex 역할과 검토 지침
Claud/                  Claude 역할과 검토 지침
Reviews/                질문·답변·반박·증거·Callback·결정
Reviews/_TEMPLATE/      새 검토 주제 템플릿
Reviews/run-review.ps1  반자동 교차검증 실행기
sync.ps1                로컬 대상 프로젝트의 참고 미러 갱신
sync.cmd                sync.ps1 실행 래퍼
```

`CyphenEngine/`, `Modules/`, `CyphenBuild.props`, `Temp/`는 첫 번째 실제 대상인 CyphenEngine의 로컬 참고 미러와 빌드 흔적입니다. 공개 저장소에는 포함되지 않으며 `sync.ps1`이 각 컴퓨터에서 별도로 구성합니다.

현재 CyphenEngine 미러는 검토와 패치 초안 작성에 필요한 기준 파일을 함께 가져옵니다.

- `CyphenEngine/Source/`
- `CyphenEngine/DevLog/`
- `CyphenEngine/Resources/`
- `CyphenEngine/CyphenEngine.vcxproj`
- `CyphenEngine/CyphenEngine.sln`
- `CyphenEngine/CMakeLists.txt` (원본에 있을 때)
- `Modules/`
- `CyphenBuild.props`

원본에서 `CyphenEngine/CMakeLists.txt`가 사라지면 미러의 stale 파일도 제거합니다. `.baseline`에는 실제 동기화 시점과 Source / DevLog / Resources / CMakeLists / ModuleProjects 상태를 기록합니다.

## 빠른 시작

```powershell
# 대상 프로젝트의 로컬 참고 미러 갱신
.\sync.ps1 -SourceRepoRoot C:\Project\CyphenEngine

# 새 검토 주제 생성
Copy-Item Reviews\_TEMPLATE Reviews\2026-06-20_Example -Recurse

# 질문 작성 후 상태 확인 또는 실행
.\Reviews\run-review.ps1 -Topic 2026-06-20_Example -Status
.\Reviews\run-review.ps1 -Topic 2026-06-20_Example
```

자세한 기록 규칙은 `Reviews/README.md`, 공동 판단 규칙은 `Common/SHARED_RULES.md`를 참고합니다.

## 세션과 프로젝트 기록

이 저장소는 교차검증의 재현 가능한 프로젝트 기록을 보존합니다. Codex·Claude의 로컬 대화 UUID와 원본 JSONL은 프로젝트 파일과 별개이며, 동일 대화를 다른 컴퓨터에서 재개해야 할 때는 별도 `AgentSessionSync` 저장소가 담당합니다.

## 현재 안전 경계

- 대상 프로젝트 원본은 이 저장소에서 수정하지 않습니다.
- 대상 프로젝트 미러는 원본 적용 전 검토와 패치 초안 작성 기준입니다.
- 에이전트가 작성하는 append-only 검토 기록은 `Reviews/`에만 추가합니다.
- 원본 프로젝트 수정·커밋·푸시는 사용자가 원본 저장소에서 수행합니다.
- 로컬 인증정보, 에이전트 세션, IDE 상태, 빌드 산출물은 이 저장소에 포함하지 않습니다.
