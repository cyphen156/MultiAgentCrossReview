Date: 2026-06-22
Question-ID: Q001
Author: Claude
Responds-To: Questions/Q001.md (사용자 제출 #2_5 구현안)
Supersedes: none
Status: Cross-Review-Complete
Baseline: 2026-06-22T23:29 sync

# Q001 #2_5 구현안 교차검증 (Claude)

## 총평
전반 설계는 탄탄하다. 잘 잡힌 점:
- ABI 규율: POD + static_assert(Word/Header/Payload/List 크기 고정, x64 가정)
- device 스레드 친화: createRenderer / executeCommandList / destroyRenderer 모두 Render Thread
- 방어적 파서: 경계검사(payloadWordCount > 남은 word) + 무결성 재검증(currentWord / commandCount 일치)
- 버퍼 재활용: Swap으로 정상상태 무할당 (writable / pending / executable 3버퍼 회전)

차단 후보 1건, 스타일 규칙 위반 1건, 범위(과설계) 판정 1건.

## 1. 시작 핸드셰이크 lost-wakeup 위험 (correctness, 조건부)
근거: threadState는 std::atomic이고 Run()은 SetThreadState(Running) 후 threadCondition.notify_all().
Initialize는 threadCondition/threadMutex로 대기(대기 코드 제안 미포함).

문제: cv 술어가 의존하는 변수는 atomic이라도 mutex를 잡은 채 변경해야 깨움 유실이 없다.
SetThreadState가 threadMutex를 안 잡고 store만 하면 다음 인터리빙에서 영구 대기:
	Engine: lock; wait(pred) → pred()=false 평가 (lock 보유)
	Render: state.store(Running); notify_all();  // Engine이 cv.wait 진입 전
	Engine: cv.wait(lock) 진입 → notify 유실 → 영구 대기
queueCondition 쪽은 isAccepting/hasPending을 항상 queueMutex 안에서 변경하므로 안전.
문제는 threadState만 mutex 밖에서 바뀔 수 있다는 점.

개선안: Initialize가 관찰하는 startup 전이(Running/Failed)는 threadMutex를 잡은 채 변경 후 notify.
SetThreadState 본문과 Initialize 대기 루프가 제안에 빠져 검증 불가 → 두 조각 확정 필요.

## 2. 람다 금지 위반 (style, 베이스라인 must-fix)
근거: Common/SHARED_RULES.md 2장 "람다 금지 — JS 또는 외부 데이터 콜백에만 허용".
문제: RenderCommandQueue.cpp Submit/WaitAndAcquire가 queueCondition.wait(lock, [this](){...}) 술어 람다 사용.
개선안: 명시적 while 루프로 동일 의미 표현(람다 제거).

## 3. Word Stream 범위 (design 판정)
근거: SHARED_RULES "과설계 경계 — Skull stream-container식 반복 금지", "작은 검토 가능한 패치".
문제: 명령은 Clear/Present 둘인데 Word+Header/Payload 인코딩+padding zero-fill+무결성 재검증까지 완전한
스트림 인프라를 먼저 세운다. 최소 typed 명령으로 충분할 수 있다.
반대 근거: 지금 스트림 ABI를 두면 파괴적 ABI 변경을 피하고 인코딩이 격리된다.
→ 결함 아닌 사용자 판정 사항. 권고: 스트림 골격 유지하되 명령 3~4종 전까지 가변 Payload 추가 보류.

## 낮은 우선순위 / 메모
- Shutdown의 threadCondition.notify_all()은 잉여(Render Thread는 queueCondition에서 대기).
- DXGI: 창=메인 스레드, swapchain=Render Thread 생성 → Alt+Enter/리사이즈 경고 가능. WM_SIZE 미처리는 의도된 보류.
- 파이프라이닝: queue depth 1 + blocking Submit + Present(1,0) → engine↔render 거의 lock-step.
  (→ 008에서 사용자 교정 수용: 실제로는 ≤1프레임 선행)
- Render()가 append bad_alloc에도 false→엔진 종료. OOM이라 수용 가능하나 일시/치명 구분 메모.
- 동기화 원시: Module에서 std::mutex/cv 직접 사용. Core/Thread.h 정책과 통일 여부 확인.
- DevLog: #2_5는 SHARED_RULES 4장 포맷으로 별도 항목 작성 필요(제안 미포함, 적용 주체가 작성).

## 종합
흐름과 소유권 분리는 #2_4 결론과 정합. 차단 이슈는 #1(핸드셰이크 동기화) 하나이며 미포함 코드에 달림.
#2(람다)는 기계적 수정, #3(스트림 범위)은 판정 사항.
