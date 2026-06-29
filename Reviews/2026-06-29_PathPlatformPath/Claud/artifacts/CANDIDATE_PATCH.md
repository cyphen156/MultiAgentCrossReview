# CANDIDATE PATCH — PlatformPath 계약 확정 (baseline d2eedf9)

읽기 전용 워크플로 초안. 적용·커밋은 사용자가 원본 repo에서 수행.
파일별 전체 내용(신규/교체) + `PlatformFile.cpp` 호출부 변경점.

---

## 1. `Source/HAL/Private/PlatformPath.h` (교체)

```cpp
#pragma once

#include "Core/Public/CString.h"

// ============================================================================
// PlatformPath
// ----------------------------------------------------------------------------
// 엔진 표준 경로 문자열을 현재 빌드 타겟의 File IO 경계 규칙으로 직렬화하는
// HAL 경로 유틸리티입니다. 빌드시점에 플랫폼별 .cpp 구현이 선택됩니다.
//
// 존재 근거:
//     단순 구분자 변환이 아니라, 플랫폼 경로 규칙의 지정 거처입니다.
//     separator + (향후) long-path \\?\ 접두 / UNC / drive·root 규칙을 한 곳에
//     모읍니다. 이 규칙들은 Core/Path(엔진-공간 전용)와 Core/Separators(구분자
//     지식 테이블)의 책임이 아닙니다.
//
// 책임:
//     엔진 표준 path -> 현재 플랫폼 경로 규칙 path (ToPlatformPath)
//     현재 플랫폼 경로 규칙 path -> 엔진 표준 path (ToEnginePath)
//
// 비책임:
//     문자열 인코딩 전사(UTF-8 <-> UTF-16 등).
//         OS API 호출 직전 단계에서 PlatformFile.cpp 의 WindowsString 등이 담당.
//     파일 / 디렉터리 I/O, 존재 확인, 프로젝트 루트 / 정책 경로 보정.
//
// outPlatformPath 는 CString 이지만 '엔진 표준 path 가 아닙니다'.
// Path API(Combine/Normalize/...)로 되먹이지 말고, PlatformFile 내부에서
// OS API 호출 직전까지만 짧게 사용합니다.
//
// 반환 정책:
//     성공 / 실패만 반환합니다(현재 실패 = 빈 입력. 향후 long-path/UNC 규칙
//     실패가 그 위에 얹힙니다).
// ============================================================================

class PlatformFile;

class PlatformPath final
{
private:
	friend class PlatformFile;

	static bool ToPlatformPath(const CString& enginePath, CString& outPlatformPath);
	static bool ToEnginePath(const CString& platformPath, CString& outEnginePath);

	PlatformPath() = delete;
	~PlatformPath() = delete;

	PlatformPath(const PlatformPath& other) = delete;
	PlatformPath& operator=(const PlatformPath& other) = delete;

	PlatformPath(PlatformPath&& other) = delete;
	PlatformPath& operator=(PlatformPath&& other) = delete;
};
```

변경점: `#include <string>` 제거(더 이상 wstring 없음). 메서드 public→private+friend(PlatformFile.h 접근 정책과 동일). `MakeDirectorySearchPattern`/`MakeChildPath` 제거(아래 3에서 PlatformFile.cpp로 이동).

---

## 2-a. `Source/Platform/Windows/Private/PlatformPath.cpp` (교체)

```cpp
#include "pch.h"

#include "HAL/Private/PlatformPath.h"

#include "Core/Public/Separator.h"

bool PlatformPath::ToPlatformPath(const CString& enginePath, CString& outPlatformPath)
{
	outPlatformPath.clear();

	if (enginePath.empty())
	{
		return false;
	}

	// 현재는 구분자 규칙만. 향후 long-path \\?\ / UNC / drive 규칙이 여기 얹힌다.
	outPlatformPath =
		Separators::Convert(enginePath, Separators::Engine, Separators::Windows);

	return true;
}

bool PlatformPath::ToEnginePath(const CString& platformPath, CString& outEnginePath)
{
	outEnginePath.clear();

	if (platformPath.empty())
	{
		return false;
	}

	outEnginePath =
		Separators::Convert(platformPath, Separators::Windows, Separators::Engine);

	return true;
}
```

변경점: `WindowsString` include 제거(인코딩 전사 책임이 여기서 빠짐). `ConvertWindowsPath`/`MakeDirectorySearchPattern`/`MakeChildPath` 삭제.

## 2-b. `Source/Platform/Linux/Private/PlatformPath.cpp` (신규)

```cpp
#include "pch.h"

#include "HAL/Private/PlatformPath.h"

#include "Core/Public/Separator.h"

bool PlatformPath::ToPlatformPath(const CString& enginePath, CString& outPlatformPath)
{
	outPlatformPath.clear();

	if (enginePath.empty())
	{
		return false;
	}

	// Linux 경로 구분자는 엔진 표준('/')과 동일 → 사실상 항등.
	outPlatformPath =
		Separators::Convert(enginePath, Separators::Engine, Separators::Unix);

	return true;
}

bool PlatformPath::ToEnginePath(const CString& platformPath, CString& outEnginePath)
{
	outEnginePath.clear();

	if (platformPath.empty())
	{
		return false;
	}

	outEnginePath =
		Separators::Convert(platformPath, Separators::Unix, Separators::Engine);

	return true;
}
```

---

## 3. `Source/Platform/Windows/Private/PlatformFile.cpp` (호출부 변경)

### 3-a. include 추가
```cpp
#include "Platform/Windows/Private/WindowsString.h"   // 인코딩 전사를 여기서 수행
```

### 3-b. 익명 ns 상단에 2단계 helper 추가 + 이동해 온 헬퍼

```cpp
namespace
{
	// 엔진 path -> 플랫폼 경로 규칙(CString) -> OS wide path. 인코딩 전사는 여기서.
	bool ToWidePath(const CString& enginePath, std::wstring& outWidePath)
	{
		outWidePath.clear();

		CString platformPath;

		if (!PlatformPath::ToPlatformPath(enginePath, platformPath))
		{
			return false;
		}

		return WindowsString::ToWideString(platformPath, outWidePath);
	}

	// PlatformPath 에서 이동: native wstring 조작 + Win32 FindFirstFile glob.
	std::wstring MakeDirectorySearchPattern(const std::wstring& directoryName)
	{
		std::wstring searchPattern = directoryName;

		if (!searchPattern.empty())
		{
			const wchar_t lastCharacter = searchPattern.back();

			if (lastCharacter != L'\\' && lastCharacter != L'/')
			{
				searchPattern.push_back(L'\\');
			}
		}

		searchPattern.push_back(L'*');

		return searchPattern;
	}

	std::wstring MakeChildPath(const std::wstring& directoryName, const wchar_t* childName)
	{
		std::wstring childPath = directoryName;

		if (!childPath.empty())
		{
			const wchar_t lastCharacter = childPath.back();

			if (lastCharacter != L'\\' && lastCharacter != L'/')
			{
				childPath.push_back(L'\\');
			}
		}

		childPath += childName;

		return childPath;
	}

	// ... 기존 ScopedFileHandle / ScopedFindHandle / handle I/O 그대로 ...
}
```

### 3-c. 호출부 치환 (전부 `PlatformPath::ConvertWindowsPath(x, w)` → `ToWidePath(x, w)`)

| 위치 | 변경 전 | 변경 후 |
|---|---|---|
| `OpenFile` | `PlatformPath::ConvertWindowsPath(path, fileName)` | `ToWidePath(path, fileName)` |
| `GetAttributes` | `PlatformPath::ConvertWindowsPath(path, fileName)` | `ToWidePath(path, fileName)` |
| `GetSize` | `PlatformPath::ConvertWindowsPath(path, fileName)` | `ToWidePath(path, fileName)` |
| `Remove` | `PlatformPath::ConvertWindowsPath(path, fileName)` | `ToWidePath(path, fileName)` |
| `MakeDirectory` | `PlatformPath::ConvertWindowsPath(path, directoryName)` | `ToWidePath(path, directoryName)` |
| `DeleteDirectory` | `PlatformPath::ConvertWindowsPath(path, directoryName)` | `ToWidePath(path, directoryName)` |
| `DeleteDirectoryRecursively` | `PlatformPath::ConvertWindowsPath(path, directoryName)` | `ToWidePath(path, directoryName)` |
| `Copy` | `ConvertWindowsPath(sourcePath, ...) \|\| ConvertWindowsPath(targetPath, ...)` | `ToWidePath(sourcePath, ...) \|\| ToWidePath(targetPath, ...)` |
| `Move` | `ConvertWindowsPath(sourcePath, ...) \|\| ConvertWindowsPath(targetPath, ...)` | `ToWidePath(sourcePath, ...) \|\| ToWidePath(targetPath, ...)` |
| `DeleteDirectoryTree` | `PlatformPath::MakeDirectorySearchPattern(...)` / `PlatformPath::MakeChildPath(...)` | 로컬 `MakeDirectorySearchPattern(...)` / `MakeChildPath(...)` |

`#include "HAL/Private/PlatformPath.h"` 는 유지(여전히 `ToPlatformPath` 호출). `ToWidePath`가 그 위에 wide 전사를 한 겹 얹는 구조.

---

## 검증 체크리스트
- [ ] PlatformPath.h 에 `std::wstring` / `<string>` 흔적 0.
- [ ] PlatformPath.cpp(Win/Linux) 에 `WindowsString` 의존 0(인코딩 전사 없음).
- [ ] PlatformFile.cpp 의 모든 native wide 변환이 `ToWidePath` 한 곳을 경유.
- [ ] `MakeChildPath`/search-pattern 이 PlatformFile.cpp 익명 ns 안에만 존재.
- [ ] CoreIO 테스트(파일 생성/읽기/복사/이동/디렉터리 트리 삭제) 회귀 없음.
- [ ] Linux 빌드에서 PlatformPath.cpp 항등 경로 컴파일 확인.
