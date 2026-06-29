---
Review-ID: 2026-06-29_PathPlatformPath
Author: User
Baseline: commit=d2eedf9
Status: Pending        # Pending -> Decided. (Claude 초안 — 사용자 확인·커밋 시 Decided)
---

# DECISION — Path / File / FileSystem 책임 분리와 PlatformPath 신설

## 판정
ADOPT(Claude)

## 근거
- 책임 3분할(Path=엔진 표준 경로 대수 / Separators=구분자 지식 / PlatformPath=플랫폼 경로 규칙 직렬화)이 기존 불변식과 정합.
- `PlatformPath`는 단순 구분자 변환이 아니라 long-path `\\?\`·UNC·drive/root 등 플랫폼 경로 규칙의 지정 거처 — 크로스플랫폼(Windows 실 FS + Linux) 목표상 결국 필요. Path/Separators가 가질 수 없는 책임.
- 계약 `bool ToPlatformPath / ToEnginePath (CString out)` — 하우스 스타일(PlatformFile 전체 bool+out)과 일치, native 타입/별칭 미노출로 HAL 헤더 청결 유지, 미래 fallible 규칙에 시그니처 호환.
- 인코딩 전사·`wstring` 헬퍼·Win32 glob를 PlatformPath 밖(PlatformFile.cpp)으로 빼 책임 위반 1건 해소, 익명 ns는 TU-local Win32 glue로 한정(목표 "최소화" 충족).

## 적용
- 원본 repo 반영은 사용자가 수행(읽기 전용 워크플로). 초안: `Claud/artifacts/CANDIDATE_PATCH.md`.
- 적용 순서: ① `PlatformPath.h` 계약 교체 → ② Windows/Linux `PlatformPath.cpp` 구현 → ③ `PlatformFile.cpp` 호출부 2단계화(`ToWidePath` 헬퍼) + `MakeChildPath`/search-pattern 익명 ns 이동.
- `ToEnginePath` 역전사(`WindowsString` 역방향)는 호출처 생길 때 구현(현재 스텁/얇은 테스트).
- 빌드: `Projects/CyphenEngine/edit/Claud` 에서 검증 후 채택 patch만 `artifacts/` 커밋.
