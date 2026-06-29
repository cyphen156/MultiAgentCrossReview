---
Review-ID: 2026-06-29_PlatformPathContract
Author: Codex
Baseline: commit=d2eedf9
Session-Id:
Status: Revised
---

# Codex REVIEW — PlatformPath / PlatformFile 계약 고정

## 1. 독립 초기판단

Position: REVISE

초기 구현 방향은 `PlatformPath`에 Windows wide path 변환과 child/search path 조립을 올리는 형태였으나, 이는 baseline 책임 분리와 맞지 않는다.
`PlatformFile`은 OS API 호출과 그 직전 인코딩 전사를 맡고, `PlatformPath`는 현재 플랫폼 경로 규칙을 `CString` 단위로 적용하는 HAL private 계약이어야 한다.

근거:
- `CyphenEngine/Source/Core/Public/Path.h`: Path는 엔진 표준 path 문자열 대수만 담당한다.
- `CyphenEngine/Source/HAL/Private/PlatformFile.h`: PlatformFile은 File / FileSystem 뒤에 숨겨지는 파일 시스템 HAL이며, 텍스트 인코딩과 정책 경로는 비책임이다.
- `CyphenEngine/Source/Platform/Windows/Private/PlatformFile.cpp`: Win32 API 호출 직전의 wide 변환은 Windows 구현 내부 경계에 둔다.

## 2. 교차검증 — Claude REVIEW 대상

Verdict: AGREE

사용자 Callback과 교차 검토 결론은 동일한 방향으로 수렴했다.
`PlatformPath`는 `PlatformTime`류 concrete HAL처럼 공유 계약을 갖되, native 타입 별칭을 노출하지 않는다.
`ToPlatformPath`라는 이름은 OS native buffer가 아니라 플랫폼 경로 규칙이 적용된 `CString`이라는 사실을 더 정확하게 드러낸다.

## 3. 수정 결론

Position: REVISE

확정 계약:

```cpp
static bool ToPlatformPath(const CString& enginePath, CString& outPlatformPath);
static bool ToEnginePath(const CString& platformPath, CString& outEnginePath);
```

결정 사항:
- `PlatformPath`는 `HAL/Private/PlatformPath.h`에 둔다.
- Windows / Linux 구현은 `Source/Platform/<OS>/Private/PlatformPath.cpp`가 제공한다.
- `outPlatformPath`는 `CString`이지만 엔진 표준 path가 아니므로 Path API로 되먹이지 않는다.
- empty 입력은 `false`로 처리한다.
- Windows `UTF-16` 전사는 `PlatformFile.cpp` 내부에서 `WindowsString::ToWideString`으로 수행한다.
- `MakeChildPath`, search pattern, glob, `std::wstring` 조립은 PlatformPath 계약 밖에 둔다.

## 4. 증거 재확인

Evidence-Status: CONFIRMED

현재 Codex edit 제안은 다음을 만족한다.

- `PlatformPath.h`는 `CString` 기반 `ToPlatformPath` / `ToEnginePath` 계약만 둔다.
- Windows 구현은 `Separators::Convert(Engine, Windows)`를 사용한다.
- Linux 구현은 `Separators::Convert(Engine, Unix)`를 사용한다.
- `PlatformFile.cpp`는 별도 경로 변환 helper 없이 각 File IO 경계에서 `PlatformPath::ToPlatformPath` 후 `WindowsString::ToWideString`을 수행한다.
- child path / search pattern 조립은 `PlatformFile.cpp` 익명 네임스페이스에 남아 있다.

## 5. Handle / Stream 교차검토 반영

Position: ACCEPT

사용자 Callback과 교차 검토 결과, Handle과 Stream은 택일이 아니라 계층으로 둔다.

- `FileHandle`은 raw non-RAII opaque handle이다.
- `FileStream`은 `FileHandle`을 소유하는 RAII 계층으로 둔다.
- `PlatformFile`은 raw `OpenRead` / `OpenWrite` / `OpenAppend` / `Close` / `Read` / `Write` / `Seek` / `Tell` / handle `GetSize`와 namespace op를 맡는다.
- `File`은 `ReadAllBytes` / `WriteAllBytes` / `AppendAllBytes` whole-file 편의 API를 raw handle 계약 위에서 조합한다.
- raw `Read` / `Write`는 단일 OS I/O 호출 의미이며, 끝까지 읽기 / 쓰기 루프는 `File` 또는 이후 `FileStream` 책임이다.

Evidence-Status: CONFIRMED

- `FileTypes.h`는 `FileHandle { std::uintptr_t value; }` 하나만 둔다.
- `FileStream.h` / `FileStream.cpp`는 `FileHandle` 소유와 destructor `Close`를 제공한다.
- `PlatformFile.h`에서 HAL whole-file 함수는 제거되고 raw handle 계약이 추가됐다.
- `File.cpp`가 whole-file 루프를 수행한다.
- Windows `PlatformFile.cpp`는 `FileHandle.value`를 `HANDLE`로 해석하고 native 타입은 `.cpp` 밖으로 노출하지 않는다.
