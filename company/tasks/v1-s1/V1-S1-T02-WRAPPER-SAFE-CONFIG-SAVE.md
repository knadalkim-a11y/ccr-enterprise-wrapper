---
id: V1-S1-T02
stage: V1-S1
title: Add a wrapper-only T00 safe config-save helper
kind: implementation
status: in_progress
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

This Task is active for the exact wrapper-only scope below.

Activation record:

```text
Date: 2026-09-01
Authority: HUMAN_GATE_OWNER
Decision: APPROVED_FOR_IMPLEMENTATION
CCR packages/** changes: PROHIBITED
T00 Attempt 2: NOT_STARTED
T01: BLOCKED
```

The final Human decision remains pending until External PASS, exact-head T00 Attempt 2, and Human Gate review.

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
- Observability 세 필드 중 하나라도 바뀌면 stock runtime-change 판정상 Gateway start가 요구되므로 loopback gateway/core, disabled proxy/media/plugin/tool surfaces와 free ports를 apply 전에 확인해야 한다.
- `saveConfig`는 Provider model auto-refresh를 동기화하며 enabled Provider의 `autoFetchModels`가 켜져 있으면 즉시 refresh를 예약한다.
- `getConfig`도 stock migration/API-key initialization을 수행할 수 있으므로 default mode는 엄밀한 read-only가 아니라 **no-save preflight**다.
- `saveAppConfig`는 legacy profile mirror를 동기화하므로 global Claude Code profile cleanup은 `profile.claudeCode.enabled`와 조건부 `profile.enabled`도 source-derived 값으로 바꾼다.
- Claude App sync backup은 real `%APPDATA%\claude-code-router`에 저장되므로 stale backup이 있으면 apply 전에 차단해야 한다.
- `getServiceIdentity`만으로 pinned binary/config root를 증명할 수 없으므로 `getAppInfo`의 name/version/platform/config/data paths를 함께 검증해야 한다.
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
- `packages/core/src/runtime/app-paths.ts` — read-only
- `packages/core/src/config/config.ts` — read-only
- `packages/core/src/web/management-server.ts` — read-only
- `packages/core/src/contracts/app.ts` — read-only
- `packages/core/src/providers/model-auto-refresh.ts` — read-only
- `packages/core/src/agents/claude-app/gateway-service.ts` — read-only
- `packages/core/src/gateway/runtime-change.ts` — read-only
- `packages/core/src/gateway/application/gateway-service.ts` — read-only

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

1. Accept only no argument or one exact `--apply`; invalid arguments return a fixed usage category without echoing input. Default mode is a **no-`saveConfig` preflight**, not an inert/read-only claim.
2. Require Windows and an absolute `APPDATA`. Reject `CCR_INTERNAL_APP_DATA_DIR`, `CCR_INTERNAL_USER_DATA_DIR` or other runtime-path overrides. Never fall back to restored `LOCALAPPDATA`.
3. Read only `%APPDATA%\claude-code-router\service.json`, with file-type and size limits. Require the pinned exact state shape, positive numeric PID, live process, `profileManaged === false`, `startGateway === false`, nonempty service token, valid `startedAt`, and no unexpected keys.
4. Require `%APPDATA%\claude-code-router\claude-app-gateway-backup.json` to be absent before any RPC that can save.
5. Accept only a canonical `http://127.0.0.1:<explicit-port>/?ccr_web_token=<one-nonempty-value>` URL: root path, no userinfo, fragment, extra/duplicate query or DNS hostname. Send the token only as `x-ccr-web-auth` to fixed `/api/ccr/rpc`.
6. Use direct built-in `node:http` with `agent: false`, no redirect/retry/proxy, fixed timeouts, explicit content length, JSON content-type validation, and bounded request/response bodies. Neutralize runtime HTTP debug before networking.
7. Call `getAppInfo([])` and require exact name `Claude Code Router`, version `3.0.22`, platform `win32`, and config/data paths equal to `%APPDATA%\claude-code-router` without printing them.
8. Call `getServiceIdentity([serviceToken])`. Require `serviceTokenConfigured === true`, `serviceTokenMatches === true`, and returned PID equal to service state.
9. Call `getGatewayStatus([])`. Require fresh pre-save state `stopped`, no external-management flag equal to `true`, and no already-active gateway/core endpoint or network listener state.
10. Call `getOnboardingFinished([])` and retain only its boolean value for equality checking.
11. Call `getConfig([])` and reject fallback/default or malformed config: nonempty enabled Provider/model, unique profile IDs, existing reusable API key, pinned JSON-safe shape, and required current-config invariants.
12. Require `gateway.enabled === true`, numeric gateway/core ports and exact loopback hosts. Require proxy/system proxy, media tools, plugins, provider plugins, Tool Hub/browser automation and configured agent MCP servers to be disabled/empty before apply.
13. Treat a Provider as enabled unless `enabled === false`. Require `enabled` and `autoFetchModels` to be boolean or absent; block if any enabled Provider has `autoFetchModels === true`. Do not modify Provider state.
14. Verify the initial legacy profile mirrors are already source-consistent. Build a JSON-safe deep clone and change only:
    - enabled `claude-code` profiles whose scope is neither `"ccr"` nor `"custom"`—including global, missing and unknown legacy values—to `enabled: false`;
    - `observability.requestLogs` to `false`;
    - `observability.agentAnalysis` to `false`;
    - `observability.requestLogBodyCapture` to `"none"`;
    - source-derived `profile.claudeCode.enabled` to `false`;
    - source-derived `profile.enabled` to the pinned `synchronizeLegacyProfileConfig` result.
15. Canonically prove before save that profile count/IDs/order and every non-allowlisted field—including Providers, preferred Provider, models, router, API keys and onboarding-relevant config—are exact-equal.
16. Without `--apply`, report only whether a change is required and the target safe state; do not claim the current global count is already zero and do not call `saveConfig`.
17. If `--apply` is requested but no change is required, return `APPLY=SKIP|CHANGE=N` without save. T00 must classify this as config-save coverage not exercised, not PASS.
18. Immediately before save, re-read the raw service-state file and require exact equality, then repeat service identity, stopped Gateway, onboarding boolean and `getConfig`. Require the second config to be canonically equal to the initial snapshot and re-run all guards.
19. Check that the configured loopback gateway and core TCP ports are free immediately before save. A race or ambiguity blocks.
20. Call exactly one mutation RPC: `saveConfig([fullNextConfig, { applyProfile: false }])`.
21. Never retry a mutation. Any timeout, disconnect, malformed/oversized response or RPC error after save dispatch is `INDETERMINATE_SAVE` with `SAVE=UNKNOWN`; it is not a safe pre-save block.
22. After a confirmed save response, call `getConfig([])`, `getOnboardingFinished([])` and `getGatewayStatus([])`. Require returned and re-read config exact-equal to the expected target, onboarding unchanged, and post Gateway state either safely stopped or locally managed running—not starting/error/external.
23. Do not call `setOnboardingFinished`, `applyProfile`, `applyClaudeAppGateway`, `openProfile`, Gateway controls, Provider probes, connectivity checks, model catalog methods or model APIs.
24. A Gateway may start only as the stock `saveConfig` side effect. The helper must not invoke it or send a request through it.
25. Never print, persist or return the management URL/token, service token, full config, Provider fields, API keys, model IDs, paths, raw RPC bodies or server error text.
26. Do not stop the service after save or an indeterminate save; T00 A3 always owns fingerprint, stop and cleanup.
27. On any pre-save ambiguity, output a fixed `BLOCKED` category and guarantee no save dispatch.
28. Output exactly one compact sanitized line and a documented process exit code.

## Sanitized output contract

Apply path:

```text
T02|RESULT=PASS|SERVICE=P|GW_PRE=STOP|GW_POST=STOP_OR_RUN|RPC=P|APPLY=P|CHANGE=Y|GLOBAL=0|LOGS=OFF|ANALYSIS=OFF|BODY=NONE|PROVIDER=SAME|ONBOARDING=SAME|AUTOFETCH=OFF|RAW=NO
```

No-save preflight:

```text
T02|RESULT=PASS|SERVICE=P|GW_PRE=STOP|RPC=P|APPLY=N|CHANGE=Y_OR_N|TARGET_GLOBAL=0|TARGET_LOGS=OFF|TARGET_ANALYSIS=OFF|TARGET_BODY=NONE|AUTOFETCH=OFF|RAW=NO
```

Already-safe apply:

```text
T02|RESULT=PASS|SERVICE=P|GW_PRE=STOP|RPC=P|APPLY=SKIP|CHANGE=N|GLOBAL=0|LOGS=OFF|ANALYSIS=OFF|BODY=NONE|PROVIDER=SAME|ONBOARDING=SAME|AUTOFETCH=OFF|RAW=NO
```

Failure output contains only a documented category:

```text
INVALID_ARGUMENTS
BLOCKED_RUNTIME_ENV
BLOCKED_SERVICE_STATE
BLOCKED_SERVICE_IDENTITY
BLOCKED_APP_IDENTITY
BLOCKED_GATEWAY_STATE
BLOCKED_NON_LOOPBACK
BLOCKED_AUTH
BLOCKED_STALE_BACKUP
BLOCKED_RUNTIME_SURFACE
BLOCKED_PORT_IN_USE
BLOCKED_PROVIDER_AUTO_REFRESH
BLOCKED_CONFIG_SHAPE
BLOCKED_CONCURRENT_CHANGE
UNEXPECTED_CONFIG_DIFF
RPC_FAILURE
INDETERMINATE_SAVE
POSTCONDITION_FAILURE
```

Fixed failure capsules:

```text
T02|RESULT=BLOCKED|CATEGORY=<PRE_SAVE_CATEGORY>|SAVE=N|RAW=NO
T02|RESULT=FAIL|CATEGORY=INDETERMINATE_SAVE|SAVE=UNKNOWN|RAW=NO
T02|RESULT=FAIL|CATEGORY=<POST_SAVE_CATEGORY>|SAVE=Y_OR_UNKNOWN|RAW=NO
```

Exit codes:

```text
0 = successful preflight/apply/skip
2 = pre-save BLOCKED; save not dispatched
3 = mutation dispatched or post-save failure
64 = invalid invocation
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

- invocation: default never saves; only one exact `--apply`; invalid/duplicate arguments are fixed-output exit `64`;
- state: missing/malformed/oversized/symlink state, strict field types, dead/mismatched PID, `startGateway != false`, `profileManaged != false`, path overrides and stale backup all block before save;
- endpoint/transport: only canonical numeric loopback HTTP; reject localhost/DNS/LAN/HTTPS/userinfo/fragment/path/port/token/query variants; exact RPC path/header/body, no redirect/proxy/retry, bounded JSON and timeout behavior;
- identity: exact app name/version/platform/config roots, configured/matching token and PID;
- Gateway: stopped/non-external fresh pre-state; unsafe post-state fails;
- runtime surface: loopback gateway/core, free ports and disabled proxy/media/plugin/provider-plugin/Tool Hub/MCP side effects;
- config fallback and malformed JSON-safe shapes block;
- auto-fetch matrix: enabled/absent Provider plus `true` blocks; disabled Provider plus `true` is allowed; non-boolean values block;
- transform: global/missing/unknown Claude scope disabled; `ccr`, `custom` and non-Claude profiles preserved; profile ID/count/order preserved;
- source-derived legacy `profile.claudeCode.enabled` and conditional `profile.enabled` exactly modeled;
- logging/analysis/body capture OFF while Provider/model/router/API-key/onboarding and all unrelated config remain exact;
- concurrency: service state, identity, Gateway, onboarding and config are rechecked; any change blocks before save;
- exact one save with `{ applyProfile: false }`; no forbidden/Gateway/model RPC;
- confirmed save response and post-read exact expected config;
- already-safe apply skips save and is not represented as T00 save coverage;
- save timeout/disconnect is one-attempt `INDETERMINATE_SAVE`, zero retry, fixed exit `3`;
- canary URL/auth/service token/API key/provider endpoint/model/path/server error/raw body never appears in combined stdout/stderr or written artifacts.

## Acceptance criteria

- [ ] exact candidate and instruction SHA recorded
- [ ] diff limited to approved `company/**` paths
- [ ] no upstream/CCR source, dependency, lockfile or workflow change
- [ ] no direct runtime DB/config edit
- [ ] default invocation makes no `saveConfig` call
- [ ] apply requires explicit flag
- [ ] no pre-existing service and fresh A2 state/PID proved by T00 A0/A2
- [ ] pinned app identity/config root verified
- [ ] stale Claude App backup fail-closed
- [ ] loopback HTTP/auth-header/service identity/Gateway pre-state fail-closed
- [ ] unsafe Gateway startup surfaces and occupied ports fail-closed
- [ ] auto-fetch fail-closed
- [ ] exact allowlisted transform proven
- [ ] source-derived legacy profile mirrors modeled
- [ ] profile count/IDs preserved
- [ ] Provider/model/router/API-key/onboarding state preserved
- [ ] concurrency recheck before save
- [ ] `applyProfile:false` passed
- [ ] already-safe state skips save
- [ ] mutation uncertainty classified without retry
- [ ] safe post Gateway state observed
- [ ] no forbidden or explicit Gateway-control RPC invoked
- [ ] synthetic/mock tests pass
- [ ] compact sanitized output only
- [ ] T00 Attempt 2 is the only internal runtime validation
- [ ] T01 remains blocked

## Stop conditions

- A `packages/**`, upstream root, dependency, lockfile or workflow change appears necessary.
- Direct runtime DB/config edit appears necessary.
- Management endpoint is not loopback/authenticated.
- Pinned app identity/config root or fresh service state cannot be proven.
- A stale Claude App backup exists.
- T00 cannot prove the service was stopped before A2 or service identity does not match.
- Gateway is already running or externally owned before save.
- Gateway/core addresses, ports, proxy, media, plugin, Tool Hub or MCP startup surfaces are unsafe.
- Full config round-trip cannot preserve non-target fields.
- Config/service/onboarding state changes during the pre-save concurrency window.
- Enabled Provider auto-fetch cannot be proven OFF before save.
- A Provider/model request or explicit Gateway-control RPC is required.
- Secret/raw internal evidence would need to be exported.
- Human Gate withdraws approval or the required scope expands beyond the approved Company-only paths.

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

T00 Attempt 1 is the only internal runtime Evidence so far.
Human Gate activated this Task on `2026-09-01`; implementation and synthetic tests are now authorized only within the declared paths.
The pinned Management RPC dependency must be revalidated on every upstream update.

## Agent recommendation

`IN_PROGRESS — IMPLEMENT WRAPPER-ONLY HELPER`

## Human decision

`PENDING`
