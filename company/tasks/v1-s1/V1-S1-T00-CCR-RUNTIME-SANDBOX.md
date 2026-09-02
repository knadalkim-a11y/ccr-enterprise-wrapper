---
id: V1-S1-T00
stage: V1-S1
title: Prove CCR runtime sandbox and Enterprise baseline invariance
kind: spike
status: in_progress
primary_actor: INTERNAL_VALIDATOR
execution_mode: human_assisted
implementation_required: true
internal_validation: required
github_write_allowed: false
candidate_sha: pending_exact_runtime_head
instruction_sha: same_as_candidate
candidate_role: validation_overlay
tested_product_sha: 97b73a9f4e1fb23d406bb987d0785cefa1f99966
merge_policy: internal_pass_required
authorized_phase: NONE
depends_on:
  - V1-S0-T02
unblocks:
  - V1-S1-T01
required_capabilities:
  - WINDOWS_RUNTIME_ALLOWED
  - CLAUDE_CODE_EXECUTION_ALLOWED
allowed_git_actions:
  - init_bare_disposable_repository
  - explicit_ref_fetch_to_disposable_repository
  - show_task_and_required_knowledge_at_instruction_sha
  - archive_to_nonce_workspace
  - rev_parse
  - hash_object_without_write
  - merge_base
  - diff_name_only_for_candidate_scope
  - diff_exit_code
allowed_paths:
  - AGENTS.md
  - company/AGENTS.md
  - company/project-state.yml
  - company/docs/AGENT_WORKFLOW.md
  - company/docs/DECISIONS.md
  - company/docs/DESIGN_SESSION_PLAYBOOK.md
  - company/docs/ENVIRONMENTS.md
  - company/docs/INTERNAL_VALIDATION.md
  - company/docs/ROLES_AND_HANDOFF.md
  - company/docs/STATUS.md
  - company/docs/TRAPS.md
  - company/gates/V1-S1.md
  - company/scripts/t00-a0-preflight.ps1
  - company/scripts/t00-runtime-controller.ps1
  - company/scripts/t00-safe-config-save.mjs
  - company/tasks/README.md
  - company/tasks/TASK_TEMPLATE.md
  - company/tasks/v1-s1/V1-S1-T00-CCR-RUNTIME-SANDBOX.md
  - company/tasks/v1-s1/V1-S1-T02-WRAPPER-SAFE-CONFIG-SAVE.md
  - company/tests/t00-a0-preflight-contract.test.mjs
  - company/tests/t00-runtime-controller-contract.test.mjs
  - company/tests/t00-safe-config-save.test.mjs
forbidden_paths:
  - packages/**
  - build/**
  - package.json
  - package-lock.json
human_decision: retry
---

# Prove CCR Runtime Sandbox and Enterprise Baseline Invariance

## Current authorization boundary

이 head는 다음 두 사실만 canonical하게 기록한다.

```text
Attempt 3 at e16b4a90...: A0_PASS_ONLY / INCOMPLETE / H0_NOT_STARTED
H0 minimal design: APPROVED
```

이 head 자체가 승인하는 사내 실행은 없다.

```text
Authorized phase: NONE
Runtime controller: NOT_IMPLEMENTED
H0 execution: NOT_AUTHORIZED
A1+ / T01 / merge: HOLD
```

이번 Human 결정은 A0 Evidence 기록과 H0 설계만 승인했다. 이후 runtime controller
구현, 새 exact PR head 승인과 source verification 없이는 Attempt 4 H0를 시작하지
않는다. 아래 Attempt 3 A0 script/contract는 보존된 Evidence의 의미를 설명하는
historical asset이며 새 head에서 다시 실행할 권한이 아니다.

A0 PASS와 H0 설계 승인은 T00 PASS, T02 internal PASS, PR merge 승인 또는 H0 실행
승인이 아니다. 이전의 “A0부터 A3까지 동일 PowerShell process 유지” 계약은 폐기한다.

## Validation question

> Stock CCR management/runtime를 process-local `LOCALAPPDATA` sandbox에서 실행하고
> global/System-default Claude Code profile을 제거해도 Enterprise Claude Code와
> 실제 Claude Desktop의 CCR-managed surface가 변경되지 않는가?

전체 질문의 내부 runtime 검증은 아직 끝나지 않았다. 현재 A0 checkpoint는 다음
선행 질문만 답한다.

> Human이 승인한 exact PR overlay와 exact tested-product build plane을 사내 Windows에서
> shared checkout 변경 없이 materialize하고 install/typecheck/build를 완료할 수 있는가?

## Why this Task exists

Attempt 1에서 process-local `LOCALAPPDATA`를 사용한 management start isolation은
통과했다. 그러나 unfinished onboarding에서는 금지된 `Connect agent` 없이 required
cleanup/save 화면에 도달할 수 없어 config-save isolation은 실행되지 않았다.

Human Gate는 CCR `packages/**` patch를 거부하고 Stock authenticated loopback
Management RPC를 사용하는 Company-only helper `V1-S1-T02`를 승인했다. Helper는
159/159 external synthetic/mock tests를 통과했지만 internal runtime에서는 실행되지 않았다.
T02는 완료된 dependency가 아니라 이 A0가 reviewed helper/test blob으로 확인할
`external_pass` artifact이며, 나중 runtime 검증에서만 prerequisite가 된다.

Attempt 2 A0는 dependency install/typecheck/build를 수행한 뒤
`BLOCKED_TOOLCHAIN_IDENTITY`를 반환했으나 기존 capsule이 exact checkpoint를
보존하지 않았다. 따라서 stale console을 재사용하지 않고 A0 계약만 단순화한다.

## Required knowledge

- `company/docs/INTERNAL_VALIDATION.md`
- `company/docs/SECURITY.md`
- `company/docs/TRAPS.md`
- `company/docs/CLAUDE_CODE_ISOLATION.md`
- `company/scripts/t00-a0-preflight.ps1`
- `company/tasks/v1-s1/V1-S1-T02-WRAPPER-SAFE-CONFIG-SAVE.md`
- `company/scripts/t00-safe-config-save.mjs`
- `packages/cli/src/cli.ts` — read-only
- `packages/core/src/config/constants.ts` — read-only
- `packages/core/src/config/config-repository.ts` — read-only
- `packages/core/src/config/default-config.ts` — read-only
- `packages/core/src/web/management-server.ts` — read-only
- `packages/core/src/gateway/runtime-change.ts` — read-only

T02 Task/helper와 CCR runtime source는 historical A0에서 실행하거나 해석하지 않았다.
위 추가 경로는 이번 H0 설계의 source 근거이며, future controller implementation head는
실제 executable contract에 필요한 exact knowledge와 artifact를 다시 동결해야 한다.

## Attempt 3 A0 contract — historical

아래 `Exact handoff tuple`부터 `Human-readable Evidence`까지는 exact head
`e16b4a90c7f5f7171905ad7c2993e8dcf6781353`에서 실행된 Attempt 3 A0 계약을
Evidence와 함께 보존한다. 현재 design head 또는 future Attempt 4의 실행 권한이 아니며,
hard-coded A0 script를 새 head에서 다시 실행하지 않는다.

## Attempt 3 exact handoff tuple — historical

Human Gate가 보낸 A0 handoff에는 다음 값이 모두 있어야 했다. 이 A0 head에는
중간 Human Step이 없으며 agent는 A0 result를 출력한 뒤 멈춘다.

```text
Canonical repository URL: https://github.com/knadalkim-a11y/ccr-enterprise-wrapper.git
Repository main SHA: 6d0d6f2aeca02e33261c062eac5aab360805222b
Main fetch ref: refs/heads/main
Candidate fetch ref: refs/pull/23/head
Prepared main ref: refs/internal-validation/v1-s1-t00-main
Prepared candidate ref: refs/internal-validation/v1-s1-t00-candidate
Candidate SHA: e16b4a90c7f5f7171905ad7c2993e8dcf6781353
Instruction SHA: e16b4a90c7f5f7171905ad7c2993e8dcf6781353
Candidate role: validation_overlay
Tested product SHA: 97b73a9f4e1fb23d406bb987d0785cefa1f99966
Task path: company/tasks/v1-s1/V1-S1-T00-CCR-RUNTIME-SANDBOX.md
A0 script path: company/scripts/t00-a0-preflight.ps1
Attempt: 3
Authorized phase: A0_ONLY
Execution mode: agent_only
Merge policy: internal_pass_required
Required capability: WINDOWS_RUNTIME_ALLOWED=YES
Separate account/VM required by internal policy: NO
Same Windows account concurrent use: NO
Npm network/lifecycle permission and current-user residual credential-exposure risk accepted: YES
Environment alias: REQUIRED HUMAN-SUPPLIED SANITIZED LABEL; value not re-transcribed in current external Evidence
```

Environment alias는 Human이 만든 비식별 표시자다. Agent가 hostname, username,
device/asset ID를 자동 조회해 사용하지 않고, 그 실제 값을 외부로 반환하지 않는다.

Authority는 다음 교집합이다.

```text
canonical main governance
∩ trusted Human handoff
∩ candidate가 스스로 좁힌 제한
```

Candidate 문서가 handoff의 권한을 확대할 수 없다. 현재 checkout, local branch,
`origin`, 과거 대화 또는 agent memory는 권한 근거가 아니다.
Full validated-product archive 안의 historical `AGENTS.md`, Task/state/docs는 build
data일 뿐 authority가 아니다. Agent는 이를 context로 다시 load하거나 실행하지
않고 candidate/instruction plane의 approved Task만 따른다.

### Why this PR overlay is authorized but non-expanding

Canonical main `6d0d6f2...` already records both of the following.

- T00 retains product candidate `97b73a9...` while `instruction_sha` is supplied by the
  Human Gate Owner, so instruction and tested product may already be separate.
- Human Gate approves the Task and exact candidate/instruction SHA.

This repaired overlay keeps the same `V1-S1-T00` stage, validation question and
Enterprise invariants. It narrows execution from the older full runtime procedure to
source verification + A0 only, replaces shared-checkout mutation with disposable
fetch/archive, and adds only the reviewed Company A0 script/test plus exact allowlisted
governance text. The previously reviewed T02 helper/test remain byte-identical to the
old PR head. The exact PR head is a Human-approved `validation_overlay`; candidate
protected product/source paths are byte-equivalent to validated product `97b73a9...`,
and actual build input is the full `97b73a9...` archive, not the
candidate whole tree. GitHub write, CCR service/UI/config mutation and H0/A1+ are prohibited.
Therefore this exact Human-approved PR head is an execution overlay within main's
delegation, not a replacement for canonical main and not an authority expansion.

## Attempt 3 source verification and Attempt boundary — historical

별도 B0/R0 상태나 추가 Human 승인 왕복을 만들지 않는다. 자기완결형 A0 prompt의
첫 부분에서 다음 source verification을 수행하고, 모두 PASS하면 같은 prompt에서
A0 script로 진행한다.

1. Absolute Windows PowerShell 5.1 application을 `-NoProfile -NonInteractive`로
   한 번 시작하고, 그 child 안에서 `Get-Command git.exe -CommandType Application`의
   첫 absolute Application path 하나를 bind해 모든 init/fetch/show/archive/hash에
   재사용한다. 기존 clone을 변경하지 않고 repository 밖
   `%LOCALAPPDATA%\CompanyCCR\validation-workspaces\<32hex>` nonce 경로 하나를 만든다.
   이 child bootstrap에서 inherited
   `GIT_*`를 모두 제거하고 `GIT_CONFIG_NOSYSTEM=1`, `GIT_CONFIG_GLOBAL=NUL`,
   `GIT_TERMINAL_PROMPT=0`, `GCM_INTERACTIVE=Never`를 적용한다. Nonce 안의 빈
   template directory로 `git init --bare --template=<empty>`를 실행해 `repo.git`을
   만들고 fetch에는 `-c credential.helper=`를 적용한다.
2. Literal canonical HTTPS URL에서 `refs/pull/23/head`와 `refs/heads/main`을
   `--no-tags`, `--prune` 없이 각각 `refs/internal-validation/v1-s1-t00-candidate`와
   `refs/internal-validation/v1-s1-t00-main`으로 fetch한다.
3. fetched PR ref가 approved candidate/instruction SHA와 정확히 같은지 확인한다.
4. fetched main ref가 approved main SHA와 같은지 확인한다.
5. approved Task path/id/stage/authorized phase/execution mode와
   `candidate_role: validation_overlay`, exact `tested_product_sha`를 확인하고 Required
   knowledge의 Task-declared exact paths만 approved candidate/instruction plane에서
   read-only `git show`로 읽는다.
6. Candidate의 exact A0 script blob을 Git의 binary-safe archive로 materialize한다.
   PowerShell text redirection으로 script bytes를 다시 쓰지 않는다. Windows
   PowerShell 5.1 parser로 syntax error가 없는지 확인하고, 실행 전에 candidate의
   expected blob과 extracted file의 `git hash-object --no-filters`가 같은지 확인한다.
7. Absolute Windows PowerShell 5.1 application을 사용해 `-NoProfile -NonInteractive
   -File`로 exact script를 실행하고 prepared bare repository path와 handoff tuple을
   인자로 전달한다. Script process exit code를 보존한다.

Changed-path scope, protected product/source equality, T02 reviewed blobs와 full
validated-product archive는 A0 script가 fail-closed로 확인한다. Bootstrap에 같은
parser/검사를 중복 구현하지 않는다.

이 단계에서 ref/SHA/task/script가 불일치하면 다음으로 종료한다.

```text
Event: PRE_EXECUTION_HANDOFF_BLOCKED
Approved Task-phase command/runtime UI/A0 started: NO
Source-verification commands/local write: REPORT_ACTUAL
Canonical Git fetch/network read: REPORT_ATTEMPTED_OR_NOT_STARTED
Workspace ID: <32hex>
Nonce retained for review: YES
Formal Task result/category: NOT_APPLICABLE
Attempt 3: NOT_STARTED
```

Source verification이 PASS하고 `t00-a0-preflight.ps1`가 실제 실행되기 시작할 때
Attempt 3가 시작된다.

## Attempt 3 truthful local effects — historical

Source verification과 A0는 read-only라고 표현하지 않는다.

```text
Canonical Git fetch/network read: YES
A0-requested GitHub/remote write: NONE
A0-authored Git history/source: NONE
A0-targeted existing shared checkout mutation: NONE
Disposable local Git object/ref write: YES
Validation workspace write: YES
npm network access permitted: YES
npm actual connection observation: NOT_CLAIMED
Dependency lifecycle execution permitted: YES
Dependency lifecycle actual execution observation: NOT_CLAIMED
A0-requested CCR/service/Gateway/UI/config action: NONE
Dependency-child effects outside nonce: NOT_OBSERVED / NOT_CLAIMED
```

`RAW=NO`는 과정을 숨긴다는 뜻이 아니라 이 sanitized result/capsule에
secret/raw 내부 자료를 싣지 않았다는 뜻이다. Network-enabled dependency
lifecycle의 실제 child/network behavior에 대한 host-wide attestation은 아니다.

## Attempt 3 A0 script contract — historical

Canonical instruction asset:

```text
company/scripts/t00-a0-preflight.ps1
```

Script는 다음만 수행한다.

1. Windows x64와 Windows PowerShell 5.1을 확인한다.
2. prepared bare repository의 exact refs/objects/task/candidate scope를 다시 확인하고,
   candidate의 protected product 경로와 T02 helper/test blob을 검증한다.
3. candidate 전체가 아니라 full validated product commit `97b73a9...`를 prepared
   repository와 같은 single nonce workspace에 archive/extract한다. 이렇게 하면
   Tailwind의 repository-wide automatic source scan도 실제 V1-S0 tested tree와 같다.
   Shared checkout은 fetch/prune/pull/checkout하지 않는다.
4. 실행 중인 script bytes가 candidate의 approved script와 같은지 확인한다.
5. Node `>=22` LTS와 같은 설치의 `npm-cli.js`를 bound Node로 실행한다.
6. private npm user/global config, cache, temp를 사용하고 child environment에서
   credential-like 변수와 inherited `npm_config_*` override를 제거한다.
7. 다음을 한 번씩 실행한다.

```text
npm ci --audit=false --fund=false --ignore-scripts=false
node node_modules/typescript/bin/tsc --noEmit
node build/build.mjs
```

8. full validated-product archive의 install/build 전후 source fingerprint가 같은지 확인한다.
9. built CLI가 regular file인지 확인한다. T02 helper/test는 build root 밖의 candidate
   Git blob으로만 확인하며 A0에서 실행하지 않는다.
10. readable result, sanitized 32-hex workspace ID와 compact capsule을 출력하고 종료한다.

Script는 CCR service/Gateway/UI를 시작하거나 actual CCR/Claude config를 읽고 쓰지
않는다. npm nonce workspace는 filesystem sandbox가 아니며 dependency lifecycle
process가 현재 Windows user 권한으로 실행될 수 있다. Human의 나중 exact-head A0
승인은 이 standard supply-chain risk 수용과 script의
`-AllowNpmNetworkAndLifecycle` switch 승인을 함께 명시해야 한다. 현재 PR 편집
승인만으로 사내 실행 승인을 추정하지 않는다.

Single nonce workspace는 A0 Evidence 검토를 위해 유지하고, 외부로 반환된
32-hex workspace ID로 해당 nonce만 나중에 정리한다. Gate 검토 전 자동
삭제하거나 상위 `validation-workspaces` 전체를 광범위하게 정리하지 않는다.

다음이면 A0를 시작하지 않는다. Human은 새 exact-head A0 승인 한 번에 아래 세
조건을 sanitized handoff field로 확인하며, Agent가 host identity/session을 조회해
대신 판단하지 않는다.

- 사내 정책이 별도 account/VM을 요구한다.
- 같은 Windows account를 다른 사람이 동시에 사용한다.
- 현재 account에서 dependency child process에 허용할 수 없는 credential exposure가 있다.

이 경우 별도 account/VM은 `CONDITIONAL` 통제이며 모든 환경에 의무화하지 않는다.

## Attempt 3 A0 Acceptance criteria — historical

모두 충족해야 `A0_PASS_PAUSED_FOR_REVIEW`다.

- exact main/PR ref/candidate/instruction/task/script identity PASS
- candidate changed paths contained by exact allowlist
- candidate protected product/source paths equal validated product
- full tested product commit `97b73a9...` archive selected for build
- reviewed T02 helper/test candidate blob identity PASS
- shared checkout mutation `NO`
- Windows x64 / Windows PowerShell 5.1 PASS
- Node `>=22` LTS and coherent npm CLI PASS
- dependency install exit `0`
- typecheck exit `0`
- build assets exit `0`
- product source fingerprint unchanged
- built CLI present
- CCR service/Gateway/UI/model request `NOT_STARTED`
- H0/A1+ `NOT_STARTED`
- secret/raw evidence included in sanitized result `NO`

## Attempt 3 A0 result rules — historical

### PASS

Process exit code는 `0`이다.

```text
A0_PASS_PAUSED_FOR_REVIEW
```

사람이 읽는 설명 뒤에 다음 capsule을 제공한다.

```text
A0|RESULT=PASS|FETCH=OK|SOURCE=OK|PRODUCT=OK|TOOL=OK|INSTALL=OK|TYPE=OK|BUILD=OK|NPM=YES|LIFE=ALLOW|NET=ALLOW|LOCAL=YES|SERVICE=NO|H0=NO|RAW=NO
```

### BLOCKED

Process exit code는 `1`이다.

Script가 시작된 뒤 다음 category 중 하나로 멈춘다.

```text
BLOCKED_HOST
BLOCKED_SOURCE_IDENTITY
BLOCKED_TOOLCHAIN
BLOCKED_DEPENDENCY_INSTALL
BLOCKED_TYPECHECK
BLOCKED_BUILD
BLOCKED_SOURCE_MUTATION
BLOCKED_CLEANUP
BLOCKED_POLICY
INTERNAL_ERROR
```

```text
A0|RESULT=BLOCKED|FETCH=OK|PHASE=<HOST|SOURCE|TOOL|INSTALL|TYPE|BUILD|FINAL>|STEP=<allowlisted-checkpoint>|CATEGORY=<allowlisted-category>|NPM=<YES|NO>|LIFE=<ALLOW|NONE>|NET=<ALLOW|NONE>|LOCAL=YES|SERVICE=NO|H0=NO|RAW=NO
```

`FETCH=OK`는 canonical remote ref fetch가 script 시작 전 source verification에서
통과했다는 뜻이다. `NET=ALLOW`는 npm network가 허용됐음을 뜻하며
실제 connection 발생 증거가 아니다. `SERVICE=NO`는 A0가 CCR service/Gateway
동작을 요청하지 않았다는 뜻이지 host 전체를 관찰한 것이 아니다.

Capsule의 `SOURCE=OK`는 exact main/candidate/instruction/task/script, candidate
changed-path allowlist와 reviewed T02 blob identity가 확인됐다는 뜻이다.
`PRODUCT=OK`는 candidate의 protected product/source 경로가 `97b73a9...`와 같고
build에는 full `97b73a9...` archive를 사용했다는 뜻이다. Current main/PR full-head
build equivalence나 merge safety를 뜻하지 않는다.

자동 retry, local source patch, dependency 변경 또는 H0 진행은 금지한다.

## Attempt 3 Human-readable Evidence — historical

Capsule만 반환하지 않는다. Internal Validator는 먼저 다음을 평문으로 설명한다.

```text
A0가 무엇을 확인했는가
무엇을 실행했고 어떤 local/network effect가 있었는가
무엇을 실행하지 않았는가
PASS 또는 BLOCKED 이유
사용자가 옮겨 적을 마지막 capsule
```

최소 sanitized Evidence:

```text
Role: INTERNAL_VALIDATOR
Task ID: V1-S1-T00
Session role: Attempt 3 A0 only
Instruction/Candidate SHA: <approved exact SHA>
Candidate role: validation_overlay
Environment alias: <sanitized Human-supplied label>
Workspace ID:
Source verification: PASS / BLOCKED
Canonical Git fetch/network read: PASS / BLOCKED / NOT_STARTED
A0 result: PASS / BLOCKED
Stopped phase/checkpoint:
Process exit code: 0 / nonzero
Validated product target: 97b73a9f4e1fb23d406bb987d0785cefa1f99966
Product build completed: YES / NO
Candidate protected product/source equivalence: PASS / BLOCKED
T02 helper/test reviewed blob identity: PASS / BLOCKED
Node/npm version when known:
Dependency lifecycle: PERMITTED / NOT_STARTED; actual lifecycle child execution is not independently observed
npm network: PERMITTED / NOT_STARTED; actual connection is not independently observed
CCR service/Gateway/H0/A1+: NOT_INVOKED_BY_A0
A0-requested GitHub/remote write: NONE
A0-authored source/history: NONE
A0-targeted existing shared checkout mutation: NONE
Existing shared checkout final status: NOT_APPLICABLE
Disposable local Git/workspace write: YES / NO
A0-requested CCR/service/UI/config action: NONE
Dependency-child effects outside nonce: NOT_OBSERVED / NOT_CLAIMED
Secrets/raw evidence included in sanitized result: NO
Next phase/Task started: NO
Capsule:
```

실제 path, hostname, Windows identity, executable hash, endpoint, token, key, raw log와
raw error text는 외부로 반환하지 않는다.

## H0 and A1+ boundary

```text
H0 design: APPROVED
H0 execution: NOT_AUTHORIZED
Executable procedure in this head: NONE
Runtime controller: NOT_IMPLEMENTED
A1+: HOLD
```

H0는 독립 실행 checkpoint가 아니다. Writer quiescence는 일시적이므로 H0만 실행한
뒤 head를 바꾸거나 A1+를 설계하면 무효가 된다. 실제 Attempt 4에서는 완전한 runtime
controller가 포함된 exact head를 먼저 동결·승인하고 다음 순서를 끊김 없이 사용한다.

```text
new exact-head source verification (pre-Attempt)
→ exact match이면 controller `-Prepare` starts Attempt 4 in a fresh nonce
→ full `97b73a9...` archive + npm ci + typecheck + build
→ Sonnet completely exits
→ H0 Human Enterprise before-smoke and same-account quiescence
→ plain Windows PowerShell 5.1 launches controller `-Run` once
→ controller backup/baseline/runtime/T02/cleanup
→ cleanup safe일 때만 H2 Human Enterprise after-smoke
→ readable summary + one compact external capsule
```

활성 Sonnet/Claude Code validator 자체도 current-user Claude writer다. 따라서 그
세션이 살아 있는 상태로 quiescence를 PASS 처리하거나 baseline 뒤 다시 열어 runtime을
운전할 수 없다. Sonnet은 exact controller의 preparation mode로 fresh product workspace와
한 줄 run command를 준비한 뒤 종료하고, 사용자는 일반 PowerShell에서 그 command를
실행한다.

### H0 minimal Human contract

Human이 수행하거나 확인할 항목은 다음으로 한정한다.

1. 일반 `claude`의 Enterprise authentication smoke `PASS`.
2. Enterprise model visibility `PASS`; CCR/internal model request는 하지 않는다.
3. 일반 Claude Desktop smoke `PASS`.
4. 같은 Windows account 동시 사용 `NO`.
5. 현재 account의 Claude Code CLI/App, Internal Sonnet, Claude Desktop, CCR UI/tray와
   config writer를 모두 종료한다. 다른 Windows account 세션 전체 종료는 요구하지 않는다.
6. reviewed controller가 exact no-save preflight에서 `CHANGE=Y`를 반환할 때만
   `saveConfig` 한 번을 허용한다. 이 조건부 승인은 controller 시작 전에 전달한다.
7. source verification/preparation이 제공한 exact 한 줄을 일반 PowerShell에서 실행한다.

Controller는 client 종료 직후 relevant process/port owner를 다시 확인하고 현재 Attempt의
local-only recovery backup과 authoritative baseline을 만든 뒤 즉시 runtime으로 이어져야
한다. Backup은 repository/shared folder 밖에 두고 Enterprise settings, CCR가 쓰는 실제
Claude-3p 세 파일과 bounded canonical CCR config DB/optional sidecars의 존재 상태를
manifest로 남기고, 당시 존재한 bounded regular non-reparse file의 exact bytes만 포함한다.
Backup directory는 current-user local profile 아래의 fresh exact-nonce, regular non-reparse
directory여야 하며 inherited broad access를 제거하고 current Windows identity와 `SYSTEM`
만 읽기/쓰기할 수 있게 한다. Pre-baseline `ABSENT`도 복구 상태다. 원문, path, hash와
secret은 사외 Evidence에 넣지 않는다. 관련 client가 다시 열리거나 같은 account 동시
사용 또는 owner 불명이 생기면 H0는 무효이며 runtime을 시작하지 않는다.

### Future controller contract

구현은 별도 승인 대상이다. Bounded implementation write scope는 다음 일곱 파일뿐이다.

```text
company/scripts/t00-runtime-controller.ps1
company/tests/t00-runtime-controller-contract.test.mjs
company/tasks/v1-s1/V1-S1-T00-CCR-RUNTIME-SANDBOX.md
company/tasks/v1-s1/V1-S1-T02-WRAPPER-SAFE-CONFIG-SAVE.md
company/project-state.yml
company/docs/STATUS.md
company/gates/V1-S1.md
```

첫 두 파일이 `-Prepare`, one-shot `-Run`과 post-Gate exact-backup cleanup을 구현한다.
나머지 다섯 파일은 같은 final runtime head에서 서로 일치하게 다음 canonical transition만
기록한다.

```text
Task/project status: ready_internal
Runtime controller: IMPLEMENTED / EXTERNAL_REVIEW_PASS
Authorized phase: ATTEMPT_4_PREPARE_AND_H0_RUNTIME_AFTER_EXACT_HEAD_HUMAN_APPROVAL
Attempt 4: NOT_STARTED until that frozen exact head receives Human approval
```

Future implementation handoff는 이 current design head의 frozen exact SHA를
`implementation_base_sha`로 제공한다. Final runtime Task도 그 값을 기록하고 controller는
base가 runtime head의 ancestor인지, `implementation_base_sha..runtime_head` changed-path가
위 일곱 파일 안에만 있는지 검증한다. 이 bounded delta 검증은 main-wide Task
`allowed_paths` containment와 `97b73a9...` protected equality를 대체하지 않고 추가한다.

이 conditional phase는 final runtime head가 외부 검토를 통과하고 Human이 frozen exact SHA,
capability matrix와 npm network/lifecycle/current-user risk를 명시적으로 승인한 뒤에만 실행
가능하다. 승인 정보를 넣기 위해 freeze 뒤 docs commit을 추가하지 않는다. 현재 design
head의 `authorized_phase: NONE`은 바뀌지 않는다.

- `-Prepare`는 새 nonce에서 exact main/candidate/instruction/product identity, candidate
  changed-path가 Task `allowed_paths` 안에만 있다는 것, protected product/source path가
  `97b73a9...`와 byte-identical이라는 것과 externally reviewed/pinned final helper/controller
  blob identity를 확인한다. 그 뒤 Windows/PowerShell/Node/npm을 bind하고 full
  `97b73a9...` archive에 `npm ci --audit=false --fund=false --ignore-scripts=false`, direct
  typecheck와 build를 한 번씩 수행한다. Existing shared checkout, CCR service/UI/config는
  건드리지 않는다.
- Preparation 전 Human handoff가 npm network/lifecycle current-user 실행과 residual
  credential-exposure risk를 다시 승인하고 같은 Windows account 동시 사용 `NO`를
  확인해야 한다. Local/network/lifecycle effect는 A0와 같은 truthful semantics로 보고한다.
- `-Prepare`는 isolated cache/temp를 execution root 밖에 두고, prepared execution root의
  tracked source, `packages/**/dist`, CLI `models.json`과 whole `node_modules` runtime tree를
  relative path/type/size/content identity로 local bounded manifest에 묶는다. Unknown
  reparse point는 금지하며 exact npm workspace junction만 resolved target이 같은 nonce
  내부일 때 허용하고 그 target tree를 별도로 fingerprint한다.
- Bound Node의 `require.resolve`로 `better-sqlite3`와 runtime dependency/native
  `better_sqlite3.node`가 nonce 안에 있음을 확인하고, in-memory DB open/close smoke를
  preparation에서 수행한다. Selected CLI cwd/model-catalog와 exact controller/helper blobs,
  package lock/toolchain도 manifest에 포함한다.
- `-Prepare`는 exact workspace ID와 manifest digest를 bind한 한 줄 `-Run` command만
  사내 화면에 반환한다. 그 command는 absolute Windows PowerShell 5.1 application을
  `-NoProfile`로 시작한다. H2 입력을 위해 long-lived interactive process여야 하므로
  `-NonInteractive`는 쓰지 않는다. 그 same no-profile process가 inline bootstrap으로
  bounded regular non-reparse controller가 literal approved Git blob과 같은지 먼저
  확인한 뒤 verified script를 structured parameter로 실행하고 H2까지 기다린다. 추가
  PowerShell child, `Invoke-Expression`, command-string reconstruction 또는 ExecutionPolicy
  변경은 금지한다. `-Run`은 전달된 digest와 manifest/runtime tree 재계산 결과를 모두
  비교한다. Raw
  npm/native output, manifest path/hash와 file list는 외부 Evidence로 내보내지 않는다.
  Preparation과 H0/runtime 사이에 workspace integrity 또는 same-account exclusivity를
  확인할 수 없으면 `-Run`하지 않고 BLOCKED로 종료한다. 새 nonce preparation은 Human
  review와 새 Attempt 승인 뒤에만 가능하다.
- `-Run`은 manifest, exact workspace ID, full prepared runtime tree, module/native resolution,
  CLI cwd/model-catalog identity를 다시 계산해 exact match한 뒤에만 진행한다. Attempt 3
  workspace는 이 preparation/runtime에 사용하지 않는다.
- pre-existing CCR service, stale Claude App backup, legacy import/migration source,
  startup/debug override와 ambiguous relevant writer/port owner가 있으면 시작 전 차단한다.
- targeted Enterprise settings, actual Claude-3p, Process/User/Machine managed env와 normal
  `claude` resolution baseline을 client 종료 뒤 capture한다.
- Service child용 sandbox `LOCALAPPDATA`는 repository/shared path 밖의 approved current-user
  local root 아래 fresh exact-nonce child로만 만든다. Child의 initial state는 `ABSENT`여야
  하며 canonical root/ancestors와 생성된 directory/entries의 reparse 부재, current Windows
  identity와 `SYSTEM`만 허용하는 ACL, exact path/identity를 manifest에 bind한다. 하나라도
  불명확하거나 stale child가 있으면 service를 시작하지 않는다.
- real `APPDATA`/`USERPROFILE`은 유지하고 service child에만 sandbox `LOCALAPPDATA`를
  주어 prepared exact `97b73a9...` built CLI를 explicit loopback `--no-open --no-gateway`로 한 번
  시작한다. 기존 service 재사용은 fresh ownership PASS가 아니다.
- parent `LOCALAPPDATA`를 즉시 복구하고 exact new service state/PID/start time,
  `getAppInfo`/`getServiceIdentity`와 Gateway `stopped`를 결합해 ownership을 증명한다.
- Stock start/stop과 모든 native child stdout/stderr는 size/time bounded memory로 capture해
  allowlisted fresh/reuse/result state만 parse하고 raw console로 전달하지 않는다. Tokenized
  management URL, PID, path, token과 raw error는 terminal 또는 sanitized Evidence에 출력하지
  않는다.
- T02 helper default no-`saveConfig` preflight를 한 번 실행한다. 이는 storage
  initialization/migration 가능성이 있어 read-only라고 부르지 않는다.
- 첫 runtime Node/service 직전, default preflight helper spawn 직전과 `--apply` helper spawn
  직전에 startup/debug override 부재를 각각 다시 확인한다. 두 helper spawn 각각의 직전에는
  Node built-ins만 사용하는 exact helper blob, bound Node executable과 fresh service
  ownership/state binding만 다시 확인한다. 하나라도 다르거나 불명확하면 해당 helper를
  시작하지 않고 BLOCKED/FAIL로 분류하되 `finally` cleanup은 계속한다. Full prepared tree는
  `-Run` admission과 stock CLI stop 직전에 검증하며 매 helper spawn마다 다시 hash하지 않는다.
- exact preflight PASS와 `CHANGE=Y`일 때만 `--apply`를 한 번 실행한다. `CHANGE=N`,
  `APPLY=SKIP`은 coverage 미완료이며, `SAVE=UNKNOWN`을 포함한 모든 mutation ambiguity는
  재시도 없이 FAIL이다.
- Fresh service가 시작된 뒤에는 helper가 실행되지 못한 경우, preflight BLOCKED,
  `SAVE=UNKNOWN`, malformed output, confirmed apply와 post-save failure를 포함한 모든 helper
  outcome에서 cleanup 전에 targeted Enterprise settings, actual Claude-3p,
  Process/User/Machine managed env와 normal `claude` resolution을 baseline과 비교한다.
  Snapshot unavailable 또는 change는 `FAIL / ISOLATION_BREACH` Evidence이며, 결과와 무관하게
  `finally` cleanup은 계속한다. PASS는 confirmed apply 뒤 `DURING=SAME`일 때만 가능하다.
- service start 이후 모든 경로에서 `finally` cleanup을 수행한다. Ownership이 계속
  일치하는지 stop 직전에 다시 확인한다. 같은 시점에 exact manifest/full runtime tree,
  bound Node와 CLI/model/native resolution을 다시 확인한다. 하나라도 다르거나 불명확하면
  변경된 stock code를 실행해 stop하지 않고
  manual recovery로 넘겨 PASS를 금지한다. 모두 같을 때만 start와 동일한 manifest-bound
  sandbox `LOCALAPPDATA`를 stop child에도 주고 real `APPDATA`/`USERPROFILE`을 유지한 채
  같은 stock CLI로 stop한다. 그 뒤 captured PID death, service state/backup 부재,
  Gateway stop과 source/targeted real invariant의 `AFTER=SAME`을 별도로 증명한다. 모든
  service-start 경로에서 sandbox cleanup 여부를 결정하되, captured PID `DEAD`와 service/
  ownership 부재가 모두 증명된 경우에만 manifest의 same exact nonce/root/ACL/non-reparse/
  entry set과 다시 대조한다. 그때만 junction을 따라가지 않고 그 child 하나를 삭제해
  absence를 증명한다. Stop skip/failure, surviving PID, ownership uncertainty 또는 sandbox
  검증·삭제·absence failure에서는 sandbox를 건드리지 않고 manual recovery용으로 보존하며
  PASS를 금지한다.
  Foreign/unknown ownership은 임의 stop/kill하지 않고 manual recovery로 넘기며 PASS를
  금지한다.
- cleanup과 environment restoration이 safe한 뒤 controller가 `H2_READY`만 출력하고 같은
  plain-PowerShell process에서 기다린다. Human이 일반 `claude` auth/model visibility와
  Claude Desktop smoke를 수행한 뒤 exact PASS/FAIL 세 값과 recovery 여부만 입력하면
  controller가 final capsule을 만든다. Sonnet을 다시 열지 않는다. Manual recovery,
  surviving PID, cleanup uncertainty, invariant change 또는 H2 failure는 PASS가 아니다.
- H2의 `RECOVERY`는 runtime 중 manual recovery가 필요했거나 수행됐는지만 기록하며 backup
  삭제 권한이 아니다. Post-Gate cleanup 승인은 Evidence 검토 뒤 내리는 별도 destructive
  action 결정이므로 두 값을 합치지 않는다.
- 한번 만들어진 Recovery backup은 결과와 무관하게 runtime/H2 및 Human Gate review가
  끝날 때까지 `RETAINED`로 보존하며, 이 상태에서도 runtime PASS Evidence를 낼 수 있다. `-Run`은 자동
  삭제하지 않고 exact manifest에 bind된 별도 post-Gate cleanup command만 사내에 남긴다.
  Human Gate가 `RECOVERY=N`과 더 이상 backup이 필요 없음을 명시적으로 승인한 뒤에만
  absolute PS5.1 `-NoProfile` bootstrap을 거친 controller cleanup mode를 실행한다. 삭제
  직전 approved recovery root의 동일한 exact-nonce child인지 다시 resolve하고, directory와
  모든 entry가 regular non-reparse이며 original manifest/ACL owner와 같고 bounded manifest
  path만 포함하는지 확인한다. 그 exact directory 하나만 junction을 따라가지 않고 삭제한
  뒤 absence를 증명한다. 확인·삭제·absence 중 하나라도 실패하거나 mutation/cleanup이
  불명확하면 보존하며 T00 `ACCEPTED`/merge를 금지한다. 외부 Evidence에는 path/hash 없이
  compact `B=N|R|D`만 포함하고, `N`은 backup 생성 전 결과에만 허용한다. Manual recovery는
  PASS 금지와 allowlisted failure category로 나타낸다.

Attempt 3 A0 workspace `4b5fc32468f4a9c103af7686987e9b26`은 Evidence review용으로
보존하고 새 ref를 fetch하거나 runtime root로 자동 재사용하지 않는다. Post-A0 dependency/
build seal이 없으므로 기본 Attempt 4는 위 fresh preparation nonce를 사용한다. 별도 bounded
integrity verifier와 Human 승인이 있을 때만 exact-nonce reuse를 `CONDITIONAL`로 검토한다.

현재 config가 Stock default를 유지했다면 `requestLogBodyCapture="all"`일 수 있으나 T02
helper는 이미 `"none"`인 fixed point만 허용한다. 실제 internal state는 확인하지 않았으므로
미리 수정하지 않고 future no-save preflight의 sanitized `BLOCKED_RUNTIME_SURFACE` 여부로
판단한다.

### Attempt 4 start and compact Evidence

새 exact runtime head의 ref/SHA/Task/controller source verification 실패는
`PRE_EXECUTION_HANDOFF_BLOCKED`이며 Attempt 4를 소비하지 않는다. Exact source 확인 뒤
exact reviewed controller의 `-Prepare` process가 성공적으로 시작되면 Attempt 4가 시작된다.
그 invocation 이후의 source recheck, toolchain, install, typecheck 또는 build failure는
각각 allowlisted `BLOCKED_SOURCE_IDENTITY`, `BLOCKED_TOOLCHAIN`,
`BLOCKED_DEPENDENCY_INSTALL`, `BLOCKED_TYPECHECK` 또는 `BLOCKED_BUILD`와 실제 effect를
보존하는 formal Attempt 4 result다. Preparation PASS 뒤 H0를 따로 보고하고 pause하지
않고 같은 approved Attempt를 계속한다.

`SRC=P`는 exact ref/SHA/Task identity뿐 아니라 Human-pinned `implementation_base_sha`의
ancestor 관계, 그 base부터 runtime head까지의 seven-file implementation-lane containment,
main-wide candidate changed-path allowlist, `97b73a9...` 대비 protected product/source
equality와 externally reviewed/pinned final controller/helper blob identity가 모두 PASS했다는
뜻이다. 하나라도 빠지면 `SRC=P`가 아니다.

PASS final capsule은 상세 내부 결과를 중복하지 않고 다음 한 줄로 제한한다. `H`는 approved
full PR head의 첫 12 hex이며, Orchestrator가 이미 승인한 full SHA와 live frozen PR head가
같은지 확인한 뒤 그 prefix와 대조한다. 이는 full SHA authority를 대체하는 값이 아니라
사람의 짧은 confirmation token이다.
`PREP=P`는 tool/install/type/build/runtime seal, `SAVE=1`은 preflight PASS + `CHANGE=Y` +
exactly one apply + global count zero, `INV=S/S`는 during/after SAME, `CLEAN=P`는 stock stop,
PID death와 sandbox absence를 모두 뜻한다. Full SHA/workspace/manifest와 세부 결과는 사내
readable report에만 남긴다.

```text
T00R|PASS|A4|H=<12hex>|SRC=P|PREP=P|H0=P|SAVE=1|INV=S/S|CLEAN=P|H2=P|B=R|RAW=N
```

BLOCKED/FAIL은 `T00R|BLOCKED|A4|H=<12hex>|P=<phase>|C=<allowlisted>|B=<N|R>|CLEAN=<P|N>|RAW=N`
형태로 제한한다. Post-Gate cleanup은 `T00C|PASS|H=<12hex>|B=D|RAW=N`만 옮긴다. Readable
internal explanation은 유지하되 외부에는 actual path/PID/token/hash/config/raw log를
옮기지 않는다.

### Proportionality review

```text
MUST NOW: exact-head + seven-file delta bootstrap, one Company PS5.1 controller,
          fresh build/runtime seal, sandbox ACL/reparse lifecycle, existing T02 helper,
          targeted backup, fresh ownership, one save/no retry, DURING/AFTER + H2,
          post-Gate exact backup cleanup, compact keyboard capsule
CONDITIONAL: retained workspace reuse verifier, separate account/VM, targeted forced kill
DEFER: all-user logout, Job Object, host-wide tracing, full Claude-3p tree hash,
       auto-recovery, CCR packages patch, company-claude/T01/model request,
       Tailwind merge-safety repair
```

Runtime PASS 뒤 validated head를 Evidence 문서만을 위해 다시 움직이지 않는다. Sanitized
Evidence는 PR comment/Issue에 먼저 연결하고, exact head Gate 처리 뒤 canonical status
갱신은 별도 governance commit으로 수행한다.

## Attempt history

### Attempt 1 — preserved sanitized evidence

```text
Date: 2026-09-01
Instruction SHA: 6d0d6f2aeca02e33261c062eac5aab360805222b
Candidate SHA: 97b73a9f4e1fb23d406bb987d0785cefa1f99966
Result: BLOCKED_POLICY — CONFIG_SAVE_PATH_UNAVAILABLE
Cause: ONBOARDING_GATE_REQUIRES_FORBIDDEN_CONNECT_AGENT
Management start isolation: TESTED_PASS
Config-save isolation: NOT_TESTED
Enterprise/Claude-3p/env invariant: SAME
Service cleanup and H2: PASS
Manual recovery: NO
```

`GLOBAL_PROFILE_PERSISTENCE`는 확인된 원인이 아니므로 failure category로 사용하지
않는다. 실제 blocker는 금지된 onboarding path 없이 cleanup/save에 도달할 수
없었던 policy/path precondition이다.

### Attempt 2 — preserved sanitized evidence

```text
Date: 2026-09-01
Candidate / instruction SHA: c2459b90182041afdb7b9c0cf44149494b30f910
Result: BLOCKED — BLOCKED_TOOLCHAIN_IDENTITY
Exact failed phase/tool/reason: UNKNOWN
Post-block diagnostic: NOT_RUN
Console: CLOSED / NOT_REUSABLE
CCR service/Gateway/H0/A1+: NOT_STARTED
```

Human-transcribed observation은 archive, dependency install, typecheck와 build가 실행된
사실을 보존하지만 old capsule만으로 exact failed checkpoint를 증명하지 않는다.
Attempt 2의 local fetch/checkout/workspace/dependency effects는 있었고 GitHub write,
source authoring, service start는 없었다.

### Pre-execution handoff incident — not an Attempt

Internal Sonnet은 이전 handoff의 stage/commit authority를 repository에서 확인할 수
없다고 판단해 명령을 하나도 실행하지 않았다.

```text
Commands/UI/A0: NONE / NOT_STARTED
Formal INTERNAL_VALIDATOR result/category: NOT_EVIDENCED
GitHub/local execution write: NONE
Attempt accounting at this incident: Attempt 3 had not started
```

### Attempt 3

```text
Date: 2026-09-02
Evidence provenance: HUMAN_TRANSCRIBED_SANITIZED_INTERNAL_VALIDATOR_OUTPUT
External independent rerun: NO
Approved and repository-correlated candidate / instruction SHA: e16b4a90c7f5f7171905ad7c2993e8dcf6781353
Human SHA confirmation token: E16_OK
Repository correlation at review: PR #23 head e16b4a90c7f5f7171905ad7c2993e8dcf6781353 — independently verified
Candidate role: validation_overlay
Tested product / build plane: 97b73a9f4e1fb23d406bb987d0785cefa1f99966
Authorized phase: source verification + A0 only
Result: A0_PASS_ONLY / INCOMPLETE / H0_NOT_STARTED
Workspace ID (Human-transcribed): 4b5fc32468f4a9c103af7686987e9b26
Workspace cleanup decision: RETAIN_FOR_REVIEW
Exact-nonce cleanup: NOT_STARTED
Node/npm (Human-transcribed): v24.15.0 / 11.12.1
Process exit code (Human-transcribed): 0
Normalized capsule reconstructed from Human-transcribed fields: A0|RESULT=PASS|FETCH=OK|SOURCE=OK|PRODUCT=OK|TOOL=OK|INSTALL=OK|TYPE=OK|BUILD=OK|NPM=YES|LIFE=ALLOW|NET=ALLOW|LOCAL=YES|SERVICE=NO|H0=NO|RAW=NO
CCR service/Gateway/H0/A1+: NOT_STARTED_BY_A0
T01: BLOCKED
```

Capsule 의미는 A0 contract 범위를 넘지 않는다. `SOURCE=OK`는 exact overlay/scope와
reviewed T02 blob identity, `PRODUCT=OK`는 protected-path equivalence와 full
`97b73a9...` archive build를 뜻한다. Candidate/full-head build equivalence, merge safety,
T02 runtime 또는 Enterprise invariant PASS가 아니다. `LIFE=ALLOW`/`NET=ALLOW`는 허용,
`SERVICE=NO`는 A0 미호출, `RAW=NO`는 sanitized handoff에 raw/secret이 없다는 뜻이며
각각 host-wide observation으로 확대하지 않는다.

### Attempt 4

```text
Candidate / instruction SHA: pending exact runtime-controller PR head
Candidate role: validation_overlay
Tested product SHA: 97b73a9f4e1fb23d406bb987d0785cefa1f99966
Prior A0 checkpoint: Attempt 3 at e16b4a90c7f5f7171905ad7c2993e8dcf6781353
A0 reuse: NOT_AUTOMATIC / PENDING_EXPLICIT_HUMAN_DECISION
Current result: NOT_STARTED
H0/A1+: NOT_STARTED
Runtime authorization: PENDING IMPLEMENTATION + NEW EXACT-HEAD HUMAN APPROVAL
```

## Human decision

`RETRY — RECORD ATTEMPT 3 A0; APPROVE H0 DESIGN ONLY; IMPLEMENTATION/H0 EXECUTION/A1+ HOLD`
