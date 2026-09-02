# Project Status

`company/project-state.yml`이 현재 Stage/Task의 기계 판독 기준이다.
이 문서는 사람이 이해해야 할 확인 사실, blocker, 미검증 범위와 정확한 다음 행동을 기록한다.

## Baseline

- CCR ref: `v3.0.22`
- CCR commit: `829298cf8bdcc6ddb9120a5a7c790c30227a1937`
- Upstream history integrated: `YES`
- Integration main commit: `b05567891e15a157d8e54fac627618f8214128a7`
- Wrapper version: `pre-v1`
- External development: Android/Termux External Codex
- Internal mode: Windows pull-only validation
- GitHub orchestration: ChatGPT Orchestrator + Human Gate Owner
- GitHub Actions: `DISABLED` pending upstream workflow review

## Current

- Stage: `V1-S1`
- Active Task: `V1-S1-T00`
- Active Task path: `company/tasks/v1-s1/V1-S1-T00-CCR-RUNTIME-SANDBOX.md`
- Status: `READY_FOR_INTERNAL_VALIDATION — A0_ONLY`
- T02: `EXTERNAL_PASS` — wrapper-only helper syntax PASS, synthetic/mock tests 159/159
- Repair scope: T00 frontmatter의 exact `allowed_paths` only; protected CCR source/build/package paths unchanged and prohibited; candidate whole-tree build equivalence `NOT_CLAIMED`; A0 build plane은 full `97b73a9...`
- T00 Attempt 1: `BLOCKED_POLICY — CONFIG_SAVE_PATH_UNAVAILABLE`; management start isolation PASS, config-save `NOT_TESTED`
- T00 Attempt 2: `BLOCKED — BLOCKED_TOOLCHAIN_IDENTITY` at A0 on `c2459b90182041afdb7b9c0cf44149494b30f910`; exact checkpoint not captured; console closed
- Pre-execution handoff incident: Internal Sonnet rejected inconsistent authority before commands; formal Task result 없음; Attempt 3 remains `NOT_STARTED`
- T00 Attempt 3: `NOT_STARTED`; new exact frozen-head source verification + A0 only pending Human handoff
- External repair verification: A0 source-contract tests `11 PASS / 1 SKIP`; Windows PowerShell 5.1 parser/runtime `NOT_RUN_EXTERNAL`; unchanged T02 tests `159/159 PASS`
- Coverage: management start isolation `TESTED_PASS`; config-save isolation `NOT_TESTED`
- Goal: shared checkout을 변경하지 않는 exact overlay verification 뒤 full validated product `97b73a9...` archive에서 reviewed one-shot PS5.1 A0 install/typecheck/build만 수행하고 HOLD
- Validated product commit: `97b73a9f4e1fb23d406bb987d0785cefa1f99966`
- Last passed Gate: `V1-S0`

## Accepted execution model

사용자 실행 경로를 두 개로 분리한다.

```text
claude
→ 기존 Enterprise Claude Code
→ Enterprise settings/auth/models

company-claude
→ CCR 전용 Claude Code
→ CCR-scoped settings + Local CCR + internal model
```

CCR service ON/OFF가 일반 `claude`의 설정을 전환하지 않는다.
이미 실행 중인 Company 세션도 CCR가 중지되면 Enterprise로 자동 fallback하지 않는다.

V1의 Claude Code profile 계약:

```text
Effect scope: Only opened from CCR
Internal scope: ccr
Entry mode: CLI only
System default: prohibited
```

추가로 CCR management/service process의 `LOCALAPPDATA`를 Company sandbox로 분리한다.
이유는 Stock CCR start/config-save 경로가 Windows의 `%LOCALAPPDATA%\Claude-3p`를 동기화할 수 있기 때문이다.

상세 설계는 `company/docs/CLAUDE_CODE_ISOLATION.md`를 따른다.

## Recovery observation

사내에서 다음이 확인됐다.

```text
Router stop 후 Claude Code:
CCR Base URL이 남아 127.0.0.1:3456 token endpoint 오류

Base URL 제거 후:
CCR WIF/Federation 값이 남아 federation_rule_id prefix 오류

CCR Base URL + WIF/Federation 값을 제거:
Enterprise Claude Code 인증 정상 복귀

%LOCALAPPDATA%\Claude-3p의 CCR third-party inference config 제거:
일반 Claude Desktop 정상 복귀
```

확인된 CCR-managed 값 범위:

```text
ANTHROPIC_BASE_URL
ANTHROPIC_API_BASE_URL
CLAUDE_AGENT_API_BASE_URL

ANTHROPIC_FEDERATION_RULE_ID
ANTHROPIC_IDENTITY_TOKEN_FILE
ANTHROPIC_ORGANIZATION_ID
```

CCR source에는 추가 WIF/model/helper/MCP 관리 키도 있으므로 future Doctor는 전체 allowlist를 검사해야 한다.

판정:

```text
Router stop
≠
client configuration rollback

Observed categories:
CLIENT_AUTH_CONFIG_PERSISTENCE
CLAUDE_APP_CONFIG_PERSISTENCE
ROLLBACK_GAP
```

Enterprise Claude Code와 Claude Desktop은 현재 수동 복구 후 정상이다.
기존 오염 가능 CCR runtime을 그대로 재시작하지 않는다.

## Gemma Provider evidence — preserved

신규 host-authorized credential로 다음이 확인됐다.

```text
Direct OpenAI Chat Completions: PASS
CCR OpenAI Chat Completions Check Connection: PASS
CCR OpenAI Responses Check Connection: FAIL — HTTP 500
```

현재 판정:

```text
Credential host scope: AUTHORIZED
Gemma Chat Completions: SUPPORTED
OpenAI Responses: UNSUPPORTED_OR_INCOMPATIBLE
Responses V1 gating: NON_BLOCKING
```

현재 Gemma V1 운영 protocol:

```text
Protocol detection mode: manual
Auto detect protocols: OFF
Selected protocol: openai_chat_completions only
```

이 protocol evidence는 유효하다.
다만 `V1-S1-T01` Provider 저장·영속화는 runtime isolation prerequisite가 통과할 때까지 `BLOCKED`다.

## Why V1-S1-T00 comes first

`Only opened from CCR`는 Claude Code profile settings를 격리한다.
하지만 Stock CCR management start와 config save는 별도로 Claude App Gateway sync를 호출할 수 있고, Windows 기본 target은 실제 `%LOCALAPPDATA%\Claude-3p`다.

따라서 V1-S1-T00은 다음을 검증한다.

```text
CCR service process:
sandbox LOCALAPPDATA

CCR config/profile state:
enabled global Claude Code profile = 0

Actual Enterprise settings:
UNCHANGED

Actual Claude-3p:
UNCHANGED

User/Machine CCR env:
UNCHANGED

Normal claude:
Enterprise before/during/after PASS
```

수동 rollback이 필요하면 PASS가 아니라 `ISOLATION_BREACH`다.

## Confirmed facts

| Item | Status | Evidence |
|---|---|---|
| Company repository foundation | PASS | foundation history |
| CCR upstream history | PASS | PR #5; pinned ancestry preserved |
| Stock CCR internal Windows build | PASS | V1-S0-T01 |
| Stock CCR Windows runtime smoke | PASS | V1-S0-T02 |
| V1-S0 Gate | ACCEPTED | install/build/start/stop without product source changes |
| Credential/host scope model | CONFIRMED | host-authorized key required |
| Current Gemma credential scope | PASS | direct Chat + CCR Chat |
| Gemma Chat protocol | PASS_CANDIDATE | connection works; isolated persistence pending |
| OpenAI Responses | DEFERRED_NON_BLOCKING | HTTP 500 |
| Enterprise Claude recovery | PASS | manual local recovery |
| Router stop as rollback | REJECTED | observed persistent client config |
| Dual command model | ACCEPTED_AS_V1_DEFAULT | `claude` vs `company-claude` |
| Only-opened-from-CCR + CLI-only | ACCEPTED_AS_V1_DEFAULT | System default prohibited |
| Runtime LOCALAPPDATA sandbox | START_ISOLATION_PASS_CONFIG_SAVE_READY_INTERNAL | V1-S1-T00 Attempt 1 + T02 External PASS |
| GLM onboarding | DEFERRED | serving rollout |
| Gateway completion/stream/tool | UNVERIFIED | later V1-S1 Tasks |
| Claude Code isolated E2E | UNVERIFIED | V1-S2 |
| Managed Local Fleet | DESIGN_DEFAULT | Local data plane + central metadata analytics |

## Invariant and allowed paths

### Must remain unchanged

```text
%USERPROFILE%\.claude\settings.json
actual %LOCALAPPDATA%\Claude-3p
normal claude command resolution
Windows User/Machine CCR-managed env
Enterprise auth/models
normal Claude Desktop
```

### Allowed

```text
%APPDATA%\claude-code-router\**
%APPDATA%\CompanyCCR\runtime-localappdata\**
%LOCALAPPDATA%\CompanyCCR\validation-workspaces\**
CCR-scoped profile/settings
local recovery backup outside repository
```

## Current open risks

- Management start isolation passed one Windows Attempt, but the wrapper-assisted config-save isolation has not run internally.
- Attempt 2의 exact toolchain checkpoint는 old capsule로 확인할 수 없으며 stale console을 재사용하지 않는다.
- 이전 Attempt 3 handoff는 명령 실행 전에 거부됐다. 현재 PR head가 아니라 새 repaired head/ref/SHA handoff가 필요하다.
- A0의 `npm ci` 자식은 pinned dependency lifecycle code 실행과 npm network access가 허용된 상태로 현재 Windows user 권한에서 실행된다. 실제 lifecycle child/connection 발생은 별도로 관찰했다고 주장하지 않는다. 별도 account/VM은 정책, account 동시 사용 또는 credential exposure 위험이 있을 때만 요구한다.
- Tailwind v4 build는 repository-root text를 자동 탐색하므로 candidate의 governance/docs 변경도 full-head CSS build input이 될 수 있다. A0는 이 숨은 입력을 `97b73a9...` full archive build plane으로 분리하며 current main/PR full-head build equivalence 또는 merge safety를 주장하지 않는다. Eventual merge/release 전 exact-head를 새 product로 검증할지 Tailwind input boundary를 별도 product Task에서 고정할지 결정해야 한다.
- A0 script의 source contract는 외부에서 검토됐지만 Windows PowerShell 5.1 parser와 실제 Windows 실행은 아직 사내 exact-head source verification/A0에서 확인해야 한다.
- A0-only head에는 executable H0/A1+ procedure가 없다. A0 Evidence 뒤 최소 runtime procedure를 별도로 설계하고 새 exact head/Attempt로 검증해야 한다.
- Unfinished onboarding has no supported stock UI path to the required cleanup without the forbidden `Connect agent` action.
- Human Gate rejected CCR `packages/**` changes; the repair must be Company-owned under `company/**`.
- Existing CCR runtime config may contain stale global/System-default profile state; Attempt 1 did not verify its saved count.
- The wrapper-only helper passed 159/159 external synthetic/mock tests but has not touched internal runtime data.
- Future runtime must still prove fresh service ownership, stopped Gateway, relevant current-user writer quiescence, Enterprise invariance and unconditional cleanup.
- 다른 Windows 사용자 세션 전체 종료는 필요 없지만 같은 Windows account 동시 사용 또는 relevant process/port owner 불명확은 runtime blocker다.
- The single nonce validation workspace remains local for Gate review; its sanitized 32-hex ID must be returned so Human cleanup later targets that exact nonce only.
- The Management RPC is pinned-version source surface rather than a permanent public API and must be revalidated on upstream update.
- Provider persistence, local gateway completion, Streaming, Tools and error classification remain unverified.
- GLM rollout is pending.
- GitHub Actions remain disabled.

## Last passed Gate

- Gate: `V1-S0`
- Decision: `ACCEPTED`
- Validated product commit: `97b73a9f4e1fb23d406bb987d0785cefa1f99966`
- Date: `2026-08-27`

## Last completed Task

- Task: `V1-S0-T02`
- Decision: `ACCEPTED`
- Tested product commit: `97b73a9f4e1fb23d406bb987d0785cefa1f99966`

## Paused Task

- Task: `V1-S1-T01`
- Status: `BLOCKED_ON_V1-S1-T00`
- Preserved evidence: Direct Chat PASS, CCR Chat PASS, Responses HTTP 500 non-blocking
- Resume condition: V1-S1-T00 Human decision `ACCEPTED`

## Exact next action

```text
1. External source-contract review를 통과한 simplified A0-only repair를 새 exact PR head로 동결한다.
2. Human Gate가 canonical URL, refs/pull/23/head, main/candidate/instruction/product SHA, `A0_ONLY`, `agent_only`, capability, same-account/VM precondition과 npm network/lifecycle risk 수용을 한 번 승인한다.
3. Internal Validator가 하나의 self-contained prompt에서 disposable source verification 후 reviewed A0 script만 실행한다.
4. readable explanation + compact A0 capsule을 반환하고 종료한다.
5. CHATGPT_ORCHESTRATOR와 Human Gate가 Evidence를 검토한다.
```

A0 검토 전 H0 또는 A1+ procedure를 만들거나 실행하지 않는다. A0 PASS도 T00 PASS,
T02 internal PASS 또는 repair PR merge 승인이 아니다. T00 Human decision `ACCEPTED`
전에는 T01을 시작하지 않는다.
