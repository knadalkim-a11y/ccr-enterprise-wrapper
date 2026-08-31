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
- Evidence: `V1-S1-T01` Attempt 1, Issue #15
- Recheck when: credential 발급 또는 allowlist 정책이 변경되거나 host-independent credential이 제공됨

Provider-only Task는 credential-authorized Windows host에서 수행할 수 있다.
Claude Code E2E는 추가로 `CLAUDE_CODE_EXECUTION_ALLOWED`가 있는 host에서 수행해야 한다.

## TRAP-004 — 일부 protocol 실패를 Provider 전체 실패로 해석하지 말 것

- Status: `ACTIVE`
- Scope: Custom OpenAI-compatible Provider protocol detection and connectivity
- Applies to: CCR `v3.0.22`, current internal Gemma Provider
- Symptom: 동일 endpoint/key/model에서 `openai_chat_completions`는 PASS하지만 `openai_responses`는 HTTP `500`으로 실패함
- Code behavior: CCR probe는 protocol별로 별도 endpoint/body를 전송하며 하나 이상의 protocol이 supported이면 Provider connectivity를 usable로 판정함
- Root cause: `UNKNOWN` — 사내 Gateway의 `/v1/responses` 미지원/비호환 또는 CCR Responses contract와의 비호환 가능성
- Avoid: 현재 Gemma V1 운영 config는 Auto detect OFF, manual `openai_chat_completions` only로 저장함
- Detect: protocol detail에서 Chat PASS와 Responses FAIL이 분리되어 나타남
- Classification: Responses는 `UNSUPPORTED_OR_INCOMPATIBLE`; 현재 Gemma V1에서 non-blocking
- Do not classify as: Provider 전체 실패, credential failure, Gemma model failure, 특정 replica failure 확정
- Recovery: 검증된 Chat protocol로 진행하고 Responses는 공식 지원 여부 또는 별도 compatibility Task에서 확인함
- Evidence: `V1-S1-T01` Attempt 2; direct Chat PASS, CCR Chat PASS, CCR Responses HTTP 500; `packages/core/src/providers/probe.ts`
- Recheck when: 사내 Gateway가 `/v1/responses` 공식 지원을 선언하거나 CCR/Gateway version이 변경됨

부분 성공 UX가 혼동을 일으킬 수 있지만 현재 V1에서는 Core patch보다 Company-managed Chat-only config를 우선한다.

## TRAP-005 — Router stop을 Claude Code Enterprise 설정 rollback으로 간주하지 말 것

- Status: `ACTIVE`
- Scope: Claude Code global/System-default profile and Enterprise auth
- Applies to: CCR `v3.0.22`, internal Windows
- Symptom 1: Router stop 후 Claude Code가 `127.0.0.1:3456` token endpoint를 계속 호출함
- Symptom 2: Base URL 제거 후 `federation_rule_id does not have prefix 'fdrl_'` 오류가 발생함
- Confirmed residual settings:
  - `ANTHROPIC_BASE_URL`
  - `ANTHROPIC_API_BASE_URL`
  - `CLAUDE_AGENT_API_BASE_URL`
  - `ANTHROPIC_FEDERATION_RULE_ID = ccr-local`
  - `ANTHROPIC_IDENTITY_TOKEN_FILE = CCR-managed file`
  - `ANTHROPIC_ORGANIZATION_ID = ccr-local`
- Code basis: CCR global profile apply는 Gateway URL, WIF/Federation, model/helper/MCP 값을 Claude Code settings에 기록할 수 있음
- Root cause: global/System-default client config가 Router lifecycle과 독립적으로 persistent storage에 남을 수 있음; 해당 실행에서 자동 restore가 Enterprise 상태를 보장하지 못함
- Avoid:
  - V1에서 `System default` 금지
  - `Only opened from CCR` + CLI-only 사용
  - Enterprise baseline before/during/after equality 검사
- Detect: 기본 `%USERPROFILE%\.claude\settings.json`에 CCR-managed Base URL/WIF/model/helper marker 존재
- Classification: `CLIENT_AUTH_CONFIG_PERSISTENCE`, `ROLLBACK_GAP`, `ISOLATION_BREACH`
- Recovery: Human Gate Owner가 승인된 로컬 backup 또는 알려진 Enterprise baseline으로 복구함; Internal Validator가 runtime DB/source를 수정하지 않음
- Evidence: V1-S1-T01 recovery observation; `packages/core/src/profiles/service.ts`
- Recheck when: isolated profile/stop repeatability Task가 통과하거나 upstream global restore logic이 변경됨

수동 복구에 성공해도 해당 isolation Task는 PASS가 아니다.
정상 lifecycle은 rollback이 필요 없어야 한다.

## TRAP-006 — `Only opened from CCR`만으로 실제 Claude-3p side effect가 격리된다고 가정하지 말 것

- Status: `ACTIVE`
- Scope: CCR management/config save and Claude Desktop third-party inference configuration
- Applies to: CCR `v3.0.22`, Windows
- Symptom: 일반 Claude Desktop이 CCR local model만 표시하거나 CCR service 종료 후 정상 모델로 자동 복귀하지 않음
- Confirmed recovery: `%LOCALAPPDATA%\Claude-3p`의 CCR third-party inference config를 제거하자 일반 Claude Desktop 정상 복귀
- Code behavior:
  - management startup/config save는 `syncClaudeAppGatewayConfig`를 호출할 수 있음
  - Windows default target은 `%LOCALAPPDATA%\Claude-3p`
  - `start --no-gateway`라도 UI save는 sync path를 호출할 수 있음
- Root cause: Claude Code profile scope와 Claude App Gateway sync는 별도 메커니즘임
- Avoid:
  - CCR service/admin process를 process-local sandbox `LOCALAPPDATA`로 실행
  - actual Claude-3p before/during/after fingerprint equality 확인
  - CLI-only scope에서 Claude App/Desktop 연결 금지
- Detect: actual Claude-3p fingerprint 변경 또는 일반 Claude Desktop 모델/인증 변경
- Classification: `CLAUDE_APP_CONFIG_PERSISTENCE`, `ISOLATION_BREACH`
- Recovery: Human Gate Owner가 local backup/known baseline으로 복구함
- Evidence: V1-S1 recovery observation; `packages/core/src/agents/claude-app/gateway-service.ts`; `packages/core/src/web/management-server.ts`
- Recheck when: `V1-S1-T00` sandbox가 통과하거나 explicit Claude App sync-disable option이 구현됨

`Only opened from CCR`는 Claude Code settings 격리에 유효하지만 전체 CCR Runtime side effect 격리를 의미하지 않는다.

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
