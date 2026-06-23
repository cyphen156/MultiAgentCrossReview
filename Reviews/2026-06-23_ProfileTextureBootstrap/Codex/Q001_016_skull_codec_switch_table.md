Date: 2026-06-23
Question-ID: Q001
Author: Codex
Responds-To: User reference to Skull ContentRecordCodec.cs
Supersedes: none
Status: Implementation-Correction
Baseline: 2026-06-23T19:08 sync

# #2_6 구현 보정 - Skull codec switch table 근거

## 확인한 근거

`C:/Project/Skul-Dimension-Rift/Client/Assets/Scripts/Content/ContentRecordCodec.cs`의 `TryDecode`는 `record.header.staticKey`에서 class key를 뽑고 `switch`로 구체 body decode 타입을 선택한다.

핵심 구조:

```text
input metadata
    -> classKey 추출
    -> switch table
    -> 약속된 concrete decode
```

이는 #2_6 codec 설계의 근거로 쓸 수 있다.

## #2_6 적용

`ImageCodec` 신규 파일은 만들지 않고, 현재 `TextCodec` 내부에 임시 이미지 decode entry를 둔다. 개별 decode 선택은 Skull 방식처럼 metadata 기반 switch table로 처리한다.

#2_6에서는 metadata가 `staticKey`가 아니라 `Path::GetExtension(sourcePath)`다.

```text
sourcePath
    -> Path::GetExtension
    -> extension switch table
    -> DecodeJpgToRgba8
```

## 구현 방향

```cpp
bool TextCodec::DecodeImageRgba8(
	const CString& sourcePath,
	const std::vector<uint8>& bytes,
	DecodedImageRgba8& outImage)
{
	outImage = {};

	if (bytes.empty())
	{
		return false;
	}

	const CString extension = Path::GetExtension(sourcePath);

	if (extension == CTEXT(".jpg") ||
		extension == CTEXT(".jpeg"))
	{
		return DecodeJpgToRgba8(bytes, outImage);
	}

	return false;
}
```

현재 C++ `CString`으로 `switch`를 직접 쓰기 어렵다면 `if` 체인으로 시작해도 된다. 중요한 것은 구조상 "등록된 key -> 약속된 concrete codec"의 switch table 형태를 유지하는 것이다.

## 장기 승격

나중에 `TextCodec`이 `Codec`으로 승격되면 위 dispatch는 다음처럼 확장된다.

```text
Codec::DecodeImageRgba8
    extension switch/registry
        .jpg/.jpeg -> DecodeJpgToRgba8
        .png       -> DecodePngToRgba8
```

즉 #2_6의 `TextCodec` 내부 구현은 임시 위치일 뿐이고, 설계 모양은 Skull의 codec dispatch와 같은 계열이다.
