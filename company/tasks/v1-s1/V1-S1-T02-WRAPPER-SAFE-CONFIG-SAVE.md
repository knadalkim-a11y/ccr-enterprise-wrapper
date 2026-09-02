---
id: V1-S1-T02
stage: V1-S1
title: Add a wrapper-only T00 safe config-save helper
kind: implementation
status: external_pass
primary_actor: EXTERNAL_CODEX
execution_mode: agent_only
implementation_required: true
internal_validation: required
github_write_allowed: true
candidate_sha: final_repair_pr_head_supplied_by_human_gate_owner
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

External implementation is complete for the exact wrapper-only scope below.
Internal runtime validation is `NOT_STARTED` and remains required before merge.

Activation record:

```text
Date: 2026-09-01
Authority: HUMAN_GATE_OWNER
Decision: APPROVED_FOR_IMPLEMENTATION
CCR packages/** changes: PROHIBITED
T00 Attempt 2 at activation: NOT_STARTED
T01: BLOCKED
```

Continuation approval after source/security audit:

```text
Date: 2026-09-01
Authority: HUMAN_GATE_OWNER
Decision: CONTINUE_AS_T00_VALIDATION_ONLY_HELPER
Standalone production safety claim: PROHIBITED
Runtime invariants at that decision: fresh service ownership + relevant-writer quiescence + unconditional cleanup
Status of old A2/A3 labels: RETIRED_BY_A0_ONLY_REPAIR
```

The final Human decision remains pending until a later exact-head T00 runtime Attempt
and Human Gate review. Attempt 3 exact `e16b4a90...` A0 is recorded as
`A0_PASS_ONLY / INCOMPLETE / H0_NOT_STARTED`; the helper itself remains internally
unexecuted. H0 minimal design is approved, but the runtime controller and H0/helper
execution are not implemented or authorized.

## Validation question

> Company-owned helper가 Stock CCR `v3.0.22`의 authenticated loopback Management RPC만 사용해 CCR source와 runtime DB를 직접 수정하지 않고 future T00-approved 안전 상태를 저장할 수 있는가?

## Why now

V1-S1-T00 Attempt 1은 management start isolation을 통과했지만 required cleanup/save에 도달하지 못해 `BLOCKED`됐다.
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
- `saveConfig`는 restart-sensitive config가 바뀌면 Gateway를 side effect로 시작할 수 있다.
- Observability 세 필드 중 하나라도 바뀌면 Stock runtime-change 판정상 Gateway start가 요구된다. Gateway compile은 Provider plugin이 비어 있어도 로컬 Grok OAuth refresh를 시도할 수 있으므로 T02는 observability를 바꾸지 않고 이미 safe인지 확인해야 한다.
- Profile/legacy mirror 필드는 pinned restart predicate에 포함되지 않는다. Reusable API key와 `gateway.enabled=true`가 이미 성립하고 Claude App sync가 config를 바꾸지 않으면 profile-only save는 `updateConfig` 경로를 사용하고 Gateway는 stopped 상태를 유지한다.
- `saveConfig`는 Provider model auto-refresh를 동기화하며 enabled Provider의 `autoFetchModels`가 켜져 있으면 즉시 refresh를 예약한다.
- `getOnboardingFinished`와 `getConfig`도 storage open/initialization/migration 또는 API-key initialization을 수행할 수 있으므로 default mode는 엄밀한 read-only가 아니라 **no-`saveConfig` preflight**다.
- Windows config storage는 sandboxed `LOCALAPPDATA`가 아니라 real `APPDATA`를 사용한다. 첫 repository open 전 constants import는 `%APPDATA%\Claude Code Router` 전체를 active config dir로 복사할 수 있고, repository open은 legacy SQLite/API-key/onboarding stores를 migrate/remove할 수 있다. Legacy JSON source가 선택되면 `getConfig`가 `${ENV}`/`$ENV` placeholder를 process env 값으로 보간한 snapshot을 SQLite에 저장할 수 있다.
- `saveAppConfig`는 legacy profile mirror를 동기화하므로 global Claude Code profile cleanup은 `profile.claudeCode.enabled`와 조건부 `profile.enabled`도 source-derived 값으로 바꾼다.
- Stock reload는 enabled Provider의 명시적 `enabled:true`를 제거한다. Codex/opencode/kilo/workbuddy/zcode profile item에서는 `coreMode`, `frontendMode`, `remoteFrontendMode`를 disk 저장 시 제거한 뒤 reload에서 `remoteFrontendMode:"app"`을 만들고, legacy `profile.codex.remoteFrontendMode`는 제거한다. Helper는 item mode가 exact `"app"`, 두 legacy item field와 legacy profile field가 absent인 fixed point만 허용한다.
- Stock reload는 unknown profile agent를 제거하고 NVIDIA preset Provider capabilities를 한 개의 `openai_chat_completions` capability로 repair한다. Helper는 known exact agent set과 NVIDIA normalized capability fixed point만 허용한다.
- Claude App sync backup은 real `%APPDATA%\claude-code-router`에 저장되므로 stale backup이 있으면 apply 전에 차단해야 한다.
- `getServiceIdentity`만으로 pinned binary/config root를 증명할 수 없으므로 `getAppInfo`의 name/version/platform/config/data paths를 함께 검증해야 한다.
- Management RPC는 pinned `v3.0.22` source dependency이며 영구 public API로 간주하지 않는다.
- `NODE_DEBUG`는 Node startup 전에 제거해야 한다. Helper 내부에서 값을 지우는 것은 HTTP header/body debug를 안전하게 끄는 방법이 아니다.
- Node 24의 coverage/compile-cache/warning redirect 환경변수는 helper code보다 먼저 또는 process exit 때 파일을 만들 수 있고, npm lifecycle은 `npm_config_node_options`/`npm_config_script_shell`을 해석한다. Future T00 runtime procedure는 첫 runtime Node/service 전과 helper spawn 직전에 이 surface를 확인한다.
- `CCR_WEB_AUTH_TOKEN`/`CCR_WEB_ALLOWED_ORIGINS`는 management auth/CORS 경계를 바꾸며, `CCR_MODEL_CATALOG_PATH`와 legacy `CCR_MODELS_JSON_PATH`는 정상 Claude App sync가 읽는 model catalog를 바꾼다. 모두 inherited override로 간주한다.
- Local-agent Provider는 load/save 정규화 중 host의 Grok environment/version file/account endpoint를 읽을 수 있으므로 이 좁은 validation helper에서는 magic local-agent API key를 가진 모든 Provider를 save 전에 차단한다.

## Scope boundary

이 Task는 T00 차단 해소용 validation helper다.
V1-S1에서 Company helper를 추가하는 것은 원래 V1-S3/V1-S4 launcher/Doctor 일정의 좁은 예외이므로 Human Gate의 별도 activation 승인이 필요하다.
Production `company-claude` launcher, installer, setup 또는 Doctor로 일반화하지 않는다.

Stock `v3.0.22` RPC는 daemon이 실제로 상속한 `LOCALAPPDATA`를 노출하지 않고 `saveConfig`에 revision/CAS를 제공하지 않는다.
따라서 helper 단독으로 sandbox inheritance나 원자적 compare-and-save를 증명한다고 주장하지 않는다.
Future T00 runtime instructions가 absent state에서 sandbox `LOCALAPPDATA`로 fresh
daemon을 시작한 사실을 증명하고, relevant CCR management/client writer를 quiesce하며,
결과와 관계없이 actual Enterprise/Claude-3p invariant와 cleanup을 검증하는 범위에서만
사용한다. 기존 A0–A3 same-PowerShell 계약은 retired됐으며 새 runtime controller는
A0 Evidence 뒤 별도 exact head에서 검토한다.
또한 T00은 daemon 시작 직전에 whole legacy Windows config directory와 active/home legacy JSON, legacy API-key DB/sidecars 및 onboarding marker가 absent인지 metadata-only로 확인해야 한다. Canonical config directory, `config.sqlite`와 optional sidecars의 bounded/non-reparse metadata 검사는 DB row/schema fixed point나 첫 open의 무기록성을 증명하지 않으며, helper-only 검사는 import/migration 뒤라 너무 늦다.

이 제한은 CCR source를 수정하지 않는 Human 결정의 명시적 trade-off다.

## Required knowledge

- `company/AGENTS.md`
- `company/tasks/v1-s1/V1-S1-T00-CCR-RUNTIME-SANDBOX.md`
- `company/docs/CLAUDE_CODE_ISOLATION.md`
- `company/docs/SECURITY.md`
- `company/docs/AGENT_WORKFLOW.md`
- `packages/cli/src/cli.ts` — read-only
- `packages/core/src/runtime/app-paths.ts` — read-only
- `packages/core/src/config/constants.ts` — read-only
- `packages/core/src/config/config.ts` — read-only
- `packages/core/src/config/config-repository.ts` — read-only
- `packages/core/src/storage/migration.ts` — read-only
- `packages/core/src/config/onboarding-state.ts` — read-only
- `packages/core/src/web/management-server.ts` — read-only
- `packages/core/src/contracts/app.ts` — read-only
- `packages/core/src/providers/model-auto-refresh.ts` — read-only
- `packages/core/src/agents/claude-app/gateway-service.ts` — read-only
- `packages/core/src/gateway/runtime-change.ts` — read-only
- `packages/core/src/gateway/application/gateway-service.ts` — read-only
- `packages/core/src/gateway/core-runtime/config-compiler.ts` — read-only
- `packages/core/src/agents/local-providers/grok.ts` — read-only
- `packages/core/src/routing/route-script-runtime.ts` — read-only

## In scope

- One dependency-free Node helper under `company/scripts/`.
- Synthetic/mock tests under `company/tests/`.
- Loopback-only authenticated Management RPC.
- Fail-closed preflight and exact allowlisted config transform.
- Compact sanitized output for the keyboard-only Evidence boundary.
- Preserve exact Attempt 3 A0 Evidence while a future T00 Attempt 4 runtime head integrates this helper; helper execution remains deferred.

Role-owned canonical transition after External PASS:

```text
EXTERNAL_CODEX
→ only the frontmatter allowed_paths above

CHATGPT_ORCHESTRATOR
→ may update T00, company/project-state.yml, company/docs/STATUS.md,
  and company/gates/V1-S1.md to record external PASS and activate exact-head T00 retry
```

The orchestrator transition does not expand the helper implementation scope and may not touch `packages/**`.

## Out of scope

- Any change under `packages/**` or other upstream-owned path.
- Runtime DB/config file direct edit.
- Onboarding completion or UI automation.
- Profile application, Connect agent, Let's start or profile launch.
- Provider/key/model/protocol/router/API-key change.
- Provider probe, connectivity check, model refresh or real model request.
- Production launcher/setup/Doctor.
- Standalone claim that the helper attests daemon `LOCALAPPDATA` or provides atomic CAS.
- Dependency, lockfile or workflow change.
- T01.

## Implementation contract

0. Invoke only inside a future Human-approved T00 runtime procedure after that procedure proves no pre-existing service/backup or legacy import/migration source, quiesces relevant same-account CCR/Claude writers, and rechecks those guards immediately before freshly starting the daemon with sandbox `LOCALAPPDATA` from the exact archived-source working directory. The helper does not independently attest daemon `LOCALAPPDATA`, legacy pre-start absence, DB row/schema fixed point, or runtime cwd and is not a production launcher.
1. Accept only no argument or one exact `--apply`; invalid arguments return a fixed usage category without echoing input. Default mode is a **no-`saveConfig` preflight**, not an inert/read-only claim.
2. Require Windows and an absolute `APPDATA`. Reject `CCR_INTERNAL_APP_DATA_DIR`, `CCR_INTERNAL_HOME_DIR`, `CCR_INTERNAL_USER_DATA_DIR`, `CCR_GATEWAY_ENTRY`, `CCR_MODELS_JSON_PATH`, `CCR_MODEL_CATALOG_PATH`, `CCR_NODE_BIN`, `CCR_UPSTREAM_PROXY_URL`, `CCR_WEB_ALLOWED_ORIGINS`, `CCR_WEB_AUTH_TOKEN`, `NODE_COMPILE_CACHE`, `NODE_DEBUG`, `NODE_OPTIONS`, `NODE_REDIRECT_WARNINGS`, `NODE_V8_COVERAGE`, `npm_config_node_options` and `npm_config_script_shell`. Never fall back to restored `LOCALAPPDATA`. The future T00 runtime controller must prove these values are absent before its first runtime Node/service process and again immediately before helper spawn; helper-side rejection is defense in depth, not a claim that Node startup artifacts can be prevented from JavaScript.
3. Read only `%APPDATA%\claude-code-router\service.json`, with file-type and size limits. Require the pinned exact state shape, positive numeric PID, live process, `profileManaged === false`, `startGateway === false`, nonempty service token, valid `startedAt`, and no unexpected keys.
4. Require `%APPDATA%\claude-code-router\claude-app-gateway-backup.json` to be absent before any RPC that can save.
5. Accept only a canonical `http://127.0.0.1:<explicit-port>/?ccr_web_token=<one-nonempty-value>` URL: root path, no userinfo, fragment, extra/duplicate query or DNS hostname. Send the token only as `x-ccr-web-auth` to fixed `/api/ccr/rpc`.
6. Use direct built-in `node:http` with `agent: false`, no redirect/retry/proxy, an absolute timeout, explicit content length, exact `application/json` media-type validation, and bounded request/response bodies on every status path. Fail before loading secrets or networking if the Node process inherited `NODE_DEBUG` or `NODE_OPTIONS`.
7. Call `getAppInfo([])` and require exact name `Claude Code Router`, version `3.0.22`, platform `win32`, and config/data paths equal to `%APPDATA%\claude-code-router` without printing them.
8. Call `getServiceIdentity([serviceToken])`. Require `serviceTokenConfigured === true`, `serviceTokenMatches === true`, and returned PID equal to service state.
9. Call `getGatewayStatus([])`. Require exact fresh pre-save state `stopped`, no external-management flag equal to `true`, PID/endpoint/core endpoint/network listener absent, and no prior error/start timestamp.
10. Call `getOnboardingFinished([])` and retain only its boolean value for equality checking.
11. Call `getConfig([])` and reject fallback/default or malformed config: nonempty enabled Provider/model, unique profile IDs, existing reusable API key, pinned JSON-safe shape, and required current-config invariants.
12. Require `gateway.enabled === true`, numeric gateway/core ports and exact loopback hosts. Require proxy/system proxy/network capture, media tools, plugins, provider plugins, Tool Hub/browser automation, configured agent MCP servers and Context Archive to be disabled/empty, require `virtualModelProfiles` to be empty, and reject every enabled Router script rule before apply.
13. Treat a Provider as enabled unless `enabled === false`. Require Stock-canonical Provider state: `enabled` is absent for enabled Providers and exact `false` for disabled Providers; `autoFetchModels` is boolean or absent. Block every magic local-agent Provider and block if any enabled Provider has `autoFetchModels === true`. For an NVIDIA preset base URL, require the exact single normalized `openai_chat_completions` capability fixed point. Do not modify Provider state.
14. Require `observability.requestLogs === false`, `observability.agentAnalysis === false` and `observability.requestLogBodyCapture === "none"` before building a target; never change observability in this Task. Require every profile agent to be in the pinned known exact agent set and every scope to be canonical `global`, `ccr` or `custom`; missing/unknown agent or scope blocks before save. Every Codex/opencode/kilo/workbuddy/zcode item must have exact `remoteFrontendMode:"app"` with `coreMode` and `frontendMode` absent, and legacy `profile.codex.remoteFrontendMode` must be absent. Verify the full initial Claude/Codex legacy mirrors and single-enabled-global-per-agent invariant are already source-consistent. Build a JSON-safe deep clone and change only:
    - enabled `claude-code` profiles with exact scope `"global"` to `enabled: false`;
    - source-derived `profile.claudeCode.enabled` to `false`;
    - source-derived `profile.enabled` to the pinned `synchronizeLegacyProfileConfig` result.
15. Canonically prove before save that profile count/IDs/order and every non-allowlisted field—including all observability, Providers, preferred Provider, models, router, API keys and onboarding-relevant config—are exact-equal. The snapshot must also be a fixed point for pinned Stock Provider/profile reload normalization.
16. Without `--apply`, report only whether a change is required and the target safe state; do not claim the current global count is already zero and do not call `saveConfig`.
17. If `--apply` is requested but no change is required, return `APPLY=SKIP|CHANGE=N` without save. T00 must classify this as config-save coverage not exercised, not PASS.
18. Check the configured loopback gateway and core TCP ports immediately before the final snapshot sequence; occupied or ambiguous ports block.
19. After the port checks, re-read the raw service-state file and require exact equality, then repeat service identity, stopped Gateway, onboarding boolean and `getConfig`, re-run all guards, and check backup absence again. Require the second config to be canonically equal to the initial snapshot. Stock RPC has no revision/CAS, so relevant same-account writer quiescence in the future T00 runtime procedure is mandatory and this checkpoint is not described as an atomic guarantee.
20. Call exactly one explicit mutation RPC: `saveConfig([fullNextConfig, { applyProfile: false }])`. Read RPC handlers may initialize/migrate Stock storage, so “one mutation RPC” is not a claim that no internal storage write can occur.
21. Never retry a mutation. Any timeout, disconnect, malformed/oversized response or RPC error after save dispatch is `INDETERMINATE_SAVE` with `SAVE=UNKNOWN`; it is not a safe pre-save block.
22. After a confirmed save response, call `getConfig([])`, `getOnboardingFinished([])` and `getGatewayStatus([])`. Require returned and re-read config exact-equal to the expected target, onboarding unchanged, and post Gateway state still `stopped` with configured loopback endpoints, no PID/external ownership/network endpoint/error/start timestamp. Any `running`, `starting` or `error` state is a post-save failure.
23. Do not call `setOnboardingFinished`, `applyProfile`, `applyClaudeAppGateway`, `openProfile`, Gateway controls, Provider probes, connectivity checks, model catalog methods or model APIs.
24. Gateway start is prohibited. The pinned source proof and exact profile-only diff must keep the Stock save on `gatewayService.updateConfig`; any observed start is `POSTCONDITION_FAILURE`, followed by the future T00 runtime controller's unconditional cleanup/invariance step. The helper must not invoke or send a request through the Gateway.
25. Never print, persist or return the management URL/token, service token, full config, Provider fields, API keys, model IDs, paths, raw RPC bodies or server error text.
26. Do not stop the service after save or an indeterminate save; the future T00 runtime controller's unconditional cleanup/invariance step owns fingerprint, stock stop, captured-PID death proof and cleanup. That step is required for every helper result, especially `SAVE=UNKNOWN`.
27. On any ambiguity observed before mutation dispatch, output a fixed `BLOCKED` category and guarantee no save dispatch. Client-side snapshot checks do not claim to replace unavailable server-side CAS.
28. Output exactly one compact sanitized line and a documented process exit code.

## Sanitized output contract

Apply path:

```text
T02|RESULT=PASS|SERVICE=P|GW_PRE=STOP|GW_POST=STOP|RPC=P|APPLY=P|CHANGE=Y|GLOBAL=0|LOGS=OFF|ANALYSIS=OFF|BODY=NONE|PROVIDER=SAME|ONBOARDING=SAME|AUTOFETCH=OFF|RAW=NO
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
git diff --check 05bd8fd14048c2544a31deae99bafac4d2820ece HEAD
git diff --name-status 05bd8fd14048c2544a31deae99bafac4d2820ece HEAD
git diff 05bd8fd14048c2544a31deae99bafac4d2820ece HEAD -- company/scripts company/tests company/tasks/v1-s1/V1-S1-T02-WRAPPER-SAFE-CONFIG-SAVE.md
git diff --exit-code 97b73a9f4e1fb23d406bb987d0785cefa1f99966 HEAD -- packages package.json package-lock.json
git status --porcelain
```

Tests use only synthetic configs, fake tokens and a loopback mock RPC server.

External result:

```text
Date: 2026-09-01
Base commit: 05bd8fd14048c2544a31deae99bafac4d2820ece
Implementation scope: company/scripts + company/tests + this Task only
node --check: PASS
node --test: PASS — 159/159
Protected CCR source/build/package path equivalence: PASS
Candidate/full-head build equivalence: NOT_TESTED / NOT_CLAIMED
CCR packages/** changed: NO
Secrets/raw internal evidence used: NO
Internal runtime validation: NOT_STARTED
Recommendation: READY_FOR_INTERNAL_VALIDATION
```
They must cover:

- invocation: default never saves; only one exact `--apply`; invalid/duplicate arguments are fixed-output exit `64`;
- state: missing/malformed/oversized/symlink state, strict field types, dead/mismatched PID, `startGateway != false`, `profileManaged != false`, path/runtime/debug/output/auth/catalog/Gateway-executable overrides and stale backup all block before save;
- endpoint/transport: only canonical numeric loopback HTTP; reject localhost/DNS/LAN/HTTPS/userinfo/fragment/path/port/token/query variants; exact RPC path/header/body, no redirect/proxy/retry, bounded JSON and timeout behavior;
- identity: exact app name/version/platform/config roots, configured/matching token and PID;
- Gateway: exact stopped/non-external/never-started fresh pre-state; only configured local `STOP` is accepted post-save;
- runtime surface: loopback gateway/core, free ports, logging already safe, and disabled proxy/network-capture/media/plugin/provider-plugin/Tool Hub/MCP/Context Archive/virtual-model/enabled-script side effects;
- config fallback and malformed JSON-safe shapes block;
- Provider matrix: every local-agent Provider blocks; enabled/absent Provider plus auto-fetch `true` blocks; disabled Provider plus `true` is allowed; non-boolean values block; NVIDIA preset capability fixed point is exact;
- transform: canonical global Claude scope disabled; missing/unknown agent or scope blocks; `ccr`, `custom` and known non-Claude profiles preserved; profile ID/count/order preserved;
- complete Stock-shaped `AppConfig` success fixture and independent pinned save-normalization emulator, including enabled-Provider omission, Codex-family mode strip/reload, legacy mode removal and the profile-only `updateConfig` versus runtime-sensitive `start` decision;
- full source-derived Claude/Codex legacy mirrors, single-global invariant and conditional `profile.enabled` exactly modeled;
- logging/analysis/body capture are already OFF/NONE and remain exact while Provider/model/router/API-key/onboarding and all unrelated config remain exact;
- concurrency: service state, identity, Gateway, onboarding and config are rechecked; any change blocks before save;
- exact one save with `{ applyProfile: false }`; no forbidden/Gateway/model RPC;
- confirmed save response and post-read exact expected config;
- already-safe apply skips save and is not represented as T00 save coverage;
- save timeout/disconnect is one-attempt `INDETERMINATE_SAVE`, zero retry, fixed exit `3`;
- canary URL/auth/service token/API key/provider endpoint/model/path/server error/raw body never appears in helper capsules; actual CLI stdout/stderr is tested with startup debug/preload options absent, and no helper-created artifact or service-state write appears.

## Acceptance criteria

- [ ] exact candidate and instruction SHA recorded
- [ ] diff limited to approved `company/**` paths
- [ ] no upstream/CCR source, dependency, lockfile or workflow change
- [ ] no direct runtime DB/config edit
- [ ] validation-only scope and unavailable daemon-LOCALAPPDATA/CAS attestation limitation recorded
- [ ] default invocation makes no `saveConfig` call
- [ ] apply requires explicit flag
- [ ] no pre-existing service and fresh state/PID proved by a future approved T00 runtime controller
- [ ] pinned app identity/config root verified
- [ ] stale Claude App backup fail-closed
- [ ] loopback HTTP/auth-header/service identity/Gateway pre-state fail-closed
- [ ] Node startup/debug and Gateway executable/upstream override env fail-closed before secrets/network
- [ ] logging/analysis/body capture already OFF/OFF/NONE and unchanged
- [ ] unsafe Gateway startup/network-capture/Context Archive/virtual-model/enabled-script surfaces and occupied ports fail-closed
- [ ] auto-fetch fail-closed
- [ ] exact allowlisted transform proven
- [ ] full source-derived legacy profile mirrors and single-global invariant modeled
- [ ] Stock Provider/profile reload fixed point modeled, including NVIDIA capabilities, exact Codex-family `remoteFrontendMode:"app"` and stripped legacy fields; missing/unknown profile agent or scope blocks
- [ ] profile count/IDs preserved
- [ ] Provider/model/router/API-key/onboarding state preserved
- [ ] concurrency recheck before save
- [ ] `applyProfile:false` passed
- [ ] already-safe state skips save
- [ ] mutation uncertainty classified without retry
- [ ] post Gateway remains exactly stopped; any start fails
- [ ] no forbidden or explicit Gateway-control RPC invoked
- [ ] synthetic/mock tests pass
- [ ] compact sanitized output only
- [ ] T00 Attempt 3 exact `e16...` A0 is recorded PASS-only; current authorized phase is `NONE` and helper runtime remains `NOT_STARTED`
- [ ] T01 remains blocked

## Stop conditions

- A `packages/**`, upstream root, dependency, lockfile or workflow change appears necessary.
- Direct runtime DB/config edit appears necessary.
- Management endpoint is not loopback/authenticated.
- Pinned app identity/config root or fresh service state cannot be proven.
- A stale Claude App backup exists.
- The future T00 runtime procedure cannot prove no pre-existing service and fresh service ownership, or service identity does not match.
- Gateway is already running or externally owned before save.
- Gateway/core addresses, ports, proxy, media, plugin, Tool Hub or MCP startup surfaces are unsafe.
- Request logs/agent analysis/body capture are not already `OFF/OFF/NONE`, or an enabled Router script would be prepared.
- Node startup/debug, Gateway executable or inherited upstream override env is present.
- Full config round-trip cannot preserve non-target fields.
- Config/service/onboarding state changes during the pre-save concurrency window.
- The future T00 runtime procedure cannot quiesce relevant same-account CCR management/config writers for the client-side snapshot/save interval.
- Enabled Provider auto-fetch cannot be proven OFF before save.
- A Provider/model request or explicit Gateway-control RPC is required.
- The save would require or actually causes a Gateway start.
- Secret/raw internal evidence would need to be exported.
- Human Gate withdraws approval or the required scope expands beyond the approved Company-only paths.

## Internal validation and merge

`merge_policy: internal_pass_required`.

After External PASS, Human Gate supplies the exact PR head as candidate/instruction SHA.
T00 Attempt 2 stopped at A0 on `c2459b90182041afdb7b9c0cf44149494b30f910` with
`BLOCKED_TOOLCHAIN_IDENTITY`; no helper/runtime service execution occurred. T00 Attempt 3
then completed A0 on exact `e16b4a90...`, but did not invoke the helper/service/H0.
Future Attempt 4 requires a reviewed Company-owned controller, new exact-head approval and
source verification. Helper runtime remains deferred.
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
Secrets/raw evidence included in sanitized result: NO
GitHub PR:
Next Task started: NO
```

## Attempts

| Attempt | Actor / session role | Candidate | Instruction | External | Internal | Recommendation |
|---:|---|---|---|---|---|---|
| 1 | EXTERNAL_CODEX / wrapper-only implementation | helper/test blobs frozen in PR #23 | same as candidate | `PASS` — syntax, 159/159 synthetic/mock tests, protected CCR source/build/package paths equal tested product; candidate/full-head build equivalence not tested or claimed | helper runtime `NOT_STARTED`; T00 Attempt 3 exact `e16...` A0 `PASS_ONLY` without service/helper invocation | `RUNTIME_CONTROLLER_PENDING` — integrate in a new exact Attempt 4 head; current execution authorization `NONE` |

## Evidence / limitations

T00 Attempt 1 remains the only internal service/runtime execution Evidence so far.
Attempt 2 added only an A0 `BLOCKED_TOOLCHAIN_IDENTITY` capsule; exact checkpoint was
not captured, post-block diagnostic was not run, and its console is closed.
Attempt 3 exact `e16b4a90...` passed source verification/install/typecheck/build A0 only;
it did not add helper/runtime service coverage.
Human Gate activated this Task on `2026-09-01`; implementation and synthetic tests passed only within the declared paths.
The helper remains validation-only and has not run against internal runtime data.
The pinned Management RPC dependency must be revalidated on every upstream update.

## Agent recommendation

`RUNTIME_CONTROLLER_PENDING — H0 DESIGN APPROVED; FREEZE A NEW EXACT ATTEMPT 4 HEAD BEFORE INTERNAL EXECUTION`

## Human decision

`PENDING`
