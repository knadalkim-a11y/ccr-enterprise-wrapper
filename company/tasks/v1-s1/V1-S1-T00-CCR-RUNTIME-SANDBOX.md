---
id: V1-S1-T00
stage: V1-S1
title: Prove CCR runtime sandbox and Enterprise baseline invariance
kind: spike
status: ready_internal
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
human_decision: pending
---

# Prove CCR Runtime Sandbox and Enterprise Baseline Invariance

## Validation question

> Stock CCR management/runtime를 process-local `LOCALAPPDATA` sandbox에서 실행하고 활성 Claude Code global/System-default profile을 제거해도, 기존 Enterprise Claude Code 설정·인증·모델과 실제 `%LOCALAPPDATA%\Claude-3p`가 전혀 변경되지 않는가?

이 Task는 격리 선행조건 하나만 검증한다.
Provider 연결 재검사, model request, `Connect agent`, Streaming, Tool, CCR Claude Code 실행은 하지 않는다.

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
실제 %LOCALAPPDATA%\Claude-3p
일반 claude command resolution
Windows User/Machine CCR-managed environment values
Enterprise Claude Code authentication/model visibility
일반 Claude Desktop 동작
```

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

H0보다 먼저 fingerprint를 잡지 않는다.

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

function Get-FileFingerprint([string]$Path) {
  if (-not (Test-Path $Path)) { return "ABSENT" }
  return (Get-FileHash -Algorithm SHA256 -Path $Path).Hash
}

function Get-TreeFingerprint([string]$Path) {
  if (-not (Test-Path $Path)) { return "ABSENT" }
  $Rows = Get-ChildItem -Path $Path -Recurse -File -ErrorAction Stop |
    Sort-Object FullName |
    ForEach-Object {
      $Relative = $_.FullName.Substring($Path.Length).TrimStart("\")
      $Hash = (Get-FileHash -Algorithm SHA256 -Path $_.FullName).Hash
      "$Relative|$Hash"
    }
  $Bytes = [System.Text.Encoding]::UTF8.GetBytes(($Rows -join "`n"))
  $Sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($Sha.ComputeHash($Bytes))).Replace("-", "")
  } finally {
    $Sha.Dispose()
  }
}

function Get-EnvFingerprint([string]$Scope) {
  $Rows = foreach ($Name in $ManagedEnvKeys) {
    $Value = [Environment]::GetEnvironmentVariable($Name, $Scope)
    "$Name=$Value"
  }
  $Bytes = [System.Text.Encoding]::UTF8.GetBytes(($Rows -join "`n"))
  $Sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($Sha.ComputeHash($Bytes))).Replace("-", "")
  } finally {
    $Sha.Dispose()
  }
}

function Get-ClaudeResolutionFingerprint {
  $Rows = @(
    (where.exe claude 2>$null),
    (Get-Command claude -All -ErrorAction SilentlyContinue |
      ForEach-Object { "$($_.CommandType)|$($_.Source)|$($_.Path)" })
  )
  $Bytes = [System.Text.Encoding]::UTF8.GetBytes(($Rows -join "`n"))
  $Sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($Sha.ComputeHash($Bytes))).Replace("-", "")
  } finally {
    $Sha.Dispose()
  }
}

$Baseline = [PSCustomObject]@{
  EnterpriseSettings = Get-FileFingerprint $EnterpriseSettings
  RealClaude3p       = Get-TreeFingerprint $RealClaude3p
  UserEnv            = Get-EnvFingerprint "User"
  MachineEnv         = Get-EnvFingerprint "Machine"
  ClaudeResolution   = Get-ClaudeResolutionFingerprint
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

$StartExit
$ParentLocalAppDataRestored = $env:LOCALAPPDATA -eq $OriginalLocalAppData
$ParentLocalAppDataRestored
```

기대 결과:

```text
StartExit = 0
ParentLocalAppDataRestored = True
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
    RealClaude3p       = Get-TreeFingerprint $RealClaude3p
    UserEnv            = Get-EnvFingerprint "User"
    MachineEnv         = Get-EnvFingerprint "Machine"
    ClaudeResolution   = Get-ClaudeResolutionFingerprint
  }
}

$During = Get-CurrentInvariantState

$SettingsDuringSame = $Baseline.EnterpriseSettings -eq $During.EnterpriseSettings
$Claude3pDuringSame = $Baseline.RealClaude3p -eq $During.RealClaude3p
$UserEnvDuringSame = $Baseline.UserEnv -eq $During.UserEnv
$MachineEnvDuringSame = $Baseline.MachineEnv -eq $During.MachineEnv
$ClaudeResolutionDuringSame = $Baseline.ClaudeResolution -eq $During.ClaudeResolution
$SandboxClaude3pExists = Test-Path (Join-Path $SandboxLocalAppData "Claude-3p")

node $Cli stop
$StopExit = $LASTEXITCODE

$After = Get-CurrentInvariantState

$SettingsAfterSame = $Baseline.EnterpriseSettings -eq $After.EnterpriseSettings
$Claude3pAfterSame = $Baseline.RealClaude3p -eq $After.RealClaude3p
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
actual Claude-3p during/after = SAME
User env during/after = SAME
Machine env during/after = SAME
normal claude resolution during/after = SAME
sandbox Claude-3p exists = TRUE
StopExit = 0
ProductDiffExit = 0
final git status = clean
```

Boolean/equality만 보고하고 fingerprint 값은 출력하지 않는다.

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

- [ ] exact instruction SHA 기록
- [ ] exact candidate SHA 기록
- [ ] working tree before test clean
- [ ] Enterprise baseline smoke PASS
- [ ] local recovery backup 상태 기록
- [ ] all Claude clients closed before fingerprint
- [ ] baseline captured after smoke and shutdown
- [ ] service starts with process-local sandbox `LOCALAPPDATA`
- [ ] parent PowerShell `LOCALAPPDATA` restored immediately
- [ ] enabled global Claude Code profiles after save = `0`
- [ ] Request logs OFF
- [ ] Agent observability OFF
- [ ] Provider unchanged
- [ ] actual Enterprise settings during/after = SAME
- [ ] actual Claude-3p during/after = SAME
- [ ] User env during/after = SAME
- [ ] Machine env during/after = SAME
- [ ] normal `claude` resolution during/after = SAME
- [ ] sandbox Claude-3p exists
- [ ] stop exit `0`
- [ ] Enterprise after smoke PASS
- [ ] manual rollback not required
- [ ] product diff exit `0`
- [ ] final Git status clean
- [ ] secrets/raw fingerprints exported = NO
- [ ] Git write performed = NO
- [ ] next Task started = NO

## Result rules

```text
PASS
→ runtime sandbox proves Enterprise invariance
→ Human Gate may reactivate V1-S1-T01

FAIL — ISOLATION_BREACH
→ Enterprise settings/env/Claude-3p/command changed
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

A2:
- sandbox service start:
- start exit code:
- parent LOCALAPPDATA restored:

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
- actual Claude-3p: SAME / CHANGED
- User env: SAME / CHANGED
- Machine env: SAME / CHANGED
- normal claude resolution: SAME / CHANGED
- sandbox Claude-3p exists:

A3 after:
- CCR stop / exit code:
- Enterprise settings: SAME / CHANGED
- actual Claude-3p: SAME / CHANGED
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

Failure classification:
Reproducibility:
Sanitized observation:
Secrets/raw fingerprints exported: NO
Git write performed: NO
Next Task started: NO
```

## Attempts

| Attempt | Actor / session role | Candidate | Internal result | Recommendation |
|---:|---|---|---|---|
| 1 | Internal runtime isolation | `97b73a9f...` | `PENDING` | process-local sandbox 검증 |

## Human decision

`PENDING`
