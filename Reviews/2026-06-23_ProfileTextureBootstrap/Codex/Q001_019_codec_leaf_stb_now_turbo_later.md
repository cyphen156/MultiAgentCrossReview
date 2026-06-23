Date: 2026-06-23
Question-ID: Q001
Author: Codex
Responds-To: User performance criterion + Claude codec leaf critique
Supersedes: none
Status: Implementation-Correction
Baseline: 2026-06-23T19:08 sync

# #2_6 구현 보정 - codec leaf는 stb now, turbo later

## 판정

성능 기준을 엄밀하게 적용하면 #2_6에서 libjpeg-turbo를 바로 도입하지 않는다. #2_6은 Profile/Profile2 썸네일을 debug fixture에서 1회 decode하는 단계이므로, libjpeg-turbo의 SIMD 우위가 실제 병목으로 드러나는 상황이 아니다.

## 결정

#2_6 codec leaf:

```text
stb_image 기반 Core leaf
```

장기 성능 leaf:

```text
libjpeg-turbo는 ResourceManager / async streaming / 대량 texture load에서 decode 비용이 측정 가능한 병목이 될 때 switch-table 뒤에서 드롭인한다.
```

## 근거

- JPEG decode는 #2_6에서 매 프레임 비용이 아니라 debug fixture 1회 로딩 비용이다.
- 성능이 실제로 중요해지는 지점은 ResourceManager의 병렬 decode, async I/O, GPU upload batching, memory reuse다.
- libjpeg-turbo는 성능 endgame으로 타당하지만 NASM/prebuilt/lib 관리, 라이선스/업데이트/빌드 의존성이 생긴다.
- #2_6에서는 그 영구 비용을 지불해도 측정 가능한 성능 이득이 없다.
- switch-table 구조가 leaf 교체를 허용하므로 stb -> libjpeg-turbo 마이그레이션 비용은 낮게 유지된다.

## 수정된 codec 구조

```text
Codec::DecodeImageRgba8(path, bytes)
    -> extension switch
        .jpg/.jpeg -> DecodeJpgToRgba8_STB
```

나중에:

```text
Codec::DecodeImageRgba8(path, bytes)
    -> extension switch
        .jpg/.jpeg -> DecodeJpgToRgba8_Turbo
        .png       -> DecodePngToRgba8
```

## 매니페스트 보정

삭제:

```text
HAL/Private/PlatformImageDecoder.h
Platform/Windows/Private/PlatformImageDecoder.cpp
```

추가/수정:

```text
ThirdParty/stb/stb_image.h 또는 동등한 third-party 위치
Core/Private/Codec.cpp 내부 JPG leaf
CyphenEngine.vcxproj third-party include/path or file item
```

## 유지되는 계약

- `Codec::DecodeImageRgba8` facade는 유지한다.
- 확장자 기반 switch-table은 유지한다.
- 출력은 canonical `DecodedImageRgba8`다.
- Renderer/backend는 encoded image bytes나 source format을 모른다.
- Renderer ABI는 `createTextureRgba8` 그대로 유지한다.
