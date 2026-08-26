# Trap Registry

반복 가능하고 검증된 함정만 기록한다. 미확인 현상은 활성 Task 또는 `STATUS.md` blocker에 둔다.

## 등록 조건

- 재현되었거나 코드/공식 문서 근거가 있음
- 다시 발생할 가능성이 있음
- 회피 또는 탐지 방법이 있음
- 적용 CCR/Wrapper 버전이 명확함
- 관련 Task와 commit 증거가 있음

## TRAP-001 — Native Termux 결과를 Windows/native build 증거로 취급하지 말 것

- Status: `ACTIVE`
- Scope: Stock CCR source install/build
- Applies to: CCR `v3.0.22`, native Termux Android/arm64, Node `v26.4.0`
- Symptom: `npm ci`에서 `better-sqlite3` Android/arm64 prebuilt binary를 찾지 못하고 `node-gyp` Android NDK 설정 단계에서 실패함
- Root cause: native Termux의 Node는 `process.platform=android`이며 Windows 또는 일반 desktop native addon 배포 대상과 다름
- Avoid: build/runtime 증거는 실제 target인 사내 Windows + Node 22에서 수집하고, 별도 PC/CI/PRoot는 필요할 때만 보조로 사용함
- Detect: `node -p "process.platform"`이 `android`를 반환함
- Evidence: `V1-S0-T01` Attempt 1, PR #8, main commit `4ce3fad7067065fc87c9c6ae4603303c1f22fd6e`
- Recheck when: CCR의 `better-sqlite3` 버전 또는 Android native addon 지원 상태가 변경됨

이 Trap은 Android에서 프로젝트를 관리하거나 코드를 작성하지 말라는 뜻이 아니다.
Git·문서·에이전트 제어는 native Termux에서 계속 수행하고, native addon과 Windows 동작 증거만 target environment로 분리한다.

## Template

```markdown
## TRAP-XXX — Title

- Status: ACTIVE / RESOLVED / RECHECK
- Scope:
- Applies to:
- Symptom:
- Root cause:
- Avoid:
- Detect:
- Evidence: Task / commit / upstream path
- Recheck when:
```
