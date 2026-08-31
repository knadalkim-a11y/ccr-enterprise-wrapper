---
id: V1-S1-T01
stage: V1-S1
title: Finalize internal Gemma Chat provider connection in isolated runtime
kind: validation
status: blocked
blocker: V1-S1-T00
primary_actor: INTERNAL_VALIDATOR
execution_mode: human_assisted
implementation_required: false
internal_validation: required
github_write_allowed: false
candidate_sha: 97b73a9f4e1fb23d406bb987d0785cefa1f99966
instruction_sha: supplied_after_unblock
merge_policy: not_applicable
depends_on:
  - V1-S1-T00
required_capabilities:
  - WINDOWS_RUNTIME_ALLOWED
  - LLM_CREDENTIAL_AUTHORIZED_FOR_HOST
allowed_git_actions:
  - fetch
  - detached_checkout
  - show_task_at_instruction_sha
  - rev_parse
  - status
  - diff_exit_code
forbidden_paths:
  - packages/**
  - package.json
  - package-lock.json
human_decision: pending
---

# Finalize Internal Gemma Chat Provider Connection in Isolated Runtime

## Validation question

> V1-S1-T00에서 승인된 CCR runtime sandbox를 사용해 Enterprise Claude 환경을 변경하지 않으면서, 사내 Gemma Provider를 `openai_chat_completions` 전용으로 저장·영속화하고 안전하게 종료할 수 있는가?

## Current status

```text
BLOCKED_ON:
V1-S1-T00 runtime sandbox and Enterprise baseline invariance

DO NOT EXECUTE:
until V1-S1-T00 is accepted and a new instruction SHA is issued
```

기존 protocol evidence는 유효하다.
기존 CCR runtime config와 글로벌 client state를 그대로 재개하는 것은 금지한다.

## Confirmed evidence

### Attempt 1 — credential host scope

- 이전 credential이 선택한 host/source scope에서 허용되지 않아 `401`.
- 분류: `BLOCKED_CREDENTIAL_HOST_SCOPE`.
- 신규 host-authorized credential 발급 후 해소.

### Attempt 2 — protocol capability

```text
Direct OpenAI Chat Completions: PASS
CCR OpenAI Chat Completions Check Connection: PASS
CCR OpenAI Responses Check Connection: FAIL — HTTP 500
```

확인된 capability:

```text
WINDOWS_RUNTIME_ALLOWED = YES
LLM_CREDENTIAL_AUTHORIZED_FOR_HOST = YES
CLAUDE_CODE_EXECUTION_ALLOWED = YES
```

현재 Gemma V1 운영 protocol:

```text
Protocol detection mode: manual
Auto detect protocols: OFF
Selected protocol: openai_chat_completions only
OpenAI Responses: UNSUPPORTED_OR_INCOMPATIBLE, NON_BLOCKING
```

Chat PASS로 확인된 것:

- 현재 host/source scope에서 credential 사용 가능
- CCR에서 사내 Gateway까지 network/TLS path 가능
- Gemma model 식별과 권한 가능
- CCR Chat Completions probe 가능

Responses HTTP 500만으로 다음을 확정하지 않는다.

- 사내 Gateway의 공식 Responses 미지원
- CCR Responses 구현 결함
- 특정 replica 고장

## New isolation boundary

사내 복구에서 다음 side effect가 확인됐다.

```text
Enterprise Claude Code settings에 CCR Base URL/WIF/Federation 값 잔존
실제 %LOCALAPPDATA%\Claude-3p에 CCR third-party inference config 잔존
Router stop만으로 원래 Enterprise 상태가 자동 복구되지 않음
```

따라서 이 Task는 다음 조건에서만 재개한다.

```text
CCR management/service
→ approved sandbox LOCALAPPDATA

Enabled global/System-default Claude Code profile
→ 0

Actual Enterprise settings
→ immutable

Actual Claude-3p
→ immutable

Request logs / Agent observability
→ OFF
```

상세 계약은 `company/docs/CLAUDE_CODE_ISOLATION.md`와 `V1-S1-T00`을 따른다.

## Required knowledge

- `company/docs/CLAUDE_CODE_ISOLATION.md`
- `company/docs/INTERNAL_VALIDATION.md`
- `company/docs/SECURITY.md`
- `company/docs/TRAPS.md`
- `company/gates/V1-S1.md`
- `packages/core/src/providers/probe.ts`
- `packages/core/src/agents/claude-app/gateway-service.ts`
- `packages/core/src/web/management-server.ts`

## Scope after reactivation

### In scope

- exact instruction/candidate SHA 기록
- accepted sandbox launcher/manual boundary 사용
- Enterprise baseline before fingerprint
- existing Gemma Provider를 manual Chat-only로 저장
- reopen/refresh 후 Provider 영속화 확인
- Request logs OFF
- Agent observability OFF
- enabled global Claude Code profiles = `0`
- `Connect agent`, `Let's start` 미진행
- CCR 정상 종료
- Enterprise baseline after = unchanged
- product source/lockfile 무변경
- sanitized Evidence 반환

### Out of scope

- Stock CCR start/save를 실제 LOCALAPPDATA에서 실행
- System default/global Claude Code profile
- 새 Claude Code profile 생성
- `Connect agent` / `Let's start`
- local gateway basic completion
- Streaming
- Tool call/result continuation
- Claude Code 실행
- Claude App/Desktop 연결
- `/v1/responses` 추가 조사
- source/dependency/runtime DB 직접 수정
- Internal Validator GitHub write

## Reactivation contract

V1-S1-T00가 PASS한 뒤 ChatGPT Orchestrator가:

1. 이 Task를 `ready_internal`로 변경한다.
2. exact instruction SHA를 발행한다.
3. T00에서 승인된 sandbox 시작 절차를 포함한다.
4. Provider finalization 전후 Enterprise baseline equality를 요구한다.

현재 문서만으로 사내 검증을 시작하지 않는다.

## Acceptance criteria after reactivation

- [x] `WINDOWS_RUNTIME_ALLOWED = YES`
- [x] `LLM_CREDENTIAL_AUTHORIZED_FOR_HOST = YES`
- [x] Direct Chat Completions PASS
- [x] CCR Chat Completions Check Connection PASS
- [x] Responses HTTP 500 non-blocking 분리
- [ ] V1-S1-T00 Human decision `ACCEPTED`
- [ ] exact instruction/candidate SHA 기록
- [ ] accepted sandbox runtime 사용
- [ ] enabled global Claude Code profiles = `0`
- [ ] Enterprise baseline before PASS
- [ ] Provider saved PASS
- [ ] Provider persisted after reopen/refresh PASS
- [ ] Auto detect OFF
- [ ] selected protocol `openai_chat_completions` only
- [ ] Responses selected NO
- [ ] Request logs OFF
- [ ] Agent observability OFF
- [ ] Connect agent / Let's start 미진행
- [ ] CCR stop exit `0`
- [ ] Enterprise settings/Claude-3p/User/Machine env after = SAME
- [ ] manual rollback required = NO
- [ ] product diff exit `0`
- [ ] final Git status clean
- [ ] secret/raw evidence 외부 반출 없음
- [ ] Internal Validator Git write 없음
- [ ] 다음 Task 미시작

## Failure classification

- `ISOLATION_PRECONDITION`
- `ISOLATION_BREACH`
- `PROVIDER_PERSISTENCE`
- `PROTOCOL_COMPATIBILITY`
- `LOGGING_SAFETY`
- `SHUTDOWN`
- `PRODUCT_DIFF`
- `UNKNOWN`

Responses HTTP 500은 현재 Chat-only Provider의 Task failure가 아니다.

## Attempts

| Attempt | Actor / session role | Candidate | Internal result | Recommendation |
|---:|---|---|---|---|
| 1 | Internal validation | V1-S0 product tree | `BLOCKED_CREDENTIAL_HOST_SCOPE` | approved credential 필요 |
| 2 | Internal protocol validation | `97b73a9f...` | Direct Chat PASS; CCR Chat PASS; Responses HTTP 500 | Chat-only finalization 후보 |
| 3 | Internal recovery observation | same host | Enterprise client/Claude-3p CCR config persistence 확인; 수동 복구 PASS | runtime isolation prerequisite 필요 |
| 4 | Provider finalization | `97b73a9f...` | `BLOCKED_ON_V1-S1-T00` | T00 acceptance 후 재개 |

## Evidence / limitations

- Provider protocol evidence는 보존된다.
- Provider persistence와 isolated runtime finalization은 아직 증명되지 않았다.
- Local gateway completion, Streaming, Tool, Claude Code는 미검증이다.
- Claude App/Desktop은 V1 초기 범위 밖이다.

## Agent recommendation

`STOP` — V1-S1-T00가 승인되기 전에는 이 Task를 실행하지 않는다.

## Human decision

`PENDING`
