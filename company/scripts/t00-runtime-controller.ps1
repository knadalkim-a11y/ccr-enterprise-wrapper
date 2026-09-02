[CmdletBinding(DefaultParameterSetName = "Prepare")]
param(
  [Parameter(Mandatory = $true, ParameterSetName = "Prepare")][switch]$Prepare,
  [Parameter(Mandatory = $true, ParameterSetName = "Prepare")][string]$PreparedGitDir,
  [Parameter(Mandatory = $true, ParameterSetName = "Prepare")][string]$PreparedCandidateRef,
  [Parameter(Mandatory = $true, ParameterSetName = "Prepare")][string]$PreparedMainRef,
  [Parameter(Mandatory = $true, ParameterSetName = "Prepare")][string]$MainSha,
  [Parameter(Mandatory = $true, ParameterSetName = "Prepare")][string]$CandidateSha,
  [Parameter(Mandatory = $true, ParameterSetName = "Prepare")][string]$InstructionSha,
  [Parameter(Mandatory = $true, ParameterSetName = "Prepare")][string]$ImplementationBaseSha,
  [Parameter(Mandatory = $true, ParameterSetName = "Prepare")][string]$ValidatedProductSha,
  [Parameter(Mandatory = $true, ParameterSetName = "Prepare")][string]$TaskPath,
  [Parameter(Mandatory = $true, ParameterSetName = "Prepare")][string]$EnvironmentAlias,
  [Parameter(Mandatory = $true, ParameterSetName = "Prepare")][switch]$ConfirmWindowsRuntimeAllowed,
  [Parameter(Mandatory = $true, ParameterSetName = "Prepare")][switch]$ConfirmClaudeCodeExecutionAllowed,
  [Parameter(Mandatory = $true, ParameterSetName = "Prepare")][switch]$ConfirmNoSameAccountConcurrentUse,
  [Parameter(Mandatory = $true, ParameterSetName = "Prepare")][switch]$AllowNpmNetworkAndLifecycle,
  [Parameter(Mandatory = $true, ParameterSetName = "Prepare")][switch]$ApproveSingleSaveIfChangeY,
  [Parameter(Mandatory = $true, ParameterSetName = "Prepare")][switch]$ConfirmStockGetAppInfoResidualRisk,

  [Parameter(Mandatory = $true, ParameterSetName = "Run")][switch]$Run,
  [Parameter(Mandatory = $true, ParameterSetName = "Run")]
  [Parameter(Mandatory = $true, ParameterSetName = "CleanupBackup")]
  [string]$ManifestPath,
  [Parameter(Mandatory = $true, ParameterSetName = "Run")]
  [Parameter(Mandatory = $true, ParameterSetName = "CleanupBackup")]
  [string]$ManifestDigest,
  [Parameter(Mandatory = $true, ParameterSetName = "Run")]
  [Parameter(Mandatory = $true, ParameterSetName = "CleanupBackup")]
  [string]$WorkspaceId,
  [Parameter(Mandatory = $true, ParameterSetName = "Run")]
  [Parameter(Mandatory = $true, ParameterSetName = "CleanupBackup")]
  [string]$ApprovedHeadSha,

  [Parameter(Mandatory = $true, ParameterSetName = "CleanupBackup")][switch]$CleanupBackup,
  [Parameter(Mandatory = $true, ParameterSetName = "CleanupBackup")][string]$CleanupTicketPath,
  [Parameter(Mandatory = $true, ParameterSetName = "CleanupBackup")][string]$CleanupTicketDigest,
  [Parameter(Mandatory = $true, ParameterSetName = "CleanupBackup")][string]$RecoveryManifestDigest,
  [Parameter(Mandatory = $true, ParameterSetName = "CleanupBackup")][switch]$ConfirmPostGateRecoveryNo,
  [Parameter(Mandatory = $true, ParameterSetName = "CleanupBackup")][switch]$ConfirmDeleteRecoveryBackup
)

Set-StrictMode -Version 2.0

$script:SavedErrorActionPreference = $ErrorActionPreference
$script:SavedProgressPreference = $ProgressPreference
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$script:CanonicalMainSha = "6d0d6f2aeca02e33261c062eac5aab360805222b"
$script:CanonicalImplementationBaseSha = "e6fe7e3b00dd42311cb30d88472949b03d18a2aa"
$script:CanonicalProductSha = "97b73a9f4e1fb23d406bb987d0785cefa1f99966"
$script:CanonicalTaskPath = "company/tasks/v1-s1/V1-S1-T00-CCR-RUNTIME-SANDBOX.md"
$script:CanonicalCandidateRef = "refs/internal-validation/v1-s1-t00-candidate"
$script:CanonicalMainRef = "refs/internal-validation/v1-s1-t00-main"
$script:ControllerRepositoryPath = "company/scripts/t00-runtime-controller.ps1"
$script:ControllerTestRepositoryPath = "company/tests/t00-runtime-controller-contract.test.mjs"
$script:T02HelperRepositoryPath = "company/scripts/t00-safe-config-save.mjs"
$script:T02TestRepositoryPath = "company/tests/t00-safe-config-save.test.mjs"
$script:T02HelperBlob = "cc1ef5f92b5448f2ef2ddd6ef384c6fdce711ff8"
$script:T02TestBlob = "f711915a7ed7a98a55d81c486e1f5027cd6cd86c"
$script:TaskId = "V1-S1-T00"
$script:Attempt = 4
$script:ShaPattern = "^[0-9a-f]{40}$"
$script:DigestPattern = "^[0-9A-Fa-f]{64}$"
$script:WorkspacePattern = "^[0-9a-f]{32}$"
$script:AliasPattern = "^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$"
$script:CaptureLimitChars = 2097152
$script:MaximumTreeEntries = 400000
$script:MaximumTreeBytes = [Int64]8589934592
$script:MaximumManifestBytes = 134217728
$script:SystemSid = "S-1-5-18"
$script:Phase = "INPUT"
$script:SafeHeadPrefix = "INVALID"
$script:ExitCode = 0
$script:FailureBackupCode = "N"
$script:FailureCleanupCode = "N"
$script:PrepareCleanupCode = "P"
$script:PrepareWorkspaceId = "UNKNOWN"
$script:PrepareLocalWriteAttempted = $false
$script:PrepareNpmInstallAttempted = $false
$script:PrepareNpmEffectsAllowed = $false
$script:PrepareTypecheckAttempted = $false
$script:PrepareBuildAttempted = $false
$script:CleanupDeletionCommitted = $false
$script:GetAppInfoUncertain = $false
$script:NativeCleanupUncertain = $false

$script:ImplementationAllowedPaths = @(
  "company/scripts/t00-runtime-controller.ps1",
  "company/tests/t00-runtime-controller-contract.test.mjs",
  "company/tasks/v1-s1/V1-S1-T00-CCR-RUNTIME-SANDBOX.md",
  "company/tasks/v1-s1/V1-S1-T02-WRAPPER-SAFE-CONFIG-SAVE.md",
  "company/project-state.yml",
  "company/docs/STATUS.md",
  "company/gates/V1-S1.md"
)

$script:TaskAllowedPaths = @(
  "AGENTS.md",
  "company/AGENTS.md",
  "company/project-state.yml",
  "company/docs/AGENT_WORKFLOW.md",
  "company/docs/DECISIONS.md",
  "company/docs/DESIGN_SESSION_PLAYBOOK.md",
  "company/docs/ENVIRONMENTS.md",
  "company/docs/INTERNAL_VALIDATION.md",
  "company/docs/ROLES_AND_HANDOFF.md",
  "company/docs/STATUS.md",
  "company/docs/TRAPS.md",
  "company/gates/V1-S1.md",
  "company/scripts/t00-a0-preflight.ps1",
  "company/scripts/t00-runtime-controller.ps1",
  "company/scripts/t00-safe-config-save.mjs",
  "company/tasks/README.md",
  "company/tasks/TASK_TEMPLATE.md",
  "company/tasks/v1-s1/V1-S1-T00-CCR-RUNTIME-SANDBOX.md",
  "company/tasks/v1-s1/V1-S1-T02-WRAPPER-SAFE-CONFIG-SAVE.md",
  "company/tests/t00-a0-preflight-contract.test.mjs",
  "company/tests/t00-runtime-controller-contract.test.mjs",
  "company/tests/t00-safe-config-save.test.mjs"
)

$script:ProtectedProductPaths = @(
  "packages",
  "build",
  "package.json",
  "package-lock.json",
  "npm-shrinkwrap.json",
  ".npmrc",
  ".gitignore",
  ".gitattributes",
  "tsconfig.json",
  "tsconfig.node.json",
  "tests/e2e"
)

$script:StartupOverrideKeys = @(
  "CCR_CLI_COMMAND_NAME",
  "CCR_GATEWAY_ENTRY",
  "CCR_INTERNAL_APP_DATA_DIR",
  "CCR_INTERNAL_HOME_DIR",
  "CCR_INTERNAL_USER_DATA_DIR",
  "CCR_MODEL_CATALOG_PATH",
  "CCR_MODELS_JSON_PATH",
  "CCR_NODE_BIN",
  "CCR_SERVICE_INSTANCE_TOKEN",
  "CCR_UPSTREAM_PROXY_URL",
  "CCR_WEB_ALLOWED_ORIGINS",
  "CCR_WEB_AUTH_TOKEN",
  "CCR_WEB_HOST",
  "CCR_WEB_PORT",
  "ELECTRON_RUN_AS_NODE",
  "NODE_COMPILE_CACHE",
  "NODE_DEBUG",
  "NODE_OPTIONS",
  "NODE_PATH",
  "NODE_REDIRECT_WARNINGS",
  "NODE_V8_COVERAGE",
  "npm_config_node_options",
  "npm_config_script_shell"
)

$script:ManagedEnterpriseEnvironmentKeys = @(
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
  "CLAUDE_CONFIG_DIR",
  "CCR_CLAUDE_CODE_MCP_CONFIG",
  "CODEXL_CLAUDE_CODE_MCP_CONFIG"
)

$script:AllowedPhases = @(
  "INPUT", "HOST", "SOURCE", "TOOL", "INSTALL", "TYPE", "BUILD", "SEAL",
  "H0", "BACKUP", "BASELINE", "SERVICE", "PREFLIGHT", "APPLY", "DURING",
  "CLEANUP", "H2", "POST_GATE", "FINAL"
)

$script:AllowedCategories = @(
  "BLOCKED_INPUT_CONTRACT",
  "BLOCKED_WINDOWS_RUNTIME",
  "BLOCKED_PREPARED_REPOSITORY",
  "BLOCKED_SOURCE_IDENTITY",
  "BLOCKED_TASK_METADATA",
  "BLOCKED_IMPLEMENTATION_SCOPE",
  "BLOCKED_PRODUCT_TREE_MISMATCH",
  "BLOCKED_ARTIFACT_IDENTITY",
  "BLOCKED_TOOLCHAIN",
  "BLOCKED_DEPENDENCY_INSTALL",
  "BLOCKED_TYPECHECK",
  "BLOCKED_BUILD",
  "BLOCKED_RUNTIME_SEAL",
  "BLOCKED_MANIFEST_IDENTITY",
  "BLOCKED_RUNTIME_ENV",
  "BLOCKED_H0",
  "BLOCKED_RELEVANT_WRITER",
  "BLOCKED_PREEXISTING_SERVICE",
  "BLOCKED_STALE_BACKUP",
  "BLOCKED_LEGACY_SOURCE",
  "BLOCKED_BACKUP",
  "BLOCKED_BASELINE",
  "BLOCKED_SANDBOX",
  "BLOCKED_SERVICE_START",
  "BLOCKED_SERVICE_IDENTITY",
  "BLOCKED_GATEWAY_STATE",
  "BLOCKED_T02_PREFLIGHT",
  "BLOCKED_CHANGE_REQUIRED",
  "BLOCKED_T02_APPLY",
  "FAIL_SAVE_UNKNOWN",
  "ISOLATION_BREACH",
  "BLOCKED_CLEANUP",
  "BLOCKED_H2",
  "BLOCKED_POST_GATE_CLEANUP",
  "INTERNAL_ERROR"
)

function Set-T00Phase {
  param([Parameter(Mandatory = $true)][string]$Value)
  if ($script:AllowedPhases -cnotcontains $Value) {
    $script:Phase = "FINAL"
    Stop-T00 "INTERNAL_ERROR"
  }
  $script:Phase = $Value
}

function Stop-T00 {
  param([Parameter(Mandatory = $true)][string]$Category)
  if ($script:AllowedCategories -cnotcontains $Category) {
    $Category = "INTERNAL_ERROR"
  }
  throw ("T00_STOP::{0}::{1}" -f $script:Phase, $Category)
}

function Get-T00Failure {
  param([Parameter(Mandatory = $true)]$ErrorRecord)
  $Message = [string]$ErrorRecord.Exception.Message
  $Match = [regex]::Match($Message, '^T00_STOP::(?<phase>[A-Z0-9_]+)::(?<category>[A-Z0-9_]+)$')
  if ($Match.Success -and
      $script:AllowedPhases -ccontains $Match.Groups["phase"].Value -and
      $script:AllowedCategories -ccontains $Match.Groups["category"].Value) {
    return [PSCustomObject]@{
      Phase = $Match.Groups["phase"].Value
      Category = $Match.Groups["category"].Value
    }
  }
  return [PSCustomObject]@{ Phase = "FINAL"; Category = "INTERNAL_ERROR" }
}

function Write-T00ReadableRunFailure {
  param(
    [Parameter(Mandatory = $true)]$Failure,
    [Parameter(Mandatory = $true)][string]$BackupStatus,
    [Parameter(Mandatory = $true)][string]$CleanupStatus,
    [Parameter(Mandatory = $true)][bool]$ServiceMayExist,
    [Parameter(Mandatory = $true)][bool]$ManualRecovery
  )
  if (@("NONE_BEFORE_ATTEMPT", "PARTIAL_OR_UNKNOWN", "VERIFIED_RETAINED") -cnotcontains $BackupStatus) {
    $BackupStatus = "PARTIAL_OR_UNKNOWN"
  }
  if (@("NOT_REQUIRED", "PASS", "NOT_PASS") -cnotcontains $CleanupStatus) {
    $CleanupStatus = "NOT_PASS"
  }
  if ($BackupStatus -ceq "PARTIAL_OR_UNKNOWN" -or $CleanupStatus -ceq "NOT_PASS") {
    $ManualRecovery = $true
  }
  $ServiceText = if ($ServiceMayExist) { "YES" } else { "NO" }
  $RecoveryText = if ($ManualRecovery) { "YES" } else { "NO" }
  Write-Output "T00 RUNTIME RESULT: BLOCKED"
  Write-Output ("STOPPED PHASE: {0}" -f [string]$Failure.Phase)
  Write-Output ("FAILURE CATEGORY: {0}" -f [string]$Failure.Category)
  Write-Output ("SERVICE START MAY HAVE BEEN ATTEMPTED: {0}" -f $ServiceText)
  Write-Output ("CLEANUP STATUS: {0}" -f $CleanupStatus)
  Write-Output ("RECOVERY BACKUP: {0}" -f $BackupStatus)
  Write-Output ("MANUAL REVIEW OR RECOVERY REQUIRED: {0}" -f $RecoveryText)
  Write-Output "NEXT ACTION: STOP. DO NOT START OR RESTART H2, A1+, T01, MERGE, OR THE NEXT TASK."
}

function ConvertTo-T00SingleQuotedLiteral {
  param([AllowEmptyString()][string]$Value)
  if ($null -eq $Value -or $Value -match '[\x00-\x08\x0A-\x1F]') {
    Stop-T00 "BLOCKED_INPUT_CONTRACT"
  }
  return "'" + $Value.Replace("'", "''") + "'"
}

function ConvertTo-T00WindowsArgument {
  param([AllowEmptyString()][string]$Value)
  if ($null -eq $Value) {
    Stop-T00 "BLOCKED_INPUT_CONTRACT"
  }
  if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') {
    return $Value
  }
  $Builder = New-Object Text.StringBuilder
  [void]$Builder.Append('"')
  $BackslashCount = 0
  foreach ($Character in $Value.ToCharArray()) {
    if ($Character -eq [char]'\') {
      $BackslashCount += 1
      continue
    }
    if ($Character -eq [char]'"') {
      if ($BackslashCount -gt 0) {
        [void]$Builder.Append([char]'\', (2 * $BackslashCount))
      }
      [void]$Builder.Append([char]'\')
      [void]$Builder.Append([char]'"')
      $BackslashCount = 0
      continue
    }
    if ($BackslashCount -gt 0) {
      [void]$Builder.Append([char]'\', $BackslashCount)
      $BackslashCount = 0
    }
    [void]$Builder.Append($Character)
  }
  if ($BackslashCount -gt 0) {
    [void]$Builder.Append([char]'\', (2 * $BackslashCount))
  }
  [void]$Builder.Append('"')
  return $Builder.ToString()
}

function Get-T00Sha256Bytes {
  param([Parameter(Mandatory = $true)][byte[]]$Bytes)
  $Hasher = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($Hasher.ComputeHash($Bytes))).Replace("-", "")
  } finally {
    $Hasher.Dispose()
  }
}

function Get-T00Sha256Text {
  param([Parameter(Mandatory = $true)][string]$Text)
  return Get-T00Sha256Bytes ([Text.Encoding]::UTF8.GetBytes($Text))
}

function Assert-T00RegularFile {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Int64]$MaximumBytes = 0
  )
  try {
    $Item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
  } catch {
    Stop-T00 "BLOCKED_MANIFEST_IDENTITY"
  }
  if ($Item -isnot [IO.FileInfo] -or
      (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) -or
      ($MaximumBytes -gt 0 -and ($Item.Length -lt 0 -or $Item.Length -gt $MaximumBytes))) {
    Stop-T00 "BLOCKED_MANIFEST_IDENTITY"
  }
  return $Item
}

function Get-T00Sha256File {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Int64]$MaximumBytes = 0
  )
  [void](Assert-T00RegularFile $Path $MaximumBytes)
  return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path -ErrorAction Stop).Hash.ToUpperInvariant()
}

function Get-T00GitBlobSha1 {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Int64]$MaximumBytes = 8388608
  )
  $Item = Assert-T00RegularFile $Path $MaximumBytes
  $Header = [Text.Encoding]::ASCII.GetBytes(("blob {0}`0" -f $Item.Length))
  $Hasher = [Security.Cryptography.SHA1]::Create()
  $Stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
  try {
    [void]$Hasher.TransformBlock($Header, 0, $Header.Length, $Header, 0)
    $Buffer = New-Object byte[] 65536
    while (($Count = $Stream.Read($Buffer, 0, $Buffer.Length)) -gt 0) {
      [void]$Hasher.TransformBlock($Buffer, 0, $Count, $Buffer, 0)
    }
    [void]$Hasher.TransformFinalBlock((New-Object byte[] 0), 0, 0)
    return ([BitConverter]::ToString($Hasher.Hash)).Replace("-", "").ToLowerInvariant()
  } finally {
    $Stream.Dispose()
    $Hasher.Dispose()
  }
}

function Write-T00BytesAtomic {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][byte[]]$Bytes
  )
  if (-not (Test-T00PathAbsent $Path "BLOCKED_MANIFEST_IDENTITY")) {
    Stop-T00 "BLOCKED_MANIFEST_IDENTITY"
  }
  $Parent = Split-Path -Parent $Path
  if ((Get-T00PathStateNoFollow $Parent "BLOCKED_MANIFEST_IDENTITY").State -cne "DIRECTORY") {
    Stop-T00 "BLOCKED_MANIFEST_IDENTITY"
  }
  $Temporary = Join-Path $Parent (([IO.Path]::GetFileName($Path)) + ".tmp-" + (New-T00Nonce))
  $Committed = $false
  try {
    $Stream = [IO.File]::Open(
      $Temporary,
      [IO.FileMode]::CreateNew,
      [IO.FileAccess]::Write,
      [IO.FileShare]::None
    )
    try {
      $Stream.Write($Bytes, 0, $Bytes.Length)
      $Stream.Flush($true)
    } finally {
      $Stream.Dispose()
    }
    [IO.File]::Move($Temporary, $Path)
    $Committed = $true
  } finally {
    if (-not $Committed -and -not (Test-T00PathAbsent $Temporary "BLOCKED_MANIFEST_IDENTITY")) {
      [IO.File]::Delete($Temporary)
      if (-not (Test-T00PathAbsent $Temporary "BLOCKED_MANIFEST_IDENTITY")) {
        Stop-T00 "BLOCKED_MANIFEST_IDENTITY"
      }
    }
  }
}

function Get-T00RunSuccessMarkerBytes {
  param(
    [Parameter(Mandatory = $true)][string]$Candidate,
    [Parameter(Mandatory = $true)][string]$Workspace,
    [Parameter(Mandatory = $true)][string]$PreparedManifestDigest,
    [Parameter(Mandatory = $true)][string]$RunReportDigest,
    [Parameter(Mandatory = $true)][string]$CleanupTicketDigest
  )
  if ($Candidate -cnotmatch $script:ShaPattern -or
      $Workspace -cnotmatch $script:WorkspacePattern -or
      $PreparedManifestDigest -cnotmatch $script:DigestPattern -or
      $RunReportDigest -cnotmatch $script:DigestPattern -or
      $CleanupTicketDigest -cnotmatch $script:DigestPattern) {
    Stop-T00 "BLOCKED_MANIFEST_IDENTITY"
  }
  $Text = "T00-RUN-SUCCESS-V1`nCANDIDATE=$Candidate`nWORKSPACE=$Workspace`nMANIFEST=$($PreparedManifestDigest.ToUpperInvariant())`nREPORT=$($RunReportDigest.ToUpperInvariant())`nTICKET=$($CleanupTicketDigest.ToUpperInvariant())`n"
  return ,([Text.Encoding]::ASCII.GetBytes($Text))
}

function Assert-T00RunSuccessMarker {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][byte[]]$ExpectedBytes,
    [Parameter(Mandatory = $true)][string]$CurrentSid
  )
  $Item = Assert-T00RegularFile $Path 4096
  if ($Item.Length -ne $ExpectedBytes.Length -or
      (Get-T00Sha256File $Path 4096) -cne (Get-T00Sha256Bytes $ExpectedBytes)) {
    Stop-T00 "BLOCKED_POST_GATE_CLEANUP"
  }
  [void](Assert-T00PrivateAcl $Path $CurrentSid)
}

function Write-T00JsonAtomic {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)]$Value
  )
  $Json = $Value | ConvertTo-Json -Depth 24 -Compress
  $Bytes = [Text.UTF8Encoding]::new($false).GetBytes($Json + "`n")
  if ($Bytes.Length -gt $script:MaximumManifestBytes) {
    Stop-T00 "BLOCKED_RUNTIME_SEAL"
  }
  Write-T00BytesAtomic $Path $Bytes
  return Get-T00Sha256Bytes $Bytes
}

function Read-T00VerifiedJson {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$ExpectedDigest,
    [Int64]$MaximumBytes = 134217728
  )
  if ($ExpectedDigest -cnotmatch $script:DigestPattern) {
    Stop-T00 "BLOCKED_MANIFEST_IDENTITY"
  }
  $Item = Assert-T00RegularFile $Path $MaximumBytes
  try {
    $Bytes = [IO.File]::ReadAllBytes($Item.FullName)
  } catch {
    Stop-T00 "BLOCKED_MANIFEST_IDENTITY"
  }
  if ($Bytes.Length -ne $Item.Length -or $Bytes.Length -gt $MaximumBytes) {
    Stop-T00 "BLOCKED_MANIFEST_IDENTITY"
  }
  $ActualDigest = Get-T00Sha256Bytes $Bytes
  if ($ActualDigest -cne $ExpectedDigest.ToUpperInvariant()) {
    Stop-T00 "BLOCKED_MANIFEST_IDENTITY"
  }
  try {
    return ([Text.Encoding]::UTF8.GetString($Bytes) | ConvertFrom-Json)
  } catch {
    Stop-T00 "BLOCKED_MANIFEST_IDENTITY"
  }
}

function New-T00Nonce {
  $Bytes = New-Object byte[] 16
  $Rng = [Security.Cryptography.RandomNumberGenerator]::Create()
  try {
    $Rng.GetBytes($Bytes)
    return ([BitConverter]::ToString($Bytes)).Replace("-", "").ToLowerInvariant()
  } finally {
    $Rng.Dispose()
  }
}

function Get-T00FullPath {
  param([Parameter(Mandatory = $true)][string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path) -or
      $Path -match '[\x00-\x1F]' -or
      $Path.StartsWith("\\") -or
      $Path.StartsWith("\\?\") -or
      $Path.StartsWith("\\.\")) {
    Stop-T00 "BLOCKED_INPUT_CONTRACT"
  }
  try {
    $Full = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
  } catch {
    Stop-T00 "BLOCKED_INPUT_CONTRACT"
  }
  if ($Full -cnotmatch '^[A-Za-z]:\\') {
    Stop-T00 "BLOCKED_INPUT_CONTRACT"
  }
  return $Full
}

function Get-T00PathStateNoFollow {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [string]$FailureCategory = "BLOCKED_MANIFEST_IDENTITY"
  )
  $Full = Get-T00FullPath $Path
  $PathRoot = [IO.Path]::GetPathRoot($Full)
  $Relative = $Full.Substring($PathRoot.Length)
  if ($Relative -match ':' -or [string]::IsNullOrWhiteSpace($PathRoot)) {
    Stop-T00 $FailureCategory
  }
  $Segments = @($Relative.Split([char[]]@('\'), [StringSplitOptions]::RemoveEmptyEntries))
  if ($Segments.Count -lt 1) { Stop-T00 $FailureCategory }
  $Current = $PathRoot
  for ($Index = 0; $Index -lt $Segments.Count; $Index += 1) {
    try {
      $Entries = @(Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath $Current -Force -ErrorAction Stop)
    } catch {
      Stop-T00 $FailureCategory
    }
    $Matches = @($Entries | Where-Object { $_.Name -ieq $Segments[$Index] })
    if ($Matches.Count -eq 0) {
      return [PSCustomObject]@{ State = "ABSENT"; FullPath = $Full }
    }
    if ($Matches.Count -ne 1) { Stop-T00 $FailureCategory }
    $Item = $Matches[0]
    if (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      Stop-T00 $FailureCategory
    }
    $Last = $Index -eq ($Segments.Count - 1)
    if (-not $Last -and -not $Item.PSIsContainer) { Stop-T00 $FailureCategory }
    if ($Last) {
      return [PSCustomObject]@{
        State = if ($Item.PSIsContainer) { "DIRECTORY" } else { "FILE" }
        FullPath = $Full
      }
    }
    $Current = $Item.FullName
  }
  Stop-T00 $FailureCategory
}

function Test-T00PathWithin {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Root
  )
  $FullPath = Get-T00FullPath $Path
  $FullRoot = Get-T00FullPath $Root
  return $FullPath.StartsWith($FullRoot + "\", [StringComparison]::OrdinalIgnoreCase)
}

function Assert-T00NoReparseAncestors {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [switch]$AllowLeafAbsent,
    [string]$FailureCategory = "BLOCKED_MANIFEST_IDENTITY"
  )
  $Full = Get-T00FullPath $Path
  $State = Get-T00PathStateNoFollow $Full $FailureCategory
  if ($State.State -ceq "ABSENT" -and -not $AllowLeafAbsent) {
    Stop-T00 $FailureCategory
  }
  return $Full
}

function Get-T00RelativePath {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$Path
  )
  $FullRoot = Get-T00FullPath $Root
  $FullPath = Get-T00FullPath $Path
  if (-not $FullPath.StartsWith($FullRoot + "\", [StringComparison]::OrdinalIgnoreCase)) {
    Stop-T00 "BLOCKED_RUNTIME_SEAL"
  }
  $Relative = $FullPath.Substring($FullRoot.Length + 1).Replace('\', '/')
  if ([string]::IsNullOrWhiteSpace($Relative) -or
      $Relative -match '[\x00-\x1F|]' -or
      $Relative.StartsWith("/") -or
      $Relative.Split('/') -contains "..") {
    Stop-T00 "BLOCKED_RUNTIME_SEAL"
  }
  return $Relative
}

function Resolve-T00Application {
  param([Parameter(Mandatory = $true)][string]$Name)
  try {
    $Commands = @(
      Microsoft.PowerShell.Core\Get-Command -Name $Name -CommandType Application -All -ErrorAction Stop
    )
  } catch {
    Stop-T00 "BLOCKED_TOOLCHAIN"
  }
  if ($Commands.Count -lt 1 -or [string]::IsNullOrWhiteSpace([string]$Commands[0].Path)) {
    Stop-T00 "BLOCKED_TOOLCHAIN"
  }
  $Path = Get-T00FullPath ([string]$Commands[0].Path)
  [void](Assert-T00RegularFile $Path 1073741824)
  return $Path
}

function Stop-T00NativeProcess {
  param(
    [Parameter(Mandatory = $true)][Diagnostics.Process]$Process,
    [switch]$Tree
  )
  $Succeeded = $true
  if ($Tree) {
    if ($Process.HasExited) {
      # An exited root cannot provide a trustworthy tree handle for a
      # descendant that may still own redirected output handles.
      $Succeeded = $false
    } else {
      $Taskkill = Join-Path ([Environment]::SystemDirectory) "taskkill.exe"
      if ((Get-T00PathStateNoFollow $Taskkill "BLOCKED_TOOLCHAIN").State -cne "FILE") {
        $Succeeded = $false
      } else {
        try {
          $KillResult = Invoke-T00Native $Taskkill @(
            "/PID", [string]$Process.Id, "/T", "/F"
          ) ([Environment]::SystemDirectory) 20
          if (-not $KillResult.Started -or $KillResult.RunnerFault -or
              $KillResult.TimedOut -or -not $KillResult.CleanupSucceeded -or
              $KillResult.OutputTruncated -or $null -eq $KillResult.ExitCode -or
              $KillResult.ExitCode -ne 0) {
            $Succeeded = $false
          }
        } catch {
          $Succeeded = $false
        }
      }
    }
  }
  if (-not $Process.HasExited) {
    try { $Process.Kill() } catch { $Succeeded = $false }
  }
  try { if (-not $Process.WaitForExit(10000)) { $Succeeded = $false } } catch { $Succeeded = $false }
  return $Succeeded
}

function Invoke-T00SafeNativeProcessCleanup {
  param(
    [Parameter(Mandatory = $true)][Diagnostics.Process]$Process,
    [switch]$Tree
  )
  try {
    return [bool](Stop-T00NativeProcess $Process -Tree:$Tree)
  } catch {
    # Best-effort direct-parent kill only; any helper exception leaves the
    # requested cleanup unproven and therefore returns false.
    try { $Process.Kill() } catch { }
    try { [void]$Process.WaitForExit(10000) } catch { }
    return $false
  }
}

function Invoke-T00Native {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [string[]]$ArgumentList = @(),
    [Parameter(Mandatory = $true)][string]$WorkingDirectory,
    [Parameter(Mandatory = $true)][int]$TimeoutSeconds,
    [hashtable]$EnvironmentSet = @{},
    [string[]]$EnvironmentRemove = @(),
    [switch]$KillTreeOnTimeout
  )
  [void](Assert-T00RegularFile $FilePath 1073741824)
  if ((Get-T00PathStateNoFollow $WorkingDirectory "BLOCKED_TOOLCHAIN").State -cne "DIRECTORY" -or
      $TimeoutSeconds -lt 1 -or $TimeoutSeconds -gt 3600) {
    Stop-T00 "BLOCKED_TOOLCHAIN"
  }
  $CommandLine = @($ArgumentList | ForEach-Object {
    ConvertTo-T00WindowsArgument ([string]$_)
  }) -join " "
  $StartInfo = New-Object Diagnostics.ProcessStartInfo
  $StartInfo.FileName = $FilePath
  $StartInfo.Arguments = $CommandLine
  $StartInfo.WorkingDirectory = $WorkingDirectory
  $StartInfo.UseShellExecute = $false
  $StartInfo.CreateNoWindow = $true
  $StartInfo.RedirectStandardOutput = $true
  $StartInfo.RedirectStandardError = $true
  $Utf8 = New-Object -TypeName Text.UTF8Encoding -ArgumentList $false
  $StartInfo.StandardOutputEncoding = $Utf8
  $StartInfo.StandardErrorEncoding = $Utf8
  foreach ($Name in $EnvironmentRemove) {
    if (-not [string]::IsNullOrWhiteSpace($Name)) {
      $StartInfo.EnvironmentVariables.Remove($Name)
    }
  }
  foreach ($Entry in $EnvironmentSet.GetEnumerator()) {
    $StartInfo.EnvironmentVariables[[string]$Entry.Key] = [string]$Entry.Value
  }
  $Process = New-Object Diagnostics.Process
  $Process.StartInfo = $StartInfo
  $Started = $false
  $TimedOut = $false
  $CleanupSucceeded = $true
  $RunnerFault = $false
  $ExitCode = $null
  $StdOutBuilder = New-Object Text.StringBuilder
  $StdErrBuilder = New-Object Text.StringBuilder
  $OutputTruncated = $false
  try {
    $Started = $Process.Start()
    if (-not $Started) { throw "start" }
    $ChunkSize = 8192
    $OutBuffer = New-Object 'char[]' $ChunkSize
    $ErrBuffer = New-Object 'char[]' $ChunkSize
    $OutRead = $Process.StandardOutput.ReadAsync($OutBuffer, 0, $ChunkSize)
    $ErrRead = $Process.StandardError.ReadAsync($ErrBuffer, 0, $ChunkSize)
    $Deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ($null -ne $OutRead -or $null -ne $ErrRead) {
      $Progress = $false
      if ($null -ne $OutRead -and $OutRead.IsCompleted) {
        $Count = $OutRead.Result
        if ($Count -eq 0) { $OutRead = $null } else {
          $Take = [Math]::Min($Count, $script:CaptureLimitChars - $StdOutBuilder.Length)
          if ($Take -gt 0) { [void]$StdOutBuilder.Append($OutBuffer, 0, $Take) }
          if ($Take -lt $Count) { $OutputTruncated = $true }
          $OutRead = $Process.StandardOutput.ReadAsync($OutBuffer, 0, $ChunkSize)
        }
        $Progress = $true
      }
      if ($null -ne $ErrRead -and $ErrRead.IsCompleted) {
        $Count = $ErrRead.Result
        if ($Count -eq 0) { $ErrRead = $null } else {
          $Take = [Math]::Min($Count, $script:CaptureLimitChars - $StdErrBuilder.Length)
          if ($Take -gt 0) { [void]$StdErrBuilder.Append($ErrBuffer, 0, $Take) }
          if ($Take -lt $Count) { $OutputTruncated = $true }
          $ErrRead = $Process.StandardError.ReadAsync($ErrBuffer, 0, $ChunkSize)
        }
        $Progress = $true
      }
      if ([DateTime]::UtcNow -ge $Deadline) {
        $TimedOut = $true
        $CleanupSucceeded = $false
        $CleanupSucceeded = Invoke-T00SafeNativeProcessCleanup $Process -Tree:$KillTreeOnTimeout
        break
      }
      if (-not $Progress) { [Threading.Thread]::Sleep(10) }
    }
    if (-not $TimedOut) {
      $Remaining = [int][Math]::Max(1, ($Deadline - [DateTime]::UtcNow).TotalMilliseconds)
      if (-not $Process.WaitForExit($Remaining)) {
        $TimedOut = $true
        $CleanupSucceeded = $false
        $CleanupSucceeded = Invoke-T00SafeNativeProcessCleanup $Process -Tree:$KillTreeOnTimeout
      } else {
        $Process.WaitForExit()
        $ExitCode = $Process.ExitCode
      }
    }
  } catch {
    $RunnerFault = $true
    if ($Started) {
      $CleanupSucceeded = $false
      $CleanupSucceeded = Invoke-T00SafeNativeProcessCleanup $Process -Tree:$KillTreeOnTimeout
    }
  } finally {
    $Process.Dispose()
  }
  if (-not $CleanupSucceeded) {
    $script:FailureCleanupCode = "N"
    $script:PrepareCleanupCode = "N"
    $script:NativeCleanupUncertain = $true
  }
  return [PSCustomObject]@{
    Started = $Started
    TimedOut = $TimedOut
    CleanupSucceeded = $CleanupSucceeded
    RunnerFault = $RunnerFault
    ExitCode = $ExitCode
    StdOut = $StdOutBuilder.ToString()
    StdErr = $StdErrBuilder.ToString()
    OutputTruncated = $OutputTruncated
  }
}

function Assert-T00NativeSuccess {
  param(
    [Parameter(Mandatory = $true)]$Invocation,
    [Parameter(Mandatory = $true)][string]$FailureCategory
  )
  if (-not $Invocation.Started -or $Invocation.RunnerFault -or
      $Invocation.TimedOut -or -not $Invocation.CleanupSucceeded -or
      $Invocation.OutputTruncated -or $null -eq $Invocation.ExitCode -or
      $Invocation.ExitCode -ne 0) {
    Stop-T00 $FailureCategory
  }
}

function Get-T00NativeSingleLine {
  param(
    [Parameter(Mandatory = $true)]$Invocation,
    [Parameter(Mandatory = $true)][string]$FailureCategory
  )
  Assert-T00NativeSuccess $Invocation $FailureCategory
  $Value = ([string]$Invocation.StdOut).Trim()
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -match "[`r`n]") {
    Stop-T00 $FailureCategory
  }
  return $Value
}

function Get-T00EnvironmentKeysForRemoval {
  $Keys = @{}
  foreach ($Key in @($script:StartupOverrideKeys + $script:ManagedEnterpriseEnvironmentKeys + @(
    "NODE_ENV", "npm_config_cache", "npm_config_logs_dir", "npm_config_devdir",
    "npm_config_userconfig", "npm_config_globalconfig"
  ))) {
    $Keys[[string]$Key] = $true
  }
  $EnvironmentTable = [Environment]::GetEnvironmentVariables([EnvironmentVariableTarget]::Process)
  foreach ($KeyObject in $EnvironmentTable.Keys) {
    $Key = [string]$KeyObject
    if ($Key -match '^(?i:GIT_|npm_config_)' -or
        $Key -match '(?i)(TOKEN|SECRET|PASSWORD|PASSWD|API_?KEY|CREDENTIAL)' -or
        $Key -match '^(?i:ANTHROPIC|CLAUDE|CCR|CODEXL|OPENAI|AZURE|AWS|GOOGLE|GCP|GEMINI)_') {
      $Keys[$Key] = $true
    }
  }
  return @($Keys.Keys)
}

function Get-T00GitEnvironmentKeys {
  $Keys = New-Object "Collections.Generic.List[string]"
  $EnvironmentTable = [Environment]::GetEnvironmentVariables([EnvironmentVariableTarget]::Process)
  foreach ($KeyObject in $EnvironmentTable.Keys) {
    $Key = [string]$KeyObject
    if ($Key -match '^(?i:GIT_)') { $Keys.Add($Key) }
  }
  return @($Keys)
}

function Assert-T00NoStartupOverrides {
  foreach ($Target in @(
    [EnvironmentVariableTarget]::Process,
    [EnvironmentVariableTarget]::User,
    [EnvironmentVariableTarget]::Machine
  )) {
    foreach ($Key in $script:StartupOverrideKeys) {
      $Value = [Environment]::GetEnvironmentVariable($Key, $Target)
      if ($null -ne $Value -and $Value.Length -gt 0) {
        Stop-T00 "BLOCKED_RUNTIME_ENV"
      }
    }
  }
}

function Get-T00CurrentIdentity {
  try {
    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Sid = $Identity.User.Value
    $Name = $Identity.Name
  } catch {
    Stop-T00 "BLOCKED_WINDOWS_RUNTIME"
  }
  if ($Sid -cnotmatch '^S-1-5-[0-9-]+$' -or [string]::IsNullOrWhiteSpace($Name)) {
    Stop-T00 "BLOCKED_WINDOWS_RUNTIME"
  }
  return [PSCustomObject]@{ Sid = $Sid; Name = $Name }
}

function Set-T00PrivateDirectoryAcl {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$CurrentSid
  )
  $Full = Get-T00FullPath $Path
  if ((Get-T00PathStateNoFollow $Full "BLOCKED_SANDBOX").State -cne "DIRECTORY") {
    Stop-T00 "BLOCKED_SANDBOX"
  }
  $UserSid = New-Object -TypeName Security.Principal.SecurityIdentifier -ArgumentList $CurrentSid
  $SystemSid = New-Object -TypeName Security.Principal.SecurityIdentifier -ArgumentList $script:SystemSid
  $Security = New-Object Security.AccessControl.DirectorySecurity
  $Security.SetOwner($UserSid)
  $Security.SetAccessRuleProtection($true, $false)
  $Inheritance = [Security.AccessControl.InheritanceFlags]::ContainerInherit -bor
    [Security.AccessControl.InheritanceFlags]::ObjectInherit
  $Propagation = [Security.AccessControl.PropagationFlags]::None
  foreach ($Sid in @($UserSid, $SystemSid)) {
    $Rule = New-Object -TypeName Security.AccessControl.FileSystemAccessRule -ArgumentList @(
      $Sid,
      [Security.AccessControl.FileSystemRights]::FullControl,
      $Inheritance,
      $Propagation,
      [Security.AccessControl.AccessControlType]::Allow
    )
    [void]$Security.AddAccessRule($Rule)
  }
  try {
    [IO.Directory]::SetAccessControl($Full, $Security)
  } catch {
    Stop-T00 "BLOCKED_SANDBOX"
  }
  Assert-T00PrivateAcl $Full $CurrentSid -RequireProtected
}

function Assert-T00PrivateAcl {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$CurrentSid,
    [switch]$RequireProtected
  )
  try {
    $Item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      Stop-T00 "BLOCKED_SANDBOX"
    }
    $Security = if ($Item.PSIsContainer) {
      [IO.Directory]::GetAccessControl($Item.FullName, [Security.AccessControl.AccessControlSections]::Access -bor [Security.AccessControl.AccessControlSections]::Owner)
    } else {
      [IO.File]::GetAccessControl($Item.FullName, [Security.AccessControl.AccessControlSections]::Access -bor [Security.AccessControl.AccessControlSections]::Owner)
    }
    $Owner = $Security.GetOwner([Security.Principal.SecurityIdentifier]).Value
    if ($Owner -cne $CurrentSid) { Stop-T00 "BLOCKED_SANDBOX" }
    if ($RequireProtected -and -not $Security.AreAccessRulesProtected) {
      Stop-T00 "BLOCKED_SANDBOX"
    }
    $Rules = @($Security.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))
    if ($Rules.Count -lt 2) { Stop-T00 "BLOCKED_SANDBOX" }
    $Seen = @{}
    foreach ($Rule in $Rules) {
      $RuleSid = $Rule.IdentityReference.Value
      if (@($CurrentSid, $script:SystemSid) -cnotcontains $RuleSid -or
          $Rule.AccessControlType -ne [Security.AccessControl.AccessControlType]::Allow -or
          (($Rule.FileSystemRights -band [Security.AccessControl.FileSystemRights]::FullControl) -ne
            [Security.AccessControl.FileSystemRights]::FullControl)) {
        Stop-T00 "BLOCKED_SANDBOX"
      }
      $Seen[$RuleSid] = $true
    }
    if (-not $Seen.ContainsKey($CurrentSid) -or -not $Seen.ContainsKey($script:SystemSid)) {
      Stop-T00 "BLOCKED_SANDBOX"
    }
    return $Security.GetSecurityDescriptorSddlForm([Security.AccessControl.AccessControlSections]::Access -bor [Security.AccessControl.AccessControlSections]::Owner)
  } catch {
    if ($_.Exception.Message -match '^T00_STOP::') { throw }
    Stop-T00 "BLOCKED_SANDBOX"
  }
}

function New-T00PrivateDirectory {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$CurrentSid
  )
  $Full = Get-T00FullPath $Path
  if ((Get-T00PathStateNoFollow $Full "BLOCKED_SANDBOX").State -cne "ABSENT") {
    Stop-T00 "BLOCKED_SANDBOX"
  }
  $Missing = New-Object "Collections.Generic.List[string]"
  $Cursor = $Full
  while ($true) {
    $State = Get-T00PathStateNoFollow $Cursor "BLOCKED_SANDBOX"
    if ($State.State -ceq "DIRECTORY") { break }
    if ($State.State -cne "ABSENT" -or $Missing.Count -ge 3) {
      Stop-T00 "BLOCKED_SANDBOX"
    }
    $Missing.Add($Cursor)
    $Parent = Split-Path -Parent $Cursor
    if ([string]::IsNullOrWhiteSpace($Parent) -or $Parent -ieq $Cursor) {
      Stop-T00 "BLOCKED_SANDBOX"
    }
    $Cursor = Get-T00FullPath $Parent
  }
  for ($Index = $Missing.Count - 1; $Index -ge 0; $Index -= 1) {
    $CreatePath = $Missing[$Index]
    $CreateParent = Split-Path -Parent $CreatePath
    if ((Get-T00PathStateNoFollow $CreateParent "BLOCKED_SANDBOX").State -cne "DIRECTORY" -or
        (Get-T00PathStateNoFollow $CreatePath "BLOCKED_SANDBOX").State -cne "ABSENT") {
      Stop-T00 "BLOCKED_SANDBOX"
    }
    [void][IO.Directory]::CreateDirectory($CreatePath)
    Set-T00PrivateDirectoryAcl $CreatePath $CurrentSid
  }
  return $Full
}

function Get-T00OrdinalSortedStrings {
  param([Parameter(Mandatory = $true)][object[]]$Values)
  $Strings = New-Object string[] $Values.Count
  for ($Index = 0; $Index -lt $Values.Count; $Index += 1) {
    $Strings[$Index] = [string]$Values[$Index]
  }
  [Array]::Sort($Strings, [StringComparer]::Ordinal)
  return $Strings
}

function Get-T00WorkspaceLinks {
  param([Parameter(Mandatory = $true)][string]$ExecutionRoot)
  $PackageRoot = Join-Path $ExecutionRoot "packages"
  $NodeModules = Join-Path $ExecutionRoot "node_modules"
  $Map = @{}
  $Packages = @(Get-ChildItem -LiteralPath $PackageRoot -Directory -Force -ErrorAction Stop)
  foreach ($PackageDirectory in $Packages) {
    if (($PackageDirectory.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      Stop-T00 "BLOCKED_RUNTIME_SEAL"
    }
    $PackageFile = Join-Path $PackageDirectory.FullName "package.json"
    $PackageFileState = Get-T00PathStateNoFollow $PackageFile "BLOCKED_RUNTIME_SEAL"
    if ($PackageFileState.State -ceq "ABSENT") { continue }
    if ($PackageFileState.State -cne "FILE") { Stop-T00 "BLOCKED_RUNTIME_SEAL" }
    try {
      $Package = [IO.File]::ReadAllText($PackageFile, [Text.Encoding]::UTF8) | ConvertFrom-Json
      $Name = [string]$Package.name
    } catch {
      Stop-T00 "BLOCKED_RUNTIME_SEAL"
    }
    if ($Name -cnotmatch '^(?:@[A-Za-z0-9._-]+/)?[A-Za-z0-9._-]+$') {
      Stop-T00 "BLOCKED_RUNTIME_SEAL"
    }
    $LinkPath = Join-Path $NodeModules ($Name.Replace('/', '\'))
    $LinkRelative = Get-T00RelativePath $ExecutionRoot $LinkPath
    $TargetRelative = Get-T00RelativePath $ExecutionRoot $PackageDirectory.FullName
    $Map[$LinkRelative] = $TargetRelative
  }
  if ($Map.Count -ne 4) {
    Stop-T00 "BLOCKED_RUNTIME_SEAL"
  }
  return $Map
}

function Resolve-T00LinkTarget {
  param(
    [Parameter(Mandatory = $true)]$Item,
    [Parameter(Mandatory = $true)][string]$ExecutionRoot
  )
  $TargetValue = $Item.Target
  if ($TargetValue -is [array]) { $TargetValue = $TargetValue[0] }
  if ([string]::IsNullOrWhiteSpace([string]$TargetValue)) {
    Stop-T00 "BLOCKED_RUNTIME_SEAL"
  }
  $TargetText = [string]$TargetValue
  $TargetPath = if ([IO.Path]::IsPathRooted($TargetText)) {
    $TargetText
  } else {
    Join-Path (Split-Path -Parent $Item.FullName) $TargetText
  }
  $Full = Get-T00FullPath $TargetPath
  if (-not (Test-T00PathWithin $Full $ExecutionRoot) -or
      (Get-T00PathStateNoFollow $Full "BLOCKED_RUNTIME_SEAL").State -cne "DIRECTORY") {
    Stop-T00 "BLOCKED_RUNTIME_SEAL"
  }
  return $Full
}

function Get-T00TreeSeal {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [hashtable]$AllowedLinks = @{},
    [switch]$ValidatePrivateAcl,
    [string]$CurrentSid = "",
    [switch]$AllowEmpty
  )
  $FullRoot = Get-T00FullPath $Root
  if ((Get-T00PathStateNoFollow $FullRoot "BLOCKED_RUNTIME_SEAL").State -cne "DIRECTORY") {
    Stop-T00 "BLOCKED_RUNTIME_SEAL"
  }
  $RootItem = Get-Item -LiteralPath $FullRoot -Force -ErrorAction Stop
  if (($RootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    Stop-T00 "BLOCKED_RUNTIME_SEAL"
  }
  if ($ValidatePrivateAcl) {
    [void](Assert-T00PrivateAcl $FullRoot $CurrentSid -RequireProtected)
  }
  $Rows = New-Object "Collections.Generic.List[string]"
  $Junctions = New-Object "Collections.Generic.List[object]"
  $SeenRelative = @{}
  $Pending = New-Object "Collections.Generic.Stack[string]"
  $Pending.Push($FullRoot)
  [Int64]$TotalBytes = 0
  while ($Pending.Count -gt 0) {
    $Directory = $Pending.Pop()
    $Entries = @(Get-ChildItem -LiteralPath $Directory -Force -ErrorAction Stop)
    foreach ($Entry in $Entries) {
      $Relative = Get-T00RelativePath $FullRoot $Entry.FullName
      $Key = $Relative.ToLowerInvariant()
      if ($SeenRelative.ContainsKey($Key)) {
        Stop-T00 "BLOCKED_RUNTIME_SEAL"
      }
      $SeenRelative[$Key] = $true
      if ($Rows.Count + $Junctions.Count -ge $script:MaximumTreeEntries) {
        Stop-T00 "BLOCKED_RUNTIME_SEAL"
      }
      $IsReparse = (($Entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
      if ($IsReparse) {
        if (-not $Entry.PSIsContainer -or -not $AllowedLinks.ContainsKey($Relative)) {
          Stop-T00 "BLOCKED_RUNTIME_SEAL"
        }
        $ResolvedTarget = Resolve-T00LinkTarget $Entry $FullRoot
        $TargetRelative = Get-T00RelativePath $FullRoot $ResolvedTarget
        if ($TargetRelative -cne [string]$AllowedLinks[$Relative]) {
          Stop-T00 "BLOCKED_RUNTIME_SEAL"
        }
        $Junctions.Add([PSCustomObject]@{ Path = $Relative; Target = $TargetRelative })
        continue
      }
      if ($ValidatePrivateAcl) {
        [void](Assert-T00PrivateAcl $Entry.FullName $CurrentSid)
      }
      if ($Entry.PSIsContainer) {
        $Rows.Add(("D|{0}:{1}" -f $Relative.Length, $Relative))
        $Pending.Push($Entry.FullName)
        continue
      }
      if ($Entry -isnot [IO.FileInfo] -or $Entry.Length -lt 0) {
        Stop-T00 "BLOCKED_RUNTIME_SEAL"
      }
      $TotalBytes += [Int64]$Entry.Length
      if ($TotalBytes -gt $script:MaximumTreeBytes) {
        Stop-T00 "BLOCKED_RUNTIME_SEAL"
      }
      $Hash = Get-T00Sha256File $Entry.FullName
      $Rows.Add(("F|{0}:{1}|{2}|{3}" -f $Relative.Length, $Relative, $Entry.Length, $Hash))
    }
  }
  $BaseRows = @(Get-T00OrdinalSortedStrings @($Rows))
  foreach ($Junction in $Junctions) {
    $Prefix = $Junction.Target + "/"
    $TargetRows = @($BaseRows | Where-Object {
      $_ -match '^[DF]\|[0-9]+:(?<path>[^|]+)' -and
      ($Matches["path"] -ceq $Junction.Target -or $Matches["path"].StartsWith($Prefix, [StringComparison]::Ordinal))
    })
    if ($TargetRows.Count -eq 0) {
      Stop-T00 "BLOCKED_RUNTIME_SEAL"
    }
    $TargetDigest = Get-T00Sha256Text ($TargetRows -join "`0")
    $Rows.Add(("J|{0}:{1}|{2}:{3}|{4}" -f
      $Junction.Path.Length, $Junction.Path,
      $Junction.Target.Length, $Junction.Target, $TargetDigest))
  }
  if ($Junctions.Count -ne $AllowedLinks.Count) {
    Stop-T00 "BLOCKED_RUNTIME_SEAL"
  }
  $SortedRows = @(Get-T00OrdinalSortedStrings @($Rows))
  if ($SortedRows.Count -eq 0 -and -not $AllowEmpty) {
    Stop-T00 "BLOCKED_RUNTIME_SEAL"
  }
  return [PSCustomObject]@{
    Rows = $SortedRows
    Digest = Get-T00Sha256Text ($SortedRows -join "`0")
    EntryCount = $SortedRows.Count
    TotalBytes = $TotalBytes
    LinkCount = $Junctions.Count
  }
}

function Remove-T00TreeNoFollow {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$CurrentSid
  )
  try {
    $FullRoot = Get-T00FullPath $Root
    if ((Get-T00PathStateNoFollow $FullRoot "BLOCKED_CLEANUP").State -cne "DIRECTORY") {
      Stop-T00 "BLOCKED_CLEANUP"
    }
    [void](Assert-T00NoReparseAncestors $FullRoot -FailureCategory "BLOCKED_CLEANUP")
    [void](Assert-T00PrivateAcl $FullRoot $CurrentSid -RequireProtected)
    $Files = New-Object "Collections.Generic.List[string]"
    $Directories = New-Object "Collections.Generic.List[string]"
    $Pending = New-Object "Collections.Generic.Stack[string]"
    $Pending.Push($FullRoot)
    while ($Pending.Count -gt 0) {
      $Directory = $Pending.Pop()
      $Directories.Add($Directory)
      foreach ($Entry in @(Get-ChildItem -LiteralPath $Directory -Force -ErrorAction Stop)) {
        if (($Entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
          Stop-T00 "BLOCKED_CLEANUP"
        }
        [void](Assert-T00PrivateAcl $Entry.FullName $CurrentSid)
        if ($Entry.PSIsContainer) { $Pending.Push($Entry.FullName) } else { $Files.Add($Entry.FullName) }
      }
    }
    # Narrow the same-account race window at the destructive boundary.
    [void](Assert-T00NoReparseAncestors $FullRoot -FailureCategory "BLOCKED_CLEANUP")
    foreach ($File in $Files) { [IO.File]::Delete($File) }
    $DirectoryArray = @($Directories | Sort-Object { $_.Length } -Descending)
    foreach ($Directory in $DirectoryArray) {
      [IO.Directory]::Delete($Directory, $false)
    }
    if (-not (Test-T00PathAbsent $FullRoot "BLOCKED_CLEANUP")) {
      Stop-T00 "BLOCKED_CLEANUP"
    }
  } catch {
    Stop-T00 "BLOCKED_CLEANUP"
  }
}

function Get-T00SourceSeal {
  param([Parameter(Mandatory = $true)][string]$ExecutionRoot)
  $Rows = New-Object "Collections.Generic.List[string]"
  $Root = Get-T00FullPath $ExecutionRoot
  $Pending = New-Object "Collections.Generic.Stack[string]"
  $Pending.Push($Root)
  while ($Pending.Count -gt 0) {
    $Directory = $Pending.Pop()
    foreach ($Entry in @(Get-ChildItem -LiteralPath $Directory -Force -ErrorAction Stop)) {
      $Relative = Get-T00RelativePath $Root $Entry.FullName
      $IsReparse = (($Entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
      if ($IsReparse) { Stop-T00 "BLOCKED_RUNTIME_SEAL" }
      if ($Entry.PSIsContainer) {
        if ($Relative -imatch '(^|/)node_modules$' -or $Relative -imatch '^packages/[^/]+/dist$') {
          continue
        }
        $Pending.Push($Entry.FullName)
      } else {
        $Rows.Add(("{0}:{1}|{2}|{3}" -f $Relative.Length, $Relative, $Entry.Length, (Get-T00Sha256File $Entry.FullName)))
      }
    }
  }
  $Sorted = @(Get-T00OrdinalSortedStrings @($Rows))
  if ($Sorted.Count -eq 0) { Stop-T00 "BLOCKED_RUNTIME_SEAL" }
  return Get-T00Sha256Text ($Sorted -join "`0")
}

function Invoke-T00Git {
  param(
    [Parameter(Mandatory = $true)][string]$GitExe,
    [Parameter(Mandatory = $true)][string]$GitDir,
    [Parameter(Mandatory = $true)][string]$WorkingDirectory,
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [int]$TimeoutSeconds = 120
  )
  $EnvironmentSet = @{
    "GIT_CONFIG_NOSYSTEM" = "1"
    "GIT_CONFIG_GLOBAL" = "NUL"
    "GIT_OPTIONAL_LOCKS" = "0"
    "GIT_TERMINAL_PROMPT" = "0"
  }
  return Invoke-T00Native $GitExe (@("--no-replace-objects", "--git-dir=$GitDir") + $Arguments) `
    $WorkingDirectory $TimeoutSeconds $EnvironmentSet (Get-T00GitEnvironmentKeys) -KillTreeOnTimeout
}

function Get-T00GitLine {
  param(
    [Parameter(Mandatory = $true)][string]$GitExe,
    [Parameter(Mandatory = $true)][string]$GitDir,
    [Parameter(Mandatory = $true)][string]$WorkingDirectory,
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [string]$FailureCategory = "BLOCKED_SOURCE_IDENTITY"
  )
  $Result = Invoke-T00Git $GitExe $GitDir $WorkingDirectory $Arguments
  return Get-T00NativeSingleLine $Result $FailureCategory
}

function Get-T00GitChangedPaths {
  param(
    [Parameter(Mandatory = $true)][string]$GitExe,
    [Parameter(Mandatory = $true)][string]$GitDir,
    [Parameter(Mandatory = $true)][string]$WorkingDirectory,
    [Parameter(Mandatory = $true)][string]$Base,
    [Parameter(Mandatory = $true)][string]$Head
  )
  $Result = Invoke-T00Git $GitExe $GitDir $WorkingDirectory @(
    "diff", "--name-only", "-z", "--no-renames", $Base, $Head, "--"
  )
  Assert-T00NativeSuccess $Result "BLOCKED_SOURCE_IDENTITY"
  return @(([string]$Result.StdOut).Split([char[]]@([char]0), [StringSplitOptions]::RemoveEmptyEntries))
}

function Assert-T00TaskContract {
  param([Parameter(Mandatory = $true)][string]$TaskText)
  $Patterns = @(
    '(?m)^id:\s*V1-S1-T00\s*$',
    '(?m)^stage:\s*V1-S1\s*$',
    '(?m)^status:\s*ready_internal\s*$',
    '(?m)^primary_actor:\s*INTERNAL_VALIDATOR\s*$',
    '(?m)^execution_mode:\s*human_assisted\s*$',
    '(?m)^implementation_required:\s*true\s*$',
    '(?m)^internal_validation:\s*required\s*$',
    '(?m)^github_write_allowed:\s*false\s*$',
    '(?m)^candidate_role:\s*validation_overlay\s*$',
    '(?m)^tested_product_sha:\s*97b73a9f4e1fb23d406bb987d0785cefa1f99966\s*$',
    '(?m)^implementation_base_sha:\s*e6fe7e3b00dd42311cb30d88472949b03d18a2aa\s*$',
    '(?m)^merge_policy:\s*internal_pass_required\s*$',
    '(?m)^authorized_phase:\s*ATTEMPT_4_PREPARE_AND_H0_RUNTIME_AFTER_EXACT_HEAD_HUMAN_APPROVAL\s*$',
    '(?m)^\s*- WINDOWS_RUNTIME_ALLOWED\s*$',
    '(?m)^\s*- CLAUDE_CODE_EXECUTION_ALLOWED\s*$'
  )
  foreach ($Pattern in $Patterns) {
    if ($TaskText -cnotmatch $Pattern) { Stop-T00 "BLOCKED_TASK_METADATA" }
  }
  $AllowedBlock = [regex]::Match(
    $TaskText,
    '(?ms)^allowed_paths:\s*\r?\n(?<paths>(?:\s{2}- [^\r\n]+\r?\n)+)forbidden_paths:'
  )
  if (-not $AllowedBlock.Success) { Stop-T00 "BLOCKED_TASK_METADATA" }
  $Declared = @(
    [regex]::Matches($AllowedBlock.Groups["paths"].Value, '(?m)^\s{2}- (?<path>[^\r\n]+)$') |
      ForEach-Object { $_.Groups["path"].Value }
  )
  $Expected = @(Get-T00OrdinalSortedStrings @($script:TaskAllowedPaths))
  $Actual = @(Get-T00OrdinalSortedStrings @($Declared))
  if (($Actual -join "`0") -cne ($Expected -join "`0")) {
    Stop-T00 "BLOCKED_TASK_METADATA"
  }
  foreach ($RequiredPhrase in @(
    "Runtime controller: IMPLEMENTED / EXTERNAL_REVIEW_PASS",
    "Attempt 4: NOT_STARTED",
    "ConfirmStockGetAppInfoResidualRisk"
  )) {
    if (-not $TaskText.Contains($RequiredPhrase)) { Stop-T00 "BLOCKED_TASK_METADATA" }
  }
}

function Get-T00HostContext {
  if (-not [Environment]::Is64BitOperatingSystem -or
      -not [Environment]::Is64BitProcess -or
      $PSVersionTable.PSEdition -cne "Desktop" -or
      $PSVersionTable.PSVersion.Major -ne 5 -or
      $PSVersionTable.PSVersion.Minor -ne 1) {
    Stop-T00 "BLOCKED_WINDOWS_RUNTIME"
  }
  $Identity = Get-T00CurrentIdentity
  $RealLocalAppData = Get-T00FullPath ([Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData))
  $RealAppData = Get-T00FullPath ([Environment]::GetFolderPath([Environment+SpecialFolder]::ApplicationData))
  $RealUserProfile = Get-T00FullPath ([Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile))
  foreach ($Pair in @(
    @("LOCALAPPDATA", $RealLocalAppData),
    @("APPDATA", $RealAppData),
    @("USERPROFILE", $RealUserProfile)
  )) {
    $ProcessValue = [Environment]::GetEnvironmentVariable($Pair[0], [EnvironmentVariableTarget]::Process)
    if ([string]::IsNullOrWhiteSpace($ProcessValue) -or
        (Get-T00FullPath $ProcessValue) -ine $Pair[1]) {
      Stop-T00 "BLOCKED_WINDOWS_RUNTIME"
    }
    [void](Assert-T00NoReparseAncestors $Pair[1])
  }
  $MachineSystemRoot = [Environment]::GetEnvironmentVariable("SystemRoot", [EnvironmentVariableTarget]::Machine)
  $MachineWindir = [Environment]::GetEnvironmentVariable("windir", [EnvironmentVariableTarget]::Machine)
  if ([string]::IsNullOrWhiteSpace($MachineSystemRoot) -or [string]::IsNullOrWhiteSpace($MachineWindir)) {
    Stop-T00 "BLOCKED_WINDOWS_RUNTIME"
  }
  $SystemRoot = Get-T00FullPath $MachineSystemRoot
  if ((Get-T00FullPath $MachineWindir) -ine $SystemRoot) {
    Stop-T00 "BLOCKED_WINDOWS_RUNTIME"
  }
  $PowerShellExe = Get-T00FullPath (Join-Path $SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe")
  $WhereExe = Get-T00FullPath (Join-Path $SystemRoot "System32\where.exe")
  [void](Assert-T00NoReparseAncestors $PowerShellExe)
  [void](Assert-T00NoReparseAncestors $WhereExe)
  [void](Assert-T00RegularFile $PowerShellExe 67108864)
  [void](Assert-T00RegularFile $WhereExe 67108864)
  try {
    $CurrentExecutable = Get-T00FullPath ([Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
  } catch {
    Stop-T00 "BLOCKED_WINDOWS_RUNTIME"
  }
  if ($CurrentExecutable -ine $PowerShellExe) {
    Stop-T00 "BLOCKED_WINDOWS_RUNTIME"
  }
  return [PSCustomObject]@{
    Identity = $Identity
    LocalAppData = $RealLocalAppData
    AppData = $RealAppData
    UserProfile = $RealUserProfile
    SystemRoot = $SystemRoot
    PowerShellExe = $PowerShellExe
    PowerShellHash = Get-T00Sha256File $PowerShellExe
    WhereExe = $WhereExe
    WhereHash = Get-T00Sha256File $WhereExe
  }
}

function Get-T00PreparedWorkspace {
  param(
    [Parameter(Mandatory = $true)][string]$GitDir,
    [Parameter(Mandatory = $true)]$HostContext
  )
  $FullGitDir = Get-T00FullPath $GitDir
  [void](Assert-T00NoReparseAncestors $FullGitDir -FailureCategory "BLOCKED_PREPARED_REPOSITORY")
  if ((Get-T00PathStateNoFollow $FullGitDir "BLOCKED_PREPARED_REPOSITORY").State -cne "DIRECTORY" -or
      (Split-Path -Leaf $FullGitDir) -cne "repo.git") {
    Stop-T00 "BLOCKED_PREPARED_REPOSITORY"
  }
  $ValidationRoot = Get-T00FullPath (Split-Path -Parent $FullGitDir)
  $Workspace = Split-Path -Leaf $ValidationRoot
  $ExpectedParent = Get-T00FullPath (Join-Path $HostContext.LocalAppData "CompanyCCR\validation-workspaces")
  if ((Split-Path -Parent $ValidationRoot) -ine $ExpectedParent -or
      $Workspace -cnotmatch $script:WorkspacePattern -or
      $Workspace -ceq "4b5fc32468f4a9c103af7686987e9b26") {
    Stop-T00 "BLOCKED_PREPARED_REPOSITORY"
  }
  try {
    [void](Assert-T00PrivateAcl $ValidationRoot $HostContext.Identity.Sid -RequireProtected)
    [void](Assert-T00PrivateAcl $FullGitDir $HostContext.Identity.Sid)
  } catch {
    Stop-T00 "BLOCKED_PREPARED_REPOSITORY"
  }
  $InitialEntries = @(Get-ChildItem -LiteralPath $ValidationRoot -Force -ErrorAction Stop)
  if ($InitialEntries.Count -ne 1 -or $InitialEntries[0].FullName -ine $FullGitDir) {
    Stop-T00 "BLOCKED_PREPARED_REPOSITORY"
  }
  return [PSCustomObject]@{
    Id = $Workspace
    GitDir = $FullGitDir
    Root = $ValidationRoot
    ExecutionRoot = Join-Path $ValidationRoot "source"
    ControlRoot = Join-Path $ValidationRoot "control"
    CacheRoot = Join-Path $ValidationRoot "npm-cache"
    LogsRoot = Join-Path $ValidationRoot "npm-logs"
    TempRoot = Join-Path $ValidationRoot "build-temp"
    NodeGypRoot = Join-Path $ValidationRoot "node-gyp"
    SandboxRoot = Join-Path $HostContext.AppData ("CompanyCCR\runtime-localappdata\" + $Workspace)
    RecoveryRoot = Join-Path $HostContext.LocalAppData ("CompanyCCR\recovery\" + $Workspace)
  }
}

function Get-T00NodeRuntimeBinding {
  param(
    [Parameter(Mandatory = $true)][string]$NodeExe,
    [Parameter(Mandatory = $true)][string]$ExecutionRoot,
    [Parameter(Mandatory = $true)][string]$CliPath,
    [Parameter(Mandatory = $true)][string[]]$EnvironmentRemove,
    [switch]$SmokeDatabase
  )
  $Probe = @'
const fs = require("node:fs");
const path = require("node:path");
const { createRequire } = require("node:module");
const cli = path.resolve(process.argv[1]);
const req = createRequire(cli);
const entry = req.resolve("better-sqlite3");
const packageFile = req.resolve("better-sqlite3/package.json");
const native = path.join(path.dirname(packageFile), "build", "Release", "better_sqlite3.node");
if (!fs.statSync(entry).isFile() || !fs.statSync(native).isFile()) process.exit(2);
if (process.argv[2] === "SMOKE") {
  const Database = req("better-sqlite3");
  const db = new Database(":memory:");
  db.prepare("SELECT 1 AS ok").get();
  db.close();
} else if (process.argv[2] !== "RESOLVE_ONLY") {
  process.exit(3);
}
process.stdout.write(JSON.stringify({ entry: path.resolve(entry), native: path.resolve(native) }));
'@
  $ProbeMode = if ($SmokeDatabase) { "SMOKE" } else { "RESOLVE_ONLY" }
  $Result = Invoke-T00Native $NodeExe @("-e", $Probe, $CliPath, $ProbeMode) `
    $ExecutionRoot 120 @{} $EnvironmentRemove
  $Line = Get-T00NativeSingleLine $Result "BLOCKED_RUNTIME_SEAL"
  try { $Value = $Line | ConvertFrom-Json } catch { Stop-T00 "BLOCKED_RUNTIME_SEAL" }
  $Entry = Get-T00FullPath ([string]$Value.entry)
  $Native = Get-T00FullPath ([string]$Value.native)
  if (-not (Test-T00PathWithin $Entry $ExecutionRoot) -or
      -not (Test-T00PathWithin $Native $ExecutionRoot)) {
    Stop-T00 "BLOCKED_RUNTIME_SEAL"
  }
  return [PSCustomObject]@{
    Entry = $Entry
    EntryRelative = Get-T00RelativePath $ExecutionRoot $Entry
    EntryHash = Get-T00Sha256File $Entry
    Native = $Native
    NativeRelative = Get-T00RelativePath $ExecutionRoot $Native
    NativeHash = Get-T00Sha256File $Native
  }
}

function Assert-T00RuntimeSeal {
  param(
    [Parameter(Mandatory = $true)]$Manifest,
    [Parameter(Mandatory = $true)][string]$NodeExe
  )
  $ExecutionRoot = Get-T00FullPath ([string]$Manifest.workspace.executionRoot)
  if ((Get-T00Sha256File $NodeExe) -cne [string]$Manifest.toolchain.nodeHash) {
    Stop-T00 "BLOCKED_RUNTIME_SEAL"
  }
  $CliPath = Join-Path $ExecutionRoot ([string]$Manifest.runtime.cliRelative).Replace('/', '\')
  $ModelPath = Join-Path $ExecutionRoot ([string]$Manifest.runtime.modelCatalogRelative).Replace('/', '\')
  if ((Get-T00Sha256File $CliPath) -cne [string]$Manifest.runtime.cliHash -or
      (Get-T00Sha256File $ModelPath) -cne [string]$Manifest.runtime.modelCatalogHash) {
    Stop-T00 "BLOCKED_RUNTIME_SEAL"
  }
  $Binding = Get-T00NodeRuntimeBinding $NodeExe $ExecutionRoot $CliPath (Get-T00EnvironmentKeysForRemoval)
  if ($Binding.EntryRelative -cne [string]$Manifest.runtime.moduleRelative -or
      $Binding.EntryHash -cne [string]$Manifest.runtime.moduleHash -or
      $Binding.NativeRelative -cne [string]$Manifest.runtime.nativeRelative -or
      $Binding.NativeHash -cne [string]$Manifest.runtime.nativeHash) {
    Stop-T00 "BLOCKED_RUNTIME_SEAL"
  }
  $Links = @{}
  foreach ($Link in @($Manifest.runtime.workspaceLinks)) {
    $Links[[string]$Link.path] = [string]$Link.target
  }
  $Seal = Get-T00TreeSeal $ExecutionRoot $Links
  if ($Seal.Digest -cne [string]$Manifest.runtime.digest -or
      $Seal.EntryCount -ne [int]$Manifest.runtime.entryCount -or
      $Seal.TotalBytes -ne [Int64]$Manifest.runtime.totalBytes -or
      ($Seal.Rows -join "`0") -cne (@($Manifest.runtime.rows) -join "`0")) {
    Stop-T00 "BLOCKED_RUNTIME_SEAL"
  }
}

function Get-T00RuntimePaths {
  param([Parameter(Mandatory = $true)]$HostContext)
  $ConfigDir = Join-Path $HostContext.AppData "claude-code-router"
  return [PSCustomObject]@{
    ConfigDir = $ConfigDir
    ServiceFile = Join-Path $ConfigDir "service.json"
    ServiceStartLock = Join-Path $ConfigDir "service-start.lock"
    StockBackupFile = Join-Path $ConfigDir "claude-app-gateway-backup.json"
    ConfigDb = Join-Path $ConfigDir "config.sqlite"
    ActualClaudeRoot = Join-Path $HostContext.LocalAppData "Claude-3p"
    EnterpriseSettings = Join-Path $HostContext.UserProfile ".claude\settings.json"
  }
}

function Assert-T00RuntimePreconditions {
  param(
    [Parameter(Mandatory = $true)]$HostContext,
    [Parameter(Mandatory = $true)]$Paths
  )
  $ConfigState = Get-T00PathStateNoFollow $Paths.ConfigDir "BLOCKED_RUNTIME_ENV"
  if ($ConfigState.State -ceq "FILE") { Stop-T00 "BLOCKED_RUNTIME_ENV" }
  foreach ($BlockedPath in @($Paths.ServiceFile, $Paths.ServiceStartLock, $Paths.StockBackupFile)) {
    if (-not (Test-T00PathAbsent $BlockedPath "BLOCKED_PREEXISTING_SERVICE")) {
      if ($BlockedPath -ieq $Paths.StockBackupFile) {
        Stop-T00 "BLOCKED_STALE_BACKUP"
      }
      Stop-T00 "BLOCKED_PREEXISTING_SERVICE"
    }
  }
  $LegacyWindowsRoot = Join-Path $HostContext.AppData "Claude Code Router"
  $LegacyPaths = @(
    $LegacyWindowsRoot,
    (Join-Path $Paths.ConfigDir "config.json"),
    (Join-Path $Paths.ConfigDir "api-keys.sqlite"),
    (Join-Path $Paths.ConfigDir "api-keys.sqlite-wal"),
    (Join-Path $Paths.ConfigDir "api-keys.sqlite-shm"),
    (Join-Path $Paths.ConfigDir ".onboard_finished"),
    (Join-Path $HostContext.UserProfile ".claude-code-router\config.json")
  )
  foreach ($LegacyPath in $LegacyPaths) {
    if (-not (Test-T00PathAbsent $LegacyPath "BLOCKED_LEGACY_SOURCE")) {
      Stop-T00 "BLOCKED_LEGACY_SOURCE"
    }
  }
}

function Get-T00ProcessIdentity {
  param(
    [Parameter(Mandatory = $true)][int]$ProcessId,
    [Parameter(Mandatory = $true)][string]$ExpectedOwner
  )
  try {
    $Processes = @(Get-CimInstance -ClassName Win32_Process -Filter ("ProcessId = {0}" -f $ProcessId) -ErrorAction Stop)
    if ($Processes.Count -ne 1) { Stop-T00 "BLOCKED_SERVICE_IDENTITY" }
    $Process = $Processes[0]
    $Owner = Invoke-CimMethod -InputObject $Process -MethodName GetOwner -ErrorAction Stop
    $OwnerName = if ([string]::IsNullOrWhiteSpace([string]$Owner.Domain)) {
      [string]$Owner.User
    } else {
      ([string]$Owner.Domain) + "\" + ([string]$Owner.User)
    }
    if ($Owner.ReturnValue -ne 0 -or $OwnerName -ine $ExpectedOwner) {
      Stop-T00 "BLOCKED_SERVICE_IDENTITY"
    }
    $Executable = Get-T00FullPath ([string]$Process.ExecutablePath)
    $CreationTime = ([DateTimeOffset]$Process.CreationDate).ToUniversalTime().ToString("o")
    return [PSCustomObject]@{
      Executable = $Executable
      CreationTime = $CreationTime
      Owner = $OwnerName
    }
  } catch {
    if ($_.Exception.Message -match '^T00_STOP::') { throw }
    Stop-T00 "BLOCKED_SERVICE_IDENTITY"
  }
}

function Assert-T00NoRelevantWriters {
  param(
    [Parameter(Mandatory = $true)][string]$CurrentIdentityName,
    [int[]]$AllowedProcessIds = @()
  )
  try {
    $Processes = @(Get-CimInstance -ClassName Win32_Process -ErrorAction Stop)
  } catch {
    Stop-T00 "BLOCKED_RELEVANT_WRITER"
  }
  foreach ($Process in $Processes) {
    $PidValue = [int]$Process.ProcessId
    if ($PidValue -eq $PID -or $AllowedProcessIds -contains $PidValue) { continue }
    $Name = ([string]$Process.Name).ToLowerInvariant()
    $CommandLine = ([string]$Process.CommandLine).ToLowerInvariant()
    $IsGenericRuntime = $Name -eq "node.exe" -or $Name -eq "electron.exe"
    $AmbiguousGenericRuntime = $IsGenericRuntime -and [string]::IsNullOrWhiteSpace($CommandLine)
    $Suspicious = $Name -match 'claude|claude-code-router|^ccr(?:\.exe)?$' -or
      ($IsGenericRuntime -and
        $CommandLine -match 'claude-code-router|@anthropic-ai[\\/]claude-code|company-claude|t00-safe-config-save|companyccr[\\/]validation-workspaces|packages[\\/]cli[\\/]dist[\\/]main[\\/]cli\.js|serve\s+--daemon-child')
    if (-not $Suspicious -and -not $AmbiguousGenericRuntime) { continue }
    try {
      $Owner = Invoke-CimMethod -InputObject $Process -MethodName GetOwner -ErrorAction Stop
      $OwnerName = if ([string]::IsNullOrWhiteSpace([string]$Owner.Domain)) {
        [string]$Owner.User
      } else {
        ([string]$Owner.Domain) + "\" + ([string]$Owner.User)
      }
    } catch {
      Stop-T00 "BLOCKED_RELEVANT_WRITER"
    }
    if ($Owner.ReturnValue -ne 0) { Stop-T00 "BLOCKED_RELEVANT_WRITER" }
    if ($OwnerName -ieq $CurrentIdentityName) { Stop-T00 "BLOCKED_RELEVANT_WRITER" }
  }
}

function Get-T00ListeningConnections {
  param([Parameter(Mandatory = $true)][int]$Port)
  if ($Port -lt 1 -or $Port -gt 65535) { Stop-T00 "BLOCKED_SERVICE_IDENTITY" }
  try {
    [void](Microsoft.PowerShell.Core\Get-Command NetTCPIP\Get-NetTCPConnection -CommandType Cmdlet -ErrorAction Stop)
    $Connections = @(NetTCPIP\Get-NetTCPConnection -ErrorAction Stop)
    return @($Connections | Where-Object {
      [string]$_.State -ceq "Listen" -and [int]$_.LocalPort -eq $Port
    })
  } catch {
    Stop-T00 "BLOCKED_SERVICE_IDENTITY"
  }
}

function Assert-T00PortFree {
  param([Parameter(Mandatory = $true)][int]$Port)
  if ((Get-T00ListeningConnections $Port).Count -ne 0) {
    Stop-T00 "BLOCKED_SERVICE_IDENTITY"
  }
}

function Get-T00FreshLoopbackPort {
  $Listener = New-Object -TypeName Net.Sockets.TcpListener -ArgumentList @([Net.IPAddress]::Loopback, 0)
  try {
    $Listener.Start()
    $Port = [int]$Listener.LocalEndpoint.Port
  } finally {
    $Listener.Stop()
  }
  Assert-T00PortFree $Port
  return $Port
}

function Read-T00ServiceState {
  param(
    [Parameter(Mandatory = $true)][string]$ServiceFile,
    [Parameter(Mandatory = $true)][DateTimeOffset]$NotBefore,
    [Parameter(Mandatory = $true)][int]$ExpectedPort
  )
  $Item = Assert-T00RegularFile $ServiceFile 65536
  $Raw = [IO.File]::ReadAllText($Item.FullName, [Text.Encoding]::UTF8)
  try { $Value = $Raw | ConvertFrom-Json } catch { Stop-T00 "BLOCKED_SERVICE_IDENTITY" }
  $ExpectedKeys = @("host", "pid", "profileManaged", "serviceToken", "startedAt", "startGateway", "url")
  $ActualKeys = @($Value.PSObject.Properties.Name)
  if (((Get-T00OrdinalSortedStrings $ActualKeys) -join "`0") -cne
      ((Get-T00OrdinalSortedStrings $ExpectedKeys) -join "`0")) {
    Stop-T00 "BLOCKED_SERVICE_IDENTITY"
  }
  $PidValue = 0
  if (-not [int]::TryParse(([string]$Value.pid), [ref]$PidValue) -or $PidValue -le 0 -or
      [string]$Value.host -cne "127.0.0.1" -or
      $Value.profileManaged -isnot [bool] -or $Value.profileManaged -ne $false -or
      $Value.startGateway -isnot [bool] -or $Value.startGateway -ne $false -or
      ([string]$Value.serviceToken) -cnotmatch '^[A-Za-z0-9_-]{20,256}$') {
    Stop-T00 "BLOCKED_SERVICE_IDENTITY"
  }
  try { $StartedAt = [DateTimeOffset]::Parse([string]$Value.startedAt).ToUniversalTime() } catch {
    Stop-T00 "BLOCKED_SERVICE_IDENTITY"
  }
  if ($StartedAt -lt $NotBefore.AddSeconds(-2) -or $StartedAt -gt [DateTimeOffset]::UtcNow.AddMinutes(2)) {
    Stop-T00 "BLOCKED_SERVICE_IDENTITY"
  }
  try { $Uri = New-Object -TypeName Uri -ArgumentList ([string]$Value.url) } catch {
    Stop-T00 "BLOCKED_SERVICE_IDENTITY"
  }
  if ($Uri.Scheme -cne "http" -or $Uri.Host -cne "127.0.0.1" -or
      $Uri.Port -ne $ExpectedPort -or $Uri.AbsolutePath -cne "/" -or
      -not [string]::IsNullOrEmpty($Uri.Fragment) -or
      -not [string]::IsNullOrEmpty($Uri.UserInfo)) {
    Stop-T00 "BLOCKED_SERVICE_IDENTITY"
  }
  $Query = $Uri.Query
  if ($Query -cnotmatch '^\?ccr_web_token=(?<token>[A-Za-z0-9_-]{20,256})$') {
    Stop-T00 "BLOCKED_SERVICE_IDENTITY"
  }
  return [PSCustomObject]@{
    Pid = $PidValue
    ServiceToken = [string]$Value.serviceToken
    StartedAt = $StartedAt.ToString("o")
    Url = [string]$Value.url
    WebToken = $Matches["token"]
    RawDigest = Get-T00Sha256Text $Raw
  }
}

function Invoke-T00Rpc {
  param(
    [Parameter(Mandatory = $true)]$Binding,
    [Parameter(Mandatory = $true)][string]$Method,
    [object[]]$Arguments = @(),
    [int]$TimeoutMilliseconds = 4000
  )
  if ($Method -cnotmatch '^[A-Za-z][A-Za-z0-9]+$' -or
      $TimeoutMilliseconds -lt 500 -or $TimeoutMilliseconds -gt 30000) {
    Stop-T00 "BLOCKED_SERVICE_IDENTITY"
  }
  $Payload = [ordered]@{ args = $Arguments; method = $Method }
  $Json = $Payload | ConvertTo-Json -Depth 12 -Compress
  $Bytes = [Text.Encoding]::UTF8.GetBytes($Json)
  if ($Bytes.Length -gt 8388608) { Stop-T00 "BLOCKED_SERVICE_IDENTITY" }
  $Request = [Net.HttpWebRequest]::Create(("http://127.0.0.1:{0}/api/ccr/rpc" -f $Binding.Port))
  $Request.Method = "POST"
  $Request.ContentType = "application/json"
  $Request.Accept = "application/json"
  $Request.ContentLength = $Bytes.Length
  $Request.Timeout = $TimeoutMilliseconds
  $Request.ReadWriteTimeout = $TimeoutMilliseconds
  $Request.KeepAlive = $false
  $Request.Proxy = $null
  $Request.Headers.Add("x-ccr-web-auth", [string]$Binding.WebToken)
  $Deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
  $ResponseText = $null
  $RequestDispatched = $false
  try {
    $RequestAsync = $Request.BeginGetRequestStream($null, $null)
    $Remaining = [int][Math]::Floor(($Deadline - [DateTime]::UtcNow).TotalMilliseconds)
    if ($Remaining -lt 1 -or -not $RequestAsync.AsyncWaitHandle.WaitOne($Remaining)) {
      $Request.Abort()
      Stop-T00 "BLOCKED_SERVICE_IDENTITY"
    }
    $RequestStream = $Request.EndGetRequestStream($RequestAsync)
    try {
      $Remaining = [int][Math]::Floor(($Deadline - [DateTime]::UtcNow).TotalMilliseconds)
      if ($Remaining -lt 1 -or -not $RequestStream.CanTimeout) {
        Stop-T00 "BLOCKED_SERVICE_IDENTITY"
      }
      $RequestStream.WriteTimeout = $Remaining
      $RequestDispatched = $true
      $RequestStream.Write($Bytes, 0, $Bytes.Length)
    } finally { $RequestStream.Dispose() }
    $ResponseAsync = $Request.BeginGetResponse($null, $null)
    $Remaining = [int][Math]::Floor(($Deadline - [DateTime]::UtcNow).TotalMilliseconds)
    if ($Remaining -lt 1 -or -not $ResponseAsync.AsyncWaitHandle.WaitOne($Remaining)) {
      $Request.Abort()
      Stop-T00 "BLOCKED_SERVICE_IDENTITY"
    }
    $Response = [Net.HttpWebResponse]$Request.EndGetResponse($ResponseAsync)
    try {
      if ([int]$Response.StatusCode -ne 200 -or
          -not ([string]$Response.ContentType).ToLowerInvariant().StartsWith("application/json")) {
        Stop-T00 "BLOCKED_SERVICE_IDENTITY"
      }
      $Input = $Response.GetResponseStream()
      $Output = New-Object IO.MemoryStream
      try {
        if (-not $Input.CanTimeout) { Stop-T00 "BLOCKED_SERVICE_IDENTITY" }
        $Buffer = New-Object byte[] 8192
        [Int64]$Total = 0
        while ($true) {
          $Remaining = [int][Math]::Floor(($Deadline - [DateTime]::UtcNow).TotalMilliseconds)
          if ($Remaining -lt 1) { Stop-T00 "BLOCKED_SERVICE_IDENTITY" }
          $Input.ReadTimeout = $Remaining
          $Count = $Input.Read($Buffer, 0, $Buffer.Length)
          if ($Count -eq 0) { break }
          $Total += $Count
          if ($Total -gt 8388608) { Stop-T00 "BLOCKED_SERVICE_IDENTITY" }
          $Output.Write($Buffer, 0, $Count)
        }
        $ResponseText = [Text.Encoding]::UTF8.GetString($Output.ToArray())
      } finally {
        $Input.Dispose()
        $Output.Dispose()
      }
    } finally {
      $Response.Dispose()
    }
  } catch {
    $Caught = $_
    try { $Request.Abort() } catch { }
    if ($Method -ceq "getAppInfo" -and $RequestDispatched) {
      $script:GetAppInfoUncertain = $true
    }
    if ($Caught.Exception.Message -match '^T00_STOP::') { throw $Caught }
    Stop-T00 "BLOCKED_SERVICE_IDENTITY"
  }
  $ResponseValidated = $false
  try {
    try { $Parsed = $ResponseText | ConvertFrom-Json } catch { Stop-T00 "BLOCKED_SERVICE_IDENTITY" }
    if (@($Parsed.PSObject.Properties.Name) -cnotcontains "ok" -or $Parsed.ok -ne $true -or
        @($Parsed.PSObject.Properties.Name) -cnotcontains "value") {
      Stop-T00 "BLOCKED_SERVICE_IDENTITY"
    }
    $Value = $Parsed.value
    $ResponseValidated = $true
    return $Value
  } finally {
    if ($Method -ceq "getAppInfo" -and $RequestDispatched -and -not $ResponseValidated) {
      $script:GetAppInfoUncertain = $true
    }
  }
}

function Assert-T00GatewayStopped {
  param(
    [Parameter(Mandatory = $true)]$Status,
    [ValidateSet("PRE_SAVE", "POST_SAVE", "CLEANUP")][string]$EndpointMode = "PRE_SAVE",
    $ExpectedGatewayPorts = $null
  )
  $Properties = @($Status.PSObject.Properties.Name)
  foreach ($Required in @("state", "endpoint", "coreEndpoint", "networkEndpoints")) {
    if ($Properties -cnotcontains $Required) { Stop-T00 "BLOCKED_GATEWAY_STATE" }
  }
  $PidProperty = $Status.PSObject.Properties["pid"]
  $GatewayExternal = $Status.PSObject.Properties["gatewayManagedExternally"]
  $CoreExternal = $Status.PSObject.Properties["coreManagedExternally"]
  $LastError = $Status.PSObject.Properties["lastError"]
  $LastStarted = $Status.PSObject.Properties["lastStartedAt"]
  if ([string]$Status.state -cne "stopped" -or
      $Status.endpoint -isnot [string] -or $Status.coreEndpoint -isnot [string] -or
      $null -ne $PidProperty -or
      ($null -ne $GatewayExternal -and
        ($GatewayExternal.Value -isnot [bool] -or $GatewayExternal.Value -ne $false)) -or
      ($null -ne $CoreExternal -and
        ($CoreExternal.Value -isnot [bool] -or $CoreExternal.Value -ne $false)) -or
      $null -ne $LastError -or $null -ne $LastStarted -or
      $Status.networkEndpoints -isnot [Array] -or
      @($Status.networkEndpoints).Count -ne 0) {
    Stop-T00 "BLOCKED_GATEWAY_STATE"
  }
  $EmptyEndpoints = $Status.endpoint -ceq "" -and $Status.coreEndpoint -ceq ""
  if ($EndpointMode -ceq "PRE_SAVE") {
    if (-not $EmptyEndpoints) { Stop-T00 "BLOCKED_GATEWAY_STATE" }
    return
  }
  $GatewayPort = 0
  $CorePort = 0
  if ($null -eq $ExpectedGatewayPorts -or
      -not [int]::TryParse(([string]$ExpectedGatewayPorts.Gateway), [ref]$GatewayPort) -or
      -not [int]::TryParse(([string]$ExpectedGatewayPorts.Core), [ref]$CorePort) -or
      $GatewayPort -lt 1 -or $GatewayPort -gt 65535 -or
      $CorePort -lt 1 -or $CorePort -gt 65535 -or $GatewayPort -eq $CorePort) {
    Stop-T00 "BLOCKED_GATEWAY_STATE"
  }
  $ConfiguredEndpoints = $Status.endpoint -ceq ("http://127.0.0.1:{0}" -f $GatewayPort) -and
    $Status.coreEndpoint -ceq ("http://127.0.0.1:{0}" -f $CorePort)
  if (($EndpointMode -ceq "POST_SAVE" -and -not $ConfiguredEndpoints) -or
      ($EndpointMode -ceq "CLEANUP" -and -not $EmptyEndpoints -and -not $ConfiguredEndpoints)) {
    Stop-T00 "BLOCKED_GATEWAY_STATE"
  }
}

function Get-T00ServiceBinding {
  param(
    [Parameter(Mandatory = $true)]$Manifest,
    [Parameter(Mandatory = $true)]$HostContext,
    [Parameter(Mandatory = $true)]$Paths,
    [Parameter(Mandatory = $true)][DateTimeOffset]$NotBefore,
    [Parameter(Mandatory = $true)][int]$ExpectedPort,
    $ExpectedBinding = $null,
    [switch]$IncludeAppInfo,
    [ValidateSet("PRE_SAVE", "POST_SAVE", "CLEANUP")][string]$GatewayEndpointMode = "PRE_SAVE",
    $ExpectedGatewayPorts = $null
  )
  $State = Read-T00ServiceState $Paths.ServiceFile $NotBefore $ExpectedPort
  if ($null -ne $ExpectedBinding -and
      ($State.Pid -ne $ExpectedBinding.Pid -or
       $State.RawDigest -cne $ExpectedBinding.RawDigest -or
       $State.ServiceToken -cne $ExpectedBinding.ServiceToken -or
       $State.WebToken -cne $ExpectedBinding.WebToken -or
       $State.StartedAt -cne $ExpectedBinding.StartedAt)) {
    Stop-T00 "BLOCKED_SERVICE_IDENTITY"
  }
  $ProcessIdentity = Get-T00ProcessIdentity $State.Pid $HostContext.Identity.Name
  $NodeExe = Get-T00FullPath ([string]$Manifest.toolchain.nodePath)
  if ($ProcessIdentity.Executable -ine $NodeExe -or
      ($null -ne $ExpectedBinding -and $ProcessIdentity.CreationTime -cne $ExpectedBinding.ProcessCreationTime)) {
    Stop-T00 "BLOCKED_SERVICE_IDENTITY"
  }
  $Connections = @(Get-T00ListeningConnections $ExpectedPort)
  if ($Connections.Count -ne 1 -or
      [int]$Connections[0].OwningProcess -ne $State.Pid -or
      [string]$Connections[0].LocalAddress -cne "127.0.0.1") {
    Stop-T00 "BLOCKED_SERVICE_IDENTITY"
  }
  $RpcBinding = [PSCustomObject]@{ Port = $ExpectedPort; WebToken = $State.WebToken }
  $Identity = Invoke-T00Rpc $RpcBinding "getServiceIdentity" @($State.ServiceToken)
  if ([int]$Identity.pid -ne $State.Pid -or
      $Identity.serviceTokenConfigured -ne $true -or $Identity.serviceTokenMatches -ne $true) {
    Stop-T00 "BLOCKED_SERVICE_IDENTITY"
  }
  $GatewayStatus = Invoke-T00Rpc $RpcBinding "getGatewayStatus"
  Assert-T00GatewayStopped $GatewayStatus $GatewayEndpointMode $ExpectedGatewayPorts
  if ($IncludeAppInfo) {
    $AppInfo = Invoke-T00Rpc $RpcBinding "getAppInfo" @() 15000
    try {
      $AppConfigDir = Get-T00FullPath ([string]$AppInfo.configDir)
      $AppDataDir = Get-T00FullPath ([string]$AppInfo.dataDir)
      $AppConfigDb = Get-T00FullPath ([string]$AppInfo.configDbFile)
    } catch {
      Stop-T00 "BLOCKED_SERVICE_IDENTITY"
    }
    if ([string]$AppInfo.name -cne "Claude Code Router" -or
        [string]$AppInfo.version -cne "3.0.22" -or
        [string]$AppInfo.platform -cne "win32" -or
        $AppInfo.desktop -isnot [bool] -or $AppInfo.desktop -ne $false -or
        $AppConfigDir -ine (Get-T00FullPath $Paths.ConfigDir) -or
        $AppDataDir -ine (Get-T00FullPath $Paths.ConfigDir) -or
        $AppConfigDb -ine (Get-T00FullPath $Paths.ConfigDb)) {
      Stop-T00 "BLOCKED_SERVICE_IDENTITY"
    }
  }
  return [PSCustomObject]@{
    Pid = $State.Pid
    ServiceToken = $State.ServiceToken
    StartedAt = $State.StartedAt
    WebToken = $State.WebToken
    RawDigest = $State.RawDigest
    ProcessCreationTime = $ProcessIdentity.CreationTime
    Port = $ExpectedPort
  }
}

function Get-T00FileInvariant {
  param(
    [Parameter(Mandatory = $true)][string]$Id,
    [Parameter(Mandatory = $true)][string]$Path,
    [Int64]$MaximumBytes = 16777216
  )
  if (Test-T00PathAbsent $Path "BLOCKED_BASELINE") {
    return [ordered]@{ id = $Id; state = "ABSENT" }
  }
  $Item = Assert-T00RegularFile $Path $MaximumBytes
  return [ordered]@{
    id = $Id
    state = "PRESENT"
    size = [Int64]$Item.Length
    sha256 = Get-T00Sha256File $Item.FullName $MaximumBytes
  }
}

function Get-T00ClaudeResolution {
  try { $Commands = @(Microsoft.PowerShell.Core\Get-Command claude -All -ErrorAction Stop) } catch {
    Stop-T00 "BLOCKED_BASELINE"
  }
  $Rows = New-Object "Collections.Generic.List[string]"
  foreach ($Command in $Commands) {
    $CommandType = [string]$Command.CommandType
    $CommandPath = [string]$Command.Path
    if ([string]::IsNullOrWhiteSpace($CommandPath) -or
        @("Application", "ExternalScript") -cnotcontains $CommandType) {
      continue
    }
    $Full = Get-T00FullPath $CommandPath
    $Item = Assert-T00RegularFile $Full 1073741824
    $Rows.Add(("{0}|{1}|{2}|{3}" -f $CommandType, $Full, $Item.Length, (Get-T00Sha256File $Full)))
  }
  if ($Rows.Count -eq 0) { Stop-T00 "BLOCKED_BASELINE" }
  return @(Get-T00OrdinalSortedStrings @($Rows))
}

function Get-T00EnterpriseSnapshot {
  param(
    [Parameter(Mandatory = $true)]$HostContext,
    [Parameter(Mandatory = $true)]$Paths
  )
  $Files = @(
    (Get-T00FileInvariant "enterprise-settings" $Paths.EnterpriseSettings),
    (Get-T00FileInvariant "claude-root" (Join-Path $Paths.ActualClaudeRoot "claude_desktop_config.json")),
    (Get-T00FileInvariant "claude-meta" (Join-Path $Paths.ActualClaudeRoot "configLibrary\_meta.json")),
    (Get-T00FileInvariant "claude-library" (Join-Path $Paths.ActualClaudeRoot "configLibrary\8f69f2f1-3275-4ad8-9317-4aa7e972f311.json"))
  )
  $EnvironmentRows = New-Object "Collections.Generic.List[string]"
  foreach ($Target in @(
    [EnvironmentVariableTarget]::Process,
    [EnvironmentVariableTarget]::User,
    [EnvironmentVariableTarget]::Machine
  )) {
    foreach ($Key in $script:ManagedEnterpriseEnvironmentKeys) {
      $Value = [Environment]::GetEnvironmentVariable($Key, $Target)
      if ($null -eq $Value) {
        $EnvironmentRows.Add(("{0}|{1}|ABSENT" -f [string]$Target, $Key))
      } else {
        $EnvironmentRows.Add(("{0}|{1}|PRESENT|{2}" -f [string]$Target, $Key, (Get-T00Sha256Text $Value)))
      }
    }
  }
  $Snapshot = [ordered]@{
    schema = "t00-enterprise-snapshot-v1"
    files = $Files
    environment = @(Get-T00OrdinalSortedStrings @($EnvironmentRows))
    claudeResolution = @(Get-T00ClaudeResolution)
  }
  $Json = $Snapshot | ConvertTo-Json -Depth 12 -Compress
  return [PSCustomObject]@{ Value = $Snapshot; Digest = Get-T00Sha256Text $Json }
}

function Assert-T00EnterpriseSame {
  param(
    [Parameter(Mandatory = $true)]$Baseline,
    [Parameter(Mandatory = $true)]$HostContext,
    [Parameter(Mandatory = $true)]$Paths
  )
  try {
    $Current = Get-T00EnterpriseSnapshot $HostContext $Paths
    if ($Current.Digest -cne $Baseline.Digest) {
      Stop-T00 "ISOLATION_BREACH"
    }
    return $Current
  } catch {
    Stop-T00 "ISOLATION_BREACH"
  }
}

function Copy-T00RecoveryFile {
  param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination,
    [Parameter(Mandatory = $true)][Int64]$MaximumBytes,
    [Parameter(Mandatory = $true)][string]$CurrentSid
  )
  $Item = Assert-T00RegularFile $Source $MaximumBytes
  $SourceStream = [IO.File]::Open($Item.FullName, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
  try {
    $Hasher = [Security.Cryptography.SHA256]::Create()
    try {
      $SourceHash = ([BitConverter]::ToString($Hasher.ComputeHash($SourceStream))).Replace("-", "")
    } finally { $Hasher.Dispose() }
    $SourceStream.Position = 0
    $DestinationStream = [IO.File]::Open($Destination, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
      $SourceStream.CopyTo($DestinationStream)
      $DestinationStream.Flush($true)
    } finally { $DestinationStream.Dispose() }
  } finally { $SourceStream.Dispose() }
  if ((Get-T00Sha256File $Destination $MaximumBytes) -cne $SourceHash -or
      (Get-T00Sha256File $Source $MaximumBytes) -cne $SourceHash) {
    Stop-T00 "BLOCKED_BACKUP"
  }
  [void](Assert-T00PrivateAcl $Destination $CurrentSid)
  return [ordered]@{
    state = "PRESENT"
    size = [Int64]$Item.Length
    sha256 = $SourceHash
  }
}

function New-T00RecoveryBackup {
  param(
    [Parameter(Mandatory = $true)]$Manifest,
    [Parameter(Mandatory = $true)]$HostContext,
    [Parameter(Mandatory = $true)]$Paths
  )
  $Root = Get-T00FullPath ([string]$Manifest.workspace.recoveryRoot)
  [void](New-T00PrivateDirectory $Root $HostContext.Identity.Sid)
  $Targets = @(
    [PSCustomObject]@{ Id = "enterprise-settings"; Path = $Paths.EnterpriseSettings; Name = "enterprise-settings.bin"; Max = 16777216 },
    [PSCustomObject]@{ Id = "claude-root"; Path = (Join-Path $Paths.ActualClaudeRoot "claude_desktop_config.json"); Name = "claude-root.bin"; Max = 16777216 },
    [PSCustomObject]@{ Id = "claude-meta"; Path = (Join-Path $Paths.ActualClaudeRoot "configLibrary\_meta.json"); Name = "claude-meta.bin"; Max = 16777216 },
    [PSCustomObject]@{ Id = "claude-library"; Path = (Join-Path $Paths.ActualClaudeRoot "configLibrary\8f69f2f1-3275-4ad8-9317-4aa7e972f311.json"); Name = "claude-library.bin"; Max = 16777216 },
    [PSCustomObject]@{ Id = "ccr-config"; Path = $Paths.ConfigDb; Name = "ccr-config.sqlite.bin"; Max = 536870912 },
    [PSCustomObject]@{ Id = "ccr-config-wal"; Path = ($Paths.ConfigDb + "-wal"); Name = "ccr-config.sqlite-wal.bin"; Max = 536870912 },
    [PSCustomObject]@{ Id = "ccr-config-shm"; Path = ($Paths.ConfigDb + "-shm"); Name = "ccr-config.sqlite-shm.bin"; Max = 67108864 }
  )
  $Entries = New-Object "Collections.Generic.List[object]"
  foreach ($Target in $Targets) {
    if (Test-T00PathAbsent $Target.Path "BLOCKED_BACKUP") {
      $Entries.Add([PSCustomObject][ordered]@{ id = $Target.Id; state = "ABSENT" })
      continue
    }
    $Destination = Join-Path $Root $Target.Name
    $Copy = Copy-T00RecoveryFile $Target.Path $Destination $Target.Max $HostContext.Identity.Sid
    $Entries.Add([PSCustomObject][ordered]@{
      id = $Target.Id
      state = $Copy.state
      relative = $Target.Name
      size = $Copy.size
      sha256 = $Copy.sha256
    })
  }
  $Sddl = Assert-T00PrivateAcl $Root $HostContext.Identity.Sid -RequireProtected
  $RecoveryManifest = [ordered]@{
    schema = "t00-recovery-manifest-v1"
    workspaceId = [string]$Manifest.workspace.id
    candidateSha = [string]$Manifest.authority.candidateSha
    root = $Root
    ownerSid = $HostContext.Identity.Sid
    sddl = $Sddl
    entries = @($Entries)
  }
  $RecoveryManifestPath = Join-Path $Root "recovery-manifest.json"
  $Digest = Write-T00JsonAtomic $RecoveryManifestPath $RecoveryManifest
  [void](Assert-T00PrivateAcl $RecoveryManifestPath $HostContext.Identity.Sid)
  return [PSCustomObject]@{
    Path = $RecoveryManifestPath
    Digest = $Digest
    Root = $Root
    Entries = @($Entries)
  }
}

function Assert-T00BackupMatchesBaseline {
  param(
    [Parameter(Mandatory = $true)]$Backup,
    [Parameter(Mandatory = $true)]$Baseline
  )
  $BackupById = @{}
  foreach ($Entry in @($Backup.Entries)) {
    $Id = [string]$Entry.id
    if ($BackupById.ContainsKey($Id)) { Stop-T00 "BLOCKED_BACKUP" }
    $BackupById[$Id] = $Entry
  }
  foreach ($Invariant in @($Baseline.Value.files)) {
    $Id = [string]$Invariant.id
    if (-not $BackupById.ContainsKey($Id)) { Stop-T00 "BLOCKED_BACKUP" }
    $Entry = $BackupById[$Id]
    if ([string]$Entry.state -cne [string]$Invariant.state) { Stop-T00 "BLOCKED_BACKUP" }
    if ([string]$Invariant.state -ceq "PRESENT" -and
        ([Int64]$Entry.size -ne [Int64]$Invariant.size -or
         [string]$Entry.sha256 -cne [string]$Invariant.sha256)) {
      Stop-T00 "BLOCKED_BACKUP"
    }
  }
}

function Assert-T00RecoveryBackupRetained {
  param(
    [Parameter(Mandatory = $true)]$Backup,
    [Parameter(Mandatory = $true)]$Manifest,
    [Parameter(Mandatory = $true)]$HostContext
  )
  try {
    $Root = Get-T00FullPath ([string]$Backup.Root)
    $ExpectedRoot = Get-T00FullPath ([string]$Manifest.workspace.recoveryRoot)
    $RecoveryManifestPath = Get-T00FullPath ([string]$Backup.Path)
    if ($Root -ine $ExpectedRoot -or
        $RecoveryManifestPath -ine (Join-Path $Root "recovery-manifest.json")) {
      Stop-T00 "BLOCKED_BACKUP"
    }
    [void](Assert-T00NoReparseAncestors $Root -FailureCategory "BLOCKED_BACKUP")
    if ((Get-T00PathStateNoFollow $Root "BLOCKED_BACKUP").State -cne "DIRECTORY") {
      Stop-T00 "BLOCKED_BACKUP"
    }
    $RecoveryManifest = Read-T00VerifiedJson $RecoveryManifestPath ([string]$Backup.Digest) 8388608
    Assert-T00ExactProperties $RecoveryManifest @(
      "schema", "workspaceId", "candidateSha", "root", "ownerSid", "sddl", "entries"
    )
    if ([string]$RecoveryManifest.schema -cne "t00-recovery-manifest-v1" -or
        [string]$RecoveryManifest.workspaceId -cne [string]$Manifest.workspace.id -or
        [string]$RecoveryManifest.candidateSha -cne [string]$Manifest.authority.candidateSha -or
        (Get-T00FullPath ([string]$RecoveryManifest.root)) -ine $Root -or
        [string]$RecoveryManifest.ownerSid -cne $HostContext.Identity.Sid -or
        [string]::IsNullOrWhiteSpace([string]$RecoveryManifest.sddl)) {
      Stop-T00 "BLOCKED_BACKUP"
    }
    $ExpectedEntries = Get-T00RecoveryEntryValidation @($Backup.Entries) $Root $HostContext.Identity.Sid
    $Tree = Get-T00RecoveryTreeValidation $RecoveryManifest $Root $RecoveryManifestPath `
      $HostContext.Identity.Sid ([string]$RecoveryManifest.sddl) ([string]$Backup.Digest)
    if (($ExpectedEntries.Rows -join "`0") -cne ($Tree.EntryRows -join "`0")) {
      Stop-T00 "BLOCKED_BACKUP"
    }
  } catch {
    Stop-T00 "BLOCKED_BACKUP"
  }
}

function Get-T00ChildEnvironment {
  param(
    [Parameter(Mandatory = $true)]$HostContext,
    [Parameter(Mandatory = $true)][string]$LocalAppData
  )
  return [PSCustomObject]@{
    Set = @{
      "LOCALAPPDATA" = $LocalAppData
      "APPDATA" = $HostContext.AppData
      "USERPROFILE" = $HostContext.UserProfile
      "SystemRoot" = $HostContext.SystemRoot
      "windir" = $HostContext.SystemRoot
    }
    Remove = @(Get-T00EnvironmentKeysForRemoval)
  }
}

function Assert-T00ManifestAuthority {
  param(
    [Parameter(Mandatory = $true)]$Manifest,
    [Parameter(Mandatory = $true)]$HostContext,
    [Parameter(Mandatory = $true)][string]$ExpectedWorkspaceId,
    [Parameter(Mandatory = $true)][string]$ExpectedHeadSha,
    [Parameter(Mandatory = $true)][string]$ExpectedManifestPath
  )
  if ([string]$Manifest.schema -cne "t00-prepared-manifest-v1" -or
      [string]$Manifest.taskId -cne $script:TaskId -or
      [string]$Manifest.workspace.id -cne $ExpectedWorkspaceId -or
      [string]$Manifest.authority.mainSha -cne $script:CanonicalMainSha -or
      [string]$Manifest.authority.candidateSha -cne $ExpectedHeadSha -or
      [string]$Manifest.authority.instructionSha -cne $ExpectedHeadSha -or
      [string]$Manifest.authority.implementationBaseSha -cne $script:CanonicalImplementationBaseSha -or
      [string]$Manifest.authority.validatedProductSha -cne $script:CanonicalProductSha -or
      [string]$Manifest.authority.taskPath -cne $script:CanonicalTaskPath -or
      $Manifest.approvals.windowsRuntimeAllowed -ne $true -or
      $Manifest.approvals.claudeCodeExecutionAllowed -ne $true -or
      $Manifest.approvals.noSameAccountConcurrentUse -ne $true -or
      $Manifest.approvals.npmNetworkAndLifecycle -ne $true -or
      $Manifest.approvals.singleSaveIfChangeY -ne $true -or
      $Manifest.approvals.stockGetAppInfoResidualRisk -ne $true) {
    Stop-T00 "BLOCKED_MANIFEST_IDENTITY"
  }
  $ValidationRoot = Get-T00FullPath ([string]$Manifest.workspace.validationRoot)
  $ControlRoot = Get-T00FullPath ([string]$Manifest.workspace.controlRoot)
  $ExecutionRoot = Get-T00FullPath ([string]$Manifest.workspace.executionRoot)
  $ExpectedValidationParent = Get-T00FullPath (Join-Path $HostContext.LocalAppData "CompanyCCR\validation-workspaces")
  $ExpectedSandboxRoot = Get-T00FullPath (Join-Path $HostContext.AppData ("CompanyCCR\runtime-localappdata\" + $ExpectedWorkspaceId))
  $ExpectedRecoveryRoot = Get-T00FullPath (Join-Path $HostContext.LocalAppData ("CompanyCCR\recovery\" + $ExpectedWorkspaceId))
  if ((Split-Path -Leaf $ValidationRoot) -cne $ExpectedWorkspaceId -or
      (Split-Path -Parent $ValidationRoot) -ine $ExpectedValidationParent -or
      -not (Test-T00PathWithin $ControlRoot $ValidationRoot) -or
      -not (Test-T00PathWithin $ExecutionRoot $ValidationRoot) -or
      (Get-T00FullPath ([string]$Manifest.workspace.sandboxRoot)) -ine $ExpectedSandboxRoot -or
      (Get-T00FullPath ([string]$Manifest.workspace.recoveryRoot)) -ine $ExpectedRecoveryRoot -or
      (Get-T00FullPath $ExpectedManifestPath) -ine (Get-T00FullPath ([string]$Manifest.workspace.manifestPath)) -or
      -not (Test-T00PathWithin $ExpectedManifestPath $ControlRoot)) {
    Stop-T00 "BLOCKED_MANIFEST_IDENTITY"
  }
  if ((Get-T00FullPath ([string]$Manifest.workspace.realLocalAppData)) -ine $HostContext.LocalAppData -or
      (Get-T00FullPath ([string]$Manifest.workspace.realAppData)) -ine $HostContext.AppData -or
      (Get-T00FullPath ([string]$Manifest.workspace.realUserProfile)) -ine $HostContext.UserProfile) {
    Stop-T00 "BLOCKED_MANIFEST_IDENTITY"
  }
  [void](Assert-T00NoReparseAncestors $ValidationRoot)
  [void](Assert-T00PrivateAcl $ControlRoot $HostContext.Identity.Sid -RequireProtected)
  $ControllerPath = Get-T00FullPath ([string]$Manifest.artifacts.controllerPath)
  $HelperPath = Get-T00FullPath ([string]$Manifest.artifacts.helperPath)
  $ExpectedArtifactRoot = Join-Path $ControlRoot "candidate"
  $ExpectedControllerPath = Join-Path $ExpectedArtifactRoot $script:ControllerRepositoryPath.Replace('/', '\')
  $ExpectedHelperPath = Join-Path $ExpectedArtifactRoot $script:T02HelperRepositoryPath.Replace('/', '\')
  [void](Assert-T00NoReparseAncestors $ControllerPath)
  [void](Assert-T00NoReparseAncestors $HelperPath)
  if (-not (Test-T00PathWithin $ControllerPath $ControlRoot) -or
      -not (Test-T00PathWithin $HelperPath $ControlRoot) -or
      $ControllerPath -ine $ExpectedControllerPath -or $HelperPath -ine $ExpectedHelperPath -or
      (Get-T00GitBlobSha1 $ControllerPath) -cne [string]$Manifest.artifacts.controllerBlob -or
      (Get-T00GitBlobSha1 $HelperPath) -cne [string]$Manifest.artifacts.helperBlob -or
      [string]$Manifest.artifacts.helperBlob -cne $script:T02HelperBlob -or
      [string]$Manifest.artifacts.helperTestBlob -cne $script:T02TestBlob) {
    Stop-T00 "BLOCKED_ARTIFACT_IDENTITY"
  }
  if ([string]::IsNullOrWhiteSpace($PSCommandPath) -or
      (Get-T00GitBlobSha1 $PSCommandPath) -cne [string]$Manifest.artifacts.controllerBlob) {
    Stop-T00 "BLOCKED_ARTIFACT_IDENTITY"
  }
  if ((Get-T00FullPath ([string]$Manifest.toolchain.powerShellPath)) -ine $HostContext.PowerShellExe -or
      [string]$Manifest.toolchain.powerShellHash -cne $HostContext.PowerShellHash -or
      (Get-T00FullPath ([string]$Manifest.toolchain.wherePath)) -ine $HostContext.WhereExe -or
      [string]$Manifest.toolchain.whereHash -cne $HostContext.WhereHash) {
    Stop-T00 "BLOCKED_TOOLCHAIN"
  }
  if ([string]$Manifest.policy.currentSid -cne $HostContext.Identity.Sid -or
      [string]$Manifest.policy.systemSid -cne $script:SystemSid -or
      $Manifest.policy.controllerDirectNativeProcessesBounded -ne $true -or
      $Manifest.policy.stockGetAppInfoDescendantsBoundedByController -ne $false -or
      $Manifest.policy.stockGetAppInfoResidualRiskReviewed -ne $true) {
    Stop-T00 "BLOCKED_MANIFEST_IDENTITY"
  }
}

function New-T00BootstrapCommand {
  param(
    [Parameter(Mandatory = $true)][string]$PowerShellExe,
    [Parameter(Mandatory = $true)][string]$ManifestPathValue,
    [Parameter(Mandatory = $true)][string]$ManifestDigestValue,
    [Parameter(Mandatory = $true)][string]$WorkspaceIdValue,
    [Parameter(Mandatory = $true)][string]$HeadShaValue,
    [ValidateSet("Run", "CleanupBackup")][string]$Mode = "Run",
    [string]$CleanupTicketPathValue = "",
    [string]$CleanupTicketDigestValue = "",
    [string]$RecoveryManifestDigestValue = ""
  )
  foreach ($Value in @($ManifestPathValue, $ManifestDigestValue, $WorkspaceIdValue, $HeadShaValue,
    $CleanupTicketPathValue, $CleanupTicketDigestValue, $RecoveryManifestDigestValue)) {
    if ($Value -match '[\x00-\x1F]') { Stop-T00 "BLOCKED_INPUT_CONTRACT" }
  }
  $ManifestLiteral = ConvertTo-T00SingleQuotedLiteral $ManifestPathValue
  $DigestLiteral = ConvertTo-T00SingleQuotedLiteral $ManifestDigestValue
  $WorkspaceLiteral = ConvertTo-T00SingleQuotedLiteral $WorkspaceIdValue
  $HeadLiteral = ConvertTo-T00SingleQuotedLiteral $HeadShaValue
  $Bootstrap = @"
& { `$ErrorActionPreference='Stop'; `$mp=$ManifestLiteral; `$md=$DigestLiteral; `$wid=$WorkspaceLiteral; `$head=$HeadLiteral; `$mi=Get-Item -LiteralPath `$mp -Force; if (`$mi -isnot [IO.FileInfo] -or ((`$mi.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) -or `$mi.Length -gt 134217728) { throw 'PRE_EXECUTION_HANDOFF_BLOCKED' }; `$mb=[IO.File]::ReadAllBytes(`$mp); `$sha=[Security.Cryptography.SHA256]::Create(); try { `$mh=([BitConverter]::ToString(`$sha.ComputeHash(`$mb))).Replace('-','') } finally { `$sha.Dispose() }; if (`$mh -cne `$md) { throw 'PRE_EXECUTION_HANDOFF_BLOCKED' }; `$m=([Text.Encoding]::UTF8.GetString(`$mb) | ConvertFrom-Json); if (`$m.schema -cne 't00-prepared-manifest-v1' -or `$m.workspace.id -cne `$wid -or `$m.authority.candidateSha -cne `$head) { throw 'PRE_EXECUTION_HANDOFF_BLOCKED' }; `$cp=[string]`$m.artifacts.controllerPath; `$ci=Get-Item -LiteralPath `$cp -Force; if (`$ci -isnot [IO.FileInfo] -or ((`$ci.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) -or `$ci.Length -gt 8388608) { throw 'PRE_EXECUTION_HANDOFF_BLOCKED' }; `$cb=[IO.File]::ReadAllBytes(`$cp); `$hb=[Text.Encoding]::ASCII.GetBytes((('blob {0}' -f `$cb.Length)+[char]0)); `$all=New-Object byte[] (`$hb.Length+`$cb.Length); [Array]::Copy(`$hb,0,`$all,0,`$hb.Length); [Array]::Copy(`$cb,0,`$all,`$hb.Length,`$cb.Length); `$g=[Security.Cryptography.SHA1]::Create(); try { `$blob=([BitConverter]::ToString(`$g.ComputeHash(`$all))).Replace('-','').ToLowerInvariant() } finally { `$g.Dispose() }; if (`$blob -cne [string]`$m.artifacts.controllerBlob) { throw 'PRE_EXECUTION_HANDOFF_BLOCKED' };
"@
  if ($Mode -ceq "Run") {
    $Bootstrap += " `$p=@{Run=`$true;ManifestPath=`$mp;ManifestDigest=`$md;WorkspaceId=`$wid;ApprovedHeadSha=`$head}; & `$cp @p }"
  } else {
    $TicketPathLiteral = ConvertTo-T00SingleQuotedLiteral $CleanupTicketPathValue
    $TicketDigestLiteral = ConvertTo-T00SingleQuotedLiteral $CleanupTicketDigestValue
    $RecoveryDigestLiteral = ConvertTo-T00SingleQuotedLiteral $RecoveryManifestDigestValue
    $Bootstrap += " `$p=@{CleanupBackup=`$true;ManifestPath=`$mp;ManifestDigest=`$md;WorkspaceId=`$wid;ApprovedHeadSha=`$head;CleanupTicketPath=$TicketPathLiteral;CleanupTicketDigest=$TicketDigestLiteral;RecoveryManifestDigest=$RecoveryDigestLiteral;ConfirmPostGateRecoveryNo=`$true;ConfirmDeleteRecoveryBackup=`$true}; & `$cp @p }"
  }
  $Bootstrap = ($Bootstrap -replace '[\r\n]+', ' ').Trim()
  $OuterScript = ConvertTo-T00SingleQuotedLiteral $Bootstrap
  return "& " + (ConvertTo-T00SingleQuotedLiteral $PowerShellExe) + " -NoProfile -Command " + $OuterScript
}

function Invoke-T00PrepareMode {
  Set-T00Phase "INPUT"
  foreach ($Sha in @($MainSha, $CandidateSha, $InstructionSha, $ImplementationBaseSha, $ValidatedProductSha)) {
    if ($Sha -cnotmatch $script:ShaPattern) { Stop-T00 "BLOCKED_INPUT_CONTRACT" }
  }
  $script:SafeHeadPrefix = $CandidateSha.Substring(0, 12)
  if ($MainSha -cne $script:CanonicalMainSha -or
      $ImplementationBaseSha -cne $script:CanonicalImplementationBaseSha -or
      $ValidatedProductSha -cne $script:CanonicalProductSha -or
      $CandidateSha -cne $InstructionSha -or
      $PreparedCandidateRef -cne $script:CanonicalCandidateRef -or
      $PreparedMainRef -cne $script:CanonicalMainRef -or
      $TaskPath -cne $script:CanonicalTaskPath -or
      $EnvironmentAlias -cnotmatch $script:AliasPattern -or
      -not $ConfirmWindowsRuntimeAllowed -or
      -not $ConfirmClaudeCodeExecutionAllowed -or
      -not $ConfirmNoSameAccountConcurrentUse -or
      -not $AllowNpmNetworkAndLifecycle -or
      -not $ApproveSingleSaveIfChangeY -or
      -not $ConfirmStockGetAppInfoResidualRisk) {
    Stop-T00 "BLOCKED_INPUT_CONTRACT"
  }
  $script:PrepareNpmEffectsAllowed = $true

  Set-T00Phase "HOST"
  $HostContext = Get-T00HostContext
  $Workspace = Get-T00PreparedWorkspace $PreparedGitDir $HostContext
  $script:PrepareWorkspaceId = $Workspace.Id
  $GitExe = Resolve-T00Application "git.exe"
  $NodeExe = Resolve-T00Application "node.exe"
  $NodeDirectory = Split-Path -Parent $NodeExe
  $NpmCli = Join-Path $NodeDirectory "node_modules\npm\bin\npm-cli.js"
  [void](Assert-T00RegularFile $NpmCli 16777216)

  Set-T00Phase "SOURCE"
  if ((Get-T00GitLine $GitExe $Workspace.GitDir $Workspace.Root @("rev-parse", "--is-bare-repository")) -cne "true") {
    Stop-T00 "BLOCKED_PREPARED_REPOSITORY"
  }
  if ((Get-T00GitLine $GitExe $Workspace.GitDir $Workspace.Root @("rev-parse", "--verify", "$PreparedCandidateRef^{commit}")) -cne $CandidateSha -or
      (Get-T00GitLine $GitExe $Workspace.GitDir $Workspace.Root @("rev-parse", "--verify", "$PreparedMainRef^{commit}")) -cne $MainSha) {
    Stop-T00 "BLOCKED_SOURCE_IDENTITY"
  }
  foreach ($Commit in @($InstructionSha, $ImplementationBaseSha, $ValidatedProductSha)) {
    if ((Get-T00GitLine $GitExe $Workspace.GitDir $Workspace.Root @("rev-parse", "--verify", "$Commit^{commit}")) -cne $Commit) {
      Stop-T00 "BLOCKED_SOURCE_IDENTITY"
    }
  }
  foreach ($AncestorPair in @(@($MainSha, $CandidateSha), @($ImplementationBaseSha, $CandidateSha))) {
    $Ancestor = Invoke-T00Git $GitExe $Workspace.GitDir $Workspace.Root @(
      "merge-base", "--is-ancestor", $AncestorPair[0], $AncestorPair[1]
    )
    Assert-T00NativeSuccess $Ancestor "BLOCKED_SOURCE_IDENTITY"
  }
  $TaskResult = Invoke-T00Git $GitExe $Workspace.GitDir $Workspace.Root @("show", "${InstructionSha}:$TaskPath")
  Assert-T00NativeSuccess $TaskResult "BLOCKED_TASK_METADATA"
  Assert-T00TaskContract ([string]$TaskResult.StdOut)

  $ImplementationDelta = @(Get-T00GitChangedPaths $GitExe $Workspace.GitDir $Workspace.Root $ImplementationBaseSha $CandidateSha)
  if ($ImplementationDelta.Count -eq 0) { Stop-T00 "BLOCKED_IMPLEMENTATION_SCOPE" }
  foreach ($ChangedPath in $ImplementationDelta) {
    if ($script:ImplementationAllowedPaths -cnotcontains $ChangedPath) {
      Stop-T00 "BLOCKED_IMPLEMENTATION_SCOPE"
    }
  }
  foreach ($RequiredImplementationPath in @($script:ControllerRepositoryPath, $script:ControllerTestRepositoryPath)) {
    if ($ImplementationDelta -cnotcontains $RequiredImplementationPath) {
      Stop-T00 "BLOCKED_IMPLEMENTATION_SCOPE"
    }
  }
  $MainDelta = @(Get-T00GitChangedPaths $GitExe $Workspace.GitDir $Workspace.Root $MainSha $CandidateSha)
  if ($MainDelta.Count -eq 0) { Stop-T00 "BLOCKED_IMPLEMENTATION_SCOPE" }
  foreach ($ChangedPath in $MainDelta) {
    if ($script:TaskAllowedPaths -cnotcontains $ChangedPath) {
      Stop-T00 "BLOCKED_IMPLEMENTATION_SCOPE"
    }
  }
  $ProductDiff = Invoke-T00Git $GitExe $Workspace.GitDir $Workspace.Root `
    (@("diff", "--quiet", "--no-ext-diff", "--no-textconv", $ValidatedProductSha, $CandidateSha, "--") + $script:ProtectedProductPaths)
  Assert-T00NativeSuccess $ProductDiff "BLOCKED_PRODUCT_TREE_MISMATCH"

  $ControllerBlob = Get-T00GitLine $GitExe $Workspace.GitDir $Workspace.Root @(
    "rev-parse", "--verify", "${CandidateSha}:$($script:ControllerRepositoryPath)"
  ) "BLOCKED_ARTIFACT_IDENTITY"
  $ControllerTestBlob = Get-T00GitLine $GitExe $Workspace.GitDir $Workspace.Root @(
    "rev-parse", "--verify", "${CandidateSha}:$($script:ControllerTestRepositoryPath)"
  ) "BLOCKED_ARTIFACT_IDENTITY"
  $HelperBlob = Get-T00GitLine $GitExe $Workspace.GitDir $Workspace.Root @(
    "rev-parse", "--verify", "${CandidateSha}:$($script:T02HelperRepositoryPath)"
  ) "BLOCKED_ARTIFACT_IDENTITY"
  $HelperTestBlob = Get-T00GitLine $GitExe $Workspace.GitDir $Workspace.Root @(
    "rev-parse", "--verify", "${CandidateSha}:$($script:T02TestRepositoryPath)"
  ) "BLOCKED_ARTIFACT_IDENTITY"
  if ($HelperBlob -cne $script:T02HelperBlob -or $HelperTestBlob -cne $script:T02TestBlob -or
      [string]::IsNullOrWhiteSpace($PSCommandPath) -or
      (Get-T00GitBlobSha1 $PSCommandPath) -cne $ControllerBlob) {
    Stop-T00 "BLOCKED_ARTIFACT_IDENTITY"
  }

  $script:PrepareLocalWriteAttempted = $true
  [void][IO.Directory]::CreateDirectory($Workspace.ExecutionRoot)
  [void](New-T00PrivateDirectory $Workspace.ControlRoot $HostContext.Identity.Sid)
  foreach ($Directory in @($Workspace.CacheRoot, $Workspace.LogsRoot, $Workspace.TempRoot, $Workspace.NodeGypRoot)) {
    if (-not (Test-T00PathAbsent $Directory "BLOCKED_PREPARED_REPOSITORY")) {
      Stop-T00 "BLOCKED_PREPARED_REPOSITORY"
    }
    [void][IO.Directory]::CreateDirectory($Directory)
  }
  foreach ($PlannedRoot in @($Workspace.SandboxRoot, $Workspace.RecoveryRoot)) {
    if (-not (Test-T00PathAbsent $PlannedRoot "BLOCKED_PREPARED_REPOSITORY")) {
      Stop-T00 "BLOCKED_PREPARED_REPOSITORY"
    }
  }

  $ProductArchive = Join-Path $Workspace.Root "validated-product.zip"
  $ArchiveResult = Invoke-T00Git $GitExe $Workspace.GitDir $Workspace.Root @(
    "archive", "--format=zip", "--output=$ProductArchive", $ValidatedProductSha
  ) 300
  Assert-T00NativeSuccess $ArchiveResult "BLOCKED_SOURCE_IDENTITY"
  $ArchiveItem = Assert-T00RegularFile $ProductArchive 536870912
  if ($ArchiveItem.Length -le 0) { Stop-T00 "BLOCKED_SOURCE_IDENTITY" }
  Expand-Archive -LiteralPath $ProductArchive -DestinationPath $Workspace.ExecutionRoot -ErrorAction Stop
  [IO.File]::Delete($ProductArchive)

  $ArtifactArchive = Join-Path $Workspace.Root "candidate-artifacts.zip"
  $ArtifactResult = Invoke-T00Git $GitExe $Workspace.GitDir $Workspace.Root @(
    "archive", "--format=zip", "--output=$ArtifactArchive", $CandidateSha, "--",
    $script:ControllerRepositoryPath, $script:T02HelperRepositoryPath
  ) 300
  Assert-T00NativeSuccess $ArtifactResult "BLOCKED_ARTIFACT_IDENTITY"
  $CandidateArtifactRoot = Join-Path $Workspace.ControlRoot "candidate"
  [void][IO.Directory]::CreateDirectory($CandidateArtifactRoot)
  Expand-Archive -LiteralPath $ArtifactArchive -DestinationPath $CandidateArtifactRoot -ErrorAction Stop
  [IO.File]::Delete($ArtifactArchive)
  $PreparedController = Join-Path $CandidateArtifactRoot $script:ControllerRepositoryPath.Replace('/', '\')
  $PreparedHelper = Join-Path $CandidateArtifactRoot $script:T02HelperRepositoryPath.Replace('/', '\')
  if ((Get-T00GitBlobSha1 $PreparedController) -cne $ControllerBlob -or
      (Get-T00GitBlobSha1 $PreparedHelper) -cne $HelperBlob) {
    Stop-T00 "BLOCKED_ARTIFACT_IDENTITY"
  }

  foreach ($RequiredFile in @(
    (Join-Path $Workspace.ExecutionRoot "package.json"),
    (Join-Path $Workspace.ExecutionRoot "package-lock.json"),
    (Join-Path $Workspace.ExecutionRoot "build\build.mjs")
  )) {
    [void](Assert-T00RegularFile $RequiredFile 536870912)
  }
  $SourceSealBefore = Get-T00SourceSeal $Workspace.ExecutionRoot

  Set-T00Phase "TOOL"
  $BuildEnvironmentRemove = @(Get-T00EnvironmentKeysForRemoval)
  $NodeVersion = Get-T00NativeSingleLine (Invoke-T00Native $NodeExe @("--version") $Workspace.ExecutionRoot 120 @{} $BuildEnvironmentRemove) "BLOCKED_TOOLCHAIN"
  if ($NodeVersion -cnotmatch '^v(?<major>[0-9]+)\.[0-9]+\.[0-9]+$' -or [int]$Matches["major"] -lt 22) {
    Stop-T00 "BLOCKED_TOOLCHAIN"
  }
  $NodeLts = Get-T00NativeSingleLine (Invoke-T00Native $NodeExe @("-p", "process.release.lts ? 'YES' : 'NO'") $Workspace.ExecutionRoot 120 @{} $BuildEnvironmentRemove) "BLOCKED_TOOLCHAIN"
  $NodePlatform = Get-T00NativeSingleLine (Invoke-T00Native $NodeExe @("-p", "process.platform") $Workspace.ExecutionRoot 120 @{} $BuildEnvironmentRemove) "BLOCKED_TOOLCHAIN"
  $NodeArchitecture = Get-T00NativeSingleLine (Invoke-T00Native $NodeExe @("-p", "process.arch") $Workspace.ExecutionRoot 120 @{} $BuildEnvironmentRemove) "BLOCKED_TOOLCHAIN"
  $NpmVersion = Get-T00NativeSingleLine (Invoke-T00Native $NodeExe @($NpmCli, "--version") $Workspace.ExecutionRoot 120 @{} $BuildEnvironmentRemove) "BLOCKED_TOOLCHAIN"
  if ($NodeLts -cne "YES" -or $NodePlatform -cne "win32" -or $NodeArchitecture -cne "x64" -or
      $NpmVersion -cnotmatch '^[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?$') {
    Stop-T00 "BLOCKED_TOOLCHAIN"
  }

  $NpmUserConfig = Join-Path $Workspace.Root "npm-user-config"
  $NpmGlobalConfig = Join-Path $Workspace.Root "npm-global-config"
  [IO.File]::WriteAllText($NpmUserConfig, "", [Text.UTF8Encoding]::new($false))
  [IO.File]::WriteAllText($NpmGlobalConfig, "", [Text.UTF8Encoding]::new($false))
  $BuildEnvironmentSet = @{
    "npm_config_cache" = $Workspace.CacheRoot
    "npm_config_logs_dir" = $Workspace.LogsRoot
    "npm_config_devdir" = $Workspace.NodeGypRoot
    "npm_config_userconfig" = $NpmUserConfig
    "npm_config_globalconfig" = $NpmGlobalConfig
    "TEMP" = $Workspace.TempRoot
    "TMP" = $Workspace.TempRoot
    "SystemRoot" = $HostContext.SystemRoot
    "windir" = $HostContext.SystemRoot
  }

  Set-T00Phase "INSTALL"
  $script:PrepareNpmInstallAttempted = $true
  $Install = Invoke-T00Native $NodeExe @(
    $NpmCli, "ci", "--audit=false", "--fund=false", "--ignore-scripts=false"
  ) $Workspace.ExecutionRoot 1800 $BuildEnvironmentSet $BuildEnvironmentRemove -KillTreeOnTimeout
  Assert-T00NativeSuccess $Install "BLOCKED_DEPENDENCY_INSTALL"

  Set-T00Phase "TYPE"
  $Tsc = Join-Path $Workspace.ExecutionRoot "node_modules\typescript\bin\tsc"
  [void](Assert-T00RegularFile $Tsc 16777216)
  $script:PrepareTypecheckAttempted = $true
  $Typecheck = Invoke-T00Native $NodeExe @($Tsc, "--noEmit") $Workspace.ExecutionRoot 600 $BuildEnvironmentSet $BuildEnvironmentRemove -KillTreeOnTimeout
  Assert-T00NativeSuccess $Typecheck "BLOCKED_TYPECHECK"

  Set-T00Phase "BUILD"
  $BuildScript = Join-Path $Workspace.ExecutionRoot "build\build.mjs"
  $script:PrepareBuildAttempted = $true
  $BuildResult = Invoke-T00Native $NodeExe @($BuildScript) $Workspace.ExecutionRoot 900 $BuildEnvironmentSet $BuildEnvironmentRemove -KillTreeOnTimeout
  Assert-T00NativeSuccess $BuildResult "BLOCKED_BUILD"
  if ((Get-T00SourceSeal $Workspace.ExecutionRoot) -cne $SourceSealBefore) {
    Stop-T00 "BLOCKED_BUILD"
  }

  Set-T00Phase "SEAL"
  $CliPath = Join-Path $Workspace.ExecutionRoot "packages\cli\dist\main\cli.js"
  $ModelCatalogPath = Join-Path $Workspace.ExecutionRoot "packages\core\models.json"
  [void](Assert-T00RegularFile $CliPath 268435456)
  [void](Assert-T00RegularFile $ModelCatalogPath 268435456)
  $DistRoots = @(
    "packages/cli/dist", "packages/core/dist", "packages/electron/dist", "packages/ui/dist"
  )
  foreach ($DistRoot in $DistRoots) {
    $DistPath = Join-Path $Workspace.ExecutionRoot $DistRoot.Replace('/', '\')
    if ((Get-T00PathStateNoFollow $DistPath "BLOCKED_RUNTIME_SEAL").State -cne "DIRECTORY") {
      Stop-T00 "BLOCKED_RUNTIME_SEAL"
    }
  }
  $WorkspaceLinks = Get-T00WorkspaceLinks $Workspace.ExecutionRoot
  $ModuleBinding = Get-T00NodeRuntimeBinding $NodeExe $Workspace.ExecutionRoot $CliPath `
    $BuildEnvironmentRemove -SmokeDatabase
  if ((Get-T00SourceSeal $Workspace.ExecutionRoot) -cne $SourceSealBefore) {
    Stop-T00 "BLOCKED_RUNTIME_SEAL"
  }
  $RuntimeSeal = Get-T00TreeSeal $Workspace.ExecutionRoot $WorkspaceLinks
  $LinkRows = New-Object "Collections.Generic.List[object]"
  foreach ($LinkPath in @(Get-T00OrdinalSortedStrings @($WorkspaceLinks.Keys))) {
    $LinkRows.Add([ordered]@{ path = $LinkPath; target = [string]$WorkspaceLinks[$LinkPath] })
  }
  $ManifestPathValue = Join-Path $Workspace.ControlRoot "prepared-manifest.json"
  $Manifest = [ordered]@{
    schema = "t00-prepared-manifest-v1"
    taskId = $script:TaskId
    attempt = $script:Attempt
    authority = [ordered]@{
      mainSha = $MainSha
      candidateSha = $CandidateSha
      instructionSha = $InstructionSha
      implementationBaseSha = $ImplementationBaseSha
      validatedProductSha = $ValidatedProductSha
      taskPath = $TaskPath
      candidateRef = $PreparedCandidateRef
      mainRef = $PreparedMainRef
      headPrefix = $script:SafeHeadPrefix
    }
    approvals = [ordered]@{
      windowsRuntimeAllowed = $true
      claudeCodeExecutionAllowed = $true
      noSameAccountConcurrentUse = $true
      npmNetworkAndLifecycle = $true
      singleSaveIfChangeY = $true
      stockGetAppInfoResidualRisk = $true
    }
    workspace = [ordered]@{
      id = $Workspace.Id
      environmentAlias = $EnvironmentAlias
      validationRoot = $Workspace.Root
      executionRoot = $Workspace.ExecutionRoot
      controlRoot = $Workspace.ControlRoot
      manifestPath = $ManifestPathValue
      sandboxRoot = $Workspace.SandboxRoot
      recoveryRoot = $Workspace.RecoveryRoot
      realLocalAppData = $HostContext.LocalAppData
      realAppData = $HostContext.AppData
      realUserProfile = $HostContext.UserProfile
    }
    artifacts = [ordered]@{
      controllerPath = $PreparedController
      controllerBlob = $ControllerBlob
      controllerTestBlob = $ControllerTestBlob
      helperPath = $PreparedHelper
      helperBlob = $HelperBlob
      helperTestBlob = $HelperTestBlob
    }
    toolchain = [ordered]@{
      powerShellPath = $HostContext.PowerShellExe
      powerShellHash = $HostContext.PowerShellHash
      gitPath = $GitExe
      gitHash = Get-T00Sha256File $GitExe
      nodePath = $NodeExe
      nodeHash = Get-T00Sha256File $NodeExe
      nodeVersion = $NodeVersion
      nodeLts = $NodeLts
      nodePlatform = $NodePlatform
      nodeArchitecture = $NodeArchitecture
      npmCliPath = $NpmCli
      npmCliHash = Get-T00Sha256File $NpmCli
      npmVersion = $NpmVersion
      systemRoot = $HostContext.SystemRoot
      wherePath = $HostContext.WhereExe
      whereHash = $HostContext.WhereHash
    }
    build = [ordered]@{
      npmCi = "PASS"
      typecheck = "PASS"
      buildAssets = "PASS"
      sourceSeal = $SourceSealBefore
      packageLockHash = Get-T00Sha256File (Join-Path $Workspace.ExecutionRoot "package-lock.json")
    }
    runtime = [ordered]@{
      cwd = $Workspace.ExecutionRoot
      cliRelative = Get-T00RelativePath $Workspace.ExecutionRoot $CliPath
      cliHash = Get-T00Sha256File $CliPath
      modelCatalogRelative = Get-T00RelativePath $Workspace.ExecutionRoot $ModelCatalogPath
      modelCatalogHash = Get-T00Sha256File $ModelCatalogPath
      moduleRelative = $ModuleBinding.EntryRelative
      moduleHash = $ModuleBinding.EntryHash
      nativeRelative = $ModuleBinding.NativeRelative
      nativeHash = $ModuleBinding.NativeHash
      distRoots = $DistRoots
      workspaceLinks = @($LinkRows)
      rows = @($RuntimeSeal.Rows)
      digest = $RuntimeSeal.Digest
      entryCount = $RuntimeSeal.EntryCount
      totalBytes = $RuntimeSeal.TotalBytes
    }
    policy = [ordered]@{
      currentSid = $HostContext.Identity.Sid
      systemSid = $script:SystemSid
      startupOverrideKeys = $script:StartupOverrideKeys
      managedEnterpriseEnvironmentKeys = $script:ManagedEnterpriseEnvironmentKeys
      controllerDirectNativeProcessesBounded = $true
      stockGetAppInfoDescendantsBoundedByController = $false
      stockGetAppInfoResidualRiskReviewed = $true
    }
  }
  $ManifestDigestValue = Write-T00JsonAtomic $ManifestPathValue $Manifest
  [void](Assert-T00PrivateAcl $ManifestPathValue $HostContext.Identity.Sid)
  $RunCommand = New-T00BootstrapCommand $HostContext.PowerShellExe $ManifestPathValue `
    $ManifestDigestValue $Workspace.Id $CandidateSha "Run"

  Write-Output "T00 PREPARE RESULT: PASS"
  Write-Output ("HEAD TOKEN: {0}" -f $script:SafeHeadPrefix)
  Write-Output ("WORKSPACE ID: {0}" -f $Workspace.Id)
  Write-Output "LOCAL WORKSPACE WRITE ATTEMPTED: YES"
  Write-Output "NPM CI INVOCATION ATTEMPTED: YES"
  Write-Output "NPM NETWORK PERMISSION: ALLOW"
  Write-Output "NPM LIFECYCLE PERMISSION: ALLOW"
  Write-Output "ACTUAL NETWORK CONNECTION: NOT_OBSERVED"
  Write-Output "ACTUAL LIFECYCLE CHILD EXECUTION: NOT_OBSERVED"
  Write-Output "TYPECHECK ATTEMPTED: YES"
  Write-Output "BUILD ATTEMPTED: YES"
  Write-Output "INTERNAL ONE-LINE RUN COMMAND:"
  Write-Output $RunCommand
  Write-Output "SONNET NEXT ACTION: EXIT COMPLETELY; DO NOT RUN H0 OR THE COMMAND."
}

function Assert-T00HelperAdmission {
  param(
    [Parameter(Mandatory = $true)]$Manifest,
    [Parameter(Mandatory = $true)]$HostContext,
    [Parameter(Mandatory = $true)]$Paths,
    [Parameter(Mandatory = $true)]$Binding,
    [Parameter(Mandatory = $true)][DateTimeOffset]$NotBefore,
    [Parameter(Mandatory = $true)][int]$Port
  )
  Assert-T00NoStartupOverrides
  $NodeExe = Get-T00FullPath ([string]$Manifest.toolchain.nodePath)
  $HelperPath = Get-T00FullPath ([string]$Manifest.artifacts.helperPath)
  $ControllerPath = Get-T00FullPath ([string]$Manifest.artifacts.controllerPath)
  if ((Get-T00Sha256File $NodeExe) -cne [string]$Manifest.toolchain.nodeHash -or
      (Get-T00GitBlobSha1 $HelperPath) -cne [string]$Manifest.artifacts.helperBlob -or
      (Get-T00GitBlobSha1 $ControllerPath) -cne [string]$Manifest.artifacts.controllerBlob) {
    Stop-T00 "BLOCKED_ARTIFACT_IDENTITY"
  }
  Assert-T00NoRelevantWriters $HostContext.Identity.Name @($Binding.Pid)
  [void](Get-T00ServiceBinding $Manifest $HostContext $Paths $NotBefore $Port $Binding)
}

function Set-T00HelperGetAppInfoUncertainty {
  param([Parameter(Mandatory = $true)]$Result)
  if (-not $Result.Started) { return }
  if ($Result.RunnerFault -or $Result.TimedOut -or -not $Result.CleanupSucceeded -or
      $Result.OutputTruncated -or $null -eq $Result.ExitCode -or
      -not [string]::IsNullOrWhiteSpace([string]$Result.StdErr)) {
    $script:GetAppInfoUncertain = $true
    return
  }
  $Line = ([string]$Result.StdOut).Trim()
  if ($Line -match '^T02\|RESULT=PASS\|' -and $Line -match '\|RAW=NO$') { return }
  $Failure = [regex]::Match(
    $Line,
    '^T02\|RESULT=(?:BLOCKED|FAIL)\|CATEGORY=(?<category>[A-Z0-9_]+)\|SAVE=(?:N|Y|UNKNOWN)\|RAW=NO$'
  )
  if ($Failure.Success -and $Failure.Groups["category"].Value -cne "RPC_FAILURE") { return }
  $script:GetAppInfoUncertain = $true
}

function Get-T00HelperFailureCapsule {
  param([Parameter(Mandatory = $true)]$Result)
  if (-not $Result.Started -or $Result.RunnerFault -or $Result.TimedOut -or
      -not $Result.CleanupSucceeded -or $Result.OutputTruncated -or
      $null -eq $Result.ExitCode -or
      -not [string]::IsNullOrWhiteSpace([string]$Result.StdErr)) {
    return $null
  }
  $Match = [regex]::Match(
    ([string]$Result.StdOut).Trim(),
    '^T02\|RESULT=(?<result>BLOCKED|FAIL)\|CATEGORY=(?<category>[A-Z0-9_]+)\|SAVE=(?<save>N|Y|UNKNOWN)\|RAW=NO$'
  )
  if (-not $Match.Success) { return $null }
  $ResultKind = $Match.Groups["result"].Value
  $Save = $Match.Groups["save"].Value
  if (($ResultKind -ceq "BLOCKED" -and
      ($Save -cne "N" -or -not (@(2, 64) -contains ([int]$Result.ExitCode)))) -or
      ($ResultKind -ceq "FAIL" -and (@("Y", "UNKNOWN") -cnotcontains $Save -or [int]$Result.ExitCode -ne 3))) {
    return $null
  }
  return [PSCustomObject]@{
    Category = $Match.Groups["category"].Value
    Save = $Save
  }
}

function Invoke-T00HelperPreflight {
  param(
    [Parameter(Mandatory = $true)]$Manifest,
    [Parameter(Mandatory = $true)]$HostContext
  )
  $NodeExe = Get-T00FullPath ([string]$Manifest.toolchain.nodePath)
  $HelperPath = Get-T00FullPath ([string]$Manifest.artifacts.helperPath)
  $Environment = Get-T00ChildEnvironment $HostContext $HostContext.LocalAppData
  $Result = Invoke-T00Native $NodeExe @($HelperPath) ([string]$Manifest.workspace.controlRoot) 45 `
    $Environment.Set $Environment.Remove
  Set-T00HelperGetAppInfoUncertainty $Result
  if (-not $Result.Started -or $Result.RunnerFault -or $Result.TimedOut -or
      -not $Result.CleanupSucceeded -or $Result.OutputTruncated -or
      $null -eq $Result.ExitCode -or $Result.ExitCode -ne 0 -or
      -not [string]::IsNullOrWhiteSpace([string]$Result.StdErr)) {
    Stop-T00 "BLOCKED_T02_PREFLIGHT"
  }
  $Line = ([string]$Result.StdOut).Trim()
  $Pattern = '^T02\|RESULT=PASS\|SERVICE=P\|GW_PRE=STOP\|RPC=P\|APPLY=N\|CHANGE=(?<change>[YN])\|TARGET_GLOBAL=0\|TARGET_LOGS=OFF\|TARGET_ANALYSIS=OFF\|TARGET_BODY=NONE\|AUTOFETCH=OFF\|RAW=NO$'
  $Match = [regex]::Match($Line, $Pattern)
  if (-not $Match.Success) { Stop-T00 "BLOCKED_T02_PREFLIGHT" }
  return $Match.Groups["change"].Value
}

function Invoke-T00HelperApply {
  param(
    [Parameter(Mandatory = $true)]$Manifest,
    [Parameter(Mandatory = $true)]$HostContext
  )
  $NodeExe = Get-T00FullPath ([string]$Manifest.toolchain.nodePath)
  $HelperPath = Get-T00FullPath ([string]$Manifest.artifacts.helperPath)
  $Environment = Get-T00ChildEnvironment $HostContext $HostContext.LocalAppData
  $Result = Invoke-T00Native $NodeExe @($HelperPath, "--apply") ([string]$Manifest.workspace.controlRoot) 45 `
    $Environment.Set $Environment.Remove
  Set-T00HelperGetAppInfoUncertainty $Result
  $Expected = '^T02\|RESULT=PASS\|SERVICE=P\|GW_PRE=STOP\|GW_POST=STOP\|RPC=P\|APPLY=P\|CHANGE=Y\|GLOBAL=0\|LOGS=OFF\|ANALYSIS=OFF\|BODY=NONE\|PROVIDER=SAME\|ONBOARDING=SAME\|AUTOFETCH=OFF\|RAW=NO$'
  $TransportAmbiguous = -not $Result.Started -or $Result.RunnerFault -or $Result.TimedOut -or
      -not $Result.CleanupSucceeded -or $Result.OutputTruncated -or
      $null -eq $Result.ExitCode -or
      -not [string]::IsNullOrWhiteSpace([string]$Result.StdErr)
  if ($TransportAmbiguous) {
    Stop-T00 "FAIL_SAVE_UNKNOWN"
  }
  $Line = ([string]$Result.StdOut).Trim()
  if ([int]$Result.ExitCode -eq 0 -and $Line -cmatch $Expected) { return }
  $Failure = Get-T00HelperFailureCapsule $Result
  if ($null -eq $Failure -or $Failure.Save -ceq "UNKNOWN") {
    Stop-T00 "FAIL_SAVE_UNKNOWN"
  }
  Stop-T00 "BLOCKED_T02_APPLY"
}

function Get-T00GatewayPorts {
  param([Parameter(Mandatory = $true)]$Binding)
  $Config = Invoke-T00Rpc ([PSCustomObject]@{ Port = $Binding.Port; WebToken = $Binding.WebToken }) "getConfig" @() 8000
  $Gateway = $Config.gateway
  $Port = 0
  $CorePort = 0
  if ([string]$Gateway.host -cne "127.0.0.1" -or [string]$Gateway.coreHost -cne "127.0.0.1" -or
      -not [int]::TryParse(([string]$Gateway.port), [ref]$Port) -or
      -not [int]::TryParse(([string]$Gateway.corePort), [ref]$CorePort) -or
      $Port -lt 1 -or $Port -gt 65535 -or $CorePort -lt 1 -or $CorePort -gt 65535 -or
      $Port -eq $CorePort) {
    Stop-T00 "BLOCKED_GATEWAY_STATE"
  }
  return [PSCustomObject]@{ Gateway = $Port; Core = $CorePort }
}

function Test-T00BoundProcessAlive {
  param(
    [Parameter(Mandatory = $true)][int]$ProcessId,
    [Parameter(Mandatory = $true)][string]$CreationTime,
    [Parameter(Mandatory = $true)][string]$OwnerName
  )
  try {
    $Processes = @(Get-CimInstance -ClassName Win32_Process -Filter ("ProcessId = {0}" -f $ProcessId) -ErrorAction Stop)
  } catch {
    Stop-T00 "BLOCKED_SERVICE_IDENTITY"
  }
  if ($Processes.Count -eq 0) { return $false }
  if ($Processes.Count -ne 1) { Stop-T00 "BLOCKED_SERVICE_IDENTITY" }
  $Process = $Processes[0]
  try {
    $CurrentCreationTime = ([DateTimeOffset]$Process.CreationDate).ToUniversalTime().ToString("o")
  } catch {
    Stop-T00 "BLOCKED_SERVICE_IDENTITY"
  }
  if ($CurrentCreationTime -cne $CreationTime) {
    return $false
  }
  try {
    $Owner = Invoke-CimMethod -InputObject $Process -MethodName GetOwner -ErrorAction Stop
  } catch {
    Stop-T00 "BLOCKED_SERVICE_IDENTITY"
  }
  $CurrentOwner = if ([string]::IsNullOrWhiteSpace([string]$Owner.Domain)) {
    [string]$Owner.User
  } else {
    ([string]$Owner.Domain) + "\" + ([string]$Owner.User)
  }
  if ($Owner.ReturnValue -ne 0 -or $CurrentOwner -ine $OwnerName) {
    Stop-T00 "BLOCKED_SERVICE_IDENTITY"
  }
  return $true
}

function Wait-T00BoundProcessExit {
  param(
    [Parameter(Mandatory = $true)][int]$ProcessId,
    [Parameter(Mandatory = $true)][string]$CreationTime,
    [Parameter(Mandatory = $true)][string]$OwnerName,
    [int]$TimeoutSeconds = 20
  )
  $Deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
  while ([DateTime]::UtcNow -lt $Deadline) {
    if (-not (Test-T00BoundProcessAlive $ProcessId $CreationTime $OwnerName)) { return $true }
    [Threading.Thread]::Sleep(200)
  }
  return -not (Test-T00BoundProcessAlive $ProcessId $CreationTime $OwnerName)
}

function Test-T00PathAbsent {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [string]$FailureCategory = "BLOCKED_CLEANUP"
  )
  return (Get-T00PathStateNoFollow $Path $FailureCategory).State -ceq "ABSENT"
}

function Set-T00FirstFailure {
  param(
    [Parameter(Mandatory = $true)][hashtable]$State,
    [Parameter(Mandatory = $true)]$Failure,
    [switch]$Override
  )
  if ($Override -or $null -eq $State.Failure) {
    $State.Failure = $Failure
  }
}

function Remove-T00RuntimeSandbox {
  param(
    [Parameter(Mandatory = $true)][hashtable]$State,
    [Parameter(Mandatory = $true)]$Manifest,
    [Parameter(Mandatory = $true)]$HostContext
  )
  $SandboxRoot = Get-T00FullPath ([string]$Manifest.workspace.sandboxRoot)
  $SandboxState = Get-T00PathStateNoFollow $SandboxRoot "BLOCKED_CLEANUP"
  if ($SandboxState.State -ceq "DIRECTORY") {
    try {
      [void](Assert-T00NoReparseAncestors $SandboxRoot -FailureCategory "BLOCKED_CLEANUP")
      $FirstSeal = Get-T00TreeSeal $SandboxRoot @{} -ValidatePrivateAcl `
        -CurrentSid $HostContext.Identity.Sid -AllowEmpty
      $SecondSeal = Get-T00TreeSeal $SandboxRoot @{} -ValidatePrivateAcl `
        -CurrentSid $HostContext.Identity.Sid -AllowEmpty
      if ($FirstSeal.Digest -cne $SecondSeal.Digest -or
          ($FirstSeal.Rows -join "`0") -cne ($SecondSeal.Rows -join "`0")) {
        Stop-T00 "BLOCKED_CLEANUP"
      }
      Remove-T00TreeNoFollow $SandboxRoot $HostContext.Identity.Sid
      $State.SandboxDeleted = $true
    } catch {
      $State.ManualRecovery = $true
      Set-T00FirstFailure $State ([PSCustomObject]@{ Phase = "CLEANUP"; Category = "BLOCKED_CLEANUP" })
      return $false
    }
  } elseif ($SandboxState.State -ceq "FILE") {
    $State.ManualRecovery = $true
    Set-T00FirstFailure $State ([PSCustomObject]@{ Phase = "CLEANUP"; Category = "BLOCKED_CLEANUP" })
    return $false
  } else {
    $State.SandboxDeleted = $true
  }
  return $true
}

function Invoke-T00RunCleanup {
  param(
    [Parameter(Mandatory = $true)][hashtable]$State,
    [Parameter(Mandatory = $true)]$Manifest,
    [Parameter(Mandatory = $true)]$HostContext,
    [Parameter(Mandatory = $true)]$Paths
  )
  Set-T00Phase "DURING"
  if ($State.ServiceMayExist -and $null -ne $State.Baseline) {
    try {
      [void](Assert-T00EnterpriseSame $State.Baseline $HostContext $Paths)
      $State.DuringCaptured = $true
      $State.DuringSame = $true
    } catch {
      $Failure = Get-T00Failure $_
      $State.DuringCaptured = $true
      $State.DuringSame = $false
      Set-T00FirstFailure $State $Failure -Override
    }
  }

  Set-T00Phase "CLEANUP"
  if ($script:GetAppInfoUncertain) {
    $State.ManualRecovery = $true
    Set-T00FirstFailure $State ([PSCustomObject]@{
      Phase = "CLEANUP"
      Category = "BLOCKED_CLEANUP"
    })
    return
  }
  if (-not $State.ServiceMayExist) {
    if (-not (Remove-T00RuntimeSandbox $State $Manifest $HostContext)) { return }
    $State.CleanupSafe = $true
    return
  }

  if ($null -eq $State.Binding) {
    $Deadline = [DateTime]::UtcNow.AddSeconds(5)
    while ([DateTime]::UtcNow -lt $Deadline -and
        (Test-T00PathAbsent $Paths.ServiceFile "BLOCKED_CLEANUP")) {
      [Threading.Thread]::Sleep(200)
    }
    $ServiceFileState = Get-T00PathStateNoFollow $Paths.ServiceFile "BLOCKED_CLEANUP"
    if ($ServiceFileState.State -ceq "FILE") {
      try {
        $State.Binding = Get-T00ServiceBinding $Manifest $HostContext $Paths `
          $State.StartMarkedAt $State.ManagementPort -IncludeAppInfo
        $State.FreshOwned = $true
      } catch {
        Set-T00FirstFailure $State (Get-T00Failure $_)
      }
    }
  }

  if ($null -eq $State.Binding) {
    $State.ManualRecovery = $true
    Set-T00FirstFailure $State ([PSCustomObject]@{
      Phase = "CLEANUP"
      Category = "BLOCKED_CLEANUP"
    })
    return
  } else {
    try {
      Assert-T00NoRelevantWriters $HostContext.Identity.Name @($State.Binding.Pid)
      if (-not $State.ApplyStarted) {
        [void](Get-T00ServiceBinding $Manifest $HostContext $Paths $State.StartMarkedAt `
          $State.ManagementPort $State.Binding -GatewayEndpointMode "PRE_SAVE")
      } else {
        $CurrentGatewayPorts = Get-T00GatewayPorts $State.Binding
        if ($null -ne $State.GatewayPorts -and
            ($State.GatewayPorts.Gateway -ne $CurrentGatewayPorts.Gateway -or
             $State.GatewayPorts.Core -ne $CurrentGatewayPorts.Core)) {
          Stop-T00 "BLOCKED_GATEWAY_STATE"
        }
        $GatewayEndpointMode = if ($State.SavePassed) { "POST_SAVE" } else { "CLEANUP" }
        [void](Get-T00ServiceBinding $Manifest $HostContext $Paths $State.StartMarkedAt `
          $State.ManagementPort $State.Binding -GatewayEndpointMode $GatewayEndpointMode `
          -ExpectedGatewayPorts $CurrentGatewayPorts)
        $State.GatewayPorts = $CurrentGatewayPorts
      }
      Assert-T00RuntimeSeal $Manifest (Get-T00FullPath ([string]$Manifest.toolchain.nodePath))
      $NodeExe = Get-T00FullPath ([string]$Manifest.toolchain.nodePath)
      $ExecutionRoot = Get-T00FullPath ([string]$Manifest.workspace.executionRoot)
      $CliPath = Join-Path $ExecutionRoot ([string]$Manifest.runtime.cliRelative).Replace('/', '\')
      $Environment = Get-T00ChildEnvironment $HostContext (Get-T00FullPath ([string]$Manifest.workspace.sandboxRoot))
      $StopResult = Invoke-T00Native $NodeExe @($CliPath, "stop") $ExecutionRoot 30 $Environment.Set $Environment.Remove
      Assert-T00NativeSuccess $StopResult "BLOCKED_CLEANUP"
      $State.StockStopPassed = $true
    } catch {
      $State.ManualRecovery = $true
      Set-T00FirstFailure $State (Get-T00Failure $_)
      return
    }
    $State.PidDead = Wait-T00BoundProcessExit $State.Binding.Pid $State.Binding.ProcessCreationTime $HostContext.Identity.Name 20
    $State.ServiceStateAbsent = (Test-T00PathAbsent $Paths.ServiceFile "BLOCKED_CLEANUP") -and
      (Test-T00PathAbsent $Paths.ServiceStartLock "BLOCKED_CLEANUP") -and
      (Test-T00PathAbsent $Paths.StockBackupFile "BLOCKED_CLEANUP")
    try {
      Assert-T00PortFree $State.ManagementPort
      if ($null -ne $State.GatewayPorts) {
        Assert-T00PortFree $State.GatewayPorts.Gateway
        Assert-T00PortFree $State.GatewayPorts.Core
      }
      $State.PortsFree = $true
    } catch {
      $State.PortsFree = $false
    }
  }

  if ($null -ne $State.Baseline) {
    try {
      [void](Assert-T00EnterpriseSame $State.Baseline $HostContext $Paths)
      $State.AfterSame = $true
    } catch {
      $State.AfterSame = $false
      Set-T00FirstFailure $State (Get-T00Failure $_) -Override
    }
  }

  if (-not $State.PidDead -or -not $State.ServiceStateAbsent -or -not $State.PortsFree -or
      -not $State.AfterSame) {
    $State.ManualRecovery = $true
    Set-T00FirstFailure $State ([PSCustomObject]@{ Phase = "CLEANUP"; Category = "BLOCKED_CLEANUP" })
    return
  }

  if (-not (Remove-T00RuntimeSandbox $State $Manifest $HostContext)) { return }
  $State.CleanupSafe = $true
}

function Invoke-T00RunMode {
  Set-T00Phase "INPUT"
  if ($WorkspaceId -cnotmatch $script:WorkspacePattern -or
      $ApprovedHeadSha -cnotmatch $script:ShaPattern -or
      $ManifestDigest -cnotmatch $script:DigestPattern) {
    Stop-T00 "BLOCKED_INPUT_CONTRACT"
  }
  $script:SafeHeadPrefix = $ApprovedHeadSha.Substring(0, 12)
  Set-T00Phase "HOST"
  $HostContext = Get-T00HostContext
  $Manifest = Read-T00VerifiedJson (Get-T00FullPath $ManifestPath) $ManifestDigest
  Assert-T00ManifestAuthority $Manifest $HostContext $WorkspaceId $ApprovedHeadSha $ManifestPath
  Assert-T00NoStartupOverrides
  Assert-T00RuntimeSeal $Manifest (Get-T00FullPath ([string]$Manifest.toolchain.nodePath))

  $RunMarker = Join-Path ([string]$Manifest.workspace.controlRoot) "run-consumed.marker"
  Write-T00BytesAtomic $RunMarker ([Text.Encoding]::ASCII.GetBytes("ATTEMPT4-RUN-CONSUMED`n"))
  [void](Assert-T00PrivateAcl $RunMarker $HostContext.Identity.Sid)

  Set-T00Phase "H0"
  Write-Output "H0 CONFIRMATION REQUIRED. Run only after the approved Enterprise auth/model/Desktop smokes and current-account client closure."
  $H0Token = Read-Host "Type exact H0 token"
  $ExpectedH0 = "H0|AUTH=P|MODELS=P|DESKTOP=P|CONCURRENT=N|CLIENTS=CLOSED|SAVE=Y_IF_CHANGE"
  if ($H0Token -cne $ExpectedH0) { Stop-T00 "BLOCKED_H0" }
  Assert-T00NoRelevantWriters $HostContext.Identity.Name
  Assert-T00NoStartupOverrides

  $Paths = Get-T00RuntimePaths $HostContext
  Assert-T00RuntimePreconditions $HostContext $Paths
  $State = @{
    Failure = $null
    Baseline = $null
    Backup = $null
    BackupCreationAttempted = $false
    BackupRetained = $false
    BackupVerifiedAfterH2 = $false
    H2AfterSame = $false
    ServiceMayExist = $false
    Binding = $null
    StartMarkedAt = [DateTimeOffset]::UtcNow
    ManagementPort = 0
    GatewayPorts = $null
    FreshOwned = $false
    HelperPreflightStarted = $false
    ApplyStarted = $false
    SavePassed = $false
    DuringCaptured = $false
    DuringSame = $false
    StockStopPassed = $false
    PidDead = $false
    ServiceStateAbsent = $false
    PortsFree = $false
    AfterSame = $false
    SandboxDeleted = $false
    CleanupSafe = $false
    ManualRecovery = $false
    RunSuccessCommitted = $false
  }

  try {
    try {
      Set-T00Phase "BACKUP"
      $State.BackupCreationAttempted = $true
      $script:FailureBackupCode = "R"
      $State.Backup = New-T00RecoveryBackup $Manifest $HostContext $Paths
      $State.BackupRetained = $true

      Set-T00Phase "BASELINE"
      $State.Baseline = Get-T00EnterpriseSnapshot $HostContext $Paths
      Assert-T00BackupMatchesBaseline $State.Backup $State.Baseline
      $BaselinePath = Join-Path ([string]$Manifest.workspace.controlRoot) "enterprise-baseline.json"
      $BaselineDigest = Write-T00JsonAtomic $BaselinePath $State.Baseline.Value
      [void](Assert-T00PrivateAcl $BaselinePath $HostContext.Identity.Sid)
      $State.BaselinePath = $BaselinePath
      $State.BaselineDigest = $BaselineDigest

      Assert-T00NoRelevantWriters $HostContext.Identity.Name
      Assert-T00NoStartupOverrides
      Assert-T00RuntimePreconditions $HostContext $Paths

      Set-T00Phase "SERVICE"
      $SandboxRoot = Get-T00FullPath ([string]$Manifest.workspace.sandboxRoot)
      [void](New-T00PrivateDirectory $SandboxRoot $HostContext.Identity.Sid)
      $State.ManagementPort = Get-T00FreshLoopbackPort
      $NodeExe = Get-T00FullPath ([string]$Manifest.toolchain.nodePath)
      $ExecutionRoot = Get-T00FullPath ([string]$Manifest.workspace.executionRoot)
      $CliPath = Join-Path $ExecutionRoot ([string]$Manifest.runtime.cliRelative).Replace('/', '\')
      Assert-T00NoStartupOverrides
      $Environment = Get-T00ChildEnvironment $HostContext $SandboxRoot
      $State.StartMarkedAt = [DateTimeOffset]::UtcNow
      $State.ServiceMayExist = $true
      $StartResult = Invoke-T00Native $NodeExe @(
        $CliPath, "start", "--host", "127.0.0.1", "--port", [string]$State.ManagementPort,
        "--no-open", "--no-gateway"
      ) $ExecutionRoot 45 $Environment.Set $Environment.Remove
      Assert-T00NativeSuccess $StartResult "BLOCKED_SERVICE_START"
      if (-not (Test-T00PathAbsent $Paths.ServiceStartLock "BLOCKED_SERVICE_IDENTITY")) {
        Stop-T00 "BLOCKED_SERVICE_IDENTITY"
      }
      $State.Binding = Get-T00ServiceBinding $Manifest $HostContext $Paths $State.StartMarkedAt $State.ManagementPort -IncludeAppInfo
      $State.FreshOwned = $true

      Set-T00Phase "PREFLIGHT"
      Assert-T00HelperAdmission $Manifest $HostContext $Paths $State.Binding $State.StartMarkedAt $State.ManagementPort
      $State.HelperPreflightStarted = $true
      $Change = Invoke-T00HelperPreflight $Manifest $HostContext
      if ($Change -cne "Y") { Stop-T00 "BLOCKED_CHANGE_REQUIRED" }

      Set-T00Phase "APPLY"
      Assert-T00HelperAdmission $Manifest $HostContext $Paths $State.Binding $State.StartMarkedAt $State.ManagementPort
      $State.ApplyStarted = $true
      Invoke-T00HelperApply $Manifest $HostContext
      $State.SavePassed = $true
      $State.GatewayPorts = Get-T00GatewayPorts $State.Binding
      [void](Get-T00ServiceBinding $Manifest $HostContext $Paths $State.StartMarkedAt `
        $State.ManagementPort $State.Binding -GatewayEndpointMode "POST_SAVE" `
        -ExpectedGatewayPorts $State.GatewayPorts)
    } catch {
      Set-T00FirstFailure $State (Get-T00Failure $_)
    }
  } finally {
    try {
      Invoke-T00RunCleanup $State $Manifest $HostContext $Paths
    } catch {
      $State.ManualRecovery = $true
      Set-T00FirstFailure $State (Get-T00Failure $_)
    }
  }
  $script:FailureCleanupCode = if ($State.CleanupSafe) { "P" } else { "N" }

  try {
    $H2Passed = $false
    $RecoveryNo = $false
    if ($State.CleanupSafe -and $State.AfterSame -and -not $State.ManualRecovery) {
    Set-T00Phase "H2"
    Write-Output "H2_READY"
    $H2Token = Read-Host "After smokes, close the clients and type the exact H2 token"
    $ExpectedH2 = "H2|AUTH=P|MODELS=P|DESKTOP=P|CLIENTS=CLOSED|RECOVERY=N"
    if ($H2Token -ceq $ExpectedH2) {
      $H2Passed = $true
      $RecoveryNo = $true
    } else {
      Set-T00FirstFailure $State ([PSCustomObject]@{ Phase = "H2"; Category = "BLOCKED_H2" })
    }
  }

  if ($H2Passed) {
    try {
      Assert-T00NoRelevantWriters $HostContext.Identity.Name
      [void](Assert-T00EnterpriseSame $State.Baseline $HostContext $Paths)
      $State.H2AfterSame = $true
    } catch {
      $State.AfterSame = $false
      $State.H2AfterSame = $false
      $State.ManualRecovery = $true
      $RecoveryNo = $false
      Set-T00FirstFailure $State (Get-T00Failure $_) -Override
    }
    try {
      Assert-T00RecoveryBackupRetained $State.Backup $Manifest $HostContext
      $State.BackupVerifiedAfterH2 = $true
    } catch {
      $State.ManualRecovery = $true
      $RecoveryNo = $false
      Set-T00FirstFailure $State (Get-T00Failure $_)
    }
  }

  $Pass = $null -eq $State.Failure -and $State.FreshOwned -and
    $State.HelperPreflightStarted -and $State.ApplyStarted -and $State.SavePassed -and
    $State.DuringCaptured -and $State.DuringSame -and $State.CleanupSafe -and
    $State.StockStopPassed -and $State.PidDead -and $State.ServiceStateAbsent -and
    $State.PortsFree -and $State.AfterSame -and $State.SandboxDeleted -and
    $H2Passed -and $RecoveryNo -and $State.BackupRetained -and
    $State.H2AfterSame -and $State.BackupVerifiedAfterH2

  $ControlRoot = Get-T00FullPath ([string]$Manifest.workspace.controlRoot)
  $ReportPath = Join-Path $ControlRoot "run-report.json"
  $Report = [ordered]@{
    schema = "t00-run-report-v1"
    candidateSha = $ApprovedHeadSha
    workspaceId = $WorkspaceId
    manifestDigest = $ManifestDigest.ToUpperInvariant()
    h0 = "PASS"
    backup = if ($State.BackupVerifiedAfterH2) {
      "VERIFIED_RETAINED"
    } elseif ($State.BackupCreationAttempted) {
      "PARTIAL_OR_UNKNOWN"
    } else {
      "NONE"
    }
    serviceOwned = $State.FreshOwned
    helperPreflightStarted = $State.HelperPreflightStarted
    applyStarted = $State.ApplyStarted
    savePassed = $State.SavePassed
    during = if ($State.DuringSame) { "SAME" } else { "NOT_SAME" }
    cleanup = if ($State.CleanupSafe) { "PASS" } else { "NOT_PASS" }
    after = if ($State.AfterSame) { "SAME" } else { "NOT_SAME" }
    h2 = if ($H2Passed) { "PASS" } else { "NOT_PASS" }
    recovery = if ($RecoveryNo) { "NO" } elseif ($State.ManualRecovery) { "REQUIRED" } else { "UNKNOWN" }
    result = if ($Pass) { "PASS" } else { "BLOCKED" }
    category = if ($null -eq $State.Failure) { "NONE" } else { [string]$State.Failure.Category }
  }
  $ReportDigest = Write-T00JsonAtomic $ReportPath $Report
  [void](Assert-T00PrivateAcl $ReportPath $HostContext.Identity.Sid)

  if ($Pass) {
    $CleanupTicketPathValue = Join-Path $ControlRoot "recovery-cleanup-ticket.json"
    $CleanupTicket = [ordered]@{
      schema = "t00-recovery-cleanup-v1"
      candidateSha = $ApprovedHeadSha
      workspaceId = $WorkspaceId
      manifestDigest = $ManifestDigest.ToUpperInvariant()
      runReportDigest = $ReportDigest
      recoveryManifestPath = $State.Backup.Path
      recoveryManifestDigest = $State.Backup.Digest
      recoveryRoot = $State.Backup.Root
      ownerSid = $HostContext.Identity.Sid
      entries = $State.Backup.Entries
      managementPort = $State.ManagementPort
      gatewayPort = $State.GatewayPorts.Gateway
      corePort = $State.GatewayPorts.Core
      runtimeResult = "PASS"
      h2Recovery = "NO"
    }
    $CleanupTicketJson = $CleanupTicket | ConvertTo-Json -Depth 24 -Compress
    [byte[]]$CleanupTicketBytes = [Text.UTF8Encoding]::new($false).GetBytes($CleanupTicketJson + "`n")
    if ($CleanupTicketBytes.Length -gt $script:MaximumManifestBytes) {
      Stop-T00 "BLOCKED_MANIFEST_IDENTITY"
    }
    $CleanupTicketDigestValue = Get-T00Sha256Bytes $CleanupTicketBytes
    $RunSuccessPath = Join-Path $ControlRoot "run-success.marker"
    [byte[]]$RunSuccessBytes = Get-T00RunSuccessMarkerBytes $ApprovedHeadSha $WorkspaceId `
      $ManifestDigest $ReportDigest $CleanupTicketDigestValue
    $CleanupCommand = New-T00BootstrapCommand $HostContext.PowerShellExe $ManifestPath `
      $ManifestDigest $WorkspaceId $ApprovedHeadSha "CleanupBackup" `
      $CleanupTicketPathValue $CleanupTicketDigestValue $State.Backup.Digest
    Write-T00BytesAtomic $CleanupTicketPathValue $CleanupTicketBytes
    [void](Assert-T00PrivateAcl $CleanupTicketPathValue $HostContext.Identity.Sid)
    # This commit marker is the final fallible state transition. Cleanup mode
    # rejects a PASS report/ticket unless the digest-bound marker exists.
    Write-T00BytesAtomic $RunSuccessPath $RunSuccessBytes
    $State.RunSuccessCommitted = $true
    Write-Output "T00 RUNTIME RESULT: PASS"
    Write-Output "CONFIG SAVE: EXACTLY ONE VERIFIED APPLY"
    Write-Output "ENTERPRISE INVARIANCE: DURING, AFTER, AND POST-H2 SAME"
    Write-Output "SERVICE AND SANDBOX CLEANUP: PASS"
    Write-Output "RECOVERY BACKUP: VERIFIED_RETAINED"
    Write-Output "NEXT ACTION: RETURN THE CAPSULE FOR HUMAN GATE REVIEW. DO NOT RUN BACKUP CLEANUP WITHOUT SEPARATE APPROVAL."
    Write-Output "T00R|PASS|A4|H=$($script:SafeHeadPrefix)|SRC=P|PREP=P|H0=P|SAVE=1|INV=S/S|CLEAN=P|H2=P|B=R|RAW=N"
    Write-Output "INTERNAL POST-GATE BACKUP CLEANUP COMMAND (DO NOT RUN WITHOUT SEPARATE HUMAN APPROVAL):"
    Write-Output $CleanupCommand
    return
  }

  $Failure = if ($null -ne $State.Failure) {
    $State.Failure
  } else {
    [PSCustomObject]@{ Phase = "FINAL"; Category = "INTERNAL_ERROR" }
  }
  $BackupCode = if ($State.BackupCreationAttempted) { "R" } else { "N" }
  $CleanupCode = if ($State.CleanupSafe) { "P" } else { "N" }
  $BackupStatus = if ($State.BackupVerifiedAfterH2) {
    "VERIFIED_RETAINED"
  } elseif ($State.BackupCreationAttempted) {
    "PARTIAL_OR_UNKNOWN"
  } else {
    "NONE_BEFORE_ATTEMPT"
  }
  $ReadableCleanupStatus = if ($State.CleanupSafe) { "PASS" } else { "NOT_PASS" }
  Write-T00ReadableRunFailure $Failure $BackupStatus $ReadableCleanupStatus `
    ([bool]$State.ServiceMayExist) ([bool]$State.ManualRecovery)
  Write-Output ("T00R|BLOCKED|A4|H={0}|P={1}|C={2}|B={3}|CLEAN={4}|RAW=N" -f
    $script:SafeHeadPrefix, $Failure.Phase, $Failure.Category, $BackupCode, $CleanupCode)
    $script:ExitCode = 2
    return
  } catch {
    if ($State.RunSuccessCommitted) {
      # The digest-bound PASS state is already committed. A downstream output
      # consumer failure must not create a contradictory BLOCKED capsule.
      $script:ExitCode = 0
      return
    }
    $Failure = Get-T00Failure $_
    $script:ExitCode = 2
    $BackupStatus = if ($State.BackupVerifiedAfterH2) {
      "VERIFIED_RETAINED"
    } elseif ($State.BackupCreationAttempted) {
      "PARTIAL_OR_UNKNOWN"
    } else {
      "NONE_BEFORE_ATTEMPT"
    }
    $ReadableCleanupStatus = if ($State.CleanupSafe) { "PASS" } else { "NOT_PASS" }
    Write-T00ReadableRunFailure $Failure $BackupStatus $ReadableCleanupStatus `
      ([bool]$State.ServiceMayExist) $true
    Write-Output ("T00R|BLOCKED|A4|H={0}|P={1}|C={2}|B={3}|CLEAN={4}|RAW=N" -f
      $script:SafeHeadPrefix, $Failure.Phase, $Failure.Category,
      $script:FailureBackupCode, $script:FailureCleanupCode)
    return
  }
}

function Assert-T00ExactProperties {
  param(
    [Parameter(Mandatory = $true)]$Value,
    [Parameter(Mandatory = $true)][string[]]$Expected,
    [string]$FailureCategory = "BLOCKED_POST_GATE_CLEANUP"
  )
  if ($null -eq $Value) { Stop-T00 $FailureCategory }
  $Actual = @($Value.PSObject.Properties.Name)
  if (((Get-T00OrdinalSortedStrings $Actual) -join "`0") -cne
      ((Get-T00OrdinalSortedStrings $Expected) -join "`0")) {
    Stop-T00 $FailureCategory
  }
}

function ConvertTo-T00Port {
  param(
    [Parameter(Mandatory = $true)]$Value,
    [string]$FailureCategory = "BLOCKED_POST_GATE_CLEANUP"
  )
  $Port = 0
  if (-not [int]::TryParse(([string]$Value), [ref]$Port) -or $Port -lt 1 -or $Port -gt 65535) {
    Stop-T00 $FailureCategory
  }
  return $Port
}

function Get-T00RecoveryEntryValidation {
  param(
    [Parameter(Mandatory = $true)][object[]]$Entries,
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$CurrentSid,
    [switch]$VerifyFiles
  )
  $Definitions = @{
    "enterprise-settings" = [PSCustomObject]@{ Name = "enterprise-settings.bin"; Max = [Int64]16777216 }
    "claude-root" = [PSCustomObject]@{ Name = "claude-root.bin"; Max = [Int64]16777216 }
    "claude-meta" = [PSCustomObject]@{ Name = "claude-meta.bin"; Max = [Int64]16777216 }
    "claude-library" = [PSCustomObject]@{ Name = "claude-library.bin"; Max = [Int64]16777216 }
    "ccr-config" = [PSCustomObject]@{ Name = "ccr-config.sqlite.bin"; Max = [Int64]536870912 }
    "ccr-config-wal" = [PSCustomObject]@{ Name = "ccr-config.sqlite-wal.bin"; Max = [Int64]536870912 }
    "ccr-config-shm" = [PSCustomObject]@{ Name = "ccr-config.sqlite-shm.bin"; Max = [Int64]67108864 }
  }
  if ($Entries.Count -ne $Definitions.Count) { Stop-T00 "BLOCKED_POST_GATE_CLEANUP" }
  $Seen = @{}
  $Files = @{}
  $Rows = New-Object "Collections.Generic.List[string]"
  foreach ($Entry in $Entries) {
    $Id = [string]$Entry.id
    $State = [string]$Entry.state
    if ($Definitions.Keys -cnotcontains $Id -or $Seen.ContainsKey($Id) -or
        @("PRESENT", "ABSENT") -cnotcontains $State) {
      Stop-T00 "BLOCKED_POST_GATE_CLEANUP"
    }
    $Seen[$Id] = $true
    if ($State -ceq "ABSENT") {
      Assert-T00ExactProperties $Entry @("id", "state")
      $Rows.Add(("A|{0}:{1}" -f $Id.Length, $Id))
      continue
    }
    Assert-T00ExactProperties $Entry @("id", "state", "relative", "size", "sha256")
    $Definition = $Definitions[$Id]
    $Relative = [string]$Entry.relative
    $Size = [Int64]0
    $Hash = [string]$Entry.sha256
    if ($Relative -cne [string]$Definition.Name -or
        -not [Int64]::TryParse(([string]$Entry.size), [ref]$Size) -or
        $Size -lt 0 -or $Size -gt [Int64]$Definition.Max -or
        $Hash -cnotmatch $script:DigestPattern -or $Files.ContainsKey($Relative)) {
      Stop-T00 "BLOCKED_POST_GATE_CLEANUP"
    }
    if ($VerifyFiles) {
      $FilePath = Join-Path $Root $Relative
      $Item = Assert-T00RegularFile $FilePath ([Int64]$Definition.Max)
      if ([Int64]$Item.Length -ne $Size -or
          (Get-T00Sha256File $FilePath ([Int64]$Definition.Max)) -cne $Hash.ToUpperInvariant()) {
        Stop-T00 "BLOCKED_POST_GATE_CLEANUP"
      }
      [void](Assert-T00PrivateAcl $FilePath $CurrentSid)
    }
    $Files[$Relative] = $true
    $Rows.Add(("P|{0}:{1}|{2}:{3}|{4}|{5}" -f
      $Id.Length, $Id, $Relative.Length, $Relative, $Size, $Hash.ToUpperInvariant()))
  }
  if ($Seen.Count -ne $Definitions.Count) { Stop-T00 "BLOCKED_POST_GATE_CLEANUP" }
  return [PSCustomObject]@{
    Rows = @(Get-T00OrdinalSortedStrings @($Rows))
    Files = $Files
  }
}

function Get-T00RecoveryTreeValidation {
  param(
    [Parameter(Mandatory = $true)]$RecoveryManifest,
    [Parameter(Mandatory = $true)][string]$RecoveryRoot,
    [Parameter(Mandatory = $true)][string]$RecoveryManifestPath,
    [Parameter(Mandatory = $true)][string]$CurrentSid,
    [Parameter(Mandatory = $true)][string]$ExpectedSddl,
    [Parameter(Mandatory = $true)][string]$ExpectedManifestDigest
  )
  $ActualSddl = Assert-T00PrivateAcl $RecoveryRoot $CurrentSid -RequireProtected
  if ($ActualSddl -cne $ExpectedSddl) { Stop-T00 "BLOCKED_POST_GATE_CLEANUP" }
  [void](Assert-T00RegularFile $RecoveryManifestPath $script:MaximumManifestBytes)
  [void](Assert-T00PrivateAcl $RecoveryManifestPath $CurrentSid)
  $EntryValidation = Get-T00RecoveryEntryValidation @($RecoveryManifest.entries) $RecoveryRoot $CurrentSid -VerifyFiles
  $ExpectedNames = @($EntryValidation.Files.Keys) + @("recovery-manifest.json")
  $ActualEntries = @(Get-ChildItem -LiteralPath $RecoveryRoot -Force -ErrorAction Stop)
  if ($ActualEntries.Count -ne $ExpectedNames.Count) { Stop-T00 "BLOCKED_POST_GATE_CLEANUP" }
  $SeenNames = @{}
  foreach ($Entry in $ActualEntries) {
    if ($Entry.PSIsContainer -or $Entry -isnot [IO.FileInfo] -or
        (($Entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) -or
        $ExpectedNames -cnotcontains $Entry.Name -or $SeenNames.ContainsKey($Entry.Name)) {
      Stop-T00 "BLOCKED_POST_GATE_CLEANUP"
    }
    $SeenNames[$Entry.Name] = $true
  }
  $TreeRows = @($EntryValidation.Rows) + @("M|recovery-manifest.json|" + $ExpectedManifestDigest.ToUpperInvariant())
  $TreeRows = @(Get-T00OrdinalSortedStrings $TreeRows)
  return [PSCustomObject]@{
    EntryRows = $EntryValidation.Rows
    TreeRows = $TreeRows
    TreeDigest = Get-T00Sha256Text ($TreeRows -join "`0")
    Sddl = $ActualSddl
  }
}

function Assert-T00PostGateServiceAbsent {
  param(
    [Parameter(Mandatory = $true)]$HostContext,
    [Parameter(Mandatory = $true)]$Paths,
    [Parameter(Mandatory = $true)][int[]]$Ports
  )
  $ConfigState = Get-T00PathStateNoFollow $Paths.ConfigDir "BLOCKED_POST_GATE_CLEANUP"
  if (@("ABSENT", "DIRECTORY") -cnotcontains $ConfigState.State) {
    Stop-T00 "BLOCKED_POST_GATE_CLEANUP"
  }
  foreach ($Path in @($Paths.ServiceFile, $Paths.ServiceStartLock, $Paths.StockBackupFile)) {
    if (-not (Test-T00PathAbsent $Path "BLOCKED_POST_GATE_CLEANUP")) {
      Stop-T00 "BLOCKED_POST_GATE_CLEANUP"
    }
  }
  Assert-T00NoRelevantWriters $HostContext.Identity.Name
  $SeenPorts = @{}
  foreach ($Port in $Ports) {
    if ($SeenPorts.ContainsKey([string]$Port)) { continue }
    $SeenPorts[[string]$Port] = $true
    try { Assert-T00PortFree $Port } catch { Stop-T00 "BLOCKED_POST_GATE_CLEANUP" }
  }
}

function Invoke-T00CleanupBackupMode {
  Set-T00Phase "INPUT"
  if (-not $ConfirmPostGateRecoveryNo -or -not $ConfirmDeleteRecoveryBackup -or
      $WorkspaceId -cnotmatch $script:WorkspacePattern -or
      $ApprovedHeadSha -cnotmatch $script:ShaPattern -or
      $ManifestDigest -cnotmatch $script:DigestPattern -or
      $CleanupTicketDigest -cnotmatch $script:DigestPattern -or
      $RecoveryManifestDigest -cnotmatch $script:DigestPattern) {
    Stop-T00 "BLOCKED_POST_GATE_CLEANUP"
  }
  $script:SafeHeadPrefix = $ApprovedHeadSha.Substring(0, 12)
  Set-T00Phase "POST_GATE"
  $HostContext = Get-T00HostContext
  $ManifestPathFull = Get-T00FullPath $ManifestPath
  $Manifest = Read-T00VerifiedJson $ManifestPathFull $ManifestDigest
  Assert-T00ManifestAuthority $Manifest $HostContext $WorkspaceId $ApprovedHeadSha $ManifestPathFull

  $ControlRoot = Get-T00FullPath ([string]$Manifest.workspace.controlRoot)
  $ExpectedTicketPath = Join-Path $ControlRoot "recovery-cleanup-ticket.json"
  $TicketPathFull = Get-T00FullPath $CleanupTicketPath
  if ($TicketPathFull -ine $ExpectedTicketPath) { Stop-T00 "BLOCKED_POST_GATE_CLEANUP" }
  [void](Assert-T00PrivateAcl $TicketPathFull $HostContext.Identity.Sid)
  $Ticket = Read-T00VerifiedJson $TicketPathFull $CleanupTicketDigest 8388608
  Assert-T00ExactProperties $Ticket @(
    "schema", "candidateSha", "workspaceId", "manifestDigest", "runReportDigest",
    "recoveryManifestPath", "recoveryManifestDigest", "recoveryRoot", "ownerSid", "entries",
    "managementPort", "gatewayPort", "corePort", "runtimeResult", "h2Recovery"
  )
  $RecoveryRoot = Get-T00FullPath ([string]$Ticket.recoveryRoot)
  $ExpectedRecoveryRoot = Get-T00FullPath (Join-Path $HostContext.LocalAppData ("CompanyCCR\recovery\" + $WorkspaceId))
  $RecoveryManifestPathFull = Get-T00FullPath ([string]$Ticket.recoveryManifestPath)
  if ([string]$Ticket.schema -cne "t00-recovery-cleanup-v1" -or
      [string]$Ticket.candidateSha -cne $ApprovedHeadSha -or
      [string]$Ticket.workspaceId -cne $WorkspaceId -or
      [string]$Ticket.manifestDigest -cne $ManifestDigest.ToUpperInvariant() -or
      [string]$Ticket.recoveryManifestDigest -cne $RecoveryManifestDigest.ToUpperInvariant() -or
      [string]$Ticket.ownerSid -cne $HostContext.Identity.Sid -or
      [string]$Ticket.runtimeResult -cne "PASS" -or [string]$Ticket.h2Recovery -cne "NO" -or
      $RecoveryRoot -ine $ExpectedRecoveryRoot -or
      $RecoveryRoot -ine (Get-T00FullPath ([string]$Manifest.workspace.recoveryRoot)) -or
      $RecoveryManifestPathFull -ine (Join-Path $RecoveryRoot "recovery-manifest.json")) {
    Stop-T00 "BLOCKED_POST_GATE_CLEANUP"
  }
  [void](Assert-T00NoReparseAncestors $RecoveryRoot -FailureCategory "BLOCKED_POST_GATE_CLEANUP")
  if ((Get-T00PathStateNoFollow $RecoveryRoot "BLOCKED_POST_GATE_CLEANUP").State -cne "DIRECTORY") {
    Stop-T00 "BLOCKED_POST_GATE_CLEANUP"
  }

  $RunReportPath = Join-Path $ControlRoot "run-report.json"
  $RunReportDigest = [string]$Ticket.runReportDigest
  if ($RunReportDigest -cnotmatch $script:DigestPattern) { Stop-T00 "BLOCKED_POST_GATE_CLEANUP" }
  [void](Assert-T00PrivateAcl $RunReportPath $HostContext.Identity.Sid)
  $RunReport = Read-T00VerifiedJson $RunReportPath $RunReportDigest 8388608
  Assert-T00ExactProperties $RunReport @(
    "schema", "candidateSha", "workspaceId", "manifestDigest", "h0", "backup", "serviceOwned",
    "helperPreflightStarted", "applyStarted", "savePassed", "during", "cleanup", "after", "h2",
    "recovery", "result", "category"
  )
  if ([string]$RunReport.schema -cne "t00-run-report-v1" -or
      [string]$RunReport.candidateSha -cne $ApprovedHeadSha -or
      [string]$RunReport.workspaceId -cne $WorkspaceId -or
      [string]$RunReport.manifestDigest -cne $ManifestDigest.ToUpperInvariant() -or
      [string]$RunReport.h0 -cne "PASS" -or [string]$RunReport.backup -cne "VERIFIED_RETAINED" -or
      $RunReport.serviceOwned -ne $true -or $RunReport.helperPreflightStarted -ne $true -or
      $RunReport.applyStarted -ne $true -or $RunReport.savePassed -ne $true -or
      [string]$RunReport.during -cne "SAME" -or [string]$RunReport.cleanup -cne "PASS" -or
      [string]$RunReport.after -cne "SAME" -or [string]$RunReport.h2 -cne "PASS" -or
      [string]$RunReport.recovery -cne "NO" -or [string]$RunReport.result -cne "PASS" -or
      [string]$RunReport.category -cne "NONE") {
    Stop-T00 "BLOCKED_POST_GATE_CLEANUP"
  }
  $RunSuccessPath = Join-Path $ControlRoot "run-success.marker"
  [byte[]]$ExpectedRunSuccessBytes = Get-T00RunSuccessMarkerBytes $ApprovedHeadSha $WorkspaceId `
    $ManifestDigest $RunReportDigest $CleanupTicketDigest
  Assert-T00RunSuccessMarker $RunSuccessPath $ExpectedRunSuccessBytes $HostContext.Identity.Sid

  $RecoveryManifest = Read-T00VerifiedJson $RecoveryManifestPathFull $RecoveryManifestDigest 8388608
  Assert-T00ExactProperties $RecoveryManifest @(
    "schema", "workspaceId", "candidateSha", "root", "ownerSid", "sddl", "entries"
  )
  if ([string]$RecoveryManifest.schema -cne "t00-recovery-manifest-v1" -or
      [string]$RecoveryManifest.workspaceId -cne $WorkspaceId -or
      [string]$RecoveryManifest.candidateSha -cne $ApprovedHeadSha -or
      (Get-T00FullPath ([string]$RecoveryManifest.root)) -ine $RecoveryRoot -or
      [string]$RecoveryManifest.ownerSid -cne $HostContext.Identity.Sid -or
      [string]::IsNullOrWhiteSpace([string]$RecoveryManifest.sddl)) {
    Stop-T00 "BLOCKED_POST_GATE_CLEANUP"
  }
  $TicketEntries = Get-T00RecoveryEntryValidation @($Ticket.entries) $RecoveryRoot $HostContext.Identity.Sid
  $First = Get-T00RecoveryTreeValidation $RecoveryManifest $RecoveryRoot $RecoveryManifestPathFull `
    $HostContext.Identity.Sid ([string]$RecoveryManifest.sddl) $RecoveryManifestDigest
  if (($TicketEntries.Rows -join "`0") -cne ($First.EntryRows -join "`0")) {
    Stop-T00 "BLOCKED_POST_GATE_CLEANUP"
  }
  $Ports = @(
    (ConvertTo-T00Port $Ticket.managementPort),
    (ConvertTo-T00Port $Ticket.gatewayPort),
    (ConvertTo-T00Port $Ticket.corePort)
  )
  $Paths = Get-T00RuntimePaths $HostContext
  Assert-T00PostGateServiceAbsent $HostContext $Paths $Ports

  $ConsumedMarker = Join-Path $ControlRoot "recovery-cleanup-consumed.marker"
  Write-T00BytesAtomic $ConsumedMarker ([Text.Encoding]::ASCII.GetBytes("POST-GATE-CLEANUP-CONSUMED`n"))
  [void](Assert-T00PrivateAcl $ConsumedMarker $HostContext.Identity.Sid)

  $ManifestSecond = Read-T00VerifiedJson $ManifestPathFull $ManifestDigest
  Assert-T00ManifestAuthority $ManifestSecond $HostContext $WorkspaceId $ApprovedHeadSha $ManifestPathFull
  $TicketSecond = Read-T00VerifiedJson $TicketPathFull $CleanupTicketDigest 8388608
  $RunReportSecond = Read-T00VerifiedJson $RunReportPath $RunReportDigest 8388608
  $RecoverySecond = Read-T00VerifiedJson $RecoveryManifestPathFull $RecoveryManifestDigest 8388608
  if ([string]$TicketSecond.schema -cne "t00-recovery-cleanup-v1" -or
      [string]$RunReportSecond.result -cne "PASS" -or
      [string]$RecoverySecond.schema -cne "t00-recovery-manifest-v1") {
    Stop-T00 "BLOCKED_POST_GATE_CLEANUP"
  }
  [void](Assert-T00PrivateAcl $TicketPathFull $HostContext.Identity.Sid)
  [void](Assert-T00PrivateAcl $RunReportPath $HostContext.Identity.Sid)
  $Second = Get-T00RecoveryTreeValidation $RecoverySecond $RecoveryRoot $RecoveryManifestPathFull `
    $HostContext.Identity.Sid ([string]$RecoverySecond.sddl) $RecoveryManifestDigest
  Assert-T00PostGateServiceAbsent $HostContext $Paths $Ports
  if ($First.Sddl -cne $Second.Sddl -or $First.TreeDigest -cne $Second.TreeDigest -or
      ($First.TreeRows -join "`0") -cne ($Second.TreeRows -join "`0") -or
      ($First.EntryRows -join "`0") -cne ($Second.EntryRows -join "`0")) {
    Stop-T00 "BLOCKED_POST_GATE_CLEANUP"
  }
  Assert-T00RunSuccessMarker $RunSuccessPath $ExpectedRunSuccessBytes $HostContext.Identity.Sid
  Remove-T00TreeNoFollow $RecoveryRoot $HostContext.Identity.Sid
  if (-not (Test-T00PathAbsent $RecoveryRoot "BLOCKED_POST_GATE_CLEANUP")) {
    Stop-T00 "BLOCKED_POST_GATE_CLEANUP"
  }
  $script:CleanupDeletionCommitted = $true
  Write-Output "T00 BACKUP CLEANUP RESULT: PASS"
  Write-Output "RECOVERY BACKUP: EXACT DELETION VERIFIED"
  Write-Output "NEXT ACTION: RETURN THE CAPSULE FOR HUMAN GATE REVIEW."
  Write-Output "T00C|PASS|H=$($script:SafeHeadPrefix)|B=D|RAW=N"
}

try {
  if ($PSCmdlet.ParameterSetName -ceq "Prepare") {
    Invoke-T00PrepareMode
  } elseif ($PSCmdlet.ParameterSetName -ceq "Run") {
    Invoke-T00RunMode
  } elseif ($PSCmdlet.ParameterSetName -ceq "CleanupBackup") {
    Invoke-T00CleanupBackupMode
  } else {
    Stop-T00 "BLOCKED_INPUT_CONTRACT"
  }
} catch {
  $Failure = Get-T00Failure $_
  $script:ExitCode = 2
  if ($PSCmdlet.ParameterSetName -ceq "CleanupBackup" -and $script:CleanupDeletionCommitted) {
    $script:ExitCode = 0
  } elseif ($PSCmdlet.ParameterSetName -ceq "CleanupBackup") {
    Write-Output "T00 BACKUP CLEANUP RESULT: BLOCKED"
    Write-Output "RECOVERY BACKUP: PARTIAL_OR_UNKNOWN. DO NOT ASSUME IT WAS DELETED OR PRESERVED BYTE-PERFECT."
    Write-Output "NEXT ACTION: STOP. MANUAL REVIEW IS REQUIRED; DO NOT ACCEPT OR MERGE T00."
    Write-Output "T00C|BLOCKED|H=$($script:SafeHeadPrefix)|C=BLOCKED_POST_GATE_CLEANUP|B=R|RAW=N"
  } elseif ($PSCmdlet.ParameterSetName -ceq "Prepare") {
    $LocalWriteText = if ($script:PrepareLocalWriteAttempted) { "YES" } else { "NO" }
    $InstallText = if ($script:PrepareNpmInstallAttempted) { "YES" } else { "NO" }
    $NpmPermissionText = if ($script:PrepareNpmEffectsAllowed) { "ALLOW" } else { "NONE" }
    $TypecheckText = if ($script:PrepareTypecheckAttempted) { "YES" } else { "NO" }
    $BuildText = if ($script:PrepareBuildAttempted) { "YES" } else { "NO" }
    Write-Output "T00 PREPARE RESULT: BLOCKED"
    Write-Output ("STOPPED PHASE: {0}" -f $Failure.Phase)
    Write-Output ("FAILURE CATEGORY: {0}" -f $Failure.Category)
    Write-Output ("WORKSPACE ID: {0}" -f $script:PrepareWorkspaceId)
    Write-Output ("LOCAL WORKSPACE WRITE ATTEMPTED: {0}" -f $LocalWriteText)
    Write-Output ("NPM CI INVOCATION ATTEMPTED: {0}" -f $InstallText)
    Write-Output ("NPM NETWORK PERMISSION: {0}" -f $NpmPermissionText)
    Write-Output ("NPM LIFECYCLE PERMISSION: {0}" -f $NpmPermissionText)
    Write-Output "ACTUAL NETWORK CONNECTION: NOT_OBSERVED"
    Write-Output "ACTUAL LIFECYCLE CHILD EXECUTION: NOT_OBSERVED"
    Write-Output ("TYPECHECK ATTEMPTED: {0}" -f $TypecheckText)
    Write-Output ("BUILD ATTEMPTED: {0}" -f $BuildText)
    Write-Output "CCR SERVICE OR H0 STARTED BY THIS COMMAND: NO"
    if ($script:PrepareCleanupCode -ceq "N") {
      Write-Output "NATIVE CHILD CLEANUP: NOT_PROVEN. MANUAL PROCESS REVIEW IS REQUIRED."
    } else {
      Write-Output "NATIVE CHILD CLEANUP: PASS_OR_NOT_REQUIRED"
    }
    Write-Output "NEXT ACTION: STOP. DO NOT RUN H0, THE RUN COMMAND, A1+, T01, MERGE, OR THE NEXT TASK."
    Write-Output ("T00R|BLOCKED|A4|H={0}|P={1}|C={2}|B=N|CLEAN={3}|RAW=N" -f
      $script:SafeHeadPrefix, $Failure.Phase, $Failure.Category, $script:PrepareCleanupCode)
  } else {
    $EarlyCleanupStatus = if ($script:NativeCleanupUncertain) { "NOT_PASS" } else { "NOT_REQUIRED" }
    $EarlyCleanupCode = if ($script:NativeCleanupUncertain) { "N" } else { "P" }
    Write-T00ReadableRunFailure $Failure "NONE_BEFORE_ATTEMPT" $EarlyCleanupStatus `
      $false ([bool]$script:NativeCleanupUncertain)
    Write-Output ("T00R|BLOCKED|A4|H={0}|P={1}|C={2}|B={3}|CLEAN={4}|RAW=N" -f
      $script:SafeHeadPrefix, $Failure.Phase, $Failure.Category,
      $script:FailureBackupCode, $EarlyCleanupCode)
  }
} finally {
  $ErrorActionPreference = $script:SavedErrorActionPreference
  $ProgressPreference = $script:SavedProgressPreference
}

exit $script:ExitCode
