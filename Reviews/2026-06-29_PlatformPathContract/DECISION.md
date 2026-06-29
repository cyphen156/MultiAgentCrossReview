---
Review-ID: 2026-06-29_PlatformPathContract
Author: User
Baseline: commit=d2eedf9
Status: Decided
---

# DECISION — PlatformPath / PlatformFile 계약 고정

## 판정

ACCEPT

## 근거

- `PlatformPath`는 engine path와 platform path 규칙 사이의 `CString` 변환만 맡는다.
- Windows wide 변환은 `PlatformFile.cpp`의 OS API 경계에서 `WindowsString::ToWideString`으로 수행한다.
- `FileHandle`은 `uintptr_t` 기반 opaque raw handle이며 RAII가 아니다.
- `PlatformFile`은 raw `OpenRead` / `OpenWrite` / `OpenAppend` / `Close` / `Read` / `Write` / `Seek` / `Tell` / handle `GetSize`와 namespace op를 맡는다.
- `File`은 raw handle 계약을 조합해 `ReadAllBytes` / `WriteAllBytes` / `AppendAllBytes` 같은 whole-file 편의 API를 제공한다.
- `FileStream`은 `FileHandle`을 소유해 RAII를 제공하는 상위 계층으로 둔다.

## 적용

Codex edit 제안에 반영한다. 원본 프로젝트 최종 반영은 사용자가 수행한다.
