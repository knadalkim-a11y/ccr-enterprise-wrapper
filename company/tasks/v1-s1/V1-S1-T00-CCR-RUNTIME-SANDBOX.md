---
id: V1-S1-T00
stage: V1-S1
title: Prove CCR runtime sandbox and Enterprise baseline invariance
kind: spike
status: blocked
blocker: H1_ONBOARDING_GATE_REQUIRES_FORBIDDEN_CONNECT_AGENT
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
unblocks:
  - V1-S1-T01
required_capabilities:
  - WINDOWS_RUNTIME_ALLOWED
  - CLAUDE_CODE_EXECUTION_ALLOWED
allowed_git_actions:
  - fetch
  - detached_checkout
  - show_task_at_instruction_sha
  - rev_parse
  - status
  - diff_exit_code
forbidden_paths:
  - packages/**
  - package.json
  - package-lock.json
human_decision: retry
---

# Prove CCR Runtime Sandbox and Enterprise Baseline Invariance

## Validation question

> Stock CCR management/runtime를 process-local `LOCALAPPDATA` sandbox에서 실행하고 활성 Claude Code global/System-default profile을 제거해도, 기존 Enterprise Claude Code 설정·인증·모델과 실제 Claude Desktop의 CCR-managed 설정 surface가 변경되지 않는가?

이 Task는 **CCR management/config-save Runtime 격리** 하나만 검증한다.
Provider 연결 재검사, model request, `Connect agent`, Streaming, Tool, CCR Claude Code 실행은 하지 않는다.

`company-claude` 자식 프로세스가 원래 `LOCALAPPDATA`를 유지하는지는 V1-S2의 별도 launcher Task에서 검증한다.

## Why this Task exists

사내 복구에서 다음이 확인됐다.

```text
Router stop 후 Enterprise Claude Code settings에 CCR Base URL 잔존
→ 127.0.0.1:3456 token endpoint 오류

Base URL 제거 후 CCR WIF/Federation 값 잔존
→ federation_rule_id prefix 오류

CCR Base URL + WIF/Federation 값 제거
→ Enterprise 인증 정상 복귀

실제 %LOCALAPPDATA%\Claude-3p의 CCR third-party inference config 제거
→ 일반 Claude Desktop 정상 복귀
```

Source review도 다음을 확인했다.

- `Only opened from CCR`는 Claude Code에 별도 settings와 `CLAUDE_CONFIG_DIR`을 사용한다.
- management start/config save는 Claude App Gateway sync를 호출할 수 있다.
- Windows Claude App sync 기본 경로는 `%LOCALAPPDATA%\Claude-3p`다.
- 확인된 write surface는 root config, config-library metadata와 CCR config entry다.

따라서 Provider Task를 재개하기 전에 management/runtime side effect를 Enterprise 영역에서 격리할 수 있는지 증명해야 한다.

## Task classification

```text
Primary actor: INTERNAL_VALIDATOR
Execution mode: human_assisted
Implementation required: NO
Real model request: NO
GitHub write by Internal Validator: NO
```

## Required knowledge

- `company/docs/CLAUDE_CODE_ISOLATION.md`
- `company/docs/INTERNAL_VALIDATION.md`
- `company/docs/SECURITY.md`
- `company/docs/TRAPS.md`
- `packages/core/src/agents/claude-app/gateway-service.ts`
- `packages/core/src/web/management-server.ts`
- `packages/core/src/profiles/service.ts`

## Candidate contract

```text
Instruction SHA:
→ Human Gate Owner가 제공

Candidate SHA:
→ 97b73a9f4e1fb23d406bb987d0785cefa1f99966

Mode:
→ validation-only two-ref exception
```

## Invariant and allowed surfaces

### Must remain unchanged

```text
%USERPROFILE%\.claude\settings.json
실제 %LOCALAPPDATA%\Claude-3p의 CCR-managed config files
일반 claude command resolution
Windows Process/User/Machine CCR-managed environment boundary
Enterprise Claude Code authentication/model visibility
일반 Claude Desktop 동작
```

### Known Claude-3p write surface

CCR `v3.0.22` 소스상 자동 fingerprint 대상은 다음 세 파일이다.

```text
%LOCALAPPDATA%\Claude-3p\claude_desktop_config.json
%LOCALAPPDATA%\Claude-3p\configLibrary\_meta.json
%LOCALAPPDATA%\Claude-3p\configLibrary\8f69f2f1-3275-4ad8-9317-4aa7e972f311.json
```

`Claude-3p` 전체 tree hash는 캐시·업데이트 파일로 인한 오탐 가능성이 있어 Gate에 사용하지 않는다.
마지막 일반 Claude Desktop smoke가 전체 사용자 관점의 정상성을 보완한다.

### Allowed to change

```text
%APPDATA%\claude-code-router\**
%APPDATA%\CompanyCCR\runtime-localappdata\**
CCR runtime database/config
승인된 PC 로컬 recovery backup
```

## Managed environment keys

사내 세션 안에서 before/after equality만 비교한다. 값 자체는 외부로 출력하지 않는다.

```text
CLAUDE_CONFIG_DIR
ANTHROPIC_BASE_URL
ANTHROPIC_API_BASE_URL
CLAUDE_AGENT_API_BASE_URL
ANTHROPIC_FEDERATION_RULE_ID
ANTHROPIC_ORGANIZATION_ID
ANTHROPIC_IDENTITY_TOKEN
ANTHROPIC_IDENTITY_TOKEN_FILE
ANTHROPIC_SERVICE_ACCOUNT_ID
ANTHROPIC_WORKSPACE_ID
ANTHROPIC_SCOPE
ANTHROPIC_PROFILE
ANTHROPIC_MODEL
CCR_CLAUDE_CODE_MODEL
CODEXL_CLAUDE_CODE_MODEL
ANTHROPIC_DEFAULT_FABLE_MODEL
ANTHROPIC_DEFAULT_OPUS_MODEL
ANTHROPIC_DEFAULT_SONNET_MODEL
ANTHROPIC_DEFAULT_HAIKU_MODEL
ANTHROPIC_SMALL_FAST_MODEL
CCR_CLAUDE_CODE_MCP_CONFIG
CODEXL_CLAUDE_CODE_MCP_CONFIG
```

## Critical execution order

Enterprise smoke는 정상 앱 실행 과정에서 settings/cache를 갱신할 수 있다.
따라서 반드시 다음 순서를 사용한다.

```text
A0 repository/service preflight
→ H0 Enterprise smoke와 로컬 backup
→ 모든 Claude Code/Claude Desktop process 종료
→ A1 baseline fingerprint capture
→ A2 sandbox CCR start
→ H1 safe config cleanup/save
→ A3 during/after fingerprint compare와 CCR stop
→ H2 Enterprise after smoke
→ A4 sanitized report
```

H0보다 먼저 authoritative fingerprint를 잡지 않는다.

## A0 — [INTERNAL_VALIDATOR] Repository and service preflight

```powershell
git fetch --prune origin
git show <INSTRUCTION_SHA>:company/tasks/v1-s1/V1-S1-T00-CCR-RUNTIME-SANDBOX.md
git checkout --detach 97b73a9f4e1fb23d406bb987d0785cefa1f99966

$TestedCommit = git rev-parse HEAD
git status --short

$Cli = "packages/cli/dist/main/cli.js"
$CliExists = Test-Path $Cli

node --version
npm --version
node -p "process.platform"
node -p "process.arch"

$TestedCommit
$CliExists
```

진행 조건:

```text
candidate exact match
working tree clean
process.platform = win32
CLI exists = True
CCR service stopped
```

CCR service가 실행 중이면 Task에 기록된 stock `stop`만 수행한 뒤 다시 확인한다.
정상 종료가 되지 않으면 source/runtime DB를 수정하지 말고 중단한다.

## H0 — [HUMAN_GATE_OWNER] Enterprise smoke, backup, and quiesce

CCR를 시작하기 전에 확인한다.

```text
Enterprise Claude Code authentication smoke: PASS
Enterprise Claude models visible: PASS
Claude Desktop normal smoke: PASS
```

그 뒤:

1. Enterprise settings 원본을 승인된 PC 로컬 recovery 폴더에만 백업한다.
2. 모든 Claude Code CLI/App 세션을 종료한다.
3. Claude Desktop을 완전히 종료한다.
4. 백업을 Git/repository/shared folder에 두지 않는다.

Internal Validator에 반환:

```text
Enterprise CLI baseline: PASS / FAIL
Enterprise model baseline: PASS / FAIL
Claude Desktop baseline: PASS / FAIL
Local recovery backup: CREATED / NOT_CREATED
Claude clients closed: YES / NO
```

하나라도 FAIL이거나 client가 종료되지 않으면 `ENTERPRISE_BASELINE_FAILURE`로 중단한다.

## A1 — [INTERNAL_VALIDATOR] Capture baseline after smoke and shutdown

```powershell
$EnterpriseSettings = Join-Path $env:USERPROFILE ".claude\settings.json"
$RealClaude3p = Join-Path $env:LOCALAPPDATA "Claude-3p"
$SandboxLocalAppData = Join-Path $env:APPDATA "CompanyCCR\runtime-localappdata"
$SandboxClaude3p = Join-Path $SandboxLocalAppData "Claude-3p"
$ClaudeAppConfigId = "8f69f2f1-3275-4ad8-9317-4aa7e972f311"

function New-Claude3pTargets([string]$Root) {
  @(
    [PSCustomObject]@{
      Name = "root-config"
      Path = Join-Path $Root "claude_desktop_config.json"
    },
    [PSCustomObject]@{
      Name = "library-meta"
      Path = Join-Path $Root "configLibrary\_meta.json"
    },
    [PSCustomObject]@{
      Name = "ccr-library-entry"
      Path = Join-Path $Root "configLibrary\$ClaudeAppConfigId.json"
    }
  )
}

$RealClaude3pTargets = New-Claude3pTargets $RealClaude3p
$SandboxClaude3pTargets = New-Claude3pTargets $SandboxClaude3p

$ManagedEnvKeys = @(
  "CLAUDE_CONFIG_DIR",
  "ANTHROPIC_BASE_URL",
  "ANTHROPIC_API_BASE_URL",
  "CLAUDE_AGENT_API_BASE_URL",
  "ANTHROPIC_FEDERATION_RULE_ID",
  "ANTHROPIC_ORGANIZATION_ID",
  "ANTHROPIC_IDENTITY_TOKEN",
  "ANTHROPIC_IDENTITY_TOKEN_FILE",
  "ANTHROPIC_SERVICE_ACCOUNT_ID",
  "ANTHROPIC_WORKSPACE_ID",
  "ANTHROPIC_SCOPE",
  "ANTHROPIC_PROFILE",
  "ANTHROPIC_MODEL",
  "CCR_CLAUDE_CODE_MODEL",
  "CODEXL_CLAUDE_CODE_MODEL",
  "ANTHROPIC_DEFAULT_FABLE_MODEL",
  "ANTHROPIC_DEFAULT_OPUS_MODEL",
  "ANTHROPIC_DEFAULT_SONNET_MODEL",
  "ANTHROPIC_DEFAULT_HAIKU_MODEL",
  "ANTHROPIC_SMALL_FAST_MODEL",
  "CCR_CLAUDE_CODE_MCP_CONFIG",
  "CODEXL_CLAUDE_CODE_MCP_CONFIG"
)

$ProcessBoundaryKeys = @(
  "LOCALAPPDATA",
  "APPDATA",
  "USERPROFILE"
) + $ManagedEnvKeys

function Get-StringFingerprint([string]$Value) {
  $Bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
  $Sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($Sha.ComputeHash($Bytes))).Replace("-", "")
  } finally {
    $Sha.Dispose()
  }
}

function Get-FileFingerprint([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    return "ABSENT"
  }
  return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash
}

function Get-PathSetFingerprint($Targets) {
  $Rows = foreach ($Target in $Targets) {
    $Fingerprint = Get-FileFingerprint $Target.Path
    "$($Target.Name)|$Fingerprint"
  }
  return Get-StringFingerprint ($Rows -join "`n")
}

function Get-EnvFingerprint([string]$Scope, [string[]]$Keys) {
  $Rows = foreach ($Name in $Keys) {
    $Value = [Environment]::GetEnvironmentVariable($Name, $Scope)
    "$Name=$Value"
  }
  return Get-StringFingerprint ($Rows -join "`n")
}

function Get-ClaudeResolutionFingerprint {
  $Rows = @(
    (where.exe claude 2>$null),
    (Get-Command claude -All -ErrorAction SilentlyContinue |
      ForEach-Object { "$($_.CommandType)|$($_.Source)|$($_.Path)" })
  )
  return Get-StringFingerprint ($Rows -join "`n")
}

$Baseline = [PSCustomObject]@{
  EnterpriseSettings = Get-FileFingerprint $EnterpriseSettings
  RealClaude3pConfig = Get-PathSetFingerprint $RealClaude3pTargets
  ProcessEnv = Get-EnvFingerprint "Process" $ProcessBoundaryKeys
  UserEnv = Get-EnvFingerprint "User" $ManagedEnvKeys
  MachineEnv = Get-EnvFingerprint "Machine" $ManagedEnvKeys
  ClaudeResolution = Get-ClaudeResolutionFingerprint
}
```

Fingerprint 원문과 hash는 외부로 출력하지 않는다.
잠긴 파일 등으로 수집이 실패하면 `BLOCKED_BASELINE_CAPTURE`로 중단한다.

## A2 — [INTERNAL_VALIDATOR] Start sandboxed management service

User/Machine 환경변수를 변경하지 않는다.
현재 PowerShell process에서 daemon spawn 동안만 `LOCALAPPDATA`를 바꾼다.

```powershell
New-Item -ItemType Directory -Force -Path $SandboxLocalAppData | Out-Null

$OriginalLocalAppData = $env:LOCALAPPDATA
try {
  $env:LOCALAPPDATA = $SandboxLocalAppData
  node $Cli start --no-open --no-gateway
  $StartExit = $LASTEXITCODE
} finally {
  $env:LOCALAPPDATA = $OriginalLocalAppData
}

$ParentLocalAppDataRestored = $env:LOCALAPPDATA -eq $OriginalLocalAppData
$ParentProcessEnvAfterStart = Get-EnvFingerprint "Process" $ProcessBoundaryKeys
$ParentProcessEnvRestored = $Baseline.ProcessEnv -eq $ParentProcessEnvAfterStart

$StartExit
$ParentLocalAppDataRestored
$ParentProcessEnvRestored
```

기대 결과:

```text
StartExit = 0
ParentLocalAppDataRestored = True
ParentProcessEnvRestored = True
```

Management URL/token은 사내 PC 안에서만 사용한다.
`StartExit != 0`이면 `RUNTIME_SANDBOX_INCOMPATIBLE`로 중단한다.

## H1 — [HUMAN_GATE_OWNER] Remove global profile side effects and save

로컬 Management UI에서 수행한다.

1. 활성 `System default` / global Claude Code profile을 모두 제거하거나 비활성화한다.
2. 이 Task에서는 새 Claude Code profile을 만들지 않는다.
3. `Request logs`를 OFF로 둔다.
4. `Agent observability`를 OFF로 둔다.
5. Provider endpoint/key/model/protocol은 수정하지 않는다.
6. 설정을 저장한다.
7. `Connect agent`, `Let's start`, model request를 수행하지 않는다.

설정 저장 과정에서 Gateway가 내부적으로 시작되더라도 model request를 보내지 않는다.
모든 side effect는 sandbox process 안에 머물러야 한다.

Internal Validator에 반환:

```text
Enabled global Claude Code profiles after save: 0
New profile created: NO
Request logs: OFF
Agent observability: OFF
Provider changed: NO
Connect agent executed: NO
Let's start executed: NO
```

글로벌 프로필을 제거할 수 없거나 source/runtime DB 직접 편집이 필요하면 중단한다.

## A3 — [INTERNAL_VALIDATOR] Compare during, stop, and compare after

Claude Code와 Claude Desktop은 이 비교가 끝날 때까지 실행하지 않는다.

```powershell
function Get-CurrentInvariantState {
  [PSCustomObject]@{
    EnterpriseSettings = Get-FileFingerprint $EnterpriseSettings
    RealClaude3pConfig = Get-PathSetFingerprint $RealClaude3pTargets
    ProcessEnv = Get-EnvFingerprint "Process" $ProcessBoundaryKeys
    UserEnv = Get-EnvFingerprint "User" $ManagedEnvKeys
    MachineEnv = Get-EnvFingerprint "Machine" $ManagedEnvKeys
    ClaudeResolution = Get-ClaudeResolutionFingerprint
  }
}

$During = Get-CurrentInvariantState

$SettingsDuringSame = $Baseline.EnterpriseSettings -eq $During.EnterpriseSettings
$Claude3pDuringSame = $Baseline.RealClaude3pConfig -eq $During.RealClaude3pConfig
$ProcessEnvDuringSame = $Baseline.ProcessEnv -eq $During.ProcessEnv
$UserEnvDuringSame = $Baseline.UserEnv -eq $During.UserEnv
$MachineEnvDuringSame = $Baseline.MachineEnv -eq $During.MachineEnv
$ClaudeResolutionDuringSame = $Baseline.ClaudeResolution -eq $During.ClaudeResolution

$SandboxClaude3pTargetCount = @(
  $SandboxClaude3pTargets |
    Where-Object { Test-Path -LiteralPath $_.Path -PathType Leaf }
).Count
$SandboxClaude3pConfigMaterialized =
  $SandboxClaude3pTargetCount -eq $SandboxClaude3pTargets.Count

node $Cli stop
$StopExit = $LASTEXITCODE

$After = Get-CurrentInvariantState

$SettingsAfterSame = $Baseline.EnterpriseSettings -eq $After.EnterpriseSettings
$Claude3pAfterSame = $Baseline.RealClaude3pConfig -eq $After.RealClaude3pConfig
$ProcessEnvAfterSame = $Baseline.ProcessEnv -eq $After.ProcessEnv
$UserEnvAfterSame = $Baseline.UserEnv -eq $After.UserEnv
$MachineEnvAfterSame = $Baseline.MachineEnv -eq $After.MachineEnv
$ClaudeResolutionAfterSame = $Baseline.ClaudeResolution -eq $After.ClaudeResolution

git diff --exit-code -- packages package.json package-lock.json
$ProductDiffExit = $LASTEXITCODE
git status --short
```

기대 결과:

```text
Enterprise settings during/after = SAME
actual Claude-3p CCR config surface during/after = SAME
Process env during/after = SAME
User env during/after = SAME
Machine env during/after = SAME
normal claude resolution during/after = SAME
sandbox Claude-3p config materialized = TRUE
StopExit = 0
ProductDiffExit = 0
final git status = clean
```

Boolean/equality와 target count만 보고하고 fingerprint 값·파일 원문·전체 경로는 출력하지 않는다.

## H2 — [HUMAN_GATE_OWNER] Enterprise after smoke

A3 fingerprint 비교가 끝난 뒤 정상 경로로 확인한다.

```text
Enterprise Claude Code authentication smoke: PASS
Enterprise Claude models visible: PASS
Claude Desktop normal smoke: PASS
Manual settings/env recovery required: NO
```

수동 복구가 필요했다면 최종 결과는 FAIL이다.

## Acceptance criteria

- [x] exact instruction SHA 기록
- [x] exact candidate SHA 기록
- [x] working tree before test clean
- [x] Enterprise baseline smoke PASS
- [x] local recovery backup 상태 기록
- [x] all Claude clients closed before fingerprint
- [x] baseline captured after smoke and shutdown
- [x] service starts with process-local sandbox `LOCALAPPDATA`
- [x] parent PowerShell `LOCALAPPDATA` restored immediately
- [x] parent Process env boundary restored immediately
- [ ] enabled global Claude Code profiles after save = `0`
- [ ] Request logs OFF
- [ ] Agent observability OFF
- [x] Provider unchanged
- [x] actual Enterprise settings during/after = SAME
- [x] actual Claude-3p CCR config surface during/after = SAME
- [x] Process env during/after = SAME
- [x] User env during/after = SAME
- [x] Machine env during/after = SAME
- [x] normal `claude` resolution during/after = SAME
- [x] sandbox Claude-3p config files materialized
- [x] stop exit `0`
- [x] Enterprise after smoke PASS
- [x] manual rollback not required
- [x] product diff exit `0`
- [x] final Git status clean
- [x] secrets/raw fingerprints exported = NO
- [x] Git write performed = NO
- [x] next Task started = NO

## Result rules

```text
PASS
→ management/config-save runtime sandbox proves Enterprise invariance
→ Human Gate may reactivate V1-S1-T01
→ company-claude child isolation is still UNVERIFIED until V1-S2

FAIL — ISOLATION_BREACH
→ Enterprise settings/env/Claude-3p config/command changed
→ Human restores local baseline
→ External Codex repair or explicit sync-disable Task required

FAIL — RUNTIME_SANDBOX_INCOMPATIBLE
→ Stock CCR cannot operate correctly with process-local LOCALAPPDATA
→ evaluate minimal explicit Claude App sync-disable patch

BLOCKED
→ baseline, fingerprint, policy or host precondition unavailable
```

## Stop conditions

- CCR service cannot be stopped before baseline
- working tree dirty
- Enterprise baseline smoke FAIL
- Claude clients cannot be closed
- fingerprint capture unavailable
- User/Machine env must be edited to continue
- source/runtime DB direct edit required
- Enterprise invariant changes
- secret/raw settings must be exported to diagnose
- model request would be required

## Failure classification

- `BLOCKED_BASELINE_CAPTURE`
- `ENTERPRISE_BASELINE_FAILURE`
- `RUNTIME_SANDBOX_INCOMPATIBLE`
- `ISOLATION_BREACH`
- `GLOBAL_PROFILE_PERSISTENCE`
- `CLAUDE_APP_CONFIG_PERSISTENCE`
- `PROCESS_ENVIRONMENT_LEAK`
- `LOGGING_SAFETY`
- `SHUTDOWN`
- `PRODUCT_DIFF`
- `UNKNOWN`

## Sanitized evidence template

```text
Role: INTERNAL_VALIDATOR
Task ID: V1-S1-T00
Session role: runtime isolation spike
Instruction SHA:
Candidate SHA:
Environment alias:

A0:
- candidate match:
- working tree clean:
- CLI exists:
- CCR service stopped:

H0:
- Enterprise CLI baseline:
- Enterprise model baseline:
- Claude Desktop baseline:
- local recovery backup:
- Claude clients closed:

A1:
- baseline captured after smoke/shutdown:
- fingerprint scope: TARGETED_CCR_CONFIG_FILES

A2:
- sandbox service start:
- start exit code:
- parent LOCALAPPDATA restored:
- parent Process env restored:

H1:
- enabled global Claude Code profiles:
- new profile created: NO
- Request logs:
- Agent observability:
- Provider changed: NO
- Connect agent executed: NO
- Let's start executed: NO

A3 during:
- Enterprise settings: SAME / CHANGED
- actual Claude-3p CCR config surface: SAME / CHANGED
- Process env: SAME / CHANGED
- User env: SAME / CHANGED
- Machine env: SAME / CHANGED
- normal claude resolution: SAME / CHANGED
- sandbox Claude-3p config materialized: YES / NO
- sandbox target count: 0..3

A3 after:
- CCR stop / exit code:
- Enterprise settings: SAME / CHANGED
- actual Claude-3p CCR config surface: SAME / CHANGED
- Process env: SAME / CHANGED
- User env: SAME / CHANGED
- Machine env: SAME / CHANGED
- normal claude resolution: SAME / CHANGED
- product diff / exit code:
- final git status:

H2:
- Enterprise CLI after:
- Enterprise models after:
- Claude Desktop after:
- manual rollback required: NO / YES

Coverage boundary:
- management/config-save isolation: TESTED
- company-claude child environment: NOT_TESTED

Failure classification:
Reproducibility:
Sanitized observation:
Secrets/raw fingerprints exported: NO
Git write performed: NO
Next Task started: NO
```

## Attempt 1 Evidence — sanitized

- Date: `2026-09-01`
- Result: `BLOCKED`
- Failure classification: `GLOBAL_PROFILE_PERSISTENCE`
- Cause: `ONBOARDING_GATE_REQUIRES_FORBIDDEN_CONNECT_AGENT`
- Reproducibility: `ONE_ATTEMPT / NOT_REPRODUCED`

`BLOCKED`인 이유는 Enterprise invariant 침해나 sandbox start 실패가 아니라, Task가 금지한 `Connect agent` 없이 H1 cleanup/save 화면에 도달할 수 없어 policy precondition을 충족하지 못했기 때문이다.
실제 global profile이 남았다고 단정하지 않는다. 정확한 미검증 항목은 “enabled global profile을 0으로 만들고 저장한 결과”다.

### Reference and role contract

```text
Instruction SHA: 6d0d6f2aeca02e33261c062eac5aab360805222b
Candidate SHA: 97b73a9f4e1fb23d406bb987d0785cefa1f99966
Environment alias: UNSET

A0 operator: INTERNAL_VALIDATOR
H0/H1/H2 operator: HUMAN_GATE_OWNER
A1/A2/A3 operator: HUMAN_GATE_OWNER manual PowerShell, internal agent OFF

WINDOWS_RUNTIME_ALLOWED: YES
CLAUDE_CODE_EXECUTION_ALLOWED: YES
LLM_CREDENTIAL_AUTHORIZED_FOR_HOST: NOT_REQUIRED_FOR_THIS_TASK
```

Product tree equivalence는 `packages/**`, `package.json`, `package-lock.json` 범위에서 `CHATGPT_ORCHESTRATOR`가 `SAME`으로 확인했다.
Internal Validator는 이를 독립적으로 반복하지 않았다.

### Step evidence

| Step | Sanitized result |
|---|---|
| A0 | candidate exact match `YES`; tree clean `YES`; Node `v24.15.0`; npm `11.12.1`; `win32/x64`; CLI exists `YES`; CCR stopped `YES` |
| H0 | Enterprise CLI `PASS`; Enterprise models `PASS`; Claude Desktop `PASS`; local backup `CREATED`; Claude clients closed before baseline `YES` |
| A1 | baseline captured after smoke/shutdown `YES`; scope `TARGETED_CCR_CONFIG_FILES` |
| A2 | sandbox start exit `0`; parent `LOCALAPPDATA` restored `YES`; parent Process env restored `YES` |
| H1 | cleanup/save `NOT_COMPLETED`; enabled global profiles after save `NOT_VERIFIED`; Request logs `NOT_VERIFIED`; Agent observability `NOT_VERIFIED` |
| H1 safety | new profile `NO`; Provider changed during Attempt `NO`; prior setup `SETUP_PRE`; Connect agent `NO`; Let's start `NO`; model request `NO` |
| A3 during/after | Enterprise settings, actual Claude-3p target surface, Process/User/Machine env and normal `claude` resolution all `SAME` |
| A3 cleanup | sandbox Claude-3p materialized `YES`; target count `3`; stop exit `0`; product diff exit `0`; final Git status `CLEAN` |
| H2 | Enterprise CLI/models/Desktop `PASS`; manual recovery `NO` |

Coverage boundary:

```text
management start isolation: TESTED_PASS
config-save isolation: NOT_TESTED
company-claude child environment: NOT_TESTED
acceptance criteria: 26 / 29 verified
secrets/raw fingerprints exported: NO
internal Git/GitHub write: NO
next Task started: NO
```

## Repair finding and Human Gate direction

Source review at instruction SHA confirmed:

- unfinished onboarding renders only `OnboardingLayout`; the existing Profile/Settings management views are not reachable without the `Connect agent` flow;
- onboarding profile submission persists with `applyProfile: true`, confirms the profile and advances toward `Let's start`;
- no supported stock UI path exposes the required H1 cleanup without a forbidden action;
- runtime sandbox start itself passed, so a CCR Core or UI patch is not justified by this Attempt.

Human Gate decision:

```text
CCR source changes: REJECTED
packages/** changes: PROHIBITED
repair direction: COMPANY-OWNED WRAPPER ONLY
```

Wrapper feasibility source review found a supported pinned-version path:

- Company-owned implementation belongs under `company/**`.
- Stock CCR `v3.0.22` exposes an authenticated loopback Management RPC with `getConfig` and `saveConfig`.
- The local CLI service state contains the tokenized management URL, service identity and start mode; a Company helper may read them in memory but must never print or persist raw values.
- A prior service can be reused despite `start --no-gateway`, so T00 A0/A2 plus `getServiceIdentity` and pre-save `getGatewayStatus` must prove the sandbox service identity and stopped Gateway state.
- `saveConfig(next, { applyProfile: false })` preserves the stock Claude App sync path while preventing the cleanup save from applying a global Claude Code profile.
- `saveConfig` can still start the Gateway as a config-save side effect. T00 already permits this; no Provider/model request may be sent.
- `saveConfig` always synchronizes Provider model auto-refresh. Every enabled Provider must therefore have `autoFetchModels = OFF`; otherwise the helper must stop before save.
- This RPC is a pinned `v3.0.22` dependency, not a permanent public API contract, and must be revalidated on upstream update.

The smallest proposed repair is the separate, still-`planned` Task `V1-S1-T02`:

1. Add a task-limited Company helper under `company/scripts/`; do not add a production launcher/Doctor yet.
2. Read the running sandbox service state and accept loopback-only authenticated RPC.
3. Verify service PID/token identity and require the pre-save Gateway to be stopped and not externally owned.
4. Call `getConfig` without printing raw configuration.
5. Fail closed before save if service sandbox state, auth, Provider auto-fetch state or config shape is unsafe.
6. Change only:
   - enabled `claude-code` profiles whose scope is neither `ccr` nor `custom`—including global, missing and unknown legacy values—to `enabled: false`;
   - `observability.requestLogs = false`;
   - `observability.agentAnalysis = false`;
   - `observability.requestLogBodyCapture = "none"`.
7. If already safe, omit save; otherwise call stock `saveConfig` with `{ applyProfile: false }`.
8. Re-read and verify enabled global Claude Code profiles `0`, logging/analysis/body capture OFF and Provider-related configuration unchanged.
9. Output only a compact sanitized PASS/BLOCKED/FAIL capsule; leave service stop and A3/H2 to T00.

This docs update does not authorize or implement T02.
T02 activation and its exact candidate/instruction SHA require a separate Human Gate decision.
T00 Attempt 2 and T01 remain blocked.

## Attempts

| Attempt | Actor / session role | Candidate | Internal result | Recommendation |
|---:|---|---|---|---|
| 1 | A0 Internal Validator; H0–H2 and A1–A3 Human Gate Owner | `97b73a9f...` | `BLOCKED — GLOBAL_PROFILE_PERSISTENCE` | approve Company-only T02 helper, then retry T00; do not start T01 |

## Human decision

`RETRY`
