# 2026-06-29_PlatformPathContract — PlatformPath 계약 고정

> File / FileSystem / Path 리팩토링 전에 PlatformPath의 책임과 호출 경계를 고정한다.
> 상세 판단은 `Codex/REVIEW.md`, 최종은 `DECISION.md`에 둔다.

- 주제: PlatformPath 신설 계약과 PlatformFile 호출 경계
- 기준 커밋(baseline): `commit=d2eedf9`
- 범위: `File`, `FileSystem`, `Path`, `PlatformFile`, `PlatformPath`
- 제외: Renderer backend, JPEG codec, module ABI, 원본 repo 직접 수정
- 상태: In-Review

## 현재 결론 (요약)

`PlatformPath`는 구분자 변환 자체가 아니라 플랫폼 경로 규칙의 지정 거처다.
계약은 `HAL/Private/PlatformPath.h`에 두고, 구현은 `Platform/<OS>/Private/PlatformPath.cpp`가 빌드타임으로 확정한다.

확정 계약은 `bool ToPlatformPath(const CString& enginePath, CString& outPlatformPath)`와 `bool ToEnginePath(const CString& platformPath, CString& outEnginePath)`다.
반환 타입은 `CString`이며 native OS API 버퍼가 아니다.
Windows wide 변환 같은 인코딩 전사는 `PlatformFile.cpp`의 Win32 경계에서만 수행한다.

`MakeChildPath`, search pattern, glob `*`, `std::wstring` 조립은 PlatformPath 계약에 넣지 않고 `PlatformFile.cpp`의 TU-local 구현으로 둔다.
빈 입력은 즉시 `false`로 처리해 현재 시점의 실재 failure mode를 둔다.

## Callback (사용자 개입 · append)

- [2026-06-29] PlatformPath 신설은 확정. 대상 함수는 `ToPlatformPath`와 `ToEnginePath`이며, OS native 타입 별칭은 두지 않는다.
- [2026-06-29] PlatformPath는 CString을 받아 CString을 반환하되, 반환값은 엔진 표준 path가 아니라 현재 플랫폼 경로 규칙이 적용된 path다.
- [2026-06-29] `MakeChildPath`와 search pattern은 PlatformPath 대상이 아니라 PlatformFile 내부 구현으로 남긴다.
- [2026-06-29] 최종 구현은 `ToPlatformPath` 이름을 사용하고, `bool + out-param`, empty 입력 실패 규약을 적용한다.
- [2026-06-29] Handle은 raw non-RAII, Stream은 RAII 소유자로 분리한다. PlatformFile은 raw I/O와 namespace op를 맡고, whole-file 조합은 File 계층으로 올린다.
