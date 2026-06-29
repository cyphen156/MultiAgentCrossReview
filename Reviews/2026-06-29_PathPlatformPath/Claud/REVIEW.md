---
Review-ID: 2026-06-29_PathPlatformPath
Author: Claude
Baseline: commit=d2eedf9
Session-Id: design-dialogue (run-review.ps1 미경유 — 사용자 직접 대화)
Status: Decided
---

# Claude REVIEW — Path / File / FileSystem 책임 분리와 PlatformPath 신설

> 이 검토는 적대적 루프가 아니라 사용자와의 직접 설계 대화로 진행·확정되었다.
> 따라서 2(교차검증 vs Codex)는 "사용자 Callback 대상"으로 대체한다.
> 현재 진실 = 이 파일. 이력 = git log.

## 1. 독립 초기판단

근거(baseline 미러):
- `Source/Core/Public/Path.h` : `Path` — "Path는 파일 시스템에 직접 접근하지 않습니다 ... OS native path 변환은 File/FileSystem 플랫폼 구현 계층에서". 엔진-공간 전용 불변식이 헤더에 명시.
- `Source/Core/Public/Separator.h` : `Separators` — Engine/Windows/Unix 구분자 지식 + `Convert`. 지식 테이블이지 native emit 주체 아님.
- `Source/HAL/Private/PlatformPath.h` (Codex edit) : `ConvertWindowsPath(const CString&, std::wstring&)` + `MakeDirectorySearchPattern` + `MakeChildPath` — 이름이 플랫폼 고정, native `wstring` 노출, Win32 glob(`*`) 혼입.
- `Source/Platform/Windows/Private/PlatformFile.cpp` : `OpenFile`/`GetAttributes` 등이 `ConvertWindowsPath`로 separator 변환 + 인코딩 전사를 한 번에 수행. 익명 ns에 `ScopedFileHandle`/`ScopedFindHandle`/handle I/O — 정당한 TU-local Win32 glue.
- `Source/Platform/Windows/Private/WindowsString.h` : `ToWideString` 단방향만 존재(역방향 없음).

판단:
- **책임 위반 1건**: `MakeDirectorySearchPattern`(`dir + \*`)은 경로가 아니라 Win32 `FindFirstFile` glob 관용구. 크로스플랫폼 PlatformPath 계약에 들어가면 안 됨 → PlatformFile.cpp 내부로.
- **native 타입 누수**: PlatformPath가 `std::wstring`을 헤더로 노출. HAL 공유 헤더는 엔진 타입(CString)만 노출해야 함(PlatformFile.h 선례). 인코딩 전사는 Win32 경계(`WindowsString`)에 분리 보관.
- **PlatformPath 정당성**: 단순 구분자 변환이면 `Separators::Convert` 혹은 PlatformFile.cpp 인라인으로 충분. PlatformPath는 *플랫폼 경로 규칙(long-path/UNC/drive)의 지정 거처*로서만 존재 가치가 있음 — 이 의도를 헤더에 명시해야 재논쟁 방지.

Position: REVISE

## 2. 사용자 Callback 대상 (교차검증 대체)

`README.md` Callback 시간순을 반영. 핵심 전이:
- 반환 native 타입 노출 → 폐기(별칭 불필요, CString out).
- 이름 `ToNativePath` → `ToPlatformPath`(반환은 OS 버퍼가 아니라 규칙 적용 CString).
- 반환 형태 값반환 ↔ `bool+out` 사이를 왕복 후 **`bool+out` 확정**(하우스 스타일 + 미래 fallible + 흘려보내지 않음).

Verdict: AGREE (사용자 최종 전제와 정합)

## 3. 수정 결론

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

- `bool + out`, out 타입 `CString`, native 미노출, `empty → false`.
- 인코딩 전사 → PlatformFile.cpp `WindowsString` (2단계 helper로 집약 권장).
- `MakeChildPath` / `MakeDirectorySearchPattern` → PlatformFile.cpp 익명 ns 이동.
- Linux PlatformPath = Engine↔Unix 사실상 항등 구현 추가.
- `ToEnginePath` 현재 호출처 없음 → 계약엔 두되 구현/테스트 얇게.

잔여 리스크(기록): `ToPlatformPath` out CString은 엔진 표준 path가 아님 → 주석 가드 + PlatformFile.cpp 내 짧은 수명으로만 봉인. 강타입 래퍼는 의식 과다로 비채택.

Position: REVISE (위 계약으로 확정)

## 4. 증거 재확인

- Path 엔진-공간 불변식: `Path.h` 주석 + `Path::Normalize`가 모든 구분자를 엔진 separator로 수렴 → CONFIRMED.
- 빌드시점 .cpp 교체 원칙: 메모리 [[build-abstraction-no-interfaces]], `PlatformFile.h` "인터페이스(virtual)가 아니라 플랫폼별 동일 시그니처 구현을 빌드가 선택" → CONFIRMED.
- `WindowsString` 역방향 부재: `WindowsString.h`에 `ToWideString`만 존재 → `ToEnginePath` 구현 시 역전사 필요(현 호출처 없으니 지연 가능) → CONFIRMED.
- 채택 후보 패치: `Claud/artifacts/CANDIDATE_PATCH.md` (baseline d2eedf9 기준 전체 파일 초안).

Evidence-Status: CONFIRMED
