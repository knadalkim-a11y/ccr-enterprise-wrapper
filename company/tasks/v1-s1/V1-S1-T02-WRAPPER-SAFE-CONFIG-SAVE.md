---
id: V1-S1-T02
stage: V1-S1
title: Add a wrapper-only T00 safe config-save helper
kind: implementation
status: planned
primary_actor: EXTERNAL_CODEX
execution_mode: agent_only
implementation_required: true
internal_validation: required
github_write_allowed: true
candidate_sha: supplied_by_external_codex
instruction_sha: same_as_candidate
merge_policy: internal_pass_required
depends_on:
  - V1-S0-T02
required_capabilities: []
allowed_git_actions:
  - fetch
  - checkout_branch
  - status
  - diff
  - test
  - commit
  - push
  - create_pull_request
allowed_paths:
  - company/scripts/t00-safe-config-save.mjs
  - company/tests/t00-safe-config-save.test.mjs
  - company/tasks/v1-s1/V1-S1-T02-WRAPPER-SAFE-CONFIG-SAVE.md
forbidden_paths:
  - packages/**
  - scripts/**
  - build/**
  - tests/**
  - package.json
  - package-lock.json
  - .github/workflows/**
human_decision: pending
---

# Add a Wrapper-only T00 Safe Config-save Helper

## Status boundary

This Task is a design artifact only and is not active.
Human Gate Owner approval is required before implementation, branch creation or test execution.

## Validation question

> Company-owned helper가 Stock CCR `v3.0.22`의 authenticated loopback Management RPC만 사용해 CCR source와 runtime DB를 직접 수정하지 않고 T00 H1 안전 상태를 저장할 수 있는가?

## Why now

V1-S1-T00 Attempt 1은 management start isolation을 통과했지만 H1 cleanup/save에 도달하지 못해 `BLOCKED`됐다.
Stock UI의 unfinished onboarding에서는 forbidden `Connect agent` 없이 required cleanup을 수행할 수 없다.
Human Gate는 CCR source patch를 거부했고 Company-owned wrapper 경로를 선택했다.

## Confirmed source findings

- Company-owned implementation은 기본적으로 `company/**` 아래에 둔다.
- Stock CCR web management server는 loopback-authenticated `POST /api/ccr/rpc`를 제공한다.
- Config cleanup에는 `getConfig`와 `saveConfig`를 사용한다.
- Service preflight에는 read-only `getServiceIdentity`와 `getGatewayStatus`를 사용한다.
- CLI service state `%APPDATA%\claude-code-router\service.json`은 local management URL/auth, PID, service token과 start mode를 보유한다.
- 이미 실행 중인 service가 있으면 `start --no-gateway`가 이를 재사용할 수 있으므로 command-line flag만으로 격리를 증명할 수 없다.
- `saveConfig`는 항상 Claude App config sync를 수행하므로 service `LOCALAPPDATA` sandbox가 선행돼야 한다.
- `saveConfig(next, { applyProfile: false })`는 config/Claude App sync를 유지하면서 Claude Code profile application을 생략한다.
- `saveConfig`는 config 변화에 따라 Gateway를 side effect로 시작할 수 있다. T00은 이를 허용하지만 helper가 Gateway-control RPC를 호출하거나 model request를 보내면 안 된다.
- `saveConfig`는 Provider model auto-refresh를 동기화하며 enabled Provider의 `autoFetchModels`가 켜져 있으면 즉시 refresh를 예약한다.
- `getConfig`도 stock migration/API-key initialization을 수행할 수 있으므로 default mode는 엄밀한 read-only가 아니라 **no-save preflight**다.
- Management RPC는 pinned `v3.0.22` source dependency이며 영구 public API로 간주하지 않는다.

## Scope boundary

이 Task는 T00 차단 해소용 validation helper다.
V1-S1에서 Company helper를 추가하는 것은 원래 V1-S3/V1-S4 launcher/Doctor 일정의 좁은 예외이므로 Human Gate의 별도 activation 승인이 필요하다.
Production `company-claude` launcher, installer, setup 또는 Doctor로 일반화하지 않는다.

## Required knowledge

- `company/AGENTS.md`
- `company/tasks/v1-s1/V1-S1-T00-CCR-RUNTIME-SANDBOX.md`
- `company/docs/CLAUDE_CODE_ISOLATION.md`
- `company/docs/SECURITY.md`
- `company/docs/AGENT_WORKFLOW.md`
- `packages/cli/src/cli.ts` — read-only
- `packages/core/src/web/management-server.ts` — read-only
- `packages/core/src/contracts/app.ts` — read-only

## In scope

- One dependency-free Node helper under `company/scripts/`.
- Synthetic/mock tests under `company/tests/`.
- Loopback-only authenticated Management RPC.
- Fail-closed preflight and exact allowlisted config transform.
- Compact sanitized output for the keyboard-only Evidence boundary.
- Exact repair PR head handoff to T00 Attempt 2.

## Out of scope

- Any change under `packages/**` or other upstream-owned path.
- Runtime DB/config file direct edit.
- Onboarding completion or UI automation.
- Profile application, Connect agent, Let's start or profile launch.
- Provider/key/model/protocol/router/API-key change.
- Provider probe, connectivity check, model refresh or real model request.
- Production launcher/setup/Doctor.
- Dependency, lockfile or workflow change.
- T01.

## Implementation contract

1. The helper is inert without an explicit `--apply` flag. Default mode is a **no-save preflight**: it may call stock read RPCs and `getConfig`, but it must not call `saveConfig`.
2. Resolve the running service from the pinned CLI service-state contract at `%APPDATA%\claude-code-router\service.json`. Read tokenized URL/auth, PID and service token only in memory.
3. T00 A0/A2 must prove there was no pre-existing service before the sandbox start and that A2 created fresh state/PID. The helper additionally requires service state `startGateway === false`; a missing or unexpected value blocks.
4. Accept only a loopback `http:` management URL with a `ccr_web_token` query value, and send it only as the `x-ccr-web-auth` header. Reject missing auth, a non-loopback host, another protocol, malformed URL or unexpected service-state shape.
5. Call `getServiceIdentity` with args exactly `[serviceToken]`. Require `serviceTokenConfigured === true`, `serviceTokenMatches === true`, and returned `pid === service.json.pid`.
6. Call `getGatewayStatus` with args exactly `[]`. Require `state === "stopped"`, `gatewayManagedExternally !== true`, and `coreManagedExternally !== true`; the external-management fields may be absent when safely stopped. Any unexpected RPC shape blocks.
7. Call `getConfig` with args exactly `[]` and validate the pinned `v3.0.22` config shape without printing raw values.
8. Never print, persist or return the management URL/token, service token, full config, Provider fields, API keys, model IDs, paths or raw RPC bodies.
9. Fail before save unless every enabled Provider has `autoFetchModels` equal to `false` or absent. Reject unknown non-boolean values. Do not change this flag.
10. Build a deep-cloned next config and change only:
    - `enabled: true` `claude-code` profiles whose scope is neither `"ccr"` nor `"custom"`—including `"global"`, missing and unknown legacy values—to `enabled: false`;
    - `observability.requestLogs` to `false`;
    - `observability.agentAnalysis` to `false`;
    - `observability.requestLogBodyCapture` to `"none"`.
11. Prove locally before save that profile count/IDs and all non-allowlisted fields are canonically equal.
12. If the config is already in the required safe state, omit `saveConfig` even with `--apply`.
13. Otherwise, with `--apply`, call only `saveConfig` with args exactly `[fullNextConfig, { applyProfile: false }]` for the mutation.
14. After a save, re-read with `getConfig([])` and require:
    - enabled global/legacy-global Claude Code profiles = `0`;
    - profile count/IDs unchanged;
    - Request logs = `OFF`;
    - Agent analysis = `OFF`;
    - request-log body capture = `none`;
    - Provider/preferred Provider/provider plugin/model/router/API-key/onboarding fields unchanged.
15. Do not call `setOnboardingFinished`, `applyProfile`, `applyClaudeAppGateway`, `openProfile`, Gateway controls, Provider probes or model APIs.
16. A Gateway may start only as the stock `saveConfig` side effect. The helper must not invoke any explicit Gateway-control RPC or send any request through it.
17. Do not stop the service after a successful save; T00 A3 owns during fingerprint, stop and after fingerprint.
18. On any ambiguity, output `BLOCKED` and make no save.
19. Output one compact capsule plus process exit code; no raw values.

## Sanitized output contract

Apply path:

```text
T02|SERVICE=P|GW_PRE=STOP|RPC=P|APPLY=P|GLOBAL=0|LOGS=OFF|ANALYSIS=OFF|BODY=NONE|PROVIDER=SAME|AUTOFETCH=OFF|RAW=NO
```

Default no-save preflight uses `APPLY=N`. An already-safe apply run uses `APPLY=SKIP`.

Failure output contains only a documented category:

```text
BLOCKED_SERVICE_STATE
BLOCKED_SERVICE_IDENTITY
BLOCKED_GATEWAY_STATE
BLOCKED_NON_LOOPBACK
BLOCKED_AUTH
BLOCKED_PROVIDER_AUTO_REFRESH
BLOCKED_CONFIG_SHAPE
UNEXPECTED_CONFIG_DIFF
RPC_FAILURE
POSTCONDITION_FAILURE
```

## External validation

Run and record:

```text
node --check company/scripts/t00-safe-config-save.mjs
node --test company/tests/t00-safe-config-save.test.mjs
git diff --check
git diff -- company/scripts company/tests company/tasks/v1-s1/V1-S1-T02-WRAPPER-SAFE-CONFIG-SAVE.md
git status --short
```

Tests use only synthetic configs, fake tokens and a loopback mock RPC server.
They must cover:

- default mode calls no `saveConfig`;
- service identity requires configured/matching token and exact PID;
- pre-save Gateway must be stopped; either external-management flag equal to `true` blocks while absent flags are accepted;
- exact allowlisted transform;
- missing/unknown profile scope treated as global; `ccr` and `custom` preserved;
- profile count/IDs preserved;
- logging/analysis/body capture OFF;
- Provider and all unrelated config preserved;
- enabled Provider auto-fetch blocks before save;
- non-loopback/missing-auth service state blocks;
- apply RPC sequence and args are `getServiceIdentity([serviceToken])`, `getGatewayStatus([])`, `getConfig([])`, `saveConfig([fullNextConfig, { applyProfile: false }])`, `getConfig([])`;
- default no-save and already-safe apply sequences stop after the first `getConfig([])`;
- save options are exactly `{ applyProfile: false }`;
- no forbidden or explicit Gateway-control RPC is invoked;
- raw URL/token/config never appears in output;
- unexpected returned diff fails.

## Acceptance criteria

- [ ] exact candidate and instruction SHA recorded
- [ ] diff limited to approved `company/**` paths
- [ ] no upstream/CCR source, dependency, lockfile or workflow change
- [ ] no direct runtime DB/config edit
- [ ] default invocation makes no `saveConfig` call
- [ ] apply requires explicit flag
- [ ] no pre-existing service and fresh A2 state/PID proved by T00 A0/A2
- [ ] loopback HTTP/auth-header/service identity/Gateway pre-state fail-closed
- [ ] auto-fetch fail-closed
- [ ] exact allowlisted transform proven
- [ ] profile count/IDs preserved
- [ ] Provider/model/router/API-key/onboarding state preserved
- [ ] `applyProfile:false` passed
- [ ] already-safe state skips save
- [ ] no forbidden or explicit Gateway-control RPC invoked
- [ ] synthetic/mock tests pass
- [ ] compact sanitized output only
- [ ] T00 Attempt 2 is the only internal runtime validation
- [ ] T01 remains blocked

## Stop conditions

- A `packages/**`, upstream root, dependency, lockfile or workflow change appears necessary.
- Direct runtime DB/config edit appears necessary.
- Management endpoint is not loopback/authenticated.
- T00 cannot prove the service was stopped before A2 or service identity does not match.
- Gateway is already running or externally owned before save.
- Full config round-trip cannot preserve non-target fields.
- Enabled Provider auto-fetch cannot be proven OFF before save.
- A Provider/model request or explicit Gateway-control RPC is required.
- Secret/raw internal evidence would need to be exported.
- Human Gate has not activated this Task.

## Internal validation and merge

`merge_policy: internal_pass_required`.

After External PASS, Human Gate supplies the exact PR head as candidate/instruction SHA.
T00 Attempt 2 runs on that exact head.
The repair PR must not merge before T00 PASS and Human decision.

## Sanitized evidence template

```text
Role: EXTERNAL_CODEX
Task ID: V1-S1-T02
Session role: wrapper-only T00 config-save helper
Candidate SHA:
Instruction SHA:
Changed paths:
Node syntax:
Synthetic/mock tests:
Default no-save:
Apply flag required:
Service identity/Gateway pre-state:
Loopback/auth guard:
Auto-fetch guard:
Allowlisted diff:
Forbidden path diff: 0
Secrets/raw evidence exported: NO
GitHub PR:
Next Task started: NO
```

## Attempts

| Attempt | Actor / session role | Candidate | Instruction | External | Internal | Recommendation |
|---:|---|---|---|---|---|---|

## Evidence / limitations

T00 Attempt 1 is the only internal runtime Evidence.
This planned Task contains no implementation and authorizes no execution.
The pinned Management RPC dependency must be revalidated on every upstream update.

## Agent recommendation

`NOT_STARTED — AWAIT_HUMAN_GATE_ACTIVATION`

## Human decision

`PENDING`
