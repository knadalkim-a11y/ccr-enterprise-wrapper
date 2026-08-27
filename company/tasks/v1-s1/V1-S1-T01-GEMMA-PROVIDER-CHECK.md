---
id: V1-S1-T01
stage: V1-S1
title: Finalize internal Gemma Chat provider connection
kind: validation
status: in_progress
primary_actor: INTERNAL_VALIDATOR
execution_mode: human_assisted
implementation_required: false
internal_validation: required
github_write_allowed: false
candidate_sha: 97b73a9f4e1fb23d406bb987d0785cefa1f99966
instruction_sha: supplied_by_human_gate_owner
merge_policy: not_applicable
depends_on:
  - V1-S0-T02
required_capabilities:
  - WINDOWS_RUNTIME_ALLOWED
  - LLM_CREDENTIAL_AUTHORIZED_FOR_HOST
allowed_git_actions:
  - fetch
  - pull_ff_only
  - detached_checkout
  - show_task_at_instruction_sha
  - rev_parse
  - status
  - diff_exit_code
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

# Finalize Internal Gemma Chat Provider Connection

## Validation question

> Stock CCR가 사내 Windows에서 source 수정 없이 사내 Gemma Provider를 `openai_chat_completions` 전용으로 저장·영속화하고, 검증을 안전하게 종료할 수 있는가?

이 Task는 Provider 계층만 닫는다.
Profile, local gateway completion, Streaming, Tool, Claude Code는 별도 Task다.

## Task classification

```text
Primary actor: INTERNAL_VALIDATOR
Execution mode: human_assisted
Implementation required: NO
Product code PR: NOT_APPLICABLE
GitHub write by Internal Validator: NO
```

## Confirmed evidence

### Attempt 1 — credential host scope blocker

- 이전 credential은 선택한 PC/source scope에서 허용되지 않아 `401`이 발생했다.
- 분류: `BLOCKED_CREDENTIAL_HOST_SCOPE`
- CCR, Gemma, protocol 결함으로 판정하지 않았다.

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

Responses 500은 현재 Provider 전체 실패가 아니다.
`/v1/responses` 공식 지원 여부 또는 CCR 호환성 원인 분석은 실제 요구가 생길 때 별도 Task로 수행한다.

## Candidate contract

```text
Instruction SHA:
→ Human Gate Owner가 사내 시작 프롬프트에 exact SHA로 제공

Candidate SHA:
→ 97b73a9f4e1fb23d406bb987d0785cefa1f99966

Mode:
→ validation-only two-ref exception
```

현재 candidate는 V1-S0에서 install/build/runtime이 검증된 product commit이다.
Instruction SHA와 candidate SHA가 다르므로 최종 Evidence에 둘 다 기록한다.
이 Task에서는 제품 경로를 수정하지 않으며 `packages`, `package.json`, `package-lock.json` diff `0`으로 동등성 경계를 확인한다.

## Required knowledge

- `company/docs/ROLES_AND_HANDOFF.md`
- `company/docs/INTERNAL_VALIDATION.md`
- `company/docs/SECURITY.md`
- `company/docs/ENVIRONMENTS.md`
- `company/gates/V1-S1.md`
- `packages/core/src/providers/probe.ts`

## Protocol evidence boundary

CCR `v3.0.22` probe는 다음처럼 protocol별 요청을 분리한다.

```text
openai_chat_completions
→ POST /v1/chat/completions
→ messages + max_tokens

openai_responses
→ POST /v1/responses
→ input + max_output_tokens
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

## In scope

- exact instruction/candidate SHA 기록
- current candidate와 clean working tree 확인
- 기존 Gemma Provider를 Chat-only/manual protocol로 저장
- reopen/refresh 후 Provider 영속화 확인
- 실제 사용자 prompt 전 Request logs와 Agent observability OFF 확인
- `Connect agent`, `Let's start` 미진행
- CCR 정상 종료
- 제품 source/lockfile 무변경 확인
- sanitized evidence 반환

## Out of scope

- 새 Provider 중복 생성
- `/v1/responses` 추가 요청 또는 root-cause 분석
- `Connect agent` / Profile 생성
- `Let's start`
- local gateway basic completion
- Streaming
- Tool call/result continuation
- Claude Code 실행
- GLM 설정
- Wrapper/Routing/Telemetry/V2 구현
- source/dependency/script 수정
- Internal Validator의 GitHub write

## Actor plan

| Order | Actor | Responsibility | Handoff |
|---:|---|---|---|
| 1 | `HUMAN_GATE_OWNER` | Task, instruction SHA, candidate SHA 승인 | Internal Validator 시작 |
| 2 | `INTERNAL_VALIDATOR` | Preflight 후 Human Step 준비 | H1에서 멈춤 |
| 3 | `HUMAN_GATE_OWNER` | Provider 저장·로그 안전 설정을 로컬 UI에서 수행 | 완료 상태만 반환 |
| 4 | `INTERNAL_VALIDATOR` | stop, diff, status, sanitized evidence | Human Gate Owner에게 반환 |
| 5 | `CHATGPT_ORCHESTRATOR` | Evidence 검토와 canonical 상태 갱신 | Human decision 대기 |

## A1 — [INTERNAL_VALIDATOR] Preflight

Human Gate Owner가 제공한 exact instruction SHA에서 이 Task를 읽은 뒤 candidate를 checkout한다.

```powershell
git fetch --prune origin
git show <INSTRUCTION_SHA>:company/tasks/v1-s1/V1-S1-T01-GEMMA-PROVIDER-CHECK.md
git checkout --detach 97b73a9f4e1fb23d406bb987d0785cefa1f99966

$TestedCommit = git rev-parse HEAD
git status --short

node --version
npm --version
node -p "process.platform"
node -p "process.arch"

$Cli = "packages/cli/dist/main/cli.js"
$CliExists = Test-Path $Cli

$TestedCommit
$CliExists
```

진행 조건:

```text
candidate SHA exact match
working tree clean
process.platform = win32
CLI exists = True
required capabilities = YES
```

조건이 맞으면 Human Step H1을 요청하고 멈춘다.
Dirty tree면 임의로 정리하지 않고 경로만 보고한다.

## H1 — [HUMAN_GATE_OWNER] Provider와 logging finalization

사내 로컬 CCR UI에서 수행한다.

1. 기존 Gemma Provider를 중복 생성하지 않는다.
2. `Auto detect protocols`를 OFF로 둔다.
3. `OpenAI Chat Completions`만 선택한다.
4. `OpenAI Responses`는 선택 해제한다.
5. Provider를 저장한다.
6. Provider 목록 또는 reopen/refresh 후 설정이 유지되는지 확인한다.
7. 실제 사용자 prompt 전에 Request logs와 Agent observability를 OFF로 둔다.
8. `Connect agent`와 `Let's start`는 수행하지 않는다.

Agent output에 넣지 않는다.

```text
actual endpoint
API Key
actual model ID
host/IP/proxy/egress
management URL/token
raw request/response
```

Internal Validator에 반환할 최소 상태:

```text
Provider saved: PASS / FAIL
Provider persisted: PASS / FAIL
Auto detect: OFF / ON
Selected protocol: openai_chat_completions / OTHER
Responses selected: NO / YES
Request logs: OFF / ON / UNKNOWN
Agent observability: OFF / ON / UNKNOWN
Connect agent executed: NO / YES
Let's start executed: NO / YES
```

## A2 — [INTERNAL_VALIDATOR] Cleanup and evidence

H1 결과를 받은 뒤 실행한다.

```powershell
node $Cli stop
$StopExit = $LASTEXITCODE

git diff --exit-code -- packages package.json package-lock.json
$ProductDiffExit = $LASTEXITCODE

git status --short

$StopExit
$ProductDiffExit
```

기대 결과:

```text
StopExit = 0
ProductDiffExit = 0
Final git status = clean
```

실패를 통과시키기 위해 source, runtime DB, protocol, dependency를 수정하지 않는다.

## Acceptance criteria

- [ ] exact instruction SHA 기록
- [ ] exact candidate SHA `97b73a9f...` 기록
- [ ] working tree before finalization clean
- [x] `WINDOWS_RUNTIME_ALLOWED = YES`
- [x] `LLM_CREDENTIAL_AUTHORIZED_FOR_HOST = YES`
- [x] `CLAUDE_CODE_EXECUTION_ALLOWED = YES`
- [x] Direct Chat Completions PASS
- [x] CCR Chat Completions Check Connection PASS
- [x] Responses HTTP 500을 non-blocking deferred capability로 분리
- [ ] Provider saved PASS
- [ ] Provider persisted after reopen/refresh PASS
- [ ] Auto detect OFF
- [ ] selected protocol `openai_chat_completions` only
- [ ] Responses selected NO
- [ ] Request logs OFF
- [ ] Agent observability OFF
- [ ] Connect agent / Let's start 미진행
- [ ] CCR stop exit `0`
- [ ] product diff exit `0`
- [ ] final Git status clean
- [ ] secret/raw evidence 외부 반출 없음
- [ ] Internal Validator Git write 없음
- [ ] 다음 Task 미시작

## Stop conditions

- instruction 또는 candidate SHA가 불명확함
- candidate SHA 불일치
- working tree dirty
- required capability가 `NO / UNKNOWN`
- Provider가 저장되지 않거나 reopen 후 사라짐
- Chat-only 상태를 만들기 위해 source 수정이 필요함
- Request body logging을 안전하게 끌 수 없음
- stop 또는 product diff 실패
- secret/raw evidence를 외부로 옮겨야만 진단 가능함

## Failure classification

- `PROVIDER_PERSISTENCE`
- `PROTOCOL_COMPATIBILITY`
- `LOGGING_SAFETY`
- `SHUTDOWN`
- `PRODUCT_DIFF`
- `WINDOWS_ENVIRONMENT`
- `UNKNOWN`

Responses HTTP 500은 `PROTOCOL_COMPATIBILITY` 관찰이지만 현재 Chat-only Provider의 Task failure가 아니다.

## Sanitized evidence template

```text
Role: INTERNAL_VALIDATOR
Task ID: V1-S1-T01
Session role: internal validation finalization
Instruction SHA:
Candidate SHA:
Environment alias:
Capability matrix:

A1 Preflight:
- candidate match:
- working tree clean:
- CLI exists:

H1 Human step:
- Provider saved:
- Provider persisted:
- Auto detect protocols:
- Selected protocol: openai_chat_completions
- Responses selected: NO
- Request logs:
- Agent observability:
- Connect agent executed: NO
- Let's start executed: NO

Protocol evidence:
- Direct Chat Completions: PASS
- CCR Chat Completions: PASS
- CCR Responses: FAIL, HTTP 500
- Responses classification: UNSUPPORTED_OR_INCOMPATIBLE, NON_BLOCKING

A2 Cleanup:
- CCR stop / exit code:
- product diff / exit code:
- final git status:

Failure classification:
Reproducibility:
Sanitized observation:
Secrets/raw evidence exported: NO
Git write performed: NO
Next Task started: NO
```

## Attempts

| Attempt | Actor / session role | Candidate | Instruction | Internal | Recommendation |
|---:|---|---|---|---|---|
| 1 | Internal validation | V1-S0 product tree | earlier Task instruction | `BLOCKED_CREDENTIAL_HOST_SCOPE` | Approved credential 필요 |
| 2 | Internal protocol validation | `97b73a9f...` | earlier Task instruction | Direct Chat PASS; CCR Chat PASS; Responses HTTP 500 | Chat-only finalization 진행 |
| 3 | Internal finalization | `97b73a9f...` | supplied at handoff | `PENDING` | H1 + cleanup evidence 필요 |

## Evidence / limitations

- Chat PASS는 Provider-level basic connectivity만 증명한다.
- Local gateway completion, Streaming, Tool, Claude Code는 아직 증명하지 않았다.
- Responses 지원 여부는 인프라 공식 계약 또는 별도 Task가 필요하다.
- Auto-detect UX 개선은 현재 Core patch 대상이 아니다.

## Agent recommendation

`CONTINUE` — 승인된 instruction/candidate SHA로 H1 Provider finalization과 A2 cleanup만 수행한다.

## Human decision

`PENDING`
