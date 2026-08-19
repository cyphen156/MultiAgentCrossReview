# Package Propagation - 워크벤치 간 공용 도구 전파

이 워크벤치의 `Packages/` 와 공용 루트 스크립트가 다른 로컬 워크벤치로 어떻게 흘러가는지
정의합니다.

## 문제

새 워크벤치를 만들 때 이 워크벤치의 `Packages/` 를 `Copy-Item` 으로 한 번 복사하는
방식이었습니다. 그것은 **복사 시점의 스냅샷**일 뿐 이후 연결이 없습니다. 원본을 고쳐도
사본은 그대로 남고, 사본을 고쳐도 원본은 모릅니다.

결과는 실측으로 확인됐습니다.

- 같은 워크벤치의 머신 두 대 사이에서 `Packages/` 구성이 달랐습니다.
  WorkbenchStateSync 는 `Projects/` 와 `UserSettings/` 만 운반하고 `Packages/` 는
  운반하지 않으므로, 한번 갈라진 스캐폴드는 저절로 수렴하지 않습니다.
- `AgentSessionSync/README.md` 가 워크벤치마다 다른 판본으로 남아 있었습니다.
- 미러 스크립트는 워크벤치마다 통째로 복제됐고, 복제본끼리 각자 수정됐습니다.

미러 스펙을 데이터로 분리해도(`Common/MIRROR_SPEC.md`) 이 문제는 남습니다. **스펙이
아무리 깔끔해도 스크립트 자체가 흐르지 않으면 다음 머신에서 또 갈라집니다.**

## 모델

- **SSOT 는 이 워크벤치입니다.** `C:\ClaudCode Project\Packages\` 와 루트의 공용
  스크립트가 원본입니다.
- 다른 워크벤치는 **받기만** 합니다. 대상에서 고친 내용은 다음 전파에서 덮입니다.
  고칠 것이 있으면 이 워크벤치에서 고치고 다시 보내십시오.
- 전파는 **반복 가능**합니다. 언제든 다시 실행하면 대상이 현재 원본과 같아집니다.

## 파일

| 파일 | 추적 | 내용 |
|---|---|---|
| `Packages/packages.manifest.json` | 공개, 추적됨 | 무엇이 패키지인지, 각 패키지에서 덮으면 안 되는 머신 로컬 파일은 무엇인지, 어떤 루트 파일이 공용인지 |
| `UserSettings/package-targets.json` | 머신 로컬, gitignore | 어디로 보낼지, 각 대상이 무엇을 받을지 |
| `Packages/Sync-Packages.ps1` | 공개, 추적됨 | 전파 실행기 |

`package-targets.json` 이 머신 로컬인 이유는 절대 경로이기 때문입니다. 머신마다
워크벤치 위치가 다르므로 운반하지 않고 각 머신에서 다시 만듭니다.

## 사용법

```powershell
.\Packages\Sync-Packages.ps1 -List
.\Packages\Sync-Packages.ps1 -DryRun
.\Packages\Sync-Packages.ps1
.\Packages\Sync-Packages.ps1 -Target 'C:\Project\ProjectDC'
```

`-Target` 은 **등록된 대상 중 하나만 처리한다는 필터**입니다. 미등록 경로를 주면
실패합니다. 대상이 무엇을 받을지는 언제나 `package-targets.json` 이 정합니다.

## 대상이 받는 것을 대상별로 정하는 이유

워크벤치마다 계약이 다릅니다. 모두에게 전부 보내면 안 됩니다.

- **미러하지 않는 워크벤치에 `ProjectSync` 를 보내면 안 됩니다.** 읽기 전용 증거
  인벤토리만 만드는 워크벤치는 보호된 원본을 미러하지 않습니다. 같은 이름으로 다른
  계약이 생기고, `-Project` / `-ResetEdit` 를 안내하는 README 가 거짓이 됩니다.
- **루트 `sync.ps1` 은 계약이 겹칠 수 있습니다.** 어떤 워크벤치는 같은 파일명으로
  전혀 다른 일(증거 인벤토리 생성)을 합니다. 그런 대상에 미러 스크립트를 보내면
  그 워크벤치의 스크립트를 파괴합니다.
- **`Packages/` 계층을 쓰지 않는 워크벤치도 있습니다.** 자기 `Start.ps1` 이 Vault
  런처를 직접 호출하고 세션 동기화를 의도적으로 제외하는 구성이라면, 어댑터를 받는 것이
  오히려 설계 위반입니다. 그런 대상은 루트 공용 스크립트만 받습니다.

그래서 `packages`, `files`, `rootFiles` 를 대상별로 적습니다. 빈 배열은 "이건 받지
않는다"는 **명시적 결정**이며, 이유를 `note` 에 적어 둡니다.

## 머신 로컬 설정 보호

`packages.manifest.json` 의 `keepLocal` 에 적힌 파일은 대상에 이미 존재하면 덮지
않습니다. 대상 워크벤치의 `VaultRoot` / `SourceRoot` 설정을 전파가 날리면 안 됩니다.
`*.config.example.psd1` 은 예시이므로 보호 대상이 아니며 항상 갱신됩니다.

## 새 머신에서

1. 이 워크벤치를 clone 하고 WorkbenchStateSync 로 상태를 받습니다.
2. `UserSettings/package-targets.json` 을 그 머신의 경로로 만듭니다.
3. `.\Packages\Sync-Packages.ps1 -DryRun` 으로 확인하고 실행합니다.

`Copy-Item` 으로 `Packages/` 를 직접 복사하지 마십시오. 그것이 애초의 원인이었습니다.
