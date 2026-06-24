Date: 2026-06-24
Question-ID: Q001
Author: Claude
Responds-To: 06-24 저녁 세션(스레드 경계·command 생성 위치·policy/state·Dx11 역할) 사용자↔Codex 수렴 + Claude 교차검증
Supersedes: Claud/Q001_027_locked_implementation_draft.md 의 스레드 배치·command 구조 부분 (아래 명시)
Status: Architecture-Lock
Baseline: 설계 합의(코드 미적용). 적용·빌드는 사용자.

# #2_6 스레드/Command 아키텍처 고정점

오늘(06-24) thread-cut이 네 번 오갔다(engine-encode ↔ render-encode, RHI thread 등). 더 안 뒤집게
단일 기준점으로 고정한다. **firm 불변식과 movable 변수를 분리**하는 게 핵심.

## 4개 축 (락)

```
1. Frame        = immutable world/render snapshot  (command packet 아님)
2. RenderCommand = Renderer policy 결과물
3. Dx11Renderer  = API state materializer          (policy 결정 금지)
4. ResourceId    = CPU-side logical handle, backend 내부 table로 resolve
```

## 스레드 책임

```
EngineThread
  - 월드 상태 확정
  - Frame snapshot 생성 (Object/Transform/ResourceId/Bounds/Layer/Camera)

RenderThread / Renderer  ── 렌더링 POLICY
  - Frame 해석
  - visibility / culling / occlusion / sorting / batching / pass 구성
  - RenderCommand / ResourceCommand 생성 (encode)

Dx11Renderer  ── API MECHANISM
  - command parse → D3D11 state 구성
  - resource bind, redundant bind skip
  - Draw / Present 제출
```

경계 한 줄: **Dx11Renderer는 "그래픽스 API state"를 만든다. Renderer는 "렌더링 policy"를 만든다.**
("parse 쪽에서 그래픽스 계산"은 과함 — visibility/lighting이 backend로 새서 backend마다 중복. "API 상태
계산 + 바인딩 최적화"까지가 backend.)

### 상태 최적화는 2층 (중복 아님)
- **Renderer(policy)**: 비슷한 draw를 인접하게 **정렬**(순서 결정)
- **Dx11Renderer(mechanism)**: 받은 순서에서 이미 bind된 state/resource면 **재바인딩 생략**

## 스레드 스펙트럼 (movable 변수)

firm한 건 위 4축뿐. **스레드 개수는 움직이는 변수.**

```
#2_6 (2-thread):  Engine | RenderThread(여기서 Renderer + Dx11Renderer 함께 구동)
#3   (3-thread):  Engine | RenderThread=Renderer(encode) | BackendThread=Dx11Renderer(submit) | GPU
```

- **policy/state 코드 경계 = 미래 RenderThread/BackendThread 스레드 경계.** 같은 선. 지금 코드 경계만
  깨끗이 그어두면 #3 분리는 스레드 재배치로 끝남(코드 경계 ≠ 스레드 경계 — 지금 모듈 경계 고정, 스레드는 나중).
- encode 위치 = **RenderThread**(기본값). "EngineThread encode / RenderThread submit-only"는 *틀린 게
  아니라* **#3의 BackendThread(RHI submit) seam**이다. submit-only 스레드도 지연 디커플링 + D3D11 단일
  컨텍스트 이득은 유지 — degenerate 아님. 단 #2_6은 Frame 계층 보존 + 단순성 때문에 RenderThread-encode 채택.

## Command IR 구조 (락)

- **도메인 분리**: `RenderCommand`(Clear/Present/DrawTexturedQuad) ↔ `ResourceCommand`(UploadResource/
  DestroyResource). 각 전용 버퍼가 같은 `ModuleCommandBuffer`를 내부 운반체로 wrap.
- 버퍼 중복은 **상속 아니라 template**으로: `DomainCommandBuffer<TCommandType>` (composition 유지,
  타입세이프, vtable 0). 또는 얇은 래퍼 2개(허용). **상속 금지**(base AppendCommand 노출 → 도메인 제한 우회).
- command payload struct는 **flat POD**(ABI memcpy). 상속 금지(layout/vtable 위험, 공유 필드 없음).
- **두 enum 모두 1부터** → backend는 **도메인별 실행 진입점**(`ExecuteResourceCommands`/
  `ExecuteRenderCommands`) 필요. **통합 switch 금지**(1=Upload vs 1=Clear 충돌).
- 파일 배치: `Modules/Public`(ModuleCommand*), `Modules/Renderer/Public`(RenderCommand*),
  `Modules/Resource/Public`(ResourceCommand*). `Source/Resource`는 **순수 데이터**(Resource/Texture2D)만.

## #3-readiness 불변식 (지금 충족, 깨지 말 것)

1. command list = **self-contained ABI-safe immutable** (엔진 라이브 상태 참조 없음; 업로드는 픽셀 inline)
2. **encode 완료 → submit** (단계 분리, 인터리브 금지)
3. command buffer **move-only** (double-buffer)
4. 리소스는 **upload command + backend 소유 table** (CPU 스레드가 D3D11 직접 생성 X)
\+ D3D11 immediate context는 **정확히 한 스레드 소유**(지금 RenderThread → #3 BackendThread로 이동).

## 리소스 모델

- backend는 **타입별 dense 배열** 소유(`textures[]`), `DrawTexturedQuad`는 그 배열만 조회(kind 분기/다운캐스트 없음).
- **wire는 안정 핸들(ResourceId)**, 생짜 위치 인덱스 금지(레이아웃 누수 + destroy 시 깨짐). backend가 슬롯 매핑.
- #2_6: ResourceId = dense 정수, 직접 인덱싱. **destroy/재사용 도입 시 `{index, generation}` 패킹으로 승격.**
- `Texture2DUploadPayloadHeader` = `{format, width, height}` (byteCount 제거 — `width*height*4`로 유도).
- `DestroyResource`는 2번째 타입 배열 생기면 **ResourceKind 필요**(라우팅) 또는 전 배열 스캔.

## 미해결 (설계 차단 아님)

- **리소스 핸드오프**: EngineThread CPU decode(File/Codec→Texture2D) → RenderThread upload. decode된
  Texture2D(픽셀)를 건네는 **pending resource 큐**(Frame과 별개) 미설계.
- **ResourceId 발급 주체**: #2_6 수동(1,2), 추후 ResourceManager allocator(전역 유니크).
- **WindowsJpegCodec 위치**: Content vs Platform/Windows(PlatformFile 선례) — OS 경계 불변식 결정.
- **셰이더**: first-light inline HLSL 임시.

## #2_6 최소형 (일반 모델의 최소 단면)

```
EngineThread : File/Codec → Texture2D 준비, Frame에 textured draw item(ResourceId)
RenderThread : (1회) ResourceCommand로 upload  (매 프레임) Frame→RenderCommand(Clear+DrawTexturedQuad+Present)
Dx11Renderer : quad pipeline / SRV bind / DrawIndexed(6), Present
```
cull/sort/batch/다타입/다패스 없음 → RenderThread "해석"이 거의 1:1. 이들은 씬이 생길 때 실체화.

## Q027 대비 변경 (supersede)

- 스레드: Q027의 "engine/부트스트랩이 command list 작성" → **RenderThread가 encode**.
- enum: Q027의 단일 `RenderCommandType`+100번대 → **RenderCommand/ResourceCommand 분리 enum**.
- backend: Q027 통합 switch → **도메인별 실행 진입점**.
- 버퍼: Q027의 `RenderCommandWrite` 자유함수(ModuleCommandBuffer 직접) → **도메인 버퍼(template) + RenderThread encode**.
- `Texture2DUploadPayloadHeader`: byteCount 필드 제거.

Q027의 Resource 레이어·Content codec·backend 실행 골격·WIC 본문은 유효. 갱신된 구현 초안이 필요하면
본 락 기준으로 후속 작성(별도 기록).
