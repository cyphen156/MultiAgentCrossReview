# HANDOFF — 규칙 계층 분리 인계 (Codex 이어받기용)

> 작성: Claude · 2026-06-30. **인계용 임시 문서.** 사용자가 한 번 더 수정 예정이며, 토큰 한계로 Codex가 이어받는다.

## 이번에 한 일 (커밋됨)

규칙이 한 파일(`Common/SHARED_RULES.md`)에 워크벤치·프로젝트·개인 규칙으로 섞여 있던 것을 **3층으로 분리**했다.

- `Common/SHARED_RULES.md` — **범용 워크벤치 규칙만** 남김: 독립판단→교차검증 절차(§1), 범용 커밋 본문 구조(변경요약/상세/검증/다음작업, §2), DevLog 범용 원칙(§3), Reviews 운영(§4).
- `Common/PROJECT_RULES.template.md` (신규·공개) — 새 프로젝트 등록 시 복사용 템플릿.
- `Projects/<name>/RULES.md` (로컬·gitignore) — 프로젝트별: 코드스타일·**인코딩·줄바꿈**·아키텍처·DevLog 경로·`#N_M [Category]` 커밋 제목.
- `USER_PREFS.local.md` (로컬·`*.local.md` ignore) — 개인 선호(존댓말·no-yes-man 등).
- `Reviews/run-review.ps1` — `Get-ProjectName` 추가, `Build-Prompt`가 활성 프로젝트 `RULES.md`를 `[프로젝트 규칙]` 블록으로 주입. 없으면 `Write-Warning` + 플레이스홀더(증발 방지).
- 진입점 4개(AGENTS / CLAUDE / Claud·Codex ROLE) + `README.md` 갱신, `LICENSE`(MIT, Cyphen) 추가.

## 검증됨

- `run-review.ps1` 파서 OK(PS5.1), **BOM 유지**. 변경한 마크다운 전부 no-BOM.
- `git check-ignore`: `USER_PREFS.local.md`·`Projects/CyphenEngine/RULES.md` ignore 확인. 템플릿·`SHARED_RULES.md`는 추적.
- `-DryRun` 프롬프트에 `[프로젝트 규칙 — CyphenEngine]` 블록 + Allman/Skull/Core-OS 실내용 주입 확인.

## ⚠ 다른 머신에서 주의 (로컬 파일은 이 커밋에 없음)

`Projects/CyphenEngine/RULES.md` 와 `USER_PREFS.local.md` 는 **gitignore라 커밋에 포함되지 않는다.** 다른 머신엔 직접 만들어야 한다.

- `Projects/CyphenEngine/RULES.md` — 내용은 **이번 커밋 직전 `SHARED_RULES.md`**(git 이력)의 §2 코드스타일·§3 아키텍처·§4 제목·§5 DevLog에서 그대로 옮긴 것. `Common/PROJECT_RULES.template.md`를 복사해 채우면 된다.
- `USER_PREFS.local.md` — 어조=한국어 존댓말, 검토 태도=반사적 동의 금지(no-yes-man)·근거 검증, 상태=현재 합의 신뢰·옛 기록 임의 복원 금지.

## 남은 일 / 다음

- 사용자가 **한 번 더 수정 예정** — 구체 지시는 다음 세션에서 받는다. 아래는 현재까지 확정된 구조다.
- (이전 인계에서 넘어온, **아직 미확인**) `sync.ps1` 1회 실행으로 `Projects/CyphenEngine/baseline/.baseline` 기준커밋 마커 생성, `run-review.ps1` 실제 CLI 호출 end-to-end 1바퀴 검증. — 상태 미확정이니 사용자에게 확인 후 진행.

## 깨지면 안 되는 것

- `run-review.ps1`·`sync.ps1` = **UTF-8 BOM** 의도됨. 벗기면 PS5.1 한글 파서가 깨진다.
- 줄바꿈/인코딩은 **프로젝트 룰**(워크벤치 전역 정책 아님). 전역 `.gitattributes` LF 정책은 두지 않기로 함(사용자 지시).
- 2026-06-28 이전 5개 토픽은 레거시 동결(옛 번호파일). 마이그레이션하지 않는다.
- 원본 `C:\Project\CyphenEngine`은 읽기만. 미러는 `Projects/CyphenEngine/baseline/`.
