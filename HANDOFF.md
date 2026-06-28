# HANDOFF — 워크벤치 재편 인계 (Codex 이어받기용)

> 작성: Claude · 2026-06-29. **인계용 임시 문서** — Codex가 이어받아 아래 "남은 일"을 끝내면 삭제한다.

## 현재 상태

워크벤치 재편이 **main에 머지 완료**됐다 (커밋 `e91f701`, `a511174`, `9750e81`, `334e444`).
구조 정의·오케스트레이터까지 끝났고, **실제 에이전트를 부르는 live 검증만 남았다.**

## 새 구조 (요약 — 상세는 `Reviews/README.md`, `Common/SHARED_RULES.md`)

- `Projects/<name>/`
  - `baseline/` — 읽기전용 미러 (sync가 채움). `Projects/<name>/**` 는 gitignore.
  - `edit/Claud`, `edit/Codex` — 에이전트별 코드 편집 사본. **Codex는 `edit/Codex`만 수정.**
  - 등록부 `Projects/projects.json`(추적)에 `{name, sourceRepoRoot, engineSubdir}` 적으면 `sync.ps1`이 자동으로 따온다.
- `Reviews/<id>/` — `README.md`(주제·기준커밋·범위·Callback) / `Claud/REVIEW.md` / `Codex/REVIEW.md` / `DECISION.md`.
  **단일 가변 파일 + 이력=git.** 옛 번호파일·append-only·Supersedes 모델은 폐기.
- `run-review.ps1` — 두 `REVIEW.md`의 Status로 다음 단계를 계산해 헤드리스로 1스텝씩 진행·커밋.

## 남은 일 (Codex가 이어받을 것)

1. **`sync.ps1` 1회 실행** → `Projects/CyphenEngine/baseline/.baseline` 기준커밋 마커 생성 (현재 'unsynced').
   - `.\sync.ps1` (projects.json 전체) 또는 `.\sync.ps1 -Project CyphenEngine`.
2. **`run-review.ps1` end-to-end 첫 검증** — 지금까지 `-DryRun`(파싱·단계판정·프롬프트·봉인)까지만 검증됨.
   실제 `codex exec` / `claude -p` 호출이 도는지, REVIEW.md 섹션 채우고 커밋하는지 1바퀴 확인.
   - 스크래치 토픽: `Copy-Item Reviews\_TEMPLATE Reviews\2026-06-29_Smoke -Recurse` → README 작성 → `.\Reviews\run-review.ps1 -Topic 2026-06-29_Smoke -Steps 8`.

## 주의 (놓치면 깨짐)

- **`run-review.ps1` · `sync.ps1`은 UTF-8 WITH BOM이 의도된 것** — PS 5.1이 no-BOM .ps1의 한글 리터럴을 못 읽어 파서가 깨진다. **벗기지 말 것.** (no-BOM은 CyphenEngine 엔진 소스/DevLog 규칙이지 워크벤치 .ps1 규칙이 아님.)
- `Reviews/2026-06-25_LinuxBringup/Codex/` 는 미커밋 상태 — Codex 본인 영역이니 직접 정리/커밋.
- 2026-06-28 이전 5개 토픽은 **레거시 동결**(옛 번호파일). 마이그레이션하지 않는다.
- 원본 `C:\Project\CyphenEngine`은 읽기만. 미러는 `Projects/CyphenEngine/baseline/`.
