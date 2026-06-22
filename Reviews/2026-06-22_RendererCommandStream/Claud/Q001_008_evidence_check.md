Date: 2026-06-22
Question-ID: Q001
Author: Claude
Responds-To: Claud/Q001_003_cross_review.md + 사용자 보정 응답
Supersedes: none
Status: Converged
Baseline: 2026-06-22T23:29 sync

# Q001 #2_5 수렴 확인 (Claude, 증거 재확인)

사용자가 003 교차검증에 대해 보정 응답을 제출. 각 항목 재확인 결과:

## 1. Lost-wakeup — 해소 확인
사용자 공개 코드:
	SetThreadState() { std::lock_guard lock(threadMutex); threadState.store(state); }
	Initialize() { unique_lock lock(threadMutex);
	  while (state != Running && state != Failed) threadCondition.wait(lock);
	  startupState = state.load(); }
SetThreadState가 threadMutex를 잡고 store, Initialize가 같은 mutex로 술어 검사·대기,
notify는 unlock 이후 → 정석 패턴(수정[락 안] → 해제 → notify). lost-wakeup 없음.
003 지적은 "불변식 충족 시 안전, 코드 미포함이라 검증 불가"의 조건부였고 본문 공개로 충족 확인.
→ 인정. SetThreadState의 mutex 불변식을 전체 코드에 명시하기로 함.

## 2. 람다 제거 — 변환 논리 검증 통과
기계적 while 변환은 술어 반전(De Morgan)에서 버그가 잦은 지점이라 직접 대조:
- Submit: 진행 조건 !isAccepting||!hasPending → 대기 조건 isAccepting&&hasPending
  → while (isAccepting && hasPending)  [정확]
- WaitAndAcquire: 진행 조건 !isAccepting||hasPending → 대기 조건 isAccepting&&!hasPending
  → while (isAccepting && hasPendingCommandBuffer == false)  [정확]
Stop 이후 경로 보존: Submit은 isAccepting==false면 즉시 false(생산자 거부),
WaitAndAcquire는 hasPending 남으면 마지막 1개 소비 후 false(graceful drain). 회귀 없음.

## 3. Word Stream — 결정 존중 + 가드레일 수용
사용자: 비용 확인 후 이미 선택한 결정. 재논의 대상 아님(Decision은 사용자 권한).
수용된 범위 제한: Clear/Present만, 범용 serializer·중첩 stream·압축·가변 문자열·범용 Payload API 금지,
명령 실제 발생 시에만 타입/Payload 추가. 이 제한이 명시되는 한 과설계 우려 해소.

## 나머지 — 동의 / 제 표현 교정
- Shutdown notify 제거: 동의.
- lock-step: 003의 "사실상 lock-step"은 과했음. depth 1은 생산자가 슬롯 채우고 ≤1프레임 선행 가능.
  → 교정 인정.
- Mutex/CV 래퍼 미도입: Thread=수명 추상 / 동기화 정책=별개라는 구분 타당, 이번 범위 제외 동의.
- Resize/Alt+Enter/WM_SIZE 이월: 동의.

## 결론
차단 이슈 없음. 필수 반영 = 람다 제거(완료, 논리 검증됨) + SetThreadState mutex 불변식 명시.
Word Stream 결정 유지 + 범위 가드레일. 나머지 의도된 이월.
이 보정본 기준 전체 코드 작성 진입 가능 — Claude 측 차단 근거 없음.
실제 원본 코드 적용·DevLog 작성·커밋은 사용자가 수행.
