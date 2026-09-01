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
- Status: `BLOCKED`
- Attempt 1: `BLOCKED — GLOBAL_PROFILE_PERSISTENCE`
- Blocker: `H1_ONBOARDING_GATE_REQUIRES_FORBIDDEN_CONNECT_AGENT`
- Coverage: management start isolation `TESTED_PASS`; config-save isolation `NOT_TESTED`
- Goal: Stock CCR management/runtime를 process-local `LOCALAPPDATA` sandbox에서 실행해도 Enterprise Claude settings, actual Claude-3p, User/Machine env와 일반 `claude`가 변경되지 않는지 증명
- Candidate product commit: `97b73a9f4e1fb23d406bb987d0785cefa1f99966`
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
| Runtime LOCALAPPDATA sandbox | START_ISOLATION_PASS_CONFIG_SAVE_BLOCKED | V1-S1-T00 Attempt 1 |
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
CCR-scoped profile/settings
local recovery backup outside repository
```

## Current open risks

- Management start isolation passed one Windows Attempt, but config-save isolation is still untested.
- Unfinished onboarding has no supported path to existing Profile/Settings management without the forbidden `Connect agent` action.
- Existing CCR runtime config may contain stale global/System-default profile state; Attempt 1 did not verify its saved count.
- `saveConfig` can sync Claude App state and apply profiles; T00 Attempt 2 must exercise this stock path inside the existing safety envelope.
- Enabled Provider `autoFetchModels` can schedule immediate outbound model refresh after save; retry must verify it is OFF before the first edit/save.
- Runtime sandbox may affect app discovery or child environment inheritance; CLI-only scope limits this but must be tested.
- A Core sync-disable patch is not justified by Attempt 1 because sandbox start and Claude-3p materialization passed.
- Provider persistence, local gateway completion, Streaming, Tools and error classification remain unverified.
- Request logs/body capture must be OFF before real prompt.
- GLM rollout is pending.
- Multi-user PC-level runtime ownership and telemetry source remain V1-S3 questions.
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

Human Gate Owner가 planned repair Task `V1-S1-T02`의 범위와 activation을 별도로 승인한다.

승인 전:

```text
제품 코드 수정 금지
T02 실행 금지
T00 Attempt 2 시작 금지
V1-S1-T01 재개 금지
```

승인 후 순서:

```text
1. External Codex가 onboarding의 non-persisting management entry만 구현
2. 허용된 UI/test 경로와 exact PR head 확인
3. Internal Validator는 exact PR head에서 T00 Attempt 2만 수행
4. H1 첫 save 전에 enabled Provider autoFetchModels = 0 확인
5. stock save/apply path로 global profiles 0, Request logs OFF, Agent observability OFF 저장
6. A3/H2 invariant와 Enterprise smoke 확인
7. T00 Human decision 후에만 repair PR merge와 T01 재개 판단
```

현재 docs PR은 Evidence와 설계만 기록하며 제품 코드를 변경하지 않는다.
