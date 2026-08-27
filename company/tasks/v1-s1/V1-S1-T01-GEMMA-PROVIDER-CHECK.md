---
id: V1-S1-T01
stage: V1-S1
title: Internal Gemma provider connection check
kind: spike
status: in_progress
session_role: validation
internal_validation: required
depends_on:
  - V1-S0-T02
allowed_paths:
  - company/tasks/v1-s1/V1-S1-T01-GEMMA-PROVIDER-CHECK.md
  - company/docs/STATUS.md
  - company/gates/V1-S1.md
forbidden_paths:
  - packages/**
  - package.json
  - package-lock.json
human_decision: pending
---

# Internal Gemma Provider Connection Check

## Validation question

> Stock CCR가 사내 Windows에서 source 수정 없이 사내 OpenAI-compatible Gemma Provider 한 개를 저장하고, host-authorized credential로 선택한 모델 한 개의 지원 protocol 연결을 통과할 수 있는가?

## Current result

Credential host-scope blocker는 신규 key로 해소되었다.
현재까지 확인된 protocol capability는 다음과 같다.

```text
Direct OpenAI Chat Completions request: PASS
CCR OpenAI Chat Completions Check Connection: PASS
CCR OpenAI Responses Check Connection: FAIL — HTTP 500
```

현재 V1 Gemma 공식 upstream protocol:

```text
openai_chat_completions
```

OpenAI Responses는 현재 `UNSUPPORTED_OR_INCOMPATIBLE`이며 V1-S1-T01의 non-blocking deferred capability다.
Provider 저장·영속화, logging safety, stop, product diff/final git status가 아직 최종 확인되지 않아 Task는 `in_progress`다.

## Why now

V1-S0에서 Stock CCR의 Windows install, build, CLI start/stop이 통과했다.
Gemma는 현재 serving 환경에서 먼저 사용할 수 있고 GLM은 rollout 대기 중이다.
이 Task는 local gateway client, streaming, tools, Claude Code로 확대하기 전에 Provider-level 최소 연결만 닫는다.

## Roles

```text
INTERNAL_VALIDATOR
→ 사내 Windows에서 pull-only 검증과 sanitized 결과 반환

CHATGPT_ORCHESTRATOR
→ 사용자에게 전달받은 결과로 Task/STATUS/Gate/Issue 갱신
```

Internal Validator는 GitHub 파일을 수정하거나 commit/push하지 않는다.
상세 기준은 `company/docs/ROLES_AND_HANDOFF.md`와 `company/docs/INTERNAL_VALIDATION.md`를 따른다.

## Required knowledge

- `docs/src/content/docs/en/configuration/providers.md`
- `docs/src/content/docs/en/configuration/api-keys.md`
- `packages/core/src/providers/probe.ts`
- `packages/cli/README.md`
- `company/docs/ROLES_AND_HANDOFF.md`
- `company/docs/SECURITY.md`
- `company/docs/INTERNAL_VALIDATION.md`
- `company/docs/ENVIRONMENTS.md`
- `company/gates/V1-S1.md`

## Confirmed host capabilities

```text
WINDOWS_RUNTIME_ALLOWED = YES
LLM_CREDENTIAL_AUTHORIZED_FOR_HOST = YES
CLAUDE_CODE_EXECUTION_ALLOWED = YES
```

Provider check에는 앞의 두 capability가 필요하다.
세 번째 capability는 이후 Claude Code E2E에서 사용한다.

## Protocol evidence

CCR `v3.0.22` probe는 protocol별로 서로 다른 request를 보낸다.

```text
openai_chat_completions
→ POST /v1/chat/completions
→ messages + max_tokens

openai_responses
→ POST /v1/responses
→ input + max_output_tokens
```

Observed result:

| Protocol | Result | V1 meaning |
|---|---|---|
| `openai_chat_completions` | `PASS` | Gemma V1 official upstream protocol |
| `openai_responses` | `FAIL`, HTTP `500` | `UNSUPPORTED_OR_INCOMPATIBLE`, non-blocking, deferred |

Chat Completions PASS로 다음이 확인됐다.

- 현재 host/source scope에서 credential 사용 가능
- CCR에서 사내 Gateway까지 network/TLS path 가능
- Gemma model 식별과 권한 가능
- CCR Chat Completions probe request 가능

Responses 500만으로 다음을 확정하지 않는다.

- 사내 Gateway가 모든 Responses 요청을 공식 미지원
- CCR Responses 구현 결함
- 특정 vLLM replica 고장

추후 분류:

```text
PowerShell /v1/responses도 실패
→ INTERNAL_GATEWAY_UNSUPPORTED_OR_INCOMPATIBLE

PowerShell /v1/responses는 성공하고 CCR만 실패
→ CCR_RESPONSES_COMPATIBILITY
```

이 추가 확인은 현재 Task와 V1 진행을 막지 않는다.

## In scope

- exact tested product commit 또는 동등 product tree 기록
- Chat Completions 전용 Gemma Provider 설정
- Auto detect protocols OFF
- Provider 저장과 reopen/refresh 후 영속화 확인
- Request logs / Agent observability 안전 상태 확인
- CCR 정상 종료
- 제품 source와 lockfile 무변경 확인
- sanitized evidence 반환

## Out of scope

- `Connect agent`
- `Let's start`
- CCR client API key
- local gateway basic completion
- streaming
- tool call/result continuation
- full error matrix
- `/v1/responses` root-cause investigation
- GLM Provider
- Claude Code 실행
- Wrapper/Routing/Telemetry/V2 구현
- source/dependency/script 수정
- Internal Validator의 GitHub write

## Required operating configuration

```text
Provider alias: internal_gemma
Model alias: internal_gemma_primary
Protocol detection mode: manual
Auto detect protocols: OFF
Selected protocol: openai_chat_completions only
OpenAI Responses selected for operation: NO
```

실제 endpoint, key, model ID, host/IP, management URL/token은 외부 Evidence에 기록하지 않는다.

## Remaining internal finalization

1. 현재 repository HEAD와 clean working tree를 기록한다.
2. 기존 Provider를 중복 생성하지 않고 Chat Completions 전용으로 저장한다.
3. Provider 목록 또는 reopen/refresh 후 설정이 유지되는지 확인한다.
4. `Connect agent`와 `Let's start`는 수행하지 않는다.
5. 실제 사용자 prompt 전에 Request logs와 Agent observability를 OFF로 유지한다.
6. CCR를 `stop`으로 종료한다.
7. product diff와 final git status를 확인한다.
8. `ROLES_AND_HANDOFF.md` 형식으로 sanitized 결과만 반환한다.

## Acceptance criteria

- [ ] exact final tested product commit 또는 동등 product tree 기록
- [ ] working tree before finalization clean
- [x] `WINDOWS_RUNTIME_ALLOWED = YES`
- [x] `LLM_CREDENTIAL_AUTHORIZED_FOR_HOST = YES`
- [x] `CLAUDE_CODE_EXECUTION_ALLOWED = YES`
- [x] CCR management service와 gateway 시작 가능
- [x] actual selected operational protocol 기록: `openai_chat_completions`
- [x] Gemma model 한 개의 Chat Completions `Check Connection` PASS
- [x] Responses HTTP 500을 non-blocking deferred capability로 분리
- [ ] custom Gemma Provider 저장
- [ ] reopen/refresh 후 Provider 영속화
- [ ] Auto detect OFF와 Chat-only 설정 확인
- [ ] Request logs / Agent observability 안전 상태 확인
- [ ] CCR stop exit `0`
- [ ] 제품 코드와 lockfile 무변경
- [ ] final Git status clean
- [x] secret, actual host/IP, raw internal evidence가 외부에 기록되지 않음
- [x] Connect agent / Let's start 미진행

## Failure classification

- `PROVIDER_PERSISTENCE`
- `PROTOCOL_COMPATIBILITY`
- `CCR_STARTUP`
- `SHUTDOWN`
- `PRODUCT_DIFF`
- `NETWORK_OR_PROXY`
- `TLS_OR_CERTIFICATE`
- `AUTHORIZATION`
- `MODEL_NOT_FOUND`
- `RATE_LIMIT`
- `UPSTREAM_5XX`
- `TIMEOUT`
- `UNKNOWN`

Responses HTTP 500은 현재 `PROTOCOL_COMPATIBILITY` 관찰이지만 V1 Chat-only Provider의 failure가 아니다.

## Attempts

| Attempt | Role | Evidence | Recommendation |
|---:|---|---|---|
| 1 | `INTERNAL_VALIDATOR` | 기존 credential이 선택한 host/source scope에서 허용되지 않아 `401` | `RETRY` with approved credential |
| 2 | `INTERNAL_VALIDATOR` | 신규 host-authorized key; direct Chat PASS; CCR Chat PASS; CCR Responses HTTP 500 | `CONTINUE` — finalize persisted Chat-only Provider, stop, clean-tree evidence |

## Evidence / limitations

- V1-S0 validated product commit: `97b73a9f4e1fb23d406bb987d0785cefa1f99966`
- Attempt 2 exact final tested HEAD는 finalization handoff에서 다시 기록한다.
- Chat PASS는 Provider-level basic connectivity만 증명한다.
- Local gateway client completion, streaming, tools, Claude Code compatibility는 증명하지 않는다.
- Responses 지원 여부는 인프라 공식 계약 또는 별도 compatibility Task가 필요하다.
- Auto-detect UX 개선은 현재 Core patch 대상이 아니다. Company-managed config에서는 Chat-only manual selection을 사용한다.

## Codex recommendation

`CONTINUE` — Internal Validator가 Provider 저장·영속화, logging safety, stop, product diff와 clean status만 마무리한다. 이후 Human Gate가 `V1-S1-T01` 수용 여부를 결정한다.

## Human decision

`PENDING`
