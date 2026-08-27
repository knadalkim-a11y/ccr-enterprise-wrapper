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
- Avoid: build/runtime 증거는 실제 target인 사내 Windows에서 수집하고, 별도 PC/CI/PRoot는 필요할 때만 보조로 사용함
- Detect: `node -p "process.platform"`이 `android`를 반환함
- Evidence: `V1-S0-T01` Attempt 1, PR #8, main commit `4ce3fad7067065fc87c9c6ae4603303c1f22fd6e`
- Recheck when: CCR의 `better-sqlite3` 버전 또는 Android native addon 지원 상태가 변경됨

이 Trap은 Android에서 프로젝트를 관리하거나 코드를 작성하지 말라는 뜻이 아니다.
Git·문서·에이전트 제어는 native Termux에서 계속 수행하고, native addon과 Windows 동작 증거만 target environment로 분리한다.

## TRAP-002 — `npm ci` exit code만으로 Windows 설치 무결성을 판정하지 말 것

- Status: `RECHECK`
- Scope: Internal Windows source install validation
- Applies to: CCR `v3.0.22`, Windows 11 Enterprise, Node `v24.15.0`, npm `11.12.1`, x64
- Symptom: 첫 `npm ci`가 exit `0`을 반환했지만 `node_modules/.bin`이 없었고 후속 typecheck에서 `tsc`가 인식되지 않음
- Root cause: `UNKNOWN` — 단일 관찰이며 재현되지 않음
- Avoid: `npm ci` exit code와 함께 실제 typecheck/build/runtime 명령을 반드시 실행해 설치 무결성을 확인함
- Detect: `Test-Path node_modules\.bin\tsc.cmd`가 `False`이거나 후속 npm script가 설치 도구를 찾지 못함
- Recovery: 제품 파일을 수정하지 않고 `node_modules`만 삭제한 뒤 clean `npm ci`를 한 번 재실행하고 최초/재시도 결과를 모두 기록함
- Evidence: `V1-S0-T01` Attempt 2, tested commit `97b73a9f4e1fb23d406bb987d0785cefa1f99966`
- Recheck when: 다음 Windows clean install validation 또는 npm/Node/CCR dependency 조합 변경 시

`RECHECK`는 확정된 CCR 또는 npm 결함을 뜻하지 않는다.
동일 증상이 반복 재현되거나 원인이 확인되기 전까지 검증 절차상의 주의사항으로만 취급한다.

## TRAP-003 — Host-scoped credential의 401을 protocol failure로 오분류하지 말 것

- Status: `ACTIVE`
- Scope: Internal Provider/gateway/model validation
- Applies to: V1-S1 이후의 사내 LLM 요청
- Symptom: Credential은 존재하지만 발급 범위와 다른 validation host/source identity에서 요청하면 `401`이 발생함
- Root cause: Credential이 특정 PC, source IP, NAT/proxy egress, account 또는 model entitlement scope에 묶여 있음
- Avoid: model request 전 `LLM_CREDENTIAL_AUTHORIZED_FOR_HOST` preflight를 수행하고, 선택한 host에 승인된 credential을 정식 발급받거나 승인된 scope 확장 절차를 사용함
- Detect: serving 운영 정책상 credential의 allowed host/source scope가 현재 validation host와 일치하지 않음; 실제 값은 외부에 기록하지 않음
- Classification: `BLOCKED_CREDENTIAL_HOST_SCOPE`
- Do not classify as: `PROTOCOL_COMPATIBILITY`, generic `AUTHORIZATION`, CCR source defect, model defect
- Recovery: 승인된 host/credential 조합으로 같은 Task만 재실행함. Key 공유, proxy/tunnel, allowlist 우회는 사용하지 않음
- Evidence: `V1-S1-T01` Attempt 1, Issue #15; selected validation host에서 401이 발생했고 credential은 다른 host/source scope에 한정됨
- Recheck when: credential 발급 또는 allowlist 정책이 변경되거나 host-independent credential이 제공됨

Provider-only Task는 credential-authorized Windows host에서 수행할 수 있다.
Claude Code E2E는 추가로 `CLAUDE_CODE_EXECUTION_ALLOWED`가 있는 host에서 수행해야 한다.

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
