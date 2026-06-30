# HANDOFF — 규칙 계층 분리 인계 (Codex 이어받기용)

> 작성: Claude · 2026-06-30. **인계용 임시 문서.** 사용자가 한 번 더 수정 예정이며, 토큰 한계로 Codex가 이어받는다.

## 이번에 한 일

규칙이 한 파일(`Common/SHARED_RULES.md`)에 워크벤치·프로젝트·개인 규칙으로 섞여 있던 것을 **3층으로 분리**했다.

- `Common/SHARED_RULES.md` — **범용 워크벤치 규칙만** 남김: 독립판단→교차검증 절차(§1), 범용 커밋 본문 구조(변경요약/상세/검증/다음작업, §2), DevLog 범용 원칙(§3), Reviews 운영(§4).
- `Common/PROJECT_RULES.template.md` (신규·공개) — 새 프로젝트 등록 시 복사용 템플릿.
- `Common/ROUTING.md` (신규·공개) — 작고 항상 읽는 라우터. 워크벤치/프로젝트/개인 설정 진입점을 분리.
- `Projects/<name>/RULES.md` (로컬·gitignore) — 프로젝트별: 코드스타일·**인코딩·줄바꿈**·아키텍처·DevLog 경로·커밋 제목·커밋 본문 선택 구성·DevLog 범위 산정.
- `UserSettings/` (로컬·하위 파일 ignore, `README.md`만 공개) — 개인 설정(존댓말·no-yes-man 등).
- `Reviews/run-review.ps1` — `Get-ProjectName` 추가, `Build-Prompt`가 활성 프로젝트 `RULES.md`를 `[프로젝트 규칙]` 블록으로 주입. 없으면 `Write-Warning` + 플레이스홀더(증발 방지).
- 진입점 4개(AGENTS / CLAUDE / Claud·Codex ROLE) + `README.md` 갱신, `LICENSE`(MIT, Cyphen) 추가.
- 커밋/DevLog read-before-write 게이트 추가: 대화형 초안 작성은 프로젝트 `RULES.md`가 없으면 기억으로 작성하지 않고 누락을 보고한다.
- CyphenEngine 로컬 룰 복원: 커밋 제목 `#N_M [Category] 한글 제목`, 열린 선택 본문 구성, DevLog auto-generated commit 제외, 이전 DevLog 이후 포맷 커밋 범위 검토.

## 검증됨

- `run-review.ps1` 파서 OK(PS5.1), **BOM 유지**. 마크다운에는 워크벤치 전역 LF/no-BOM 정책을 적용하지 않는다.
- `git check-ignore`: `UserSettings/<private-file>`·`Projects/CyphenEngine/RULES.md` ignore 확인. 템플릿·`SHARED_RULES.md`는 추적.
- `Projects/CyphenEngine/RULES.md`: BOM 없음, LF, CRLF 없음. 이 파일은 로컬 프로젝트 룰이라 gitignore 대상이다.

## ⚠ 다른 머신에서 주의 (로컬 파일은 이 커밋에 없음)

`Projects/CyphenEngine/RULES.md` 와 `UserSettings/` 하위 개인 설정 파일은 **gitignore라 커밋에 포함되지 않는다.** 다른 머신엔 직접 만들어야 한다.

- `Projects/CyphenEngine/RULES.md` — 현재 머신에는 복원되어 있지만 gitignore라 커밋되지 않는다. 다른 머신에서는 `Common/PROJECT_RULES.template.md`를 복사한 뒤 CyphenEngine 코드스타일·아키텍처·커밋 포맷·DevLog 범위 규칙을 채워야 한다.
- `UserSettings/preferences.md` 같은 로컬 파일 — 어조=한국어 존댓말, 검토 태도=반사적 동의 금지(no-yes-man)·근거 검증, 상태=현재 합의 신뢰·옛 기록 임의 복원 금지.

## 남은 일 / 다음

- (이전 인계에서 넘어온, **아직 미확인**) `sync.ps1` 1회 실행으로 `Projects/CyphenEngine/baseline/.baseline` 기준커밋 마커 생성, `run-review.ps1` 실제 CLI 호출 end-to-end 1바퀴 검증. — 상태 미확정이니 사용자에게 확인 후 진행.

## 깨지면 안 되는 것

- `run-review.ps1`·`sync.ps1` = **UTF-8 BOM** 의도됨. 벗기면 PS5.1 한글 파서가 깨진다.
- 줄바꿈/인코딩은 **프로젝트 룰**(워크벤치 전역 정책 아님). 특히 LF/no-BOM은 CyphenEngine 같은 대상 프로젝트 규칙이며, 워크벤치 마크다운 전역 규칙으로 끌어오지 않는다.
- 대화형 커밋/DevLog 초안 작성은 프로젝트 룰 누락 시 fail-closed. 단, `run-review.ps1` 헤드리스 리뷰 오케스트레이터는 프로젝트 룰 누락 시 경고 후 generic 룰로 계속하는 fail-open 경로다.
- 2026-06-28 이전 5개 토픽은 레거시 동결(옛 번호파일). 마이그레이션하지 않는다.
- 원본 `C:\Project\CyphenEngine`은 읽기만. 미러는 `Projects/CyphenEngine/baseline/`.
