Date: 2026-06-24
Question-ID: Q001
Author: Codex
Responds-To: User correction: boolean names must use Is/Has/Can, not Should or b-prefix
Supersedes: Codex/Q001_022_content_codec_location_revision.md
Status: Implementation-Correction
Baseline: 2026-06-23T19:08 sync

# #2_6 implementation correction - boolean naming

## Correction

The current implementation draft still used:

```cpp
const bool shouldUninitialize = SUCCEEDED(initResult);
```

This violates the naming rule. New boolean names must use short `Is`, `Has`,
or `Can` style names. Do not use `should` or `b` prefixes.

## Corrected PlatformJpegCodec COM initialization block

Use this in `Source/Platform/Windows/Private/PlatformJpegCodec.cpp`:

```cpp
const HRESULT initResult = CoInitializeEx(nullptr, COINIT_MULTITHREADED);

if (FAILED(initResult) && initResult != RPC_E_CHANGED_MODE)
{
	return false;
}

const bool IsInitialized = SUCCEEDED(initResult);
```

And at the end:

```cpp
if (IsInitialized)
{
	CoUninitialize();
}
```

## Search result

The invalid name appeared in:

```text
Codex/Q001_020_codec_platform_leaf_final.md
Codex/Q001_021_full_2_6_implementation_draft.md
Codex/Q001_022_content_codec_location_revision.md
```

`020` and `021` are already superseded by later drafts. This note supersedes
`022` for the naming correction.

## Rule for the remaining #2_6 draft

New boolean identifiers:

```text
Is...
Has...
Can...
```

Forbidden for new boolean identifiers:

```text
should...
Should...
b...
```
