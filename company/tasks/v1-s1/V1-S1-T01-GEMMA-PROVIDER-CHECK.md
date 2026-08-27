---
id: V1-S1-T01
stage: V1-S1
title: Internal Gemma provider connection check
kind: spike
status: blocked
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

> Stock CCR가 사내 Windows에서 source 수정 없이 사내 OpenAI-compatible Gemma Provider 한 개를 저장하고, 해당 host에서 사용 권한이 있는 credential로 선택한 모델 한 개의 CCR `Check Connection` 실제 요청을 통과할 수 있는가?

## Why now

V1-S0에서 Stock CCR의 Windows install, build, CLI start/stop이 통과했다.
현재 사내 serving 환경에서는 Gemma를 먼저 사용할 수 있고 GLM은 아직 rollout 대기 중이므로,
모델 순서를 아키텍처에 고정하지 않고 사용 가능한 Gemma부터 최소 Provider 계약을 확인한다.

Attempt 1에서 Claude Code 사용 후보 PC에 개인 PC의 source-IP 범위로 발급된 credential을 사용해 `401`이 발생했다.
이는 CCR protocol 또는 Gemma model 실패 증거가 아니라 validation host와 credential 실행 범위가 일치하지 않은 운영 blocker다.

## Required knowledge

- `docs/src/content/docs/en/configuration/providers.md`
- `docs/src/content/docs/en/configuration/api-keys.md`
- `packages/cli/README.md`
- `company/docs/SECURITY.md`
- `company/docs/INTERNAL_VALIDATION.md`
- `company/docs/ENVIRONMENTS.md`
- `company/gates/V1-S1.md`

## Host capability preflight

Provider request 전에 다음 세 권한을 서로 독립적으로 판정한다.

```text
WINDOWS_RUNTIME_ALLOWED
→ CCR를 build/run할 수 있는가

LLM_CREDENTIAL_AUTHORIZED_FOR_HOST
→ credential이 현재 host의 실제 outbound identity/source scope에서 허용되는가

CLAUDE_CODE_EXECUTION_ALLOWED
→ 이 host에서 Claude Code 사용이 승인되었는가
```

이 Task의 진행 조건:

```text
WINDOWS_RUNTIME_ALLOWED = YES
LLM_CREDENTIAL_AUTHORIZED_FOR_HOST = YES
CLAUDE_CODE_EXECUTION_ALLOWED = NOT_REQUIRED
```

다만 이후 V1-S2 E2E까지 같은 PC에서 이어가려면 세 조건이 모두 `YES`인 host를 우선 선택한다.
Credential scope는 local IP가 아니라 NAT/proxy egress, device 또는 account policy일 수 있으므로 실제 발급/allowlist 기준은 serving 운영자에게 확인한다.

## Current blocker

```text
Result: BLOCKED_CREDENTIAL_HOST_SCOPE
Observed response: 401
Credential: PRESENT
Validation host authorization: NO
```

실제 host/IP, endpoint, key, model ID는 외부 Evidence에 기록하지 않는다.

해결 가능한 승인 경로:

1. 선택한 validation host의 outbound identity에 허용된 별도 credential을 발급받는다.
2. 운영 승인 절차를 통해 기존 credential의 allowed host/source scope를 확장한다.
3. 정책상 허용된다면 credential이 이미 유효한 다른 사내 Windows host에서 Provider-only 검증을 수행한다. 단, V1-S2 Claude Code E2E는 Claude Code 승인 host에서 다시 검증한다.

금지:

- key 공유 또는 우회 전달
- source-IP/host allowlist 우회
- 승인되지 않은 proxy/tunnel 사용
- 실제 key를 repository, Issue, PR, log에 기록

## In scope

- build/runtime 검증을 통과한 exact product commit 또는 동등한 product tree 사용
- 적합한 사내 Windows host와 credential scope 사전 확인
- CCR management service와 gateway 시작
- CCR UI에서 custom Gemma Provider 한 개를 non-sensitive alias로 생성
- 사내 API 계약에 맞는 protocol, endpoint, credential, Gemma model 한 개를 runtime config에 입력
- 해당 모델 한 개만 `Check Connection`으로 실제 요청
- 선택한 protocol 이름과 sanitized 결과 기록
- CCR service 정상 종료
- 제품 코드와 lockfile 무변경 확인

## Out of scope

- 실제 endpoint, key, model ID, host/IP를 GitHub에 기록
- credential allowlist 우회 또는 권한 변경 구현
- Provider credential pool, usage connector, local limits
- CCR client API key 생성
- local gateway를 통한 client request
- streaming
- tool call/result continuation
- 오류 matrix 전체
- GLM Provider
- Claude Code 연결
- Wrapper, Static Economy, Telemetry, V2 구현
- 사내 source/dependency/script 수정

## Runtime aliases

외부 Evidence에서는 실제 내부 값을 다음 alias로만 표현한다.

```text
Provider alias: internal_gemma
Model alias: internal_gemma_primary
Endpoint: REDACTED_INTERNAL
Credential: PRESENT / ABSENT
Credential host scope: AUTHORIZED / MISMATCH / UNKNOWN
Validation host: approved_alias_only
```

## Windows preflight

```powershell
$TestedCommit = git rev-parse HEAD

git status --short
node --version
npm --version
node -p "process.platform"
node -p "process.arch"

$Cli = "packages/cli/dist/main/cli.js"
$CliExists = Test-Path $Cli
$CliExists
```

진행 조건:

```text
process.platform = win32
Node major >= 22 and LTS
working tree = clean
CLI entrypoint exists = True
TestedCommit 또는 동등 product tree = 기록됨
LLM credential scope for current host = AUTHORIZED
```

Credential scope가 `MISMATCH` 또는 `UNKNOWN`이면 real request를 반복하지 않고 `BLOCKED_CREDENTIAL_HOST_SCOPE`로 종료한다.

## Runtime validation

### 1. CCR management service와 gateway 시작

```powershell
node $Cli start --no-open
$StartExit = $LASTEXITCODE
$StartExit
```

Authenticated management URL과 token은 로컬 브라우저에서만 사용한다.

### 2. Gemma Provider 생성

CCR UI의 Provider 설정에서:

1. `Other / custom API endpoint`를 선택한다.
2. 외부 보고에서는 Provider를 `internal_gemma`로만 표현한다.
3. 실제 사내 endpoint와 현재 host에 사용 허가된 credential을 입력한다.
4. 사내 API 계약과 일치하는 protocol을 선택한다.
5. Gemma model 한 개만 추가한다.
6. Provider를 저장한다.

### 3. Connection check

`Check Connection`에서 방금 추가한 Gemma model 한 개만 선택한다.

기록:

```text
Selected protocol
Connection check: PASS / FAIL / BLOCKED
Credential host scope: AUTHORIZED / MISMATCH / UNKNOWN
Sanitized diagnostic category
Provider alias
Model alias
```

금지 기록:

```text
Endpoint
API key
Actual model ID
Raw request/response
Prompt/response content
Authenticated management URL/token
Internal hostname, IP, proxy
```

### 4. 종료와 source 무변경 확인

```powershell
node $Cli stop
$StopExit = $LASTEXITCODE

git diff --exit-code -- packages package.json package-lock.json
$ProductDiffExit = $LASTEXITCODE

git status --short
```

## Acceptance criteria

- [ ] exact tested product commit 또는 동등 product tree 기록
- [ ] working tree clean
- [ ] `WINDOWS_RUNTIME_ALLOWED = YES`
- [ ] `LLM_CREDENTIAL_AUTHORIZED_FOR_HOST = YES`
- [ ] CCR start with gateway exit `0`
- [ ] custom Gemma Provider 한 개 저장
- [ ] actual selected protocol 기록
- [ ] Gemma model 한 개의 `Check Connection` 결과 기록
- [ ] Connection check `PASS`
- [ ] CCR stop exit `0`
- [ ] 제품 코드와 lockfile 무변경
- [ ] secrets, host/IP, raw internal evidence가 외부에 기록되지 않음

## Internal validation contract

- Required: Yes
- Expected state before test: `BLOCKED` until credential/host scope is aligned
- Result values: `PASS`, `FAIL`, `BLOCKED`, `UNVERIFIED_INTERNAL`
- 사내에서는 source, dependency, script를 수정하지 않는다.
- runtime Provider 설정은 `%APPDATA%`의 CCR data에만 저장한다.
- host-scope mismatch는 protocol/auth implementation 실패와 분리한다.

## Failure classification

- `CREDENTIAL_HOST_SCOPE`
- `HOST_NOT_APPROVED`
- `CCR_STARTUP`
- `PROVIDER_CONFIG`
- `NETWORK_OR_PROXY`
- `TLS_OR_CERTIFICATE`
- `AUTHORIZATION`
- `MODEL_NOT_FOUND`
- `PROTOCOL_COMPATIBILITY`
- `RATE_LIMIT`
- `UPSTREAM_5XX`
- `TIMEOUT`
- `UNKNOWN`

`AUTHORIZATION`은 현재 host에 credential 사용 권한이 확인된 뒤에도 401/403이 발생할 때만 사용한다.
Host scope가 맞지 않으면 `CREDENTIAL_HOST_SCOPE`로 분류한다.

## Stop conditions

- 현재 validation host에 허용된 credential이 없음
- source 수정 없이는 Provider를 저장하거나 check할 수 없음
- 실제 endpoint/key/model 권한이 준비되지 않음
- 사내 정책으로 connection check를 수행할 수 없음
- protocol을 추측해야만 진행할 수 있고 사내 API 계약을 확인할 수 없음
- secret 또는 raw internal evidence를 외부로 옮겨야만 진단 가능함

## Rollback

- CCR service를 `stop`으로 종료한다.
- 필요하면 UI에서 테스트 Provider를 삭제하되 runtime DB 파일을 직접 편집하지 않는다.
- source checkout은 수정하지 않는다.

## Attempts

| Attempt | Session role | Commit | Internal | Recommendation |
|---:|---|---|---|---|
| 1 | validation | product tree validated in V1-S0 | `BLOCKED_CREDENTIAL_HOST_SCOPE` — credential was not authorized for the selected validation host/source identity and request returned 401 | `RETRY` — obtain an approved credential for the selected host or use a policy-approved credential-authorized host |

## Evidence / limitations

- V1-S0 validated product commit: `97b73a9f4e1fb23d406bb987d0785cefa1f99966`
- Stock CCR Windows install/build/runtime smoke: `PASS`
- Gemma is the first currently available model for V1-S1 transport validation.
- GLM serving rollout is pending; model order is an availability decision, not an architecture dependency.
- Attempt 1 proves only that the supplied credential is not usable from the selected host/source scope.
- Attempt 1 does not prove a CCR protocol defect, invalid Gemma model, or general API authorization failure.
- A PASS here proves only Provider-level basic connectivity for one Gemma model.

## Codex recommendation

`BLOCKED` — align the Gemma credential's approved host/source scope with the selected validation host, then repeat only this Task. Prefer a Claude Code-approved PC whose outbound identity is also authorized so later E2E can reuse the same runtime setup.

## Human decision

`PENDING`
