---
id: V1-S1-T01
stage: V1-S1
title: Internal GLM provider connection check
kind: spike
status: ready_internal
session_role: validation
internal_validation: required
depends_on:
  - V1-S0-T02
allowed_paths:
  - company/tasks/v1-s1/V1-S1-T01-GLM-PROVIDER-CHECK.md
  - company/docs/STATUS.md
  - company/gates/V1-S1.md
forbidden_paths:
  - packages/**
  - package.json
  - package-lock.json
human_decision: pending
---

# Internal GLM Provider Connection Check

## Validation question

> Stock CCR가 사내 Windows에서 source 수정 없이 사내 OpenAI-compatible GLM Provider 한 개를 저장하고, 선택한 모델 한 개의 CCR `Check Connection` 실제 요청을 통과할 수 있는가?

## Why now

V1-S0에서 Stock CCR의 Windows install, build, CLI start/stop이 통과했다.
Client gateway, streaming, tool calling으로 확대하기 전에 가장 작은 upstream Provider 계약부터 확인한다.

## Required knowledge

- `docs/src/content/docs/en/configuration/providers.md`
- `docs/src/content/docs/en/configuration/api-keys.md`
- `packages/cli/README.md`
- `company/docs/SECURITY.md`
- `company/docs/INTERNAL_VALIDATION.md`
- `company/gates/V1-S1.md`

## In scope

- build/runtime 검증을 통과한 exact product commit 또는 동등한 product tree 사용
- 사내 Windows에서 CCR management service와 gateway 시작
- CCR UI에서 custom Provider 한 개를 non-sensitive alias로 생성
- 사내 API 문서에 맞는 protocol, endpoint, personal key, GLM model 한 개를 runtime config에 입력
- 해당 모델 한 개만 `Check Connection`으로 실제 요청
- 선택한 protocol 이름과 sanitized 결과 기록
- CCR service 정상 종료
- 제품 코드와 lockfile 무변경 확인

## Out of scope

- 실제 endpoint, API key, model ID를 GitHub에 기록
- Provider credential pool, usage connector, local limits
- CCR client API key 생성
- local gateway를 통한 client request
- streaming
- tool call/result continuation
- 403/429/5xx/timeout 전체 matrix
- Gemma Provider
- Claude Code 연결
- Wrapper, Static Economy, Telemetry, V2 구현
- 사내 source/dependency/script 수정

## Runtime aliases

외부 Evidence에서는 실제 내부 값을 다음 alias로만 표현한다.

```text
Provider alias: internal_glm
Model alias: internal_glm_primary
Endpoint: REDACTED_INTERNAL
Credential: PRESENT / ABSENT
```

실제 model ID, endpoint, key, authenticated management URL, query token은 외부에 기록하지 않는다.

## Windows preflight

기존 Windows checkout과 source-built CLI를 사용할 수 있다.

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
```

## Runtime validation

### 1. CCR management service와 gateway 시작

```powershell
node $Cli start --no-open
$StartExit = $LASTEXITCODE
$StartExit
```

명령이 출력하는 authenticated management URL이나 token은 외부 Evidence에 복사하지 않는다.
로컬 브라우저에서만 사용한다.

### 2. Provider 생성

CCR UI의 Provider 설정에서:

1. `Other / custom API endpoint`를 선택한다.
2. Provider 이름은 로컬에서 식별 가능한 값으로 설정하되 외부에는 `internal_glm`으로만 기록한다.
3. 실제 사내 endpoint와 personal API key를 입력한다.
4. 사내 API 계약과 일치하는 protocol을 선택한다. Chat Completions 호환 계약이면 `openai_chat_completions`가 우선 후보지만, 실제 사내 문서와 CCR probe 결과를 따른다.
5. GLM model 한 개만 선택하거나 custom model로 추가한다.
6. Provider를 저장한다.

### 3. Connection check

`Check Connection`에서 방금 추가한 GLM model 한 개만 선택해 실제 요청을 수행한다.

기록할 것:

```text
Selected protocol
Connection check: PASS / FAIL / BLOCKED
CCR diagnostic category
Provider alias
Model alias
```

기록하지 않을 것:

```text
Endpoint
API key
Actual model ID
Raw request/response
Prompt/response content
Authenticated management URL/token
Internal hostname or proxy
```

### 4. 종료와 source 무변경 확인

```powershell
node $Cli stop
$StopExit = $LASTEXITCODE

Git diff --exit-code -- packages package.json package-lock.json
$ProductDiffExit = $LASTEXITCODE

git status --short
```

PowerShell에서는 `Git` 대신 `git`을 사용해도 동일하다.

## Acceptance criteria

- [ ] exact tested product commit 또는 동등 product tree 기록
- [ ] working tree clean
- [ ] CCR start with gateway exit `0`
- [ ] custom GLM Provider 한 개 저장
- [ ] actual selected protocol 기록
- [ ] GLM model 한 개의 `Check Connection` 결과 기록
- [ ] Connection check `PASS`
- [ ] CCR stop exit `0`
- [ ] 제품 코드와 lockfile 무변경
- [ ] secrets와 raw internal evidence가 외부에 기록되지 않음

## Internal validation contract

- Required: Yes
- Expected state before test: `READY_FOR_INTERNAL_VALIDATION`
- Result values: `PASS`, `FAIL`, `BLOCKED`, `UNVERIFIED_INTERNAL`
- 사내에서는 source, dependency, script를 수정하지 않는다.
- runtime Provider 설정은 `%APPDATA%`의 CCR data에만 저장한다.
- 실패 시 exact commit, protocol, 오류 분류, 재현률, sanitized diagnostic만 외부 repair session으로 반환한다.

## Failure classification

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

## Stop conditions

- source 수정 없이는 Provider를 저장하거나 check할 수 없음
- 실제 endpoint/key/model 권한이 준비되지 않음
- 사내 정책으로 connection check를 수행할 수 없음
- protocol을 추측해야만 진행할 수 있고 사내 API 계약을 확인할 수 없음
- secret 또는 raw internal evidence를 외부로 옮겨야만 진단 가능함

## Rollback

- CCR service를 `stop`으로 종료한다.
- 필요하면 UI에서 테스트 Provider를 삭제하되, runtime data 파일을 직접 편집하지 않는다.
- source checkout은 수정하지 않는다.

## Attempts

| Attempt | Session role | Commit | Internal | Recommendation |
|---:|---|---|---|---|

## Evidence / limitations

- V1-S0 validated product commit: `97b73a9f4e1fb23d406bb987d0785cefa1f99966`
- Stock CCR Windows install/build/runtime smoke: `PASS`
- This Task proves only Provider-level basic connectivity for one GLM model.
- A PASS does not prove local client gateway completion, streaming, tool calling, Gemma compatibility, or Claude Code E2E.

## Codex recommendation

`PENDING`

## Human decision

`PENDING`
