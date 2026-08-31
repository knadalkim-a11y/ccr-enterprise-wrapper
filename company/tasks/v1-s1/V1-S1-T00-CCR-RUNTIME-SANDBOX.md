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

> Stock CCR management/runtime를 process-local `LOCALAPPDATA` sandbox에서 실행하고 CCR의 활성 Claude Code 글로벌 프로필을 제거한 뒤에도, 기존 Enterprise Claude Code 설정·인증·모델과 실제 `%LOCALAPPDATA%\Claude-3p`가 전혀 변경되지 않는가?

이 Task는 격리 선행조건만 검증한다.
Provider connection, model request, `Connect agent`, Streaming, Tool, Claude Code CCR request는 수행하지 않는다.

## Why this Task exists

사내 복구에서 다음이 확인됐다.

```text
Router stop 후에도 Enterprise Claude Code settings에 CCR Base URL이 잔존
→ 127.0.0.1:3456 token endpoint 오류

Base URL 제거 후 CCR WIF/Federation 값이 잔존
→ federation_rule_id prefix 오류

CCR Base URL + WIF/Federation 값을 제거
→ Enterprise 인증 정상 복귀

%LOCALAPPDATA%\Claude-3p의 CCR third-party inference config 제거
→ 일반 Claude Desktop 정상 복귀
```

Stock CCR source는:

- `Only opened from CCR` profile에 별도 Claude Code settings와 `CLAUDE_CONFIG_DIR`을 사용한다.
- management start/config save에서 Claude App Gateway sync를 호출할 수 있다.
- Windows Claude App sync 기본 경로로 `%LOCALAPPDATA%\Claude-3p`를 사용한다.

따라서 Provider Task를 재개하기 전에 runtime side effect를 실제 Enterprise 영역에서 격리할 수 있는지 증명해야 한다.

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

## Enterprise invariant surfaces

### Must remain unchanged

```text
%USERPROFILE%\.claude\settings.json
실제 %LOCALAPPDATA%\Claude-3p
일반 claude command resolution
Windows User/Machine CCR-managed environment values
Enterprise Claude Code authentication smoke
Enterprise Claude model list
일반 Claude Desktop smoke
```

### Allowed to change

```text
%APPDATA%\claude-code-router\**
%APPDATA%\CompanyCCR\runtime-localappdata\**
CCR runtime database/config
local recovery backup outside repository
```

## Managed environment keys

비교 대상은 다음이다.

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

값은 외부 Evidence에 출력하지 않는다.
사내 세션 메모리에서 before/after equality만 비교한다.

## Actor plan

| Order | Actor | Responsibility |
|---:|---|---|
| 1 | `INTERNAL_VALIDATOR` | A1 exact candidate와 baseline fingerprint 준비 |
| 2 | `HUMAN_GATE_OWNER` | H0 Enterprise baseline smoke와 로컬 비상 백업 |
| 3 | `INTERNAL_VALIDATOR` | A2 sandbox service 시작 |
| 4 | `HUMAN_GATE_OWNER` | H1 CCR UI에서 글로벌 프로필 제거·logging OFF 저장 |
| 5 | `INTERNAL_VALIDATOR` | A3 before/during 비교, service stop, product diff |
| 6 | `HUMAN_GATE_OWNER` | H2 Enterprise after smoke |
| 7 | `INTERNAL_VALIDATOR` | A4 sanitized Evidence 반환 |

## A1 — [INTERNAL_VALIDATOR] Preflight and local fingerprints

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

### Fingerprint helper

Fingerprint 원문과 hash는 외부로 출력하지 않는다.
결과에는 `SAME / CHANGED / ABSENT`만 사용한다.

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

  $Text = $Rows -join "`n"
  $Bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
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

$Baseline = [PSCustomObject]@{
  EnterpriseSettings = Get-FileFingerprint $EnterpriseSettings
  RealClaude3p       = Get-TreeFingerprint $RealClaude3p
  UserEnv            = Get-EnvFingerprint "User"
  MachineEnv         = Get-EnvFingerprint "Machine"
  ClaudeResolution   = (where.exe claude 2>$null) -join "`n"
}
```

Fingerprint 수집이 잠긴 파일 등으로 실패하면 임의로 예외 처리하지 않고 `BLOCKED_BASELINE_CAPTURE`로 중단한다.

## H0 — [HUMAN_GATE_OWNER] Enterprise baseline confirmation

CCR를 시작하기 전에 로컬에서 확인한다.

```text
Enterprise Claude Code authentication smoke: PASS
Enterprise Claude models visible: PASS
Claude Desktop normal smoke: PASS
```

권장 비상 백업:

```text
Enterprise settings 원본
→ PC 로컬 recovery 폴더에만 복사
→ Git/repository/shared folder 금지
```

Internal Validator에 반환:

```text
Enterprise CLI baseline: PASS / FAIL
Enterprise model baseline: PASS / FAIL
Claude Desktop baseline: PASS / FAIL
Local recovery backup: CREATED / NOT_CREATED
```

하나라도 FAIL이면 `ENTERPRISE_BASELINE_FAILURE`로 중단한다.

## A2 — [INTERNAL_VALIDATOR] Start management service with sandbox LOCALAPPDATA

실제 User/Machine 환경변수를 변경하지 않는다.
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
```

기대 결과:

```text
StartExit = 0
현재 PowerShell LOCALAPPDATA = 원래 값
```

Management URL/token은 사내 PC 안에서만 사용한다.
외부 Evidence에 복사하지 않는다.

`StartExit != 0`이면 `RUNTIME_SANDBOX_INCOMPATIBLE`로 중단한다.

## H1 — [HUMAN_GATE_OWNER] Remove global profile side effects and save safely

로컬 Management UI에서 수행한다.

1. Agent Profiles에 활성 `System default` / global Claude Code profile이 있으면 제거하거나 비활성화한다.
2. 이 Task에서는 새로운 Claude Code profile을 만들지 않는다.
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

글로벌 프로필을 제거할 수 없거나 저장에 source/runtime DB 직접 편집이 필요하면 중단한다.

## A3 — [INTERNAL_VALIDATOR] Verify isolation, stop, and repository cleanliness

### During-service comparison

```powershell
$During = [PSCustomObject]@{
  EnterpriseSettings = Get-FileFingerprint $EnterpriseSettings
  RealClaude3p       = Get-TreeFingerprint $RealClaude3p
  UserEnv            = Get-EnvFingerprint "User"
  MachineEnv         = Get-EnvFingerprint "Machine"
  ClaudeResolution   = (where.exe claude 2>$null) -join "`n"
}

$SettingsDuringSame = $Baseline.EnterpriseSettings -eq $During.EnterpriseSettings
$Claude3pDuringSame = $Baseline.RealClaude3p -eq $During.RealClaude3p
$UserEnvDuringSame = $Baseline.UserEnv -eq $During.UserEnv
$MachineEnvDuringSame = $Baseline.MachineEnv -eq $During.MachineEnv
$ClaudeResolutionDuringSame = $Baseline.ClaudeResolution -eq $During.ClaudeResolution
$SandboxClaude3pExists = Test-Path (Join-Path $SandboxLocalAppData "Claude-3p")
```

기대 결과:

```text
Enterprise settings SAME
Real Claude-3p SAME
User env SAME
Machine env SAME
claude resolution SAME
Sandbox Claude-3p exists TRUE
```

### Stop

```powershell
node $Cli stop
$StopExit = $LASTEXITCODE
$StopExit
```

### After-stop comparison

```powershell
$After = [PSCustomObject]@{
  EnterpriseSettings = Get-FileFingerprint $EnterpriseSettings
  RealClaude3p       = Get-TreeFingerprint $RealClaude3p
  UserEnv            = Get-EnvFingerprint "User"
  MachineEnv         = Get-EnvFingerprint "Machine"
  ClaudeResolution   = (where.exe claude 2>$null) -join "`n"
}

$SettingsAfterSame = $Baseline.EnterpriseSettings -eq $After.EnterpriseSettings
$Claude3pAfterSame = $Baseline.RealClaude3p -eq $After.RealClaude3p
$UserEnvAfterSame = $Baseline.UserEnv -eq $After.UserEnv
$MachineEnvAfterSame = $Baseline.MachineEnv -eq $After.MachineEnv
$ClaudeResolutionAfterSame = $Baseline.ClaudeResolution -eq $After.ClaudeResolution

git diff --exit-code -- packages package.json package-lock.json
$ProductDiffExit = $LASTEXITCODE
git status --short
```

Fingerprint 값 자체는 출력하지 않고 Boolean/equality만 보고한다.

## H2 — [HUMAN_GATE_OWNER] Enterprise after smoke

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
→ actual Enterprise settings/env/Claude-3p/command changed
→ Human restores local baseline
→ External Codex repair or explicit Core sync-disable Task required

FAIL — RUNTIME_SANDBOX_INCOMPATIBLE
→ Stock CCR cannot operate correctly with process-local LOCALAPPDATA
→ evaluate minimal explicit Claude App sync-disable patch

BLOCKED
→ Enterprise baseline, fingerprint capture, policy or host precondition unavailable
```

## Stop conditions

- CCR service was not stopped before baseline
- working tree dirty
- Enterprise baseline smoke FAIL
- fingerprint capture unavailable
- User/Machine env must be edited to continue
- source or runtime DB direct edit required
- actual Enterprise invariant changes
- actual secret/raw settings must be exported to diagnose
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

A1:
- candidate match:
- working tree clean:
- CLI exists:
- baseline fingerprint capture:

H0:
- Enterprise CLI baseline:
- Enterprise model baseline:
- Claude Desktop baseline:
- local recovery backup:

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
