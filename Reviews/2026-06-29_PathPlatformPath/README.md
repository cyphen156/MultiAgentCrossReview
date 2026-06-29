# 2026-06-29_PathPlatformPath — Path / File / FileSystem 책임 분리와 PlatformPath 신설

> 검토의 현재 상태 요약(가변). 범위·상태·현재 결론을 여기서 갱신한다.
> 상세 판단은 `Claud/REVIEW.md`, 최종은 `DECISION.md`.

- 주제: FileSystem / File / Path 리팩토링 — 책임 위반 제거, 익명 네임스페이스 최소화, `PlatformPath` 신설 계약 확정.
- 기준 커밋(baseline): `commit=d2eedf9` (`Projects/CyphenEngine/baseline/.baseline`, 2026-06-29 sync)
- 범위: `Core/Path`, `HAL/PlatformPath`, `Platform/*/PlatformFile.cpp`, `Platform/*/WindowsString` 의 경로 문자열 책임 경계.
- 제외: 실제 원본 repo 반영·커밋(사용자 수행). TextCodec / Config 인코딩 정책(별도 패스).
- 상태: Decided (사용자와 직접 설계 대화로 확정. run-review.ps1 적대적 루프 미경유 — Codex 독립판단 없음.)

## 현재 결론 (요약)

책임 3분할 확정:

- `Core/Path` — 엔진 표준 경로 문자열 대수만(엔진 '/' 고정). FS·native·인코딩 무관.
- `Core/Separators` — 구분자 *지식* 테이블(Engine/Windows/Unix). native path를 emit하지는 않음.
- `HAL/PlatformPath` — 엔진 path를 **현재 빌드 타겟의 경로 규칙**으로 직렬화(+역방향). 공유 계약(PlatformTime류 concrete HAL), `HAL/Private/PlatformPath.h` 유지.

`PlatformPath` 존재 근거 = **구분자 변환이 아니라 플랫폼 경로 규칙(separator + 향후 long-path `\\?\` / UNC / drive·root)의 지정 거처.** Path가 하면 안 되는 이유: (1) Path는 엔진-공간 전용 불변식 → native 형태 emit은 규칙 위반, (2) "현재 타겟이 Windows냐"는 빌드시점 사실 → Core에 `#if` 분기 금지(빌드시점 .cpp 교체 원칙).

확정 계약:

```cpp
class PlatformPath final
{
private:
	friend class PlatformFile;

	static bool ToPlatformPath(const CString& enginePath, CString& outPlatformPath);
	static bool ToEnginePath(const CString& platformPath, CString& outEnginePath);
};
```

- 형태 `bool + out-param` (하우스 스타일 + 미래 fallible 규칙 대비). 오늘은 `empty → false`가 실재 failure mode.
- out 타입 `CString`, native 타입/별칭 미노출. "엔진 표준 path 아님 — Path로 되먹이지 말 것", 수명은 PlatformFile.cpp 안에 봉인.
- 이름 `ToPlatformPath` (`ToNativePath` ❌ — "native"가 OS wstring 버퍼 연상).
- 인코딩 전사(UTF-8↔UTF-16 등)는 PlatformPath 밖 → PlatformFile.cpp의 Win32 경계(`WindowsString`).
- `MakeChildPath` / search-pattern glob / `wstring` 헬퍼는 PlatformPath 금지 → PlatformFile.cpp 익명 ns(TU-local Win32 glue).

채택 후보 패치: `Claud/artifacts/CANDIDATE_PATCH.md`.

## Callback (사용자 개입 · append)

- [2026-06-29] (→ 주제 전반) 구현 대상은 toNativePath/toEnginePath, 그 외 함수는 추천 요청. PlatformPath 신설은 확정 전제.
- [2026-06-29] (→ 반환 타입) native 문자열을 헤더로 내보낼 필요 없음 — 인코딩 정책이 PlatformPath로 새지 않게. 내부에서 직접 처리.
- [2026-06-29] (→ 계층) Linux도 동일 제작 → HAL 공통 계약은 유지. 단 NativeString 별칭은 불필요(PlatformTime처럼 내부 처리). 목표는 "플랫폼별 경로 규칙으로 균일화하여 돌려준다".
- [2026-06-29] (→ 존재 근거) "Path가 이미 separator를 아는데 왜 PlatformPath?" → Path=문자 규칙 지식, PlatformPath=현재 타겟 I/O 경계 규칙 결정. 별개 책임. PlatformPath 유지가 원칙에 부합.
- [2026-06-29] (→ 반환 형태) `bool + out-param` 확정(미래 long-path/UNC fallible + CString이 엔진 표준 path 아님이라 흘려보내지 않음).
- [2026-06-29] (→ 이름) `ToPlatformPath`로 확정(native 오해 회피). `empty → false` 동의.
