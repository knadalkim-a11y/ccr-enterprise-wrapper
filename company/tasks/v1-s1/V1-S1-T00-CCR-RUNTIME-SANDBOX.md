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
candidate_sha: final_repair_pr_head_supplied_by_human_gate_owner
instruction_sha: same_as_candidate
merge_policy: not_applicable
depends_on:
  - V1-S0-T02
  - V1-S1-T02
unblocks:
  - V1-S1-T01
required_capabilities:
  - WINDOWS_RUNTIME_ALLOWED
  - CLAUDE_CODE_EXECUTION_ALLOWED
allowed_git_actions:
  - archive
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

- `company/tasks/v1-s1/V1-S1-T02-WRAPPER-SAFE-CONFIG-SAVE.md`
- `company/scripts/t00-safe-config-save.mjs`
- `company/docs/CLAUDE_CODE_ISOLATION.md`
- `company/docs/INTERNAL_VALIDATION.md`
- `company/docs/SECURITY.md`
- `company/docs/TRAPS.md`
- `packages/core/src/agents/claude-app/gateway-service.ts`
- `packages/core/src/config/constants.ts`
- `packages/core/src/config/config.ts`
- `packages/core/src/config/config-repository.ts`
- `packages/core/src/runtime/app-paths.ts`
- `packages/core/src/storage/migration.ts`
- `packages/core/src/config/onboarding-state.ts`
- `packages/core/src/web/management-server.ts`
- `packages/core/src/profiles/service.ts`

## Candidate contract

```text
Instruction SHA:
→ Human Gate Owner가 제공하는 final repair PR head

Candidate SHA:
→ Instruction SHA와 동일한 final repair PR head

Mode:
→ single exact-head implementation validation

Product tree equivalence:
→ 실행되는 `packages/**`, `build/**`, `package.json`, `package-lock.json`은 validated product commit `97b73a9f4e1fb23d406bb987d0785cefa1f99966`과 동일해야 함
```

이 Attempt는 V1-S0에서 승인된 host Git/Node/npm toolchain을 trusted precondition으로 상속한다. A0은 resolved executable identity와 exact candidate source/runtime tree를 session 동안 bind하지만 npm implementation/native prebuild 또는 Git local configuration까지 독립 supply-chain attestation했다고 주장하지 않는다. Install/build child에서는 LLM/credential-like process env를 제거하고 nonce workspace의 cache/log/temp/node-gyp 경로만 사용한 뒤 원상 복구한다.

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
%APPDATA%\CompanyCCR\validation-workspaces\**
CCR runtime database/config
승인된 PC 로컬 recovery backup
```

Nonce validation workspace에는 exact public source, dependency/build outputs와 local npm logs만 남는다. Recursive delete의 reparse 위험을 피하기 위해 Attempt 중 자동 삭제하지 않으며, Gate review 뒤 Human이 기록된 exact nonce 하나만 별도 local cleanup한다. 이 경로의 내용이나 절대경로는 외부 Evidence로 내보내지 않는다.

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
→ A2b wrapper no-save preflight + safe config cleanup/save
→ A3 during/after fingerprint compare와 CCR stop
→ H2 Enterprise after smoke
→ A4 sanitized report
```

H0보다 먼저 authoritative fingerprint를 잡지 않는다.

### Persistent PowerShell session contract

A0부터 A2–A3 종료까지 모든 PowerShell 블록은 **동일한 전용 64-bit
PowerShell process/console**에서 순서대로 실행한다. A0이 정의한 함수와
in-memory fingerprint를 파일로 serialize하거나 새 shell에서 재구성하지 않는다.
Sanitized A0 Evidence를 반환해 Gate 검토를 기다리는 동안에도 이 console은
열어 둔다. H0에서 종료하는 Claude/CCR client 또는 writer 목록에 이 검증
console은 포함하지 않는다.

Internal agent의 단계가 끝났다는 것은 명령 실행을 중단한다는 뜻이지 이
PowerShell process를 종료한다는 뜻이 아니다. A1/A2–A3를 별도 shell tool
call이나 새 console에서 실행하지 않는다. A2–A3는 하나의 원자적 블록이므로
중간 재개를 허용하지 않는다. A2 시작 전 session을 잃으면 해당 Attempt를
A0부터 다시 시작한다. A2–A3 도중 process를 잃었거나 service ownership/cleanup을
증명할 수 없으면 새 Attempt를 자동 시작하지 않고 `SERVICE_SHUTDOWN_FAILURE`로
Human recovery에 넘긴다.

## A0 — [INTERNAL_VALIDATOR] Repository and service preflight

```powershell
$T00A0Outcome = . {
$ErrorActionPreference = "Stop"
try {
$InstructionSha = "<INSTRUCTION_SHA>"
$ApprovedCandidateSha = "<APPROVED_CANDIDATE_SHA>"
$ValidatedProductCommit = "97b73a9f4e1fb23d406bb987d0785cefa1f99966"

if ($InstructionSha -cnotmatch '^[0-9a-f]{40}$' -or
    $ApprovedCandidateSha -cnotmatch '^[0-9a-f]{40}$' -or
    $InstructionSha -cne $ApprovedCandidateSha) {
  throw "BLOCKED_CANDIDATE_CONTRACT"
}
if (-not [Environment]::Is64BitOperatingSystem -or
    -not [Environment]::Is64BitProcess) {
  throw "BLOCKED_WINDOWS_RUNTIME"
}

function Stop-T00ToolchainIdentity(
  [string]$Phase,
  [string]$Tool,
  [string]$Reason
) {
  throw "BLOCKED_TOOLCHAIN_IDENTITY|PHASE=$Phase|TOOL=$Tool|REASON=$Reason"
}

function Get-T00BoundCommand(
  [string]$Name,
  [string]$Phase,
  [string]$Tool
) {
  try {
    $Commands = @(Get-Command $Name -CommandType Application -ErrorAction Stop)
  } catch {
    Stop-T00ToolchainIdentity $Phase $Tool "UNRESOLVED"
  }
  if ($Commands.Count -eq 0) {
    Stop-T00ToolchainIdentity $Phase $Tool "UNRESOLVED"
  }
  if ($Commands.Count -ne 1) {
    Stop-T00ToolchainIdentity $Phase $Tool "MULTI"
  }
  $CommandPath = [string]$Commands[0].Path
  if ([string]::IsNullOrWhiteSpace($CommandPath)) {
    Stop-T00ToolchainIdentity $Phase $Tool "NO_PATH"
  }
  try {
    $Item = Get-Item -LiteralPath $CommandPath -Force -ErrorAction Stop
  } catch {
    Stop-T00ToolchainIdentity $Phase $Tool "UNREADABLE"
  }
  if ($Item -isnot [IO.FileInfo]) {
    Stop-T00ToolchainIdentity $Phase $Tool "NOT_FILE"
  }
  if (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    Stop-T00ToolchainIdentity $Phase $Tool "REPARSE"
  }
  try {
    $Hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Item.FullName -ErrorAction Stop).Hash
  } catch {
    Stop-T00ToolchainIdentity $Phase $Tool "HASH_UNREADABLE"
  }
  if ($Hash -cnotmatch '^[0-9A-F]{64}$') {
    Stop-T00ToolchainIdentity $Phase $Tool "HASH_UNREADABLE"
  }
  return [PSCustomObject]@{
    Hash = $Hash
    Path = $Item.FullName
  }
}

function Get-T00BoundCommandStatus($BoundCommand) {
  if ($null -eq $BoundCommand) {
    return "INVALID_BOUND"
  }
  $Paths = @($BoundCommand.Path)
  $Hashes = @($BoundCommand.Hash)
  if ($Paths.Count -ne 1 -or
      $Hashes.Count -ne 1 -or
      [string]::IsNullOrWhiteSpace([string]$Paths[0]) -or
      ([string]$Hashes[0]) -cnotmatch '^[0-9A-F]{64}$') {
    return "INVALID_BOUND"
  }
  try {
    $Item = Get-Item -LiteralPath ([string]$Paths[0]) -Force -ErrorAction Stop
  } catch {
    return "UNREADABLE"
  }
  if ($Item -isnot [IO.FileInfo]) {
    return "NOT_FILE"
  }
  if (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    return "REPARSE"
  }
  try {
    $CurrentHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Item.FullName -ErrorAction Stop).Hash
  } catch {
    return "HASH_UNREADABLE"
  }
  if ($CurrentHash -cnotmatch '^[0-9A-F]{64}$') {
    return "HASH_UNREADABLE"
  }
  if ($CurrentHash -cne [string]$Hashes[0]) {
    return "HASH_MISMATCH"
  }
  return "MATCH"
}

function Test-T00BoundCommand($BoundCommand) {
  return (Get-T00BoundCommandStatus $BoundCommand) -ceq "MATCH"
}

function Assert-T00BoundCommand(
  $BoundCommand,
  [string]$Phase,
  [string]$Tool
) {
  $Reason = Get-T00BoundCommandStatus $BoundCommand
  if ($Reason -cne "MATCH") {
    Stop-T00ToolchainIdentity $Phase $Tool $Reason
  }
}

$GitTool = Get-T00BoundCommand "git" "BIND" "GIT"
$NodeTool = Get-T00BoundCommand "node" "BIND" "NODE"
$NpmTool = Get-T00BoundCommand "npm" "BIND" "NPM"
$GitExe = $GitTool.Path
$NodeExe = $NodeTool.Path
$NpmExe = $NpmTool.Path

$RepositoryRootRaw = @(& $GitExe rev-parse --show-toplevel 2>&1)
$RepositoryRootExit = $LASTEXITCODE
if ($RepositoryRootExit -ne 0 -or $RepositoryRootRaw.Count -ne 1) {
  $RepositoryRootRaw = $null
  throw "BLOCKED_REPOSITORY_ROOT"
}
$RepositoryRoot = [IO.Path]::GetFullPath(([string]$RepositoryRootRaw[0]).Trim()).TrimEnd('\', '/')
$RepositoryRootRaw = $null
$CurrentDirectory = [IO.Path]::GetFullPath((Get-Location).Path).TrimEnd('\', '/')
if ($CurrentDirectory -ine $RepositoryRoot) {
  throw "BLOCKED_REPOSITORY_ROOT"
}

$FetchRaw = @(& $GitExe fetch --prune origin 2>&1)
$FetchExit = $LASTEXITCODE
$FetchRaw = $null
if ($FetchExit -ne 0) {
  throw "BLOCKED_GIT_FETCH"
}

$InitialStatusRaw = @(& $GitExe status --porcelain=v1 --untracked-files=all 2>&1)
$InitialStatusExit = $LASTEXITCODE
$InitialWorkingTreeClean =
  $InitialStatusExit -eq 0 -and
  $InitialStatusRaw.Count -eq 0
$InitialStatusRaw = $null
if (-not $InitialWorkingTreeClean) {
  throw "BLOCKED_DIRTY_WORKTREE"
}

$TaskSpec = $InstructionSha + ":company/tasks/v1-s1/V1-S1-T00-CCR-RUNTIME-SANDBOX.md"
$InstructionTaskRaw = @(& $GitExe show $TaskSpec 2>&1)
$ShowTaskExit = $LASTEXITCODE
if ($ShowTaskExit -ne 0) {
  $InstructionTaskRaw = $null
  throw "BLOCKED_INSTRUCTION_LOAD"
}
$InstructionTaskRaw = $null

$CheckoutRaw = @(& $GitExe checkout --detach $ApprovedCandidateSha 2>&1)
$CheckoutExit = $LASTEXITCODE
$CheckoutRaw = $null
if ($CheckoutExit -ne 0) {
  throw "BLOCKED_CANDIDATE_CHECKOUT"
}

$TestedCommitRaw = @(& $GitExe rev-parse HEAD 2>&1)
$RevParseExit = $LASTEXITCODE
if ($RevParseExit -ne 0 -or $TestedCommitRaw.Count -ne 1) {
  $TestedCommitRaw = $null
  throw "BLOCKED_CANDIDATE_IDENTITY"
}
$TestedCommit = ([string]$TestedCommitRaw[0]).Trim()
$TestedCommitRaw = $null
if ($TestedCommit -cne $ApprovedCandidateSha) {
  throw "BLOCKED_CANDIDATE_IDENTITY"
}

$StatusRaw = @(& $GitExe status --porcelain=v1 --untracked-files=all 2>&1)
$StatusExit = $LASTEXITCODE
$WorkingTreeClean =
  $StatusExit -eq 0 -and
  $StatusRaw.Count -eq 0
$StatusRaw = $null
if (-not $WorkingTreeClean) {
  throw "BLOCKED_DIRTY_WORKTREE"
}

$ProductDiffRaw = @(
  & $GitExe diff --exit-code $ValidatedProductCommit HEAD -- packages build package.json package-lock.json 2>&1
)
$ProductTreeEquivalenceExit = $LASTEXITCODE
$ProductDiffRaw = $null
if ($ProductTreeEquivalenceExit -ne 0) {
  throw "BLOCKED_PRODUCT_TREE_MISMATCH"
}

$ForbiddenRuntimeEnvKeys = @(
  "CCR_GATEWAY_ENTRY",
  "CCR_INTERNAL_APP_DATA_DIR",
  "CCR_INTERNAL_HOME_DIR",
  "CCR_INTERNAL_USER_DATA_DIR",
  "CCR_MODELS_JSON_PATH",
  "CCR_MODEL_CATALOG_PATH",
  "CCR_NODE_BIN",
  "CCR_UPSTREAM_PROXY_URL",
  "CCR_WEB_ALLOWED_ORIGINS",
  "CCR_WEB_AUTH_TOKEN",
  "NODE_COMPILE_CACHE",
  "NODE_DEBUG",
  "NODE_OPTIONS",
  "NODE_REDIRECT_WARNINGS",
  "NODE_V8_COVERAGE",
  "npm_config_node_options",
  "npm_config_script_shell"
)
$ForbiddenRuntimeEnvPresent = @(
  $ForbiddenRuntimeEnvKeys | Where-Object {
    $RawValue = [Environment]::GetEnvironmentVariable(
      $_,
      [EnvironmentVariableTarget]::Process
    )
    $null -ne $RawValue -and $RawValue.Length -gt 0
  }
)
$RuntimeEnvSafe = $ForbiddenRuntimeEnvPresent.Count -eq 0
$ForbiddenRuntimeEnvPresent = $null
if (-not $RuntimeEnvSafe) {
  throw "BLOCKED_RUNTIME_ENV"
}

function Test-T00PathAbsent([string]$Path) {
  try {
    return -not (Test-Path -LiteralPath $Path -ErrorAction Stop)
  } catch {
    return $false
  }
}

function Test-T00BoundedRegularFile([string]$Path, [long]$MaxBytes) {
  try {
    $Item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    return (
      $Item -is [IO.FileInfo] -and
      (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) -and
      $Item.Length -gt 0 -and
      $Item.Length -le $MaxBytes
    )
  } catch {
    return $false
  }
}

function Test-T00AbsentOrBoundedRegularFile([string]$Path, [long]$MaxBytes) {
  if (Test-T00PathAbsent $Path) {
    return $true
  }
  return Test-T00BoundedRegularFile $Path $MaxBytes
}

function Test-T00CanonicalConfigStoreMetadata {
  try {
    $DirectoryItem = Get-Item -LiteralPath $CanonicalConfigDir -Force -ErrorAction Stop
    return (
      $DirectoryItem -is [IO.DirectoryInfo] -and
      (($DirectoryItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) -and
      (Test-T00BoundedRegularFile $CanonicalConfigDbFile 268435456) -and
      @($CanonicalConfigDbSidecars | Where-Object {
        -not (Test-T00AbsentOrBoundedRegularFile $_ 268435456)
      }).Count -eq 0
    )
  } catch {
    return $false
  } finally {
    $DirectoryItem = $null
  }
}

function Get-T00AllProcessEnvFingerprint {
  $Rows = @(
    [Environment]::GetEnvironmentVariables(
      [EnvironmentVariableTarget]::Process
    ).GetEnumerator() |
      Sort-Object Key -CaseSensitive |
      ForEach-Object { "$($_.Key)=$($_.Value)" }
  )
  $Bytes = [Text.Encoding]::UTF8.GetBytes(($Rows -join "`n"))
  $Sha = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($Sha.ComputeHash($Bytes))).Replace("-", "")
  } finally {
    $Sha.Dispose()
    $Rows = $null
  }
}

$RequiredAbsoluteRootNames = @("APPDATA", "LOCALAPPDATA", "USERPROFILE", "SystemRoot")
foreach ($RootName in $RequiredAbsoluteRootNames) {
  $RootValue = [Environment]::GetEnvironmentVariable(
    $RootName,
    [EnvironmentVariableTarget]::Process
  )
  if ([string]::IsNullOrWhiteSpace($RootValue) -or
      $RootValue -cnotmatch '^[A-Za-z]:\\') {
    throw "BLOCKED_WINDOWS_RUNTIME"
  }
}
$A0AppDataPath = [IO.Path]::GetFullPath($env:APPDATA).TrimEnd('\', '/')
$A0LocalAppDataPath = [IO.Path]::GetFullPath($env:LOCALAPPDATA).TrimEnd('\', '/')
$A0UserProfilePath = [IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\', '/')

$ExpectedSystemDirectory = [IO.Path]::GetFullPath([Environment]::SystemDirectory).TrimEnd('\', '/')
$ExpectedSystemRoot = [IO.Path]::GetDirectoryName($ExpectedSystemDirectory).TrimEnd('\', '/')
$ActualSystemRoot = [IO.Path]::GetFullPath(
  [Environment]::GetEnvironmentVariable(
    "SystemRoot",
    [EnvironmentVariableTarget]::Process
  )
).TrimEnd('\', '/')
if ($ActualSystemRoot -ine $ExpectedSystemRoot) {
  throw "BLOCKED_WINDOWS_RUNTIME"
}
$A0SystemRootPath = $ActualSystemRoot
$ExpectedComSpec = [IO.Path]::GetFullPath((Join-Path $ExpectedSystemDirectory "cmd.exe"))
$ActualComSpecRaw = [Environment]::GetEnvironmentVariable(
  "ComSpec",
  [EnvironmentVariableTarget]::Process
)
if ([string]::IsNullOrWhiteSpace($ActualComSpecRaw) -or
    [IO.Path]::GetFullPath($ActualComSpecRaw) -ine $ExpectedComSpec) {
  throw "BLOCKED_WINDOWS_RUNTIME"
}
$A0ComSpecPath = $ExpectedComSpec
$ComSpecItem = Get-Item -LiteralPath $ExpectedComSpec -Force -ErrorAction Stop
if (($ComSpecItem -isnot [IO.FileInfo]) -or
    (($ComSpecItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
  throw "BLOCKED_WINDOWS_RUNTIME"
}
$ComSpecItem = $null

$WhereExe = Join-Path $ExpectedSystemDirectory "where.exe"
$WhereItem = Get-Item -LiteralPath $WhereExe -Force -ErrorAction Stop
if (($WhereItem -isnot [IO.FileInfo]) -or
    (($WhereItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
  throw "BLOCKED_WINDOWS_RUNTIME"
}
$WhereItem = $null

Assert-T00BoundCommand $GitTool "PRE_FIRST_NODE" "GIT"
Assert-T00BoundCommand $NodeTool "PRE_FIRST_NODE" "NODE"
Assert-T00BoundCommand $NpmTool "PRE_FIRST_NODE" "NPM"

$ServiceStateFile = Join-Path $env:APPDATA "claude-code-router\service.json"
$ClaudeAppBackupFile = Join-Path $env:APPDATA "claude-code-router\claude-app-gateway-backup.json"
$CanonicalConfigDir = Join-Path $env:APPDATA "claude-code-router"
$CanonicalConfigDbFile = Join-Path $CanonicalConfigDir "config.sqlite"
$CanonicalConfigDbSidecars = @(
  "$CanonicalConfigDbFile-wal",
  "$CanonicalConfigDbFile-shm"
)
$LegacyActiveConfigFile = Join-Path $env:APPDATA "claude-code-router\config.json"
$LegacyHomeConfigFile = Join-Path $env:USERPROFILE ".claude-code-router\config.json"
$LegacyWindowsConfigDir = Join-Path $env:APPDATA "Claude Code Router"
$LegacyApiKeysDbFile = Join-Path $env:APPDATA "claude-code-router\api-keys.sqlite"
$LegacyOnboardingFile = Join-Path $env:APPDATA "claude-code-router\.onboard_finished"
$LegacyMigrationPaths = @(
  $LegacyActiveConfigFile,
  $LegacyHomeConfigFile,
  $LegacyWindowsConfigDir,
  $LegacyApiKeysDbFile,
  "$LegacyApiKeysDbFile-wal",
  "$LegacyApiKeysDbFile-shm",
  $LegacyOnboardingFile
)

if (-not (Test-T00PathAbsent $ServiceStateFile) -or
    -not (Test-T00PathAbsent $ClaudeAppBackupFile)) {
  throw "BLOCKED_SERVICE_PRECONDITION"
}
if (@($LegacyMigrationPaths | Where-Object {
  -not (Test-T00PathAbsent $_)
}).Count -ne 0) {
  throw "BLOCKED_CONFIG_MIGRATION_PRECONDITION"
}
if (-not (Test-T00CanonicalConfigStoreMetadata)) {
  throw "BLOCKED_CONFIG_STORE_PRECONDITION"
}
$ServiceStateAbsentBeforeBuild = $true
$ClaudeAppBackupAbsentBeforeBuild = $true
$LegacyMigrationSourcesAbsentBeforeBuild = $true
$CanonicalConfigDbReadyBeforeBuild = $true

$NodeVersionRaw = @(& $NodeExe --version 2>&1)
$NodeVersionExit = $LASTEXITCODE
$NpmVersionRaw = @(& $NpmExe --version 2>&1)
$NpmVersionExit = $LASTEXITCODE
$NodePlatformRaw = @(& $NodeExe -p "process.platform" 2>&1)
$NodePlatformExit = $LASTEXITCODE
$NodeArchRaw = @(& $NodeExe -p "process.arch" 2>&1)
$NodeArchExit = $LASTEXITCODE
if ($NodeVersionExit -ne 0 -or
    $NpmVersionExit -ne 0 -or
    $NodePlatformExit -ne 0 -or
    $NodeArchExit -ne 0 -or
    $NodeVersionRaw.Count -ne 1 -or
    $NpmVersionRaw.Count -ne 1 -or
    $NodePlatformRaw.Count -ne 1 -or
    $NodeArchRaw.Count -ne 1 -or
    ([string]$NodePlatformRaw[0]).Trim() -cne "win32" -or
    ([string]$NodeArchRaw[0]).Trim() -cne "x64" -or
    ([string]$NodeVersionRaw[0]).Trim() -cnotmatch '^v[0-9]+\.[0-9]+\.[0-9]+$' -or
    ([string]$NpmVersionRaw[0]).Trim() -cnotmatch '^[0-9]+\.[0-9]+\.[0-9]+$') {
  $NodeVersionRaw = $null
  $NpmVersionRaw = $null
  $NodePlatformRaw = $null
  $NodeArchRaw = $null
  throw "BLOCKED_WINDOWS_RUNTIME"
}

$NodeVersion = ([string]$NodeVersionRaw[0]).Trim()
$NpmVersion = ([string]$NpmVersionRaw[0]).Trim()
$NodePlatform = ([string]$NodePlatformRaw[0]).Trim()
$NodeArchitecture = ([string]$NodeArchRaw[0]).Trim()
$NodeVersionRaw = $null
$NpmVersionRaw = $null
$NodePlatformRaw = $null
$NodeArchRaw = $null

function Assert-T00SafeDirectory([string]$Path) {
  $Item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
  try {
    if (($Item -isnot [IO.DirectoryInfo]) -or
        (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
      throw "UNSAFE_LOCAL_PATH"
    }
  } finally {
    $Item = $null
  }
}

function Initialize-T00SafeDirectory([string]$Path) {
  $Exists = Test-Path -LiteralPath $Path -ErrorAction Stop
  if (-not $Exists) {
    $Created = New-Item -ItemType Directory -Path $Path -ErrorAction Stop
    $Created = $null
  }
  Assert-T00SafeDirectory $Path
}

$CompanyCcrRoot = Join-Path $env:APPDATA "CompanyCCR"
$ValidationWorkspaceRoot = Join-Path $CompanyCcrRoot "validation-workspaces"
$ValidationNonce = [Guid]::NewGuid().ToString("N")
$ValidationRoot = Join-Path $ValidationWorkspaceRoot $ValidationNonce
$ExecutionRoot = Join-Path $ValidationRoot "source"
$ArchiveFile = Join-Path $ValidationRoot "candidate.zip"

Initialize-T00SafeDirectory $CompanyCcrRoot
Initialize-T00SafeDirectory $ValidationWorkspaceRoot
if (-not (Test-T00PathAbsent $ValidationRoot)) {
  throw "UNSAFE_LOCAL_PATH"
}
$CreatedValidationRoot = New-Item -ItemType Directory -Path $ValidationRoot -ErrorAction Stop
$CreatedValidationRoot = $null
Assert-T00SafeDirectory $CompanyCcrRoot
Assert-T00SafeDirectory $ValidationWorkspaceRoot
Assert-T00SafeDirectory $ValidationRoot
$CreatedExecutionRoot = New-Item -ItemType Directory -Path $ExecutionRoot -ErrorAction Stop
$CreatedExecutionRoot = $null
Assert-T00SafeDirectory $ExecutionRoot

$ArchiveRaw = @(
  & $GitExe archive --format=zip "--output=$ArchiveFile" $ApprovedCandidateSha 2>&1
)
$ArchiveExit = $LASTEXITCODE
$ArchiveRaw = $null
if ($ArchiveExit -ne 0) {
  throw "BLOCKED_EXACT_TREE_ARCHIVE"
}
$ArchiveItem = Get-Item -LiteralPath $ArchiveFile -Force -ErrorAction Stop
if (($ArchiveItem -isnot [IO.FileInfo]) -or
    (($ArchiveItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) -or
    $ArchiveItem.Length -le 0) {
  throw "BLOCKED_EXACT_TREE_ARCHIVE"
}
$ArchiveItem = $null
$OriginalProgressPreference = $ProgressPreference
try {
  $ProgressPreference = "SilentlyContinue"
  Expand-Archive -LiteralPath $ArchiveFile -DestinationPath $ExecutionRoot -ErrorAction Stop
} finally {
  $ProgressPreference = $OriginalProgressPreference
}
Assert-T00SafeDirectory $ExecutionRoot

function Get-T00FileSetFingerprint([string[]]$Paths) {
  if ($Paths.Count -eq 0) {
    throw "BLOCKED_EXACT_TREE_ARCHIVE"
  }
  $Rows = [Collections.Generic.List[string]]::new()
  foreach ($Path in ($Paths | Sort-Object -CaseSensitive)) {
    $Item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if (($Item -isnot [IO.FileInfo]) -or
        (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
      throw "BLOCKED_EXACT_TREE_ARCHIVE"
    }
    $Hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Item.FullName -ErrorAction Stop).Hash
    $Rows.Add("$($Item.FullName)|$($Item.Length)|$Hash")
  }
  $Bytes = [Text.Encoding]::UTF8.GetBytes(($Rows -join "`n"))
  $Sha = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($Sha.ComputeHash($Bytes))).Replace("-", "")
  } finally {
    $Sha.Dispose()
  }
}

function Get-T00ExactSourcePaths {
  @(
    Get-ChildItem -LiteralPath $ExecutionRoot -File -Recurse -Force -ErrorAction Stop |
      Where-Object {
        $RelativePath = $_.FullName.Substring($ExecutionRoot.Length).TrimStart('\', '/')
        $RelativePath -inotmatch '(^|\\)node_modules\\' -and
        $RelativePath -inotmatch '^packages\\[^\\]+\\dist\\'
      } |
      ForEach-Object { $_.FullName }
  )
}

$ExactTreePaths = @(Get-T00ExactSourcePaths)
$ExactTreeFingerprint = Get-T00FileSetFingerprint $ExactTreePaths
if ($ExactTreeFingerprint -cnotmatch '^[0-9A-F]{64}$') {
  throw "BLOCKED_EXACT_TREE_ARCHIVE"
}

function Assert-T00ExecutionTreeRegular([string]$Root) {
  foreach ($FilePath in @(
    (Join-Path $Root "package.json"),
    (Join-Path $Root "package-lock.json")
  )) {
    $Item = Get-Item -LiteralPath $FilePath -Force -ErrorAction Stop
    if (($Item -isnot [IO.FileInfo]) -or
        (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
      throw "BLOCKED_EXECUTION_TREE"
    }
  }
  foreach ($TreePath in @(
    (Join-Path $Root "build"),
    (Join-Path $Root "packages")
  )) {
    $RootItem = Get-Item -LiteralPath $TreePath -Force -ErrorAction Stop
    if (($RootItem -isnot [IO.DirectoryInfo]) -or
        (($RootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
      throw "BLOCKED_EXECUTION_TREE"
    }
    $ReparseItems = @(
      Get-ChildItem -LiteralPath $TreePath -Recurse -Force -ErrorAction Stop |
        Where-Object {
          ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
        }
    )
    if ($ReparseItems.Count -ne 0) {
      throw "BLOCKED_EXECUTION_TREE"
    }
  }
}

Assert-T00ExecutionTreeRegular $ExecutionRoot
$SourcePackageHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $RepositoryRoot "package.json") -ErrorAction Stop).Hash
$SourceLockHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $RepositoryRoot "package-lock.json") -ErrorAction Stop).Hash
$ExecutionPackageHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $ExecutionRoot "package.json") -ErrorAction Stop).Hash
$ExecutionLockHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $ExecutionRoot "package-lock.json") -ErrorAction Stop).Hash
if ($SourcePackageHash -cne $ExecutionPackageHash -or
    $SourceLockHash -cne $ExecutionLockHash) {
  throw "BLOCKED_EXACT_TREE_ARCHIVE"
}

$DependencyInstallExit = $null
$TypecheckExit = $null
$BuildAssetsExit = $null
$NpmConfigSafe = $false
$NpmCacheDir = Join-Path $ValidationRoot "npm-cache"
$NpmLogsDir = Join-Path $ValidationRoot "npm-logs"
$BuildTempDir = Join-Path $ValidationRoot "build-temp"
$NodeGypDevDir = Join-Path $ValidationRoot "node-gyp"
foreach ($BuildLocalDirectory in @(
  $NpmCacheDir,
  $NpmLogsDir,
  $BuildTempDir,
  $NodeGypDevDir
)) {
  Initialize-T00SafeDirectory $BuildLocalDirectory
}
$BuildLocalDirectory = $null

$NpmUserConfigFile = Join-Path $ValidationRoot "npm-user-config"
$NpmGlobalConfigFile = Join-Path $ValidationRoot "npm-global-config"
[IO.File]::WriteAllText($NpmUserConfigFile, "", [Text.Encoding]::UTF8)
[IO.File]::WriteAllText($NpmGlobalConfigFile, "", [Text.Encoding]::UTF8)
foreach ($NpmConfigFile in @($NpmUserConfigFile, $NpmGlobalConfigFile)) {
  $NpmConfigItem = Get-Item -LiteralPath $NpmConfigFile -Force -ErrorAction Stop
  if (($NpmConfigItem -isnot [IO.FileInfo]) -or
      (($NpmConfigItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
    throw "BLOCKED_NPM_CONFIGURATION"
  }
}
$NpmConfigItem = $null

$BuildEnvironment = [Environment]::GetEnvironmentVariables(
  [EnvironmentVariableTarget]::Process
)
$BuildSensitiveEnvKeys = @(
  $BuildEnvironment.Keys | Where-Object {
    [string]$_ -match '(?i)(TOKEN|SECRET|PASSWORD|API_?KEY|CREDENTIAL)' -or
    [string]$_ -match '^(?i:ANTHROPIC|CLAUDE|CCR|CODEXL|OPENAI|AZURE|AWS|GOOGLE|GCP|GEMINI)_'
  }
)
$BuildLocalEnvValues = [ordered]@{
  "npm_config_cache" = $NpmCacheDir
  "npm_config_logs_dir" = $NpmLogsDir
  "npm_config_devdir" = $NodeGypDevDir
  "npm_config_userconfig" = $NpmUserConfigFile
  "npm_config_globalconfig" = $NpmGlobalConfigFile
  "TEMP" = $BuildTempDir
  "TMP" = $BuildTempDir
}
$BuildMutatedEnvKeys = @(
  $BuildSensitiveEnvKeys + @($BuildLocalEnvValues.Keys) | Select-Object -Unique
)
$BuildOriginalEnvValues = @{}
foreach ($BuildEnvKey in $BuildMutatedEnvKeys) {
  $BuildOriginalEnvValues[$BuildEnvKey] = [Environment]::GetEnvironmentVariable(
    $BuildEnvKey,
    [EnvironmentVariableTarget]::Process
  )
}

Push-Location $ExecutionRoot
try {
  foreach ($BuildEnvKey in $BuildSensitiveEnvKeys) {
    [Environment]::SetEnvironmentVariable(
      $BuildEnvKey,
      $null,
      [EnvironmentVariableTarget]::Process
    )
  }
  foreach ($BuildEnvEntry in $BuildLocalEnvValues.GetEnumerator()) {
    [Environment]::SetEnvironmentVariable(
      $BuildEnvEntry.Key,
      $BuildEnvEntry.Value,
      [EnvironmentVariableTarget]::Process
    )
  }

  Assert-T00BoundCommand $NodeTool "BUILD_ENTRY" "NODE"
  Assert-T00BoundCommand $NpmTool "BUILD_ENTRY" "NPM"
  $NpmNodeOptionsRaw = @(& $NpmExe --loglevel=silent config get node-options 2>&1)
  $NpmNodeOptionsExit = $LASTEXITCODE
  $NpmScriptShellRaw = @(& $NpmExe --loglevel=silent config get script-shell 2>&1)
  $NpmScriptShellExit = $LASTEXITCODE
  $NpmIgnoreScriptsRaw = @(& $NpmExe --loglevel=silent config get ignore-scripts 2>&1)
  $NpmIgnoreScriptsExit = $LASTEXITCODE
  $NpmInstallLinksRaw = @(& $NpmExe --loglevel=silent config get install-links 2>&1)
  $NpmInstallLinksExit = $LASTEXITCODE
  $NpmConfigSafe =
    $NpmNodeOptionsExit -eq 0 -and
    $NpmScriptShellExit -eq 0 -and
    $NpmIgnoreScriptsExit -eq 0 -and
    $NpmInstallLinksExit -eq 0 -and
    $NpmNodeOptionsRaw.Count -eq 1 -and
    $NpmScriptShellRaw.Count -eq 1 -and
    $NpmIgnoreScriptsRaw.Count -eq 1 -and
    $NpmInstallLinksRaw.Count -eq 1 -and
    ([string]$NpmNodeOptionsRaw[0]).Trim() -ceq "null" -and
    ([string]$NpmScriptShellRaw[0]).Trim() -ceq "null" -and
    ([string]$NpmIgnoreScriptsRaw[0]).Trim() -ceq "false" -and
    ([string]$NpmInstallLinksRaw[0]).Trim() -ceq "true"
  $NpmNodeOptionsRaw = $null
  $NpmScriptShellRaw = $null
  $NpmIgnoreScriptsRaw = $null
  $NpmInstallLinksRaw = $null
  if (-not $NpmConfigSafe) {
    throw "BLOCKED_NPM_CONFIGURATION"
  }

  try {
    $InstallRaw = @(& $NpmExe ci --audit=false --fund=false --ignore-scripts=false 2>&1)
    $DependencyInstallExit = $LASTEXITCODE
  } catch {
    $DependencyInstallExit = $null
  } finally {
    $InstallRaw = $null
  }
  if ($DependencyInstallExit -ne 0) {
    throw "BLOCKED_DEPENDENCY_INSTALL"
  }

  Assert-T00BoundCommand $NodeTool "POST_INSTALL" "NODE"
  $TypeScriptCli = Join-Path $ExecutionRoot "node_modules\typescript\bin\tsc"
  try {
    $TypecheckRaw = @(& $NodeExe $TypeScriptCli --noEmit 2>&1)
    $TypecheckExit = $LASTEXITCODE
  } catch {
    $TypecheckExit = $null
  } finally {
    $TypecheckRaw = $null
  }
  if ($TypecheckExit -ne 0) {
    throw "BLOCKED_TYPECHECK"
  }

  Assert-T00BoundCommand $NodeTool "PRE_BUILD" "NODE"
  try {
    $BuildRaw = @(& $NodeExe build/build.mjs 2>&1)
    $BuildAssetsExit = $LASTEXITCODE
  } catch {
    $BuildAssetsExit = $null
  } finally {
    $BuildRaw = $null
  }
  if ($BuildAssetsExit -ne 0) {
    throw "BLOCKED_BUILD_ASSETS"
  }
} finally {
  $InstallRaw = $null
  $TypecheckRaw = $null
  $BuildRaw = $null
  foreach ($BuildEnvKey in $BuildMutatedEnvKeys) {
    [Environment]::SetEnvironmentVariable(
      $BuildEnvKey,
      $BuildOriginalEnvValues[$BuildEnvKey],
      [EnvironmentVariableTarget]::Process
    )
  }
  $BuildEnvironment = $null
  $BuildOriginalEnvValues = $null
  Pop-Location
}

Assert-T00BoundCommand $GitTool "POST_BUILD" "GIT"
Assert-T00BoundCommand $NodeTool "POST_BUILD" "NODE"
Assert-T00BoundCommand $NpmTool "POST_BUILD" "NPM"

Assert-T00ExecutionTreeRegular $ExecutionRoot
$ExactTreePathsAfterBuild = @(Get-T00ExactSourcePaths)
$ExactTreeAfterBuild = Get-T00FileSetFingerprint $ExactTreePathsAfterBuild
if ($ExactTreeAfterBuild -cne $ExactTreeFingerprint) {
  throw "BLOCKED_BUILD_TREE_MUTATION"
}
$ExactTreeAfterBuild = $null
$ExactTreePathsAfterBuild = $null
$ExecutionPackageHashAfter = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $ExecutionRoot "package.json") -ErrorAction Stop).Hash
$ExecutionLockHashAfter = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $ExecutionRoot "package-lock.json") -ErrorAction Stop).Hash
if ($ExecutionPackageHashAfter -cne $SourcePackageHash -or
    $ExecutionLockHashAfter -cne $SourceLockHash) {
  throw "BLOCKED_BUILD_TREE_MUTATION"
}

$Cli = Join-Path $ExecutionRoot "packages\cli\dist\main\cli.js"
$HelperScript = Join-Path $ExecutionRoot "company\scripts\t00-safe-config-save.mjs"
foreach ($RequiredRuntimeFile in @($Cli, $HelperScript)) {
  $RuntimeItem = Get-Item -LiteralPath $RequiredRuntimeFile -Force -ErrorAction Stop
  if (($RuntimeItem -isnot [IO.FileInfo]) -or
      (($RuntimeItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
    throw "BLOCKED_BUILD_ASSETS"
  }
}
$RuntimeItem = $null
$CliExists = $true

function Get-T00BuildTreeFingerprint {
  $RequiredRuntimeRoots = @(
    (Join-Path $ExecutionRoot "packages\cli\dist"),
    (Join-Path $ExecutionRoot "packages\core\dist"),
    (Join-Path $ExecutionRoot "node_modules\better-sqlite3"),
    (Join-Path $ExecutionRoot "node_modules\bindings"),
    (Join-Path $ExecutionRoot "node_modules\file-uri-to-path")
  )
  $DistRoots = @(
    Get-ChildItem -LiteralPath (Join-Path $ExecutionRoot "packages") -Directory -Force -ErrorAction Stop |
      ForEach-Object { Join-Path $_.FullName "dist" } |
      Where-Object { Test-Path -LiteralPath $_ -ErrorAction Stop }
  )
  $RuntimeRoots = @($DistRoots + $RequiredRuntimeRoots | Select-Object -Unique)
  if ($DistRoots.Count -eq 0 -or
      @($RequiredRuntimeRoots | Where-Object { $RuntimeRoots -inotcontains $_ }).Count -ne 0) {
    throw "BLOCKED_BUILD_ASSETS"
  }

  $Rows = [Collections.Generic.List[string]]::new()
  foreach ($RuntimeRoot in ($RuntimeRoots | Sort-Object -CaseSensitive)) {
    $RootItem = Get-Item -LiteralPath $RuntimeRoot -Force -ErrorAction Stop
    if (($RootItem -isnot [IO.DirectoryInfo]) -or
        (($RootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
      throw "BLOCKED_BUILD_ASSETS"
    }
    $NestedDirectories = @(
      Get-ChildItem -LiteralPath $RuntimeRoot -Directory -Recurse -Force -ErrorAction Stop
    )
    if (@($NestedDirectories | Where-Object {
      ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
    }).Count -ne 0) {
      throw "BLOCKED_BUILD_ASSETS"
    }
    $Files = @(
      Get-ChildItem -LiteralPath $RuntimeRoot -File -Recurse -Force -ErrorAction Stop |
        Sort-Object FullName -CaseSensitive
    )
    if ($Files.Count -eq 0) {
      throw "BLOCKED_BUILD_ASSETS"
    }
    foreach ($File in $Files) {
      if (($File.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "BLOCKED_BUILD_ASSETS"
      }
      $FileHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $File.FullName -ErrorAction Stop).Hash
      $Rows.Add("$($File.FullName)|$($File.Length)|$FileHash")
    }
  }
  if ($Rows.Count -eq 0) {
    throw "BLOCKED_BUILD_ASSETS"
  }
  $Bytes = [Text.Encoding]::UTF8.GetBytes(($Rows -join "`n"))
  $Sha = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($Sha.ComputeHash($Bytes))).Replace("-", "")
  } finally {
    $Sha.Dispose()
  }
}

$BuildTreeFingerprint = Get-T00BuildTreeFingerprint
if ($BuildTreeFingerprint -cnotmatch '^[0-9A-F]{64}$') {
  throw "BLOCKED_BUILD_ASSETS"
}

$PostBuildStatusRaw = @(& $GitExe -C $RepositoryRoot status --porcelain=v1 --untracked-files=all 2>&1)
$PostBuildStatusExit = $LASTEXITCODE
$WorkingTreeCleanAfterBuild =
  $PostBuildStatusExit -eq 0 -and
  $PostBuildStatusRaw.Count -eq 0
$PostBuildStatusRaw = $null
if (-not $WorkingTreeCleanAfterBuild) {
  throw "BLOCKED_BUILD_TREE_MUTATION"
}

$PostBuildProductDiffRaw = @(
  & $GitExe -C $RepositoryRoot diff --exit-code $ValidatedProductCommit HEAD -- packages build package.json package-lock.json 2>&1
)
$ProductTreeEquivalenceExit = $LASTEXITCODE
$PostBuildProductDiffRaw = $null
if ($ProductTreeEquivalenceExit -ne 0) {
  throw "BLOCKED_BUILD_TREE_MUTATION"
}

if (-not (Test-T00PathAbsent $ServiceStateFile) -or
    -not (Test-T00PathAbsent $ClaudeAppBackupFile)) {
  throw "BLOCKED_SERVICE_PRECONDITION"
}
if (@($LegacyMigrationPaths | Where-Object {
  -not (Test-T00PathAbsent $_)
}).Count -ne 0) {
  throw "BLOCKED_CONFIG_MIGRATION_PRECONDITION"
}
if (-not (Test-T00CanonicalConfigStoreMetadata)) {
  throw "BLOCKED_CONFIG_STORE_PRECONDITION"
}
$ServiceStateAbsentBeforeStart = $true
$ClaudeAppBackupAbsentBeforeStart = $true
$LegacyMigrationSourcesAbsentBeforeStart = $true
$CanonicalConfigDbReadyBeforeStart = $true
$A0AllProcessEnvFingerprint = Get-T00AllProcessEnvFingerprint

$A0PassCapsule = (
  "A0|RESULT=PASS|CANDIDATE=Y|CLEAN=Y|PRODUCT=Y|" +
  "TOOLCHAIN=P|TYPECHECK=P|BUILD=P|CLI=Y|SERVICE_STATE=ABSENT|" +
  "MIGRATION=ABSENT|CONFIGSTORE_META=P|PLATFORM=WIN_X64|" +
  "NODE=$NodeVersion|NPM=$NpmVersion|RAW=NO"
)
$A0PassCapsule
} catch {
  $AllowedA0Categories = @(
    "BLOCKED_CANDIDATE_CONTRACT",
    "BLOCKED_REPOSITORY_ROOT",
    "BLOCKED_GIT_FETCH",
    "BLOCKED_DIRTY_WORKTREE",
    "BLOCKED_INSTRUCTION_LOAD",
    "BLOCKED_CANDIDATE_CHECKOUT",
    "BLOCKED_CANDIDATE_IDENTITY",
    "BLOCKED_PRODUCT_TREE_MISMATCH",
    "BLOCKED_RUNTIME_ENV",
    "BLOCKED_WINDOWS_RUNTIME",
    "BLOCKED_SERVICE_PRECONDITION",
    "BLOCKED_CONFIG_MIGRATION_PRECONDITION",
    "BLOCKED_CONFIG_STORE_PRECONDITION",
    "BLOCKED_EXACT_TREE_ARCHIVE",
    "BLOCKED_EXECUTION_TREE",
    "BLOCKED_NPM_CONFIGURATION",
    "BLOCKED_DEPENDENCY_INSTALL",
    "BLOCKED_TYPECHECK",
    "BLOCKED_BUILD_ASSETS",
    "BLOCKED_BUILD_TREE_MUTATION"
  )
  $A0FailureMessage = [string]$_.Exception.Message
  $A0ToolchainFailurePattern = (
    '^BLOCKED_TOOLCHAIN_IDENTITY\|' +
    'PHASE=(?<PHASE>BIND|PRE_FIRST_NODE|BUILD_ENTRY|POST_INSTALL|PRE_BUILD|POST_BUILD)\|' +
    'TOOL=(?<TOOL>GIT|NODE|NPM)\|' +
    'REASON=(?<REASON>UNRESOLVED|MULTI|NO_PATH|UNREADABLE|NOT_FILE|REPARSE|HASH_UNREADABLE|INVALID_BOUND|HASH_MISMATCH)$'
  )
  $A0AllowedToolchainContexts = @{
    "BIND" = @("GIT", "NODE", "NPM")
    "PRE_FIRST_NODE" = @("GIT", "NODE", "NPM")
    "BUILD_ENTRY" = @("NODE", "NPM")
    "POST_INSTALL" = @("NODE")
    "PRE_BUILD" = @("NODE")
    "POST_BUILD" = @("GIT", "NODE", "NPM")
  }
  $A0ToolchainFailureMatched = $A0FailureMessage -cmatch $A0ToolchainFailurePattern
  if ($A0ToolchainFailureMatched) {
    $A0FailurePhase = [string]$Matches["PHASE"]
    $A0FailureTool = [string]$Matches["TOOL"]
    $A0FailureReason = [string]$Matches["REASON"]
  }
  $A0ToolchainContextAllowed = (
    $A0ToolchainFailureMatched -and
    $A0AllowedToolchainContexts.ContainsKey($A0FailurePhase) -and
    $A0AllowedToolchainContexts[$A0FailurePhase] -ccontains $A0FailureTool
  )
  if ($A0ToolchainContextAllowed) {
    (
      "A0|RESULT=BLOCKED|CATEGORY=BLOCKED_TOOLCHAIN_IDENTITY|" +
      "PHASE=$A0FailurePhase|TOOL=$A0FailureTool|" +
      "REASON=$A0FailureReason|RAW=NO"
    )
  } else {
    $A0FailureCategory = if ($AllowedA0Categories -ccontains $A0FailureMessage) {
      $A0FailureMessage
    } else {
      "BLOCKED_A0_PREFLIGHT"
    }
    "A0|RESULT=BLOCKED|CATEGORY=$A0FailureCategory|RAW=NO"
  }
}
}
$T00A0Outcome
```

`BLOCKED_TOOLCHAIN_IDENTITY`이면 A0은 원문 오류, executable 경로 또는 hash를
출력하지 않고 다음 고정 allowlist만 추가한다.

```text
PHASE = BIND | PRE_FIRST_NODE | BUILD_ENTRY | POST_INSTALL | PRE_BUILD | POST_BUILD
TOOL = GIT | NODE | NPM
REASON = UNRESOLVED | MULTI | NO_PATH | UNREADABLE | NOT_FILE | REPARSE |
         HASH_UNREADABLE | INVALID_BOUND | HASH_MISMATCH
```

명령 binding은 PowerShell default precedence가 아니라 `Application` command type만
대상으로 한다. 따라서 같은 이름의 script가 먼저 보이는지 추측하거나 경로를
외부로 옮길 필요가 없다. 위 구조화 capsule이 없는 이전 Attempt의 정확한
실패 지점은 사후 추정하지 않는다.

진행 조건:

```text
candidate/instruction exact match
working tree clean before and after build
RuntimeEnvSafe = True
TypecheckExit = 0
BuildAssetsExit = 0
process.platform = win32
CLI exists = True
CCR service state absent (process absence is confirmed separately at H0)
ServiceStateAbsentBeforeStart = True
ClaudeAppBackupAbsentBeforeStart = True
LegacyMigrationSourcesAbsentBeforeStart = True
CanonicalConfigDbReadyBeforeStart = True
ProductTreeEquivalenceExit = 0
```

service state, Claude App backup, legacy migration source가 있거나 canonical SQLite store가 준비되지 않았으면 build/Node를 실행하거나 다른 사용자의 CCR를 종료하지 않고 고정 `BLOCKED_*` capsule로 중단한다.
별도 Human recovery에서 소유권을 확인한 뒤에만 Task에 기록된 stock `stop`을 사용할 수 있다.

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
4. CCR Desktop/tray, management UI/browser tab, CCR CLI/service와 다른 config writer를 모두 종료한다. State-less orphan 가능성 때문에 A0의 service-state absence만으로 process quiescence를 대신하지 않는다.
5. 백업을 Git/repository/shared folder에 두지 않는다.

Internal Validator에 반환:

```text
Enterprise CLI baseline: PASS / FAIL
Enterprise model baseline: PASS / FAIL
Claude Desktop baseline: PASS / FAIL
Local recovery backup: CREATED / NOT_CREATED
Claude clients closed: YES / NO
All CCR management/Desktop/UI/config writers closed: YES / NO
```

하나라도 FAIL이거나 Claude client/CCR writer가 종료되지 않으면 `ENTERPRISE_BASELINE_FAILURE`로 중단한다.

## A1 — [INTERNAL_VALIDATOR] Capture baseline after smoke and shutdown

```powershell
$T00A1Outcome = . {
$ErrorActionPreference = "Stop"
try {
$A1AllProcessEnvFingerprint = Get-T00AllProcessEnvFingerprint
if ($A1AllProcessEnvFingerprint -cne $A0AllProcessEnvFingerprint) {
  throw "BLOCKED_BASELINE_CAPTURE"
}
$A1RepositoryCwd = [IO.Path]::GetFullPath((Get-Location).Path).TrimEnd('\', '/')
$A1AppDataPath = [IO.Path]::GetFullPath($env:APPDATA).TrimEnd('\', '/')
$A1LocalAppDataPath = [IO.Path]::GetFullPath($env:LOCALAPPDATA).TrimEnd('\', '/')
$A1UserProfilePath = [IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\', '/')
$A1SystemRootPath = [IO.Path]::GetFullPath($env:SystemRoot).TrimEnd('\', '/')
$A1ComSpecPath = [IO.Path]::GetFullPath($env:ComSpec)
if ($A1RepositoryCwd -ine $RepositoryRoot -or
    $A1AppDataPath -ine $A0AppDataPath -or
    $A1LocalAppDataPath -ine $A0LocalAppDataPath -or
    $A1UserProfilePath -ine $A0UserProfilePath -or
    $A1SystemRootPath -ine $A0SystemRootPath -or
    $A1ComSpecPath -ine $A0ComSpecPath) {
  throw "BLOCKED_BASELINE_CAPTURE"
}
$EnterpriseSettings = Join-Path $env:USERPROFILE ".claude\settings.json"
$RealClaude3p = Join-Path $env:LOCALAPPDATA "Claude-3p"
$AttemptNonce = [Guid]::NewGuid().ToString("N")
$CompanyCcrRoot = Join-Path $env:APPDATA "CompanyCCR"
$RuntimeSandboxRoot = Join-Path $CompanyCcrRoot "runtime-localappdata"
$SandboxLocalAppData = Join-Path $RuntimeSandboxRoot $AttemptNonce
if (-not (Test-T00PathAbsent $SandboxLocalAppData)) {
  throw "BLOCKED_BASELINE_CAPTURE"
}
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

function Get-T00LeafCount($Targets) {
  $Count = 0
  foreach ($Target in $Targets) {
    $Exists = Test-Path -LiteralPath $Target.Path -ErrorAction Stop
    if ($Exists) {
      $Item = Get-Item -LiteralPath $Target.Path -Force -ErrorAction Stop
      if (($Item -isnot [IO.FileInfo]) -or
          (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
        throw "UNSAFE_SANDBOX_TARGET"
      }
      $Count += 1
    }
  }
  return $Count
}

$RealClaude3pTargets = New-Claude3pTargets $RealClaude3p
$SandboxClaude3pTargets = New-Claude3pTargets $SandboxClaude3p
$SandboxClaude3pTargetCountBefore = Get-T00LeafCount $SandboxClaude3pTargets

if ($SandboxClaude3pTargetCountBefore -ne 0) {
  throw "BLOCKED_BASELINE_CAPTURE"
}

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
  "USERPROFILE",
  "PATH",
  "PATHEXT",
  "ComSpec",
  "SystemRoot",
  "TEMP",
  "TMP"
) + $ManagedEnvKeys + $ForbiddenRuntimeEnvKeys

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
  $Exists = Test-Path -LiteralPath $Path -ErrorAction Stop
  if (-not $Exists) {
    return "ABSENT"
  }
  $Item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
  if (($Item -isnot [IO.FileInfo]) -or
      (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
    throw "BLOCKED_BASELINE_CAPTURE"
  }
  return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path -ErrorAction Stop).Hash
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
  $WhereRows = @(& $WhereExe claude 2>$null)
  $WhereExit = $LASTEXITCODE
  $Commands = @(Get-Command claude -All -ErrorAction Stop)
  if ($WhereExit -ne 0 -or $WhereRows.Count -eq 0 -or $Commands.Count -eq 0) {
    throw "BLOCKED_BASELINE_CAPTURE"
  }
  $Rows = @(
    $WhereRows
    ($Commands | ForEach-Object { "$($_.CommandType)|$($_.Source)|$($_.Path)" })
  )
  return Get-StringFingerprint ($Rows -join "`n")
}

$Baseline = [PSCustomObject]@{
  EnterpriseSettings = Get-FileFingerprint $EnterpriseSettings
  RealClaude3pConfig = Get-PathSetFingerprint $RealClaude3pTargets
  AllProcessEnv = $A1AllProcessEnvFingerprint
  ProcessEnv = Get-EnvFingerprint "Process" $ProcessBoundaryKeys
  UserEnv = Get-EnvFingerprint "User" $ManagedEnvKeys
  MachineEnv = Get-EnvFingerprint "Machine" $ManagedEnvKeys
  ClaudeResolution = Get-ClaudeResolutionFingerprint
}
$A1AllProcessEnvFingerprint = Get-T00AllProcessEnvFingerprint
"A1|RESULT=PASS|BASELINE=P|RAW=NO"
} catch {
  "A1|RESULT=BLOCKED|CATEGORY=BLOCKED_BASELINE_CAPTURE|RAW=NO"
}
}
$T00A1Outcome
```

Fingerprint 원문과 hash는 외부로 출력하지 않는다.
잠긴 파일 등으로 수집이 실패하면 `BLOCKED_BASELINE_CAPTURE`로 중단한다.

## A2–A3 — [INTERNAL_VALIDATOR] Guarded start, wrapper save, and unconditional cleanup

User/Machine 환경변수를 변경하지 않는다.
현재 PowerShell process에서 daemon spawn 동안만 `LOCALAPPDATA`를 바꾼다.

아래 블록은 **한 번에 전체 실행**한다. 중간에 `throw`, `exit`, retry 또는 다른 명령을 넣지 않는다.
Helper의 PASS/BLOCKED/FAIL/SAVE=UNKNOWN 여부와 관계없이 `finally`가 A3 fingerprint, stock stop, captured-PID 종료 확인과 post-cleanup을 수행한다.

```powershell
$T00A2A3Outcome = . {
$ErrorActionPreference = "Stop"
try {
function Get-CurrentInvariantState {
  [PSCustomObject]@{
    EnterpriseSettings = Get-FileFingerprint $EnterpriseSettings
    RealClaude3pConfig = Get-PathSetFingerprint $RealClaude3pTargets
    AllProcessEnv = Get-T00AllProcessEnvFingerprint
    ProcessEnv = Get-EnvFingerprint "Process" $ProcessBoundaryKeys
    UserEnv = Get-EnvFingerprint "User" $ManagedEnvKeys
    MachineEnv = Get-EnvFingerprint "Machine" $ManagedEnvKeys
    ClaudeResolution = Get-ClaudeResolutionFingerprint
  }
}

function Read-T00BoundedRegularFile([string]$Path, [long]$MaxBytes) {
  $Item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
  if (($Item -isnot [IO.FileInfo]) -or
      (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) -or
      $Item.Length -le 0 -or
      $Item.Length -gt $MaxBytes) {
    throw "BLOCKED_SERVICE_STATE"
  }
  $Raw = [IO.File]::ReadAllText($Item.FullName, [Text.Encoding]::UTF8)
  if ([Text.Encoding]::UTF8.GetByteCount($Raw) -gt $MaxBytes) {
    throw "BLOCKED_SERVICE_STATE"
  }
  return $Raw
}

function Test-T00ServiceStateBound([string]$Path, [string]$ExpectedFingerprint) {
  try {
    $Raw = Read-T00BoundedRegularFile $Path 65536
    $ActualFingerprint = Get-StringFingerprint $Raw
    $Raw = $null
    return $ActualFingerprint -ceq $ExpectedFingerprint
  } catch {
    return $false
  }
}

function Test-T00ProcessDead([int]$Id) {
  $Process = $null
  try {
    $Process = [Diagnostics.Process]::GetProcessById($Id)
    return $Process.HasExited
  } catch [ArgumentException] {
    return $true
  } catch {
    return $false
  } finally {
    if ($null -ne $Process) {
      $Process.Dispose()
    }
  }
}

function Get-T00ValidatedFreshServiceState(
  [string]$Path,
  [DateTimeOffset]$NotBeforeUtc,
  [Nullable[int]]$ReportedPid
) {
  $StateRaw = $null
  $ParsedState = $null
  $ManagementUri = $null
  try {
    $StateRaw = Read-T00BoundedRegularFile $Path 65536
    $ParsedState = $StateRaw | ConvertFrom-Json -ErrorAction Stop
    $ActualKeys = @($ParsedState.PSObject.Properties.Name)
    $RequiredKeys = @(
      "host",
      "pid",
      "profileManaged",
      "serviceToken",
      "startedAt",
      "startGateway",
      "url"
    )
    if (@($RequiredKeys | Where-Object { $ActualKeys -cnotcontains $_ }).Count -ne 0 -or
        @($ActualKeys | Where-Object { $RequiredKeys -cnotcontains $_ }).Count -ne 0) {
      throw "BLOCKED_SERVICE_STATE"
    }

    $ParsedPid = 0
    if (-not [int]::TryParse([string]$ParsedState.pid, [ref]$ParsedPid) -or
        $ParsedPid -le 0 -or
        ($null -ne $ReportedPid -and $ParsedPid -ne $ReportedPid.Value) -or
        ($ParsedState.profileManaged -isnot [bool]) -or
        $ParsedState.profileManaged -ne $false -or
        ($ParsedState.startGateway -isnot [bool]) -or
        $ParsedState.startGateway -ne $false -or
        ($ParsedState.serviceToken -isnot [string]) -or
        $ParsedState.serviceToken -cnotmatch '^[A-Za-z0-9_-]{43}$' -or
        ($ParsedState.startedAt -isnot [string]) -or
        ($ParsedState.url -isnot [string]) -or
        ($ParsedState.host -isnot [string]) -or
        $ParsedState.host -cne "127.0.0.1") {
      throw "BLOCKED_SERVICE_STATE"
    }

    $StateStartedAt = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParse(
      [string]$ParsedState.startedAt,
      [Globalization.CultureInfo]::InvariantCulture,
      [Globalization.DateTimeStyles]::RoundtripKind,
      [ref]$StateStartedAt
    ) -or
        $StateStartedAt -lt $NotBeforeUtc -or
        $StateStartedAt -gt [DateTimeOffset]::UtcNow.AddSeconds(5)) {
      throw "BLOCKED_SERVICE_STATE"
    }

    $ManagementUri = [Uri]$ParsedState.url
    if ($ManagementUri.Scheme -cne "http" -or
        $ManagementUri.Host -cne "127.0.0.1" -or
        $ManagementUri.Port -le 0 -or
        $ManagementUri.Port -gt 65535 -or
        $ManagementUri.AbsolutePath -cne "/" -or
        $ManagementUri.Query -cnotmatch '^\?ccr_web_token=[A-Za-z0-9_-]{43}$' -or
        -not [string]::IsNullOrEmpty($ManagementUri.Fragment) -or
        -not [string]::IsNullOrEmpty($ManagementUri.UserInfo) -or
        (Test-T00ProcessDead $ParsedPid)) {
      throw "BLOCKED_SERVICE_STATE"
    }

    return [PSCustomObject]@{
      Fingerprint = Get-StringFingerprint $StateRaw
      Pid = $ParsedPid
      StartedAt = $StateStartedAt
    }
  } finally {
    $StateRaw = $null
    $ParsedState = $null
    $ManagementUri = $null
  }
}

$StartExit = $null
$PreflightExit = $null
$ApplyExit = $null
$PreflightCapsuleExport = "T02|RESULT=BLOCKED|CATEGORY=NOT_RUN|SAVE=N|RAW=NO"
$ApplyCapsuleExport = "T02|RESULT=BLOCKED|CATEGORY=NOT_RUN|SAVE=N|RAW=NO"
$HelperDisposition = "NOT_RUN"
$SaveDisposition = "N"
$ApplyAttempted = $false
$StartInvoked = $false
$StartReportedFresh = $false
$StartReportedReuse = $false
$FreshServiceOwnershipProven = $false
$ForeignOrUnownedServiceDetected = $false
$StartedServicePid = $null
$CapturedServiceStateFingerprint = $null
$StateCaptureSucceeded = $false
$ServiceStateCreated = $false
$ServiceStateBoundForStop = $false
$ServiceStateBoundImmediatelyBeforeStop = $false
$RuntimeReady = $false
$ParentLocalAppDataRestored = $false
$ParentProcessEnvRestored = $false
$SandboxClaude3pTargetCountBeforeSave = -1
$ClaudeAppBackupAbsentBeforeSave = $false
$StopAttempted = $false
$StopExit = $null
$StartedServicePidDead = $false
$A3Attempted = $false
$A3Completed = $false
$DuringCaptureSucceeded = $false
$AfterCaptureSucceeded = $false
$SettingsDuringSame = $false
$Claude3pDuringSame = $false
$AllProcessEnvDuringSame = $false
$ProcessEnvDuringSame = $false
$UserEnvDuringSame = $false
$MachineEnvDuringSame = $false
$ClaudeResolutionDuringSame = $false
$SettingsAfterSame = $false
$Claude3pAfterSame = $false
$AllProcessEnvAfterSame = $false
$ProcessEnvAfterSame = $false
$UserEnvAfterSame = $false
$MachineEnvAfterSame = $false
$ClaudeResolutionAfterSame = $false
$SandboxClaude3pTargetCount = -1
$SandboxClaude3pTargetCountAfterStop = -1
$ClaudeAppBackupExistsDuring = $false
$ClaudeAppBackupAbsentAfterStop = $false
$ServiceStateAbsentAfterStop = $false
$ProductDiffExit = $null
$FinalHeadExit = $null
$FinalHeadSame = $false
$FinalStatusExit = $null
$FinalStatusClean = $false
$BuildTreeAfterSame = $false
$ExactTreeAfterSame = $false
$ToolchainIdentityAtPrelaunch = $false
$NodeIdentityAtStop = $false
$RuntimeTreeIdentityAtStop = $false
$GitIdentityAtFinal = $false
$ExecutionLocationPushed = $false
$ExecutionLocationRestored = $false
$A3CleanupComplete = $false
$AfterInvariantSafeForH2 = $false
$SafeForH2 = $false

$RegexOptions = [Text.RegularExpressions.RegexOptions]::CultureInvariant
$PreflightChangePattern = '^T02\|RESULT=PASS\|SERVICE=P\|GW_PRE=STOP\|RPC=P\|APPLY=N\|CHANGE=Y\|TARGET_GLOBAL=0\|TARGET_LOGS=OFF\|TARGET_ANALYSIS=OFF\|TARGET_BODY=NONE\|AUTOFETCH=OFF\|RAW=NO$'
$PreflightNoChangePattern = '^T02\|RESULT=PASS\|SERVICE=P\|GW_PRE=STOP\|RPC=P\|APPLY=N\|CHANGE=N\|TARGET_GLOBAL=0\|TARGET_LOGS=OFF\|TARGET_ANALYSIS=OFF\|TARGET_BODY=NONE\|AUTOFETCH=OFF\|RAW=NO$'
$ApplyPassPattern = '^T02\|RESULT=PASS\|SERVICE=P\|GW_PRE=STOP\|GW_POST=STOP\|RPC=P\|APPLY=P\|CHANGE=Y\|GLOBAL=0\|LOGS=OFF\|ANALYSIS=OFF\|BODY=NONE\|PROVIDER=SAME\|ONBOARDING=SAME\|AUTOFETCH=OFF\|RAW=NO$'
$ApplySkipPattern = '^T02\|RESULT=PASS\|SERVICE=P\|GW_PRE=STOP\|RPC=P\|APPLY=SKIP\|CHANGE=N\|GLOBAL=0\|LOGS=OFF\|ANALYSIS=OFF\|BODY=NONE\|PROVIDER=SAME\|ONBOARDING=SAME\|AUTOFETCH=OFF\|RAW=NO$'
$BlockedPattern = '^T02\|RESULT=BLOCKED\|CATEGORY=(BLOCKED_RUNTIME_ENV|BLOCKED_SERVICE_STATE|BLOCKED_SERVICE_IDENTITY|BLOCKED_APP_IDENTITY|BLOCKED_GATEWAY_STATE|BLOCKED_NON_LOOPBACK|BLOCKED_AUTH|BLOCKED_STALE_BACKUP|BLOCKED_RUNTIME_SURFACE|BLOCKED_PORT_IN_USE|BLOCKED_PROVIDER_AUTO_REFRESH|BLOCKED_CONFIG_SHAPE|BLOCKED_CONCURRENT_CHANGE|UNEXPECTED_CONFIG_DIFF|RPC_FAILURE)\|SAVE=N\|RAW=NO$'
$IndeterminatePattern = '^T02\|RESULT=FAIL\|CATEGORY=INDETERMINATE_SAVE\|SAVE=UNKNOWN\|RAW=NO$'
$PostFailurePattern = '^T02\|RESULT=FAIL\|CATEGORY=POSTCONDITION_FAILURE\|SAVE=Y\|RAW=NO$'

$ToolchainIdentityAtPrelaunch =
  (Test-T00BoundCommand $GitTool) -and
  (Test-T00BoundCommand $NodeTool) -and
  (Test-T00BoundCommand $NpmTool)
if (-not $ToolchainIdentityAtPrelaunch) {
  throw "BLOCKED_TOOLCHAIN_IDENTITY"
}

$PrelaunchRepositoryCwd = [IO.Path]::GetFullPath((Get-Location).Path).TrimEnd('\', '/')
$PrelaunchAppDataPath = [IO.Path]::GetFullPath($env:APPDATA).TrimEnd('\', '/')
$PrelaunchLocalAppDataPath = [IO.Path]::GetFullPath($env:LOCALAPPDATA).TrimEnd('\', '/')
$PrelaunchUserProfilePath = [IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\', '/')
$PrelaunchSystemRootPath = [IO.Path]::GetFullPath($env:SystemRoot).TrimEnd('\', '/')
$PrelaunchComSpecPath = [IO.Path]::GetFullPath($env:ComSpec)
if ($PrelaunchRepositoryCwd -ine $RepositoryRoot -or
    $PrelaunchAppDataPath -ine $A0AppDataPath -or
    $PrelaunchLocalAppDataPath -ine $A0LocalAppDataPath -or
    $PrelaunchUserProfilePath -ine $A0UserProfilePath -or
    $PrelaunchSystemRootPath -ine $A0SystemRootPath -or
    $PrelaunchComSpecPath -ine $A0ComSpecPath) {
  throw "BLOCKED_PRELAUNCH_ENV"
}

$PrelaunchProcessEnv = Get-EnvFingerprint "Process" $ProcessBoundaryKeys
if ($PrelaunchProcessEnv -cne $Baseline.ProcessEnv -or
    (Get-T00AllProcessEnvFingerprint) -cne $A1AllProcessEnvFingerprint) {
  throw "BLOCKED_PRELAUNCH_ENV"
}
$PrelaunchProcessEnv = $null

$PrelaunchHeadRaw = @(& $GitExe -C $RepositoryRoot rev-parse HEAD 2>&1)
$PrelaunchHeadExit = $LASTEXITCODE
$PrelaunchHead = if ($PrelaunchHeadRaw.Count -eq 1) {
  ([string]$PrelaunchHeadRaw[0]).Trim()
} else {
  ""
}
$PrelaunchHeadRaw = $null
$PrelaunchStatusRaw = @(& $GitExe -C $RepositoryRoot status --porcelain=v1 --untracked-files=all 2>&1)
$PrelaunchStatusExit = $LASTEXITCODE
$PrelaunchStatusClean =
  $PrelaunchStatusExit -eq 0 -and
  $PrelaunchStatusRaw.Count -eq 0
$PrelaunchStatusRaw = $null
$PrelaunchProductDiffRaw = @(
  & $GitExe -C $RepositoryRoot diff --exit-code $ValidatedProductCommit HEAD -- packages build package.json package-lock.json 2>&1
)
$PrelaunchProductDiffExit = $LASTEXITCODE
$PrelaunchProductDiffRaw = $null
if ($PrelaunchHeadExit -ne 0 -or
    $PrelaunchHead -cne $ApprovedCandidateSha -or
    -not $PrelaunchStatusClean -or
    $PrelaunchProductDiffExit -ne 0) {
  throw "BLOCKED_PRELAUNCH_TREE"
}

Assert-T00ExecutionTreeRegular $ExecutionRoot
$PrelaunchExactTreePaths = @(Get-T00ExactSourcePaths)
$PrelaunchExactTreeFingerprint = Get-T00FileSetFingerprint $PrelaunchExactTreePaths
if ($PrelaunchExactTreeFingerprint -cne $ExactTreeFingerprint) {
  throw "BLOCKED_PRELAUNCH_TREE"
}
$PrelaunchExactTreeFingerprint = $null
$PrelaunchExactTreePaths = $null

$ForbiddenRuntimeEnvPresentAtA2 = @(
  $ForbiddenRuntimeEnvKeys | Where-Object {
    $RawValue = [Environment]::GetEnvironmentVariable(
      $_,
      [EnvironmentVariableTarget]::Process
    )
    $null -ne $RawValue -and $RawValue.Length -gt 0
  }
)
$RuntimeEnvSafeAtA2 = $ForbiddenRuntimeEnvPresentAtA2.Count -eq 0
$ForbiddenRuntimeEnvPresentAtA2 = $null
if (-not $RuntimeEnvSafeAtA2) {
  throw "BLOCKED_RUNTIME_ENV"
}

$PrelaunchBuildTreeFingerprint = Get-T00BuildTreeFingerprint
if ($PrelaunchBuildTreeFingerprint -cne $BuildTreeFingerprint) {
  throw "BLOCKED_PRELAUNCH_BUILD_TREE"
}
$PrelaunchBuildTreeFingerprint = $null

if (-not (Test-T00PathAbsent $ServiceStateFile) -or
    -not (Test-T00PathAbsent $ClaudeAppBackupFile) -or
    -not (Test-T00PathAbsent $SandboxLocalAppData)) {
  throw "BLOCKED_FRESH_SERVICE_STATE"
}
if (@($LegacyMigrationPaths | Where-Object {
  -not (Test-T00PathAbsent $_)
}).Count -ne 0) {
  throw "BLOCKED_CONFIG_MIGRATION_PRECONDITION"
}
if (-not (Test-T00CanonicalConfigStoreMetadata)) {
  throw "BLOCKED_CONFIG_STORE_PRECONDITION"
}

Initialize-T00SafeDirectory $CompanyCcrRoot
Initialize-T00SafeDirectory $RuntimeSandboxRoot
if (-not (Test-T00PathAbsent $SandboxLocalAppData)) {
  throw "UNSAFE_SANDBOX_PATH"
}
$CreatedSandbox = New-Item -ItemType Directory -Path $SandboxLocalAppData -ErrorAction Stop
$CreatedSandbox = $null
Assert-T00SafeDirectory $CompanyCcrRoot
Assert-T00SafeDirectory $RuntimeSandboxRoot
Assert-T00SafeDirectory $SandboxLocalAppData

if (-not (Test-T00PathAbsent $ServiceStateFile) -or
    -not (Test-T00PathAbsent $ClaudeAppBackupFile) -or
    @($LegacyMigrationPaths | Where-Object {
      -not (Test-T00PathAbsent $_)
    }).Count -ne 0 -or
    -not (Test-T00CanonicalConfigStoreMetadata)) {
  throw "BLOCKED_FRESH_SERVICE_STATE"
}

$OriginalLocalAppData = $env:LOCALAPPDATA

try {
  Push-Location $ExecutionRoot
  $ExecutionLocationPushed = $true

  # A2 — start exactly one fresh sandboxed service.
  $StartBeganUtc = [DateTimeOffset]::UtcNow
  $ReportedStartPid = [Nullable[int]]$null
  if (-not (Test-T00BoundCommand $NodeTool)) {
    throw "BLOCKED_TOOLCHAIN_IDENTITY"
  }
  try {
    $env:LOCALAPPDATA = $SandboxLocalAppData
    $StartInvoked = $true
    $StartRaw = @(& $NodeExe $Cli start --host 127.0.0.1 --no-open --no-gateway 2>&1)
    $StartExit = $LASTEXITCODE
  } catch {
    $StartExit = $null
  } finally {
    try {
      if ($StartRaw.Count -eq 1) {
        $StartLine = [string]$StartRaw[0]
        $FreshMatch = [regex]::Match(
          $StartLine,
          '^CCR service started at http://127\.0\.0\.1:[1-9][0-9]{0,4}/\?ccr_web_token=[A-Za-z0-9_-]{43} \(pid ([1-9][0-9]*)\)\.$',
          $RegexOptions
        )
        $ReuseMatch = [regex]::Match(
          $StartLine,
          '^CCR service is already running at http://127\.0\.0\.1:[1-9][0-9]{0,4}/\?ccr_web_token=[A-Za-z0-9_-]{43} \(pid ([1-9][0-9]*)\)\.$',
          $RegexOptions
        )
        $StartReportedFresh = $StartExit -eq 0 -and $FreshMatch.Success
        $StartReportedReuse = $StartExit -eq 0 -and $ReuseMatch.Success
        if ($StartReportedFresh) {
          $ParsedReportedPid = 0
          if ([int]::TryParse($FreshMatch.Groups[1].Value, [ref]$ParsedReportedPid) -and
              $ParsedReportedPid -gt 0) {
            $ReportedStartPid = [Nullable[int]]$ParsedReportedPid
          } else {
            $StartReportedFresh = $false
          }
        }
      }
    } catch {
      $StartReportedFresh = $false
      $StartReportedReuse = $false
      $ReportedStartPid = [Nullable[int]]$null
    }
    try {
      $env:LOCALAPPDATA = $OriginalLocalAppData
    } catch {
      $ParentLocalAppDataRestored = $false
    }
    $StartLine = $null
    $FreshMatch = $null
    $ReuseMatch = $null
    $StartRaw = $null
  }

  $ParentLocalAppDataRestored = $env:LOCALAPPDATA -eq $OriginalLocalAppData
$ParentProcessEnvAfterStart = Get-EnvFingerprint "Process" $ProcessBoundaryKeys
$ParentProcessEnvRestored = $Baseline.ProcessEnv -eq $ParentProcessEnvAfterStart
$ParentAllProcessEnvRestored =
  (Get-T00AllProcessEnvFingerprint) -ceq $A1AllProcessEnvFingerprint

  $StatePollDeadline = [DateTimeOffset]::UtcNow.AddSeconds(10)
  do {
    try {
      $ServiceStateCreated = Test-Path -LiteralPath $ServiceStateFile -PathType Leaf -ErrorAction Stop
    } catch {
      $ServiceStateCreated = $false
    }

    if ($ServiceStateCreated) {
      if ($StartReportedReuse) {
        $ForeignOrUnownedServiceDetected = $true
        break
      }
      try {
        $ExpectedReportedPid = if ($StartReportedFresh) {
          $ReportedStartPid
        } else {
          [Nullable[int]]$null
        }
        $ValidatedState = Get-T00ValidatedFreshServiceState `
          $ServiceStateFile `
          $StartBeganUtc `
          $ExpectedReportedPid
        $StartedServicePid = $ValidatedState.Pid
        $CapturedServiceStateFingerprint = $ValidatedState.Fingerprint
        $StateCaptureSucceeded = $true
        $FreshServiceOwnershipProven = $StartReportedFresh
      } catch {
        $StartedServicePid = $null
        $CapturedServiceStateFingerprint = $null
        $StateCaptureSucceeded = $false
        $FreshServiceOwnershipProven = $false
      } finally {
        $ValidatedState = $null
        $ExpectedReportedPid = $null
      }
      if ($StateCaptureSucceeded) {
        break
      }
    }

    if ([DateTimeOffset]::UtcNow -lt $StatePollDeadline) {
      Start-Sleep -Milliseconds 250
    }
  } while ([DateTimeOffset]::UtcNow -lt $StatePollDeadline)

  if ($ServiceStateCreated -and -not $FreshServiceOwnershipProven) {
    $ForeignOrUnownedServiceDetected = $true
  }

  try {
    $SandboxClaude3pTargetCountBeforeSave = Get-T00LeafCount $SandboxClaude3pTargets
    $ClaudeAppBackupAbsentBeforeSave = Test-T00PathAbsent $ClaudeAppBackupFile
  } catch {
    $SandboxClaude3pTargetCountBeforeSave = -1
    $ClaudeAppBackupAbsentBeforeSave = $false
  }

  $RuntimeReady =
    $StartExit -eq 0 -and
    $StartReportedFresh -and
    $FreshServiceOwnershipProven -and
    -not $ForeignOrUnownedServiceDetected -and
    ([IO.Path]::GetFullPath((Get-Location).Path).TrimEnd('\', '/') -ieq $ExecutionRoot) -and
    $ParentLocalAppDataRestored -and
    $ParentProcessEnvRestored -and
    $ParentAllProcessEnvRestored -and
    $ServiceStateCreated -and
    $StateCaptureSucceeded -and
    $null -ne $StartedServicePid -and
    $SandboxClaude3pTargetCountBeforeSave -eq 0 -and
    $ClaudeAppBackupAbsentBeforeSave

  if ($RuntimeReady) {
    # A2b — no-save preflight. Apply only after a strict fixed PASS capsule.
    if (-not (Test-T00BoundCommand $NodeTool)) {
      throw "BLOCKED_TOOLCHAIN_IDENTITY"
    }
    try {
      $PreflightRaw = @(& $NodeExe $HelperScript 2>&1)
      $PreflightExit = $LASTEXITCODE
      $PreflightCapsule = if ($PreflightRaw.Count -eq 1) {
        [string]$PreflightRaw[0]
      } else {
        ""
      }
    } catch {
      $PreflightCapsule = ""
    } finally {
      $PreflightRaw = $null
    }

    $PreflightChangeAccepted =
      $PreflightExit -eq 0 -and
      [regex]::IsMatch(
        $PreflightCapsule,
        $PreflightChangePattern,
        $RegexOptions
      )
    $PreflightNoChange =
      $PreflightExit -eq 0 -and
      [regex]::IsMatch(
        $PreflightCapsule,
        $PreflightNoChangePattern,
        $RegexOptions
      )
    $PreflightBlocked =
      $PreflightExit -eq 2 -and
      [regex]::IsMatch(
        $PreflightCapsule,
        $BlockedPattern,
        $RegexOptions
      )

    if ($PreflightChangeAccepted -or $PreflightNoChange -or $PreflightBlocked) {
      $PreflightCapsuleExport = $PreflightCapsule
    }
    $PreflightCapsule = $null

    if ($PreflightChangeAccepted) {
      $ApplyAttempted = $true
      $HelperDisposition = "APPLY_IN_FLIGHT"
      $SaveDisposition = "UNKNOWN"
      if (-not (Test-T00BoundCommand $NodeTool)) {
        throw "BLOCKED_TOOLCHAIN_IDENTITY"
      }
      try {
        $ApplyRaw = @(& $NodeExe $HelperScript --apply 2>&1)
        $ApplyExit = $LASTEXITCODE
        $ApplyCapsule = if ($ApplyRaw.Count -eq 1) {
          [string]$ApplyRaw[0]
        } else {
          ""
        }
      } catch {
        $ApplyCapsule = ""
      } finally {
        $ApplyRaw = $null
      }

      $ApplyPass =
        $ApplyExit -eq 0 -and
        [regex]::IsMatch($ApplyCapsule, $ApplyPassPattern, $RegexOptions)
      $ApplySkip =
        $ApplyExit -eq 0 -and
        [regex]::IsMatch($ApplyCapsule, $ApplySkipPattern, $RegexOptions)
      $ApplyBlocked =
        $ApplyExit -eq 2 -and
        [regex]::IsMatch($ApplyCapsule, $BlockedPattern, $RegexOptions)
      $ApplyIndeterminate =
        $ApplyExit -eq 3 -and
        [regex]::IsMatch($ApplyCapsule, $IndeterminatePattern, $RegexOptions)
      $ApplyPostFailure =
        $ApplyExit -eq 3 -and
        [regex]::IsMatch($ApplyCapsule, $PostFailurePattern, $RegexOptions)

      if ($ApplyPass -or $ApplySkip -or $ApplyBlocked -or
          $ApplyIndeterminate -or $ApplyPostFailure) {
        $ApplyCapsuleExport = $ApplyCapsule
      }
      $ApplyCapsule = $null

      if ($ApplyPass) {
        $HelperDisposition = "CONFIRMED_APPLY"
        $SaveDisposition = "Y"
      } elseif ($ApplySkip) {
        $HelperDisposition = "APPLY_SKIP"
        $SaveDisposition = "N"
      } elseif ($ApplyBlocked) {
        $HelperDisposition = "PRE_SAVE_BLOCKED"
        $SaveDisposition = "N"
      } elseif ($ApplyIndeterminate) {
        $HelperDisposition = "INDETERMINATE_SAVE"
        $SaveDisposition = "UNKNOWN"
      } elseif ($ApplyPostFailure) {
        $HelperDisposition = "POST_SAVE_FAILURE"
        $SaveDisposition = "Y"
      } else {
        $HelperDisposition = "UNEXPECTED_APPLY_OUTCOME"
        $SaveDisposition = "UNKNOWN"
      }
    } elseif ($PreflightNoChange) {
      $HelperDisposition = "PREFLIGHT_NO_CHANGE"
      $SaveDisposition = "N"
    } elseif ($PreflightBlocked) {
      $HelperDisposition = "PREFLIGHT_BLOCKED"
      $SaveDisposition = "N"
    } else {
      $HelperDisposition = "UNEXPECTED_PREFLIGHT_OUTCOME"
      $SaveDisposition = "N"
    }
  } else {
    $HelperDisposition = "RUNTIME_START_FAILURE"
    $SaveDisposition = "N"
  }
} finally {
  # A3 — this cleanup path is unconditional after any possible A2 service creation.
  $A3Attempted = $true

  try {
    $env:LOCALAPPDATA = $OriginalLocalAppData
  } catch {
    $ParentLocalAppDataRestored = $false
  }

  try {
    $SandboxClaude3pTargetCount = Get-T00LeafCount $SandboxClaude3pTargets
    $ClaudeAppBackupExistsDuring = -not (
      Test-T00PathAbsent $ClaudeAppBackupFile
    )
  } catch {
    $SandboxClaude3pTargetCount = -1
    $ClaudeAppBackupExistsDuring = $false
  }

  try {
    $During = Get-CurrentInvariantState
    $SettingsDuringSame = $Baseline.EnterpriseSettings -eq $During.EnterpriseSettings
    $Claude3pDuringSame = $Baseline.RealClaude3pConfig -eq $During.RealClaude3pConfig
    $AllProcessEnvDuringSame = $Baseline.AllProcessEnv -ceq $During.AllProcessEnv
    $ProcessEnvDuringSame = $Baseline.ProcessEnv -eq $During.ProcessEnv
    $UserEnvDuringSame = $Baseline.UserEnv -eq $During.UserEnv
    $MachineEnvDuringSame = $Baseline.MachineEnv -eq $During.MachineEnv
    $ClaudeResolutionDuringSame = $Baseline.ClaudeResolution -eq $During.ClaudeResolution
    $DuringCaptureSucceeded = $true
  } catch {
    $DuringCaptureSucceeded = $false
  }

  try {
    $ServiceStateBoundForStop =
      $StateCaptureSucceeded -and
      (Test-T00ServiceStateBound $ServiceStateFile $CapturedServiceStateFingerprint)
  } catch {
    $ServiceStateBoundForStop = $false
  }

  # Stock stop receives no PID argument. It is called only with the exact bound
  # fresh state; Stock independently verifies token/PID identity. The captured
  # PID is used only for the conservative post-stop liveness proof.
  $NodeIdentityAtStop = Test-T00BoundCommand $NodeTool
  try {
    $RuntimeTreeIdentityAtStop =
      (Get-T00BuildTreeFingerprint) -ceq $BuildTreeFingerprint
  } catch {
    $RuntimeTreeIdentityAtStop = $false
  }
  try {
    $ServiceStateBoundImmediatelyBeforeStop =
      $StateCaptureSucceeded -and
      (Test-T00ServiceStateBound $ServiceStateFile $CapturedServiceStateFingerprint)
  } catch {
    $ServiceStateBoundImmediatelyBeforeStop = $false
  }
  if ($StartInvoked -and
      $FreshServiceOwnershipProven -and
      -not $ForeignOrUnownedServiceDetected -and
      $NodeIdentityAtStop -and
      $RuntimeTreeIdentityAtStop -and
      $StateCaptureSucceeded -and
      $ServiceStateBoundForStop -and
      $ServiceStateBoundImmediatelyBeforeStop -and
      $null -ne $StartedServicePid) {
    $StopAttempted = $true
    try {
      $StopRaw = @(& $NodeExe $Cli stop 2>&1)
      $StopExit = $LASTEXITCODE
    } catch {
      $StopExit = $null
    } finally {
      $StopRaw = $null
    }
  }

  if ($null -ne $StartedServicePid) {
    try {
      $StartedServicePidDead = Test-T00ProcessDead $StartedServicePid
    } catch {
      $StartedServicePidDead = $false
    }
  }

  try {
    $SandboxClaude3pTargetCountAfterStop = Get-T00LeafCount $SandboxClaude3pTargets
    $ClaudeAppBackupAbsentAfterStop = Test-T00PathAbsent $ClaudeAppBackupFile
    $ServiceStateAbsentAfterStop = Test-T00PathAbsent $ServiceStateFile
  } catch {
    $SandboxClaude3pTargetCountAfterStop = -1
    $ClaudeAppBackupAbsentAfterStop = $false
    $ServiceStateAbsentAfterStop = $false
  }

  try {
    $After = Get-CurrentInvariantState
    $SettingsAfterSame = $Baseline.EnterpriseSettings -eq $After.EnterpriseSettings
    $Claude3pAfterSame = $Baseline.RealClaude3pConfig -eq $After.RealClaude3pConfig
    $AllProcessEnvAfterSame = $Baseline.AllProcessEnv -ceq $After.AllProcessEnv
    $ProcessEnvAfterSame = $Baseline.ProcessEnv -eq $After.ProcessEnv
    $UserEnvAfterSame = $Baseline.UserEnv -eq $After.UserEnv
    $MachineEnvAfterSame = $Baseline.MachineEnv -eq $After.MachineEnv
    $ClaudeResolutionAfterSame = $Baseline.ClaudeResolution -eq $After.ClaudeResolution
    $AfterCaptureSucceeded = $true
  } catch {
    $AfterCaptureSucceeded = $false
  }

  try {
    $GitIdentityAtFinal = Test-T00BoundCommand $GitTool
    if (-not $GitIdentityAtFinal) {
      throw "BLOCKED_TOOLCHAIN_IDENTITY"
    }
    $ProductDiffRaw = @(
      & $GitExe -C $RepositoryRoot diff --exit-code $ValidatedProductCommit HEAD -- packages build package.json package-lock.json 2>&1
    )
    $ProductDiffExit = $LASTEXITCODE
  } catch {
    $ProductDiffExit = $null
  } finally {
    $ProductDiffRaw = $null
  }

  try {
    if (-not $GitIdentityAtFinal) {
      throw "BLOCKED_TOOLCHAIN_IDENTITY"
    }
    $FinalHeadRaw = @(& $GitExe -C $RepositoryRoot rev-parse HEAD 2>&1)
    $FinalHeadExit = $LASTEXITCODE
    $FinalHeadSame =
      $FinalHeadExit -eq 0 -and
      $FinalHeadRaw.Count -eq 1 -and
      ([string]$FinalHeadRaw[0]).Trim() -ceq $ApprovedCandidateSha
  } catch {
    $FinalHeadExit = $null
    $FinalHeadSame = $false
  } finally {
    $FinalHeadRaw = $null
  }

  try {
    if (-not $GitIdentityAtFinal) {
      throw "BLOCKED_TOOLCHAIN_IDENTITY"
    }
    $StatusRaw = @(& $GitExe -C $RepositoryRoot status --porcelain=v1 --untracked-files=all 2>&1)
    $FinalStatusExit = $LASTEXITCODE
    $FinalStatusClean =
      $FinalStatusExit -eq 0 -and
      $StatusRaw.Count -eq 0
  } catch {
    $FinalStatusExit = $null
    $FinalStatusClean = $false
  } finally {
    $StatusRaw = $null
  }

  try {
    $BuildTreeAfterSame =
      (Get-T00BuildTreeFingerprint) -ceq $BuildTreeFingerprint
  } catch {
    $BuildTreeAfterSame = $false
  }

  try {
    Assert-T00ExecutionTreeRegular $ExecutionRoot
    $FinalExactTreePaths = @(Get-T00ExactSourcePaths)
    $ExactTreeAfterSame =
      (Get-T00FileSetFingerprint $FinalExactTreePaths) -ceq $ExactTreeFingerprint
  } catch {
    $ExactTreeAfterSame = $false
  } finally {
    $FinalExactTreePaths = $null
  }

  $A3CleanupComplete =
    $FreshServiceOwnershipProven -and
    $StopAttempted -and
    $StopExit -eq 0 -and
    $StartedServicePidDead -and
    $SandboxClaude3pTargetCountAfterStop -eq 0 -and
    $ClaudeAppBackupAbsentAfterStop -and
    $ServiceStateAbsentAfterStop
  $AfterInvariantSafeForH2 =
    $AfterCaptureSucceeded -and
    $SettingsAfterSame -and
    $Claude3pAfterSame -and
    $AllProcessEnvAfterSame -and
    $ProcessEnvAfterSame -and
    $UserEnvAfterSame -and
    $MachineEnvAfterSame -and
    $ClaudeResolutionAfterSame
  $SafeForH2 = $A3CleanupComplete -and $AfterInvariantSafeForH2
  $A3Completed =
    $DuringCaptureSucceeded -and
    $AfterCaptureSucceeded -and
    $SettingsDuringSame -and
    $Claude3pDuringSame -and
    $AllProcessEnvDuringSame -and
    $ProcessEnvDuringSame -and
    $UserEnvDuringSame -and
    $MachineEnvDuringSame -and
    $ClaudeResolutionDuringSame -and
    $A3CleanupComplete -and
    $ProductDiffExit -eq 0 -and
    $FinalHeadSame -and
    $NodeIdentityAtStop -and
    $RuntimeTreeIdentityAtStop -and
    $GitIdentityAtFinal -and
    $BuildTreeAfterSame -and
    $ExactTreeAfterSame -and
    $FinalStatusClean

  if ($ExecutionLocationPushed) {
    try {
      Pop-Location
      $ExecutionLocationRestored = $true
    } catch {
      $ExecutionLocationRestored = $false
    }
  }
  $A3Completed = $A3Completed -and $ExecutionLocationRestored
  $SafeForH2 =
    $SafeForH2 -and
    $ExecutionLocationRestored -and
    $NodeIdentityAtStop -and
    $RuntimeTreeIdentityAtStop -and
    $GitIdentityAtFinal -and
    $BuildTreeAfterSame -and
    $ExactTreeAfterSame
}
$StartDisposition = if ($StartReportedReuse) {
  "REUSE"
} elseif ($StartReportedFresh -and $FreshServiceOwnershipProven) {
  "FRESH"
} else {
  "NO_BOUND_SERVICE"
}
$StopDisposition = if ($StopAttempted -and $StopExit -eq 0) {
  "P"
} elseif ($StopAttempted) {
  "F"
} else {
  "SKIP"
}
(
  "A2A3|RESULT=RECORDED|START=$StartDisposition|RUNTIME=" +
  $(if ($RuntimeReady) { "P" } else { "N" }) +
  "|HELPER=$HelperDisposition|SAVE=$SaveDisposition|STOP=$StopDisposition|A3=" +
  $(if ($A3Completed) { "P" } else { "N" }) +
  "|H2_SAFE=" + $(if ($SafeForH2) { "Y" } else { "N" }) +
  "|RAW=NO"
)
} catch {
  "A2A3|RESULT=FAIL|CATEGORY=VALIDATION_EXECUTION_FAILURE|RAW=NO"
}
}
$T00A2A3Outcome
```

Management URL/token, captured PID, fingerprint 원문/hash, 파일 원문과 전체 경로는 출력하거나 외부 Evidence로 옮기지 않는다.
Start/helper/stop의 raw stdout/stderr는 메모리에만 캡처하고 즉시 폐기한다. Management URL/token, PID 또는 malformed helper output을 콘솔이나 Evidence로 내보내지 않는다.
Bounded poll에서 fresh-shaped state를 발견해도 exact Stock `started ... (pid ...)` 단일 출력과 PID가 묶이지 않으면 shared-PC에서는 unowned로 분류하고 stock stop/H2를 금지한다. Timeout child가 실제 소유 child일 가능성은 Human recovery에서만 다룬다.
Helper가 `BLOCKED`, `APPLY=SKIP`, `INDETERMINATE_SAVE`, postcondition failure 또는 예상 밖 결과를 반환해도 retry/UI 우회를 하지 않고 위 A3를 완료한다.

결과별 lifecycle 기대값:

| Helper disposition | Save | Sandbox targets before/during/after stop | Backup before/during/after | Attempt meaning |
|---|---:|---:|---:|---|
| `CONFIRMED_APPLY` | `Y` | `0 / 3 / 0` | `ABSENT / PRESENT / ABSENT` | A3/H2까지 모두 PASS일 때만 PASS candidate |
| `PREFLIGHT_NO_CHANGE`, `PREFLIGHT_BLOCKED`, `PRE_SAVE_BLOCKED`, `APPLY_SKIP` | `N` | `0 / 0 / 0` | `ABSENT / ABSENT / ABSENT` | BLOCKED |
| `INDETERMINATE_SAVE`, unexpected apply, post-save failure | `UNKNOWN` 또는 `Y` | during은 `0` 또는 `3`; after는 `0` | during은 absent/present; after는 absent | cleanup 후에도 FAIL |
| exact `already running` | `N` | 측정하지 않음 | 측정하지 않음 | 다른 소유자의 service를 stop하지 않고 `BLOCKED_FRESH_SERVICE_STATE` |
| no bound service materialized after bounded poll | `N` | `0 / 0 / 0` | `ABSENT / ABSENT / ABSENT` | detached child의 later readiness를 배제할 수 없어 H2로 진행하지 않고 Human recovery |

정상 profile-only save의 helper capsule은 `GW_PRE=STOP|GW_POST=STOP`이어야 한다. Gateway가 시작되면 이 Attempt는 postcondition failure다.
fresh ownership과 unchanged Node/runtime identity가 증명된 경우에만 stock stop을 실행하며, `StopExit = 0`과 captured A2 PID dead가 필요하다. No-state 경로도 detached child가 더 늦게 준비될 가능성을 배제할 수 없으므로 H2-safe로 보지 않는다. Exact reuse 경로는 foreign service를 stop하지 않은 채 별도 BLOCKED로 끝낸다. PASS에는 service state absent, backup absent, sandbox target after stop `0`, product diff `0`, final status clean이 모두 필요하다.
Captured PID가 살아 있으면 `SERVICE_SHUTDOWN_FAILURE`다. 그 PID를 강제 종료하지 말고 sandbox를 보존한 채 Human recovery로 넘기며 Claude client를 다시 열지 않는다.

## H2 — [HUMAN_GATE_OWNER] Enterprise after smoke

`SafeForH2 = True`이면 helper 결과가 PASS/BLOCKED/FAIL 중 무엇이든 정상 경로로 확인한다.
`SafeForH2 = False`, exact start result가 `already running`이거나 captured PID가 살아 있으면 Claude clients를 다시 열지 말고 Human recovery로 넘긴다.

```text
Enterprise Claude Code authentication smoke: PASS
Enterprise Claude models visible: PASS
Claude Desktop normal smoke: PASS
Manual settings/env recovery required: NO
```

수동 복구가 필요했다면 최종 결과는 FAIL이다.

## A4 — [INTERNAL_VALIDATOR] Sanitized result and precedence

Fingerprint/hash/PID/path/URL/token/config 원문을 출력하지 않고 아래 precedence로 한 번만 판정한다.

```text
1. Enterprise/Claude-3p/env/command invariant changed
   → FAIL — ISOLATION_BREACH

2. exact Stock start output says `already running`
   → BLOCKED — BLOCKED_FRESH_SERVICE_STATE; do not stop the unowned service

3. a service state exists but fresh ownership is ambiguous, captured A2 PID not
   dead, or stop/backup/service/sandbox cleanup is incomplete
   → FAIL — SERVICE_SHUTDOWN_FAILURE

4. during/after invariant capture incomplete
   → FAIL — VALIDATION_EVIDENCE_INCOMPLETE

5. toolchain/runtime/source fingerprint changed, product diff nonzero,
   git status command failure, execution cwd was not restored, or final tree dirty
   → FAIL — PRODUCT_DIFF

6. SAVE=UNKNOWN, unexpected apply outcome, or confirmed post-save failure
   → FAIL — INDETERMINATE_OR_POST_SAVE_FAILURE

7. runtime start not ready, unexpected preflight, pre-save block, no-change, or APPLY=SKIP
   → BLOCKED — wrapper category or BLOCKED_CONFIG_SAVE_NOT_EXERCISED

8. only CONFIRMED_APPLY + `GW_PRE=STOP|GW_POST=STOP`
   + exact 0/3/0 and ABSENT/PRESENT/ABSENT lifecycle
   + all invariants SAME + H2 PASS + no manual rollback + clean product tree
   → PASS
```

낮은 우선순위의 helper category가 isolation breach나 shutdown failure를 가리지 않는다.
`SAVE=UNKNOWN`은 절대 retry하지 않으며 cleanup이 성공해도 해당 Attempt는 FAIL이다.

## Acceptance criteria — Attempt 3

- [ ] exact instruction SHA 기록
- [ ] exact candidate SHA 기록
- [ ] candidate/instruction/final PR head 동일
- [ ] toolchain identity block이면 fixed `PHASE/TOOL/REASON` capsule만 출력
- [ ] same dedicated 64-bit PowerShell process retained from A0 through A2–A3
- [ ] working tree before test clean
- [ ] product tree equivalence exit `0`
- [ ] forbidden runtime/debug/Gateway override env absent before first Node/npm process
- [ ] legacy config/import/migration sources absent before first Node/npm and immediately before A2
- [ ] canonical config directory/SQLite/optional sidecars pass bounded non-reparse metadata checks before first Node/npm and immediately before A2 (row/schema fixed point is not claimed)
- [ ] install/build child credential env sanitized and restored
- [ ] npm cache/log/temp/node-gyp paths confined to the nonce validation workspace
- [ ] nonce validation workspace kept local for Gate review; exact-nonce Human cleanup deferred
- [ ] exact archived source tree used as runtime cwd
- [ ] ignored CLI dist rebuilt from exact checked-out source; build exit `0`
- [ ] direct TypeScript typecheck exit `0`
- [ ] Enterprise baseline smoke PASS
- [ ] local recovery backup 상태 기록
- [ ] all Claude clients closed before fingerprint
- [ ] all CCR management/Desktop/UI/config writers closed before fingerprint
- [ ] baseline captured after smoke and shutdown
- [ ] service starts with process-local sandbox `LOCALAPPDATA`
- [ ] parent PowerShell `LOCALAPPDATA` restored immediately
- [ ] parent Process env boundary restored immediately
- [ ] fresh A2 PID captured without exporting it
- [ ] exact Stock `started` output distinguished from exact `already running`
- [ ] every invoked start outcome received bounded late-state polling
- [ ] bounded regular service state fingerprint remains bound through stock stop
- [ ] start/helper/stop raw stdout/stderr not printed or exported
- [ ] wrapper no-save preflight PASS
- [ ] wrapper apply executed with `APPLY=P`
- [ ] save disposition recorded as `Y`
- [ ] Gateway pre/post state = `STOP / STOP`; Gateway never started
- [ ] A3 attempted for every helper outcome
- [ ] A3 completed
- [ ] captured A2 PID dead after stock stop
- [ ] enabled global Claude Code profiles after save = `0`
- [ ] Request logs OFF
- [ ] Agent observability OFF
- [ ] Request body capture NONE
- [ ] observability was already safe and remained unchanged
- [ ] Provider unchanged
- [ ] actual Enterprise settings during/after = SAME
- [ ] actual Claude-3p CCR config surface during/after = SAME
- [ ] complete Process env during/after = SAME
- [ ] Process env during/after = SAME
- [ ] User env during/after = SAME
- [ ] Machine env during/after = SAME
- [ ] normal `claude` resolution during/after = SAME
- [ ] sandbox Claude-3p config files materialized
- [ ] fresh sandbox target count before/during/after stop = `0 / 3 / 0`
- [ ] Claude App backup lifecycle = `ABSENT / PRESENT / ABSENT`
- [ ] service state absent after stop
- [ ] stop exit `0`
- [ ] Enterprise after smoke PASS
- [ ] manual rollback not required
- [ ] product diff exit `0`
- [ ] source/runtime/toolchain fingerprints unchanged through A3
- [ ] execution cwd restored
- [ ] final Git status clean
- [ ] secrets/raw fingerprints exported = NO
- [ ] Git write performed = NO
- [ ] next Task started = NO

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

FAIL — SERVICE_SHUTDOWN_FAILURE
→ fresh/unowned service state is ambiguous, captured fresh A2 PID still alive, or cleanup is incomplete
→ do not force-kill an unverified PID and do not reopen Claude clients

FAIL — INDETERMINATE_OR_POST_SAVE_FAILURE
→ save may have run or confirmed save postcondition failed
→ never retry; preserve A3/H2 evidence

BLOCKED
→ baseline, fingerprint, policy or host precondition unavailable

BLOCKED — BLOCKED_FRESH_SERVICE_STATE
→ Stock reported an already-running service; do not stop or reuse it in this Attempt
```

## Stop conditions

- CCR service cannot be stopped before baseline
- working tree dirty
- Git/Node/npm Application identity cannot be bound or changes during A0
- forbidden Node/runtime/Gateway override environment present
- exact checked-out source cannot rebuild CLI assets
- Enterprise baseline smoke FAIL
- Claude clients cannot be closed
- fingerprint capture unavailable
- User/Machine env must be edited to continue
- source/runtime DB direct edit required
- Enterprise invariant changes
- secret/raw settings must be exported to diagnose
- model request would be required
- Gateway starts or does not remain stopped after profile-only save
- wrapper apply returns `APPLY=SKIP`

## Failure classification

- `BLOCKED_BASELINE_CAPTURE`
- `BLOCKED_TOOLCHAIN_IDENTITY`
- `BLOCKED_RUNTIME_ENV`
- `BLOCKED_BUILD_ASSETS`
- `ENTERPRISE_BASELINE_FAILURE`
- `RUNTIME_SANDBOX_INCOMPATIBLE`
- `ISOLATION_BREACH`
- `GLOBAL_PROFILE_PERSISTENCE`
- `CLAUDE_APP_CONFIG_PERSISTENCE`
- `PROCESS_ENVIRONMENT_LEAK`
- `LOGGING_SAFETY`
- `BLOCKED_CONFIG_SAVE_NOT_EXERCISED`
- `SERVICE_SHUTDOWN_FAILURE`
- `INDETERMINATE_OR_POST_SAVE_FAILURE`
- `VALIDATION_EVIDENCE_INCOMPLETE`
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
- candidate/instruction/PR head same:
- working tree clean:
- product tree equivalence:
- runtime env safe before Node/npm:
- build assets / exit code:
- CLI exists:
- CCR service state absent:
- service state absent before start:
- same persistent PowerShell console retained: YES / NO
- toolchain identity capsule, if blocked: fixed `PHASE/TOOL/REASON` only

H0:
- Enterprise CLI baseline:
- Enterprise model baseline:
- Claude Desktop baseline:
- local recovery backup:
- Claude clients closed:
- all CCR management/Desktop/UI/config writers closed:

A1:
- baseline captured after smoke/shutdown:
- fingerprint scope: TARGETED_CCR_CONFIG_FILES

A2:
- sandbox service start:
- start exit code:
- parent LOCALAPPDATA restored:
- parent Process env restored:
- fresh service state created:
- fresh PID captured: YES / NO
- service state bound for stock stop: YES / NO
- raw start output exported: NO

A2b:
- no-save preflight / exit code:
- apply / exit code:
- apply attempted: YES / NO
- helper disposition:
- save disposition: N / Y / UNKNOWN
- sanitized preflight capsule:
- sanitized apply capsule:
- enabled global Claude Code profiles:
- new profile created: NO
- Request logs:
- Agent observability:
- Request body capture:
- Provider changed: NO
- Gateway pre/post: STOP / STOP_OR_OTHER
- Gateway started: NO / YES / UNKNOWN
- Connect agent executed: NO
- Let's start executed: NO

A3 during:
- A3 attempted: YES / NO
- Enterprise settings: SAME / CHANGED
- actual Claude-3p CCR config surface: SAME / CHANGED
- complete Process env: SAME / CHANGED
- Process env: SAME / CHANGED
- User env: SAME / CHANGED
- Machine env: SAME / CHANGED
- normal claude resolution: SAME / CHANGED
- invariant capture completed: YES / NO
- sandbox Claude-3p config materialized: YES / NO
- sandbox target count: 0..3
- Claude App backup exists during: YES / NO

A3 after:
- CCR stop / exit code:
- captured A2 PID dead: YES / NO
- Enterprise settings: SAME / CHANGED
- actual Claude-3p CCR config surface: SAME / CHANGED
- complete Process env: SAME / CHANGED
- Process env: SAME / CHANGED
- User env: SAME / CHANGED
- Machine env: SAME / CHANGED
- normal claude resolution: SAME / CHANGED
- sandbox target count after stop:
- Claude App backup absent after stop:
- service state absent after stop:
- product diff / exit code:
- final git status / command exit:
- A3 cleanup complete: YES / NO
- A3 completed: YES / NO
- safe for H2: YES / NO

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
- `saveConfig` can start the Gateway when restart-sensitive fields change. T02 therefore requires observability already safe and proves an exact profile-only diff; any observed Gateway start fails the Attempt.
- `saveConfig` always synchronizes Provider model auto-refresh. Every enabled Provider must therefore have `autoFetchModels = OFF`; otherwise the helper must stop before save.
- This RPC is a pinned `v3.0.22` dependency, not a permanent public API contract, and must be revalidated on upstream update.

The activated Company-only repair is Task `V1-S1-T02`:

1. Add a task-limited Company helper under `company/scripts/`; do not add a production launcher/Doctor yet.
2. Read the running sandbox service state and accept loopback-only authenticated RPC.
3. Verify service PID/token identity and require the pre-save Gateway to be stopped and not externally owned.
4. Call `getConfig` without printing raw configuration.
5. Fail closed before save if service sandbox state, Node startup env, auth, Provider auto-fetch state, logging state, enabled Router script or config shape is unsafe.
6. Require logging/analysis/body capture already `OFF/OFF/NONE`; do not change observability because that would start the Gateway and can trigger unrelated local OAuth refresh.
7. Require canonical profile scopes and change only enabled `claude-code` profiles with exact `scope=global`, plus their source-derived legacy mirrors. Missing/unknown scope blocks.
8. If already safe, omit save; otherwise call Stock `saveConfig` with `{ applyProfile: false }` exactly once.
9. Require the Gateway to remain `STOP` before/after, then re-read and verify enabled global Claude Code profiles `0`, logging/analysis/body capture unchanged and Provider-related configuration unchanged.
10. Output only a compact sanitized PASS/BLOCKED/FAIL capsule; leave service stop and A3/H2 to T00.

T02 was separately activated by Human Gate on `2026-09-01` and is now
`EXTERNAL_PASS` with 159/159 synthetic/mock tests.

## Attempt 2 Evidence — sanitized

- Date: `2026-09-01`
- Candidate / instruction SHA: `c2459b90182041afdb7b9c0cf44149494b30f910`
- A0 result: `BLOCKED — BLOCKED_TOOLCHAIN_IDENTITY`
- Exact failed phase/tool/reason: `UNKNOWN — NOT_CAPTURED_BY_ATTEMPT_2_CAPSULE`
- Post-block diagnostic: `NOT_RUN — NOT_APPROVED`
- Dedicated session console: `CLOSED — PARTIAL_STATE_NOT_REUSABLE`

Sanitized operator evidence confirms that the approved A0 performed the exact-candidate
read-only context load, fetch, detached checkout, archive, dependency install,
typecheck and build. The one-line failure capsule did not identify which identity
checkpoint failed. `npm.ps1` precedence is excluded by the A0 Application-only binding
and invocation of the stored bound path; the exact Attempt 2 cause remains `UNKNOWN`
without a new bounded observation.

```text
raw/secret/path/hash evidence exported: NO
Git/GitHub write by Internal Validator: NO
CCR service or Gateway started: NO
H0 started: NO
A1+ started: NO
next Task started: NO
```

Because the original PowerShell process is closed, Attempt 2 cannot resume and its
in-memory bindings/fingerprints must not be reconstructed. The retained nonce
validation workspace is not deleted by this repair; exact-nonce cleanup remains a
separate Human action after Gate review.

## Attempt 3 authorization

Attempt 3 is `READY_FOR_INTERNAL_VALIDATION` on the new final frozen PR head supplied
by Human Gate. The only authorized first step is A0 in a new dedicated interactive
64-bit PowerShell console. The console remains open after the compact sanitized A0
capsule is returned. H0 and A1+ remain unauthorized until that Evidence is reviewed.
T01 remains blocked until T00 Human decision `ACCEPTED`.

## Attempts

| Attempt | Actor / session role | Candidate | Internal result | Recommendation |
|---:|---|---|---|---|
| 1 | A0 Internal Validator; H0–H2 and A1–A3 Human Gate Owner | `97b73a9f...` | `BLOCKED — GLOBAL_PROFILE_PERSISTENCE` | approve Company-only T02 helper, then retry T00; do not start T01 |
| 2 | INTERNAL_VALIDATOR, A0 preflight | `c2459b90182041afdb7b9c0cf44149494b30f910` | `BLOCKED — BLOCKED_TOOLCHAIN_IDENTITY`; exact checkpoint not captured; console closed | do not resume or diagnose stale state; preserve workspace; repair sanitized A0 observability only |
| 3 | INTERNAL_VALIDATOR + HUMAN_GATE_OWNER, human-assisted | new final frozen PR head supplied by Human Gate | `NOT_STARTED` | `READY_FOR_INTERNAL_VALIDATION` — A0 only; hold H0/A1+ pending sanitized A0 review; do not start T01 |

## Human decision

`RETRY`
