[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$PreparedGitDir,
  [Parameter(Mandatory = $true)][string]$PreparedCandidateRef,
  [Parameter(Mandatory = $true)][string]$PreparedMainRef,
  [Parameter(Mandatory = $true)][string]$MainSha,
  [Parameter(Mandatory = $true)][string]$CandidateSha,
  [Parameter(Mandatory = $true)][string]$InstructionSha,
  [Parameter(Mandatory = $true)][string]$ValidatedProductSha,
  [Parameter(Mandatory = $true)][string]$TaskPath,
  [Parameter(Mandatory = $true)][string]$EnvironmentAlias,
  [switch]$ConfirmNoSeparateAccountOrVmRequired,
  [switch]$ConfirmNoSameAccountConcurrentUse,
  [switch]$AllowNpmNetworkAndLifecycle
)

Set-StrictMode -Version 2.0

$SavedErrorActionPreference = $ErrorActionPreference
$SavedProgressPreference = $ProgressPreference
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$CanonicalTaskPath = "company/tasks/v1-s1/V1-S1-T00-CCR-RUNTIME-SANDBOX.md"
$ScriptRepositoryPath = "company/scripts/t00-a0-preflight.ps1"
$CanonicalCandidateRef = "refs/internal-validation/v1-s1-t00-candidate"
$CanonicalMainRef = "refs/internal-validation/v1-s1-t00-main"
$CanonicalMainSha = "6d0d6f2aeca02e33261c062eac5aab360805222b"
$CanonicalValidatedProductSha = "97b73a9f4e1fb23d406bb987d0785cefa1f99966"
$T02HelperRepositoryPath = "company/scripts/t00-safe-config-save.mjs"
$T02TestRepositoryPath = "company/tests/t00-safe-config-save.test.mjs"
$T02HelperBlob = "cc1ef5f92b5448f2ef2ddd6ef384c6fdce711ff8"
$T02TestBlob = "f711915a7ed7a98a55d81c486e1f5027cd6cd86c"
$ShaPattern = "^[0-9a-f]{40}$"
$AliasPattern = "^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$"
$CaptureLimitChars = 524288
$CurrentStage = "INPUT"
$Checkpoint = "INPUT"
$Result = "BLOCKED"
$InternalCategory = "INTERNAL_ERROR"
$Category = "INTERNAL_ERROR"
$ExternalPhase = "HOST"
$WorkspaceId = "NONE"
$SafeEnvironmentAlias = "INVALID"
$SafeCandidateSha = "INVALID"
$ValidationRoot = $null
$ExecutionRoot = $null
$NodeVersion = "UNKNOWN"
$NodeLts = "UNKNOWN"
$NpmVersion = "UNKNOWN"
$SourceVerified = $false
$ProductVerified = $false
$ToolchainVerified = $false
$InstallPassed = $false
$TypecheckPassed = $false
$BuildPassed = $false
$CliExists = $false
$T02ArtifactVerified = $false
$NpmExecutionStarted = $false

function Stop-A0 {
  param([Parameter(Mandatory = $true)][string]$FailureCategory)

  if ($FailureCategory -cnotmatch "^[A-Z0-9_]+$") {
    $FailureCategory = "BLOCKED_A0_UNEXPECTED"
  }
  throw ("A0_BLOCK::{0}" -f $FailureCategory)
}

function ConvertTo-A0ExternalFailure {
  param(
    [Parameter(Mandatory = $true)][string]$Stage,
    [Parameter(Mandatory = $true)][string]$FailureCategory
  )

  $Map = @{
    "INPUT" = @("HOST", "BLOCKED_POLICY")
    "HOST" = @("HOST", "BLOCKED_HOST")
    "SOURCE_PROVENANCE" = @("SOURCE", "BLOCKED_SOURCE_IDENTITY")
    "TOOLCHAIN" = @("TOOL", "BLOCKED_TOOLCHAIN")
    "NPM_CI" = @("INSTALL", "BLOCKED_DEPENDENCY_INSTALL")
    "TYPECHECK" = @("TYPE", "BLOCKED_TYPECHECK")
    "BUILD" = @("BUILD", "BLOCKED_BUILD")
  }
  if ($FailureCategory -ceq "BLOCKED_NATIVE_CLEANUP") {
    return [PSCustomObject]@{ Phase = "FINAL"; Category = "BLOCKED_CLEANUP" }
  }
  if ($FailureCategory -ceq "BLOCKED_NATIVE_RUNNER") {
    return [PSCustomObject]@{ Phase = "FINAL"; Category = "INTERNAL_ERROR" }
  }
  if ($Map.ContainsKey($Stage)) {
    return [PSCustomObject]@{ Phase = $Map[$Stage][0]; Category = $Map[$Stage][1] }
  }
  $FinalCategory = switch ($FailureCategory) {
    "BLOCKED_BUILD_TREE_MUTATION" { "BLOCKED_SOURCE_MUTATION"; break }
    "BLOCKED_EXECUTION_TREE" { "BLOCKED_SOURCE_MUTATION"; break }
    "BLOCKED_TOOLCHAIN_IDENTITY" { "BLOCKED_TOOLCHAIN"; break }
    "BLOCKED_BUILD_ASSETS" { "BLOCKED_BUILD"; break }
    default { "INTERNAL_ERROR" }
  }
  return [PSCustomObject]@{ Phase = "FINAL"; Category = $FinalCategory }
}

function Get-A0Sha256Text {
  param([Parameter(Mandatory = $true)][string]$Text)

  $Bytes = [Text.Encoding]::UTF8.GetBytes($Text)
  $Hasher = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($Hasher.ComputeHash($Bytes))).Replace("-", "")
  } finally {
    $Hasher.Dispose()
  }
}

function Resolve-A0Application {
  param([Parameter(Mandatory = $true)][string]$Name)

  try {
    $Commands = @(
      Microsoft.PowerShell.Core\Get-Command `
        -Name $Name `
        -CommandType Application `
        -All `
        -ErrorAction Stop
    )
  } catch {
    Stop-A0 "BLOCKED_TOOLCHAIN_IDENTITY"
  }
  if ($Commands.Count -lt 1) {
    Stop-A0 "BLOCKED_TOOLCHAIN_IDENTITY"
  }

  # Bind the same first application PowerShell would execute. Multiple PATH copies
  # are reported by Get-Command -All but are not themselves a validation failure.
  $Path = [string]$Commands[0].Path
  if ([string]::IsNullOrWhiteSpace($Path)) {
    Stop-A0 "BLOCKED_TOOLCHAIN_IDENTITY"
  }
  $FullPath = [IO.Path]::GetFullPath($Path)
  if (-not [IO.File]::Exists($FullPath)) {
    Stop-A0 "BLOCKED_TOOLCHAIN_IDENTITY"
  }
  return $FullPath
}

function ConvertTo-A0WindowsArgument {
  param([AllowEmptyString()][string]$Value)

  if ($null -eq $Value) {
    Stop-A0 "BLOCKED_NATIVE_ARGUMENT"
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

function Stop-A0ProcessTree {
  param([Parameter(Mandatory = $true)][Diagnostics.Process]$Process)

  if ($Process.HasExited) {
    # A descendant may still own a redirected pipe; cleanup cannot be proven.
    return $false
  }

  $TreeKillSucceeded = $false
  $TreeKiller = $null
  try {
    $TaskkillPath = Join-Path ([Environment]::SystemDirectory) "taskkill.exe"
    if ([IO.File]::Exists($TaskkillPath)) {
      $TaskkillInfo = New-Object Diagnostics.ProcessStartInfo
      $TaskkillInfo.FileName = $TaskkillPath
      $TaskkillInfo.Arguments = "/PID $($Process.Id) /T /F"
      $TaskkillInfo.UseShellExecute = $false
      $TaskkillInfo.CreateNoWindow = $true
      $TaskkillInfo.RedirectStandardOutput = $true
      $TaskkillInfo.RedirectStandardError = $true
      $TreeKiller = [Diagnostics.Process]::Start($TaskkillInfo)
      $TreeKillerOut = $TreeKiller.StandardOutput.ReadToEndAsync()
      $TreeKillerErr = $TreeKiller.StandardError.ReadToEndAsync()
      if ($TreeKiller.WaitForExit(15000)) {
        $TreeKillSucceeded = ($TreeKiller.ExitCode -eq 0)
      } else {
        try { $TreeKiller.Kill() } catch { }
      }
      [void]$TreeKillerOut.Wait(1000)
      [void]$TreeKillerErr.Wait(1000)
    }
  } catch {
    $TreeKillSucceeded = $false
  } finally {
    if ($null -ne $TreeKiller) {
      $TreeKiller.Dispose()
    }
  }

  if (-not $Process.HasExited) {
    try { $Process.Kill() } catch { }
  }
  $ParentExited = $Process.HasExited -or $Process.WaitForExit(10000)
  return ($TreeKillSucceeded -and $ParentExited)
}

function Invoke-A0Native {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [string[]]$ArgumentList = @(),
    [Parameter(Mandatory = $true)][string]$WorkingDirectory,
    [Parameter(Mandatory = $true)][int]$TimeoutSeconds,
    [hashtable]$EnvironmentSet = @{},
    [string[]]$EnvironmentRemove = @()
  )

  if (-not [IO.File]::Exists($FilePath) -or
      -not [IO.Directory]::Exists($WorkingDirectory) -or
      $TimeoutSeconds -lt 1 -or
      $TimeoutSeconds -gt 3600) {
    Stop-A0 "BLOCKED_NATIVE_COMMAND_CONTRACT"
  }

  $CommandLine = @($ArgumentList | ForEach-Object {
    ConvertTo-A0WindowsArgument ([string]$_)
  }) -join " "

  $StartInfo = New-Object Diagnostics.ProcessStartInfo
  $StartInfo.FileName = $FilePath
  $StartInfo.Arguments = $CommandLine
  $StartInfo.WorkingDirectory = $WorkingDirectory
  $StartInfo.UseShellExecute = $false
  $StartInfo.CreateNoWindow = $true
  $StartInfo.RedirectStandardOutput = $true
  $StartInfo.RedirectStandardError = $true

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
  $LaunchSucceeded = $false
  $TimedOut = $false
  $CleanupSucceeded = $true
  $ExitCode = $null
  $StdOutBuilder = New-Object Text.StringBuilder
  $StdErrBuilder = New-Object Text.StringBuilder
  $OutputTruncated = $false
  $RunnerFault = $false

  try {
    $LaunchSucceeded = $Process.Start()
    if (-not $LaunchSucceeded) {
      throw "Native process did not start."
    }

    # Drain both streams concurrently while retaining at most CaptureLimitChars.
    $ChunkSize = 8192
    $StdOutChunk = New-Object 'char[]' $ChunkSize
    $StdErrChunk = New-Object 'char[]' $ChunkSize
    $StdOutTask = $Process.StandardOutput.ReadAsync($StdOutChunk, 0, $ChunkSize)
    $StdErrTask = $Process.StandardError.ReadAsync($StdErrChunk, 0, $ChunkSize)
    $Deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ($null -ne $StdOutTask -or $null -ne $StdErrTask) {
      $MadeProgress = $false
      if ($null -ne $StdOutTask -and $StdOutTask.IsCompleted) {
        $Count = $StdOutTask.Result
        if ($Count -eq 0) {
          $StdOutTask = $null
        } else {
          $Take = [Math]::Min($Count, $CaptureLimitChars - $StdOutBuilder.Length)
          if ($Take -gt 0) { [void]$StdOutBuilder.Append($StdOutChunk, 0, $Take) }
          if ($Take -lt $Count) { $OutputTruncated = $true }
          $StdOutTask = $Process.StandardOutput.ReadAsync($StdOutChunk, 0, $ChunkSize)
        }
        $MadeProgress = $true
      }
      if ($null -ne $StdErrTask -and $StdErrTask.IsCompleted) {
        $Count = $StdErrTask.Result
        if ($Count -eq 0) {
          $StdErrTask = $null
        } else {
          $Take = [Math]::Min($Count, $CaptureLimitChars - $StdErrBuilder.Length)
          if ($Take -gt 0) { [void]$StdErrBuilder.Append($StdErrChunk, 0, $Take) }
          if ($Take -lt $Count) { $OutputTruncated = $true }
          $StdErrTask = $Process.StandardError.ReadAsync($StdErrChunk, 0, $ChunkSize)
        }
        $MadeProgress = $true
      }
      if ([DateTime]::UtcNow -ge $Deadline) {
        $TimedOut = $true
        $CleanupSucceeded = Stop-A0ProcessTree $Process
        break
      }
      if (-not $MadeProgress) { [Threading.Thread]::Sleep(10) }
    }

    if (-not $TimedOut) {
      $RemainingMilliseconds = [int][Math]::Max(
        1,
        ($Deadline - [DateTime]::UtcNow).TotalMilliseconds
      )
      if (-not $Process.WaitForExit($RemainingMilliseconds)) {
        $TimedOut = $true
        $CleanupSucceeded = Stop-A0ProcessTree $Process
      } else {
        $Process.WaitForExit()
        $ExitCode = $Process.ExitCode
      }
    }
  } catch {
    $ExitCode = $null
    $RunnerFault = $LaunchSucceeded
    if ($LaunchSucceeded) {
      if (-not $Process.HasExited) {
        $CleanupSucceeded = Stop-A0ProcessTree $Process
      } else {
        # An unexpected reader/runtime fault after parent exit leaves descendant
        # cleanup unprovable, so fail closed as BLOCKED_CLEANUP.
        $CleanupSucceeded = $false
      }
    }
  } finally {
    $Process.Dispose()
  }

  return [PSCustomObject]@{
    Started = $LaunchSucceeded
    TimedOut = $TimedOut
    CleanupSucceeded = $CleanupSucceeded
    ExitCode = $ExitCode
    StdOut = $StdOutBuilder.ToString()
    StdErr = $StdErrBuilder.ToString()
    OutputTruncated = $OutputTruncated
    RunnerFault = $RunnerFault
  }
}

function Assert-A0NativeSuccess {
  param(
    [Parameter(Mandatory = $true)]$Invocation,
    [Parameter(Mandatory = $true)][string]$FailureCategory
  )

  if (-not $Invocation.Started) {
    Stop-A0 "BLOCKED_NATIVE_COMMAND_START"
  }
  if (-not $Invocation.CleanupSucceeded) {
    Stop-A0 "BLOCKED_NATIVE_CLEANUP"
  }
  if ($Invocation.TimedOut) {
    Stop-A0 "BLOCKED_NATIVE_COMMAND_TIMEOUT"
  }
  if ($Invocation.RunnerFault) {
    Stop-A0 "BLOCKED_NATIVE_RUNNER"
  }
  if ($null -eq $Invocation.ExitCode -or $Invocation.ExitCode -ne 0) {
    Stop-A0 $FailureCategory
  }
  if ($Invocation.OutputTruncated) {
    Stop-A0 "BLOCKED_NATIVE_OUTPUT_LIMIT"
  }
}

function Get-A0SingleLine {
  param(
    [Parameter(Mandatory = $true)]$Invocation,
    [Parameter(Mandatory = $true)][string]$FailureCategory
  )

  Assert-A0NativeSuccess $Invocation $FailureCategory
  $Value = ([string]$Invocation.StdOut).Trim()
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -match "[`r`n]") {
    Stop-A0 $FailureCategory
  }
  return $Value
}

function Get-A0SourceFingerprint {
  param([Parameter(Mandatory = $true)][string]$Root)

  $Rows = New-Object "Collections.Generic.List[string]"
  $NormalizedRoot = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
  $PendingDirectories = New-Object "Collections.Generic.Stack[string]"
  $PendingDirectories.Push($NormalizedRoot)
  while ($PendingDirectories.Count -gt 0) {
    $CurrentDirectory = $PendingDirectories.Pop()
    $Entries = @(
      Get-ChildItem -LiteralPath $CurrentDirectory -Force -ErrorAction Stop |
        Sort-Object Name -CaseSensitive
    )
    foreach ($Entry in $Entries) {
      $RelativePath = $Entry.FullName.Substring($NormalizedRoot.Length).TrimStart('\', '/')
      if ($Entry.PSIsContainer) {
        # Prune generated/dependency trees before recursion. Enumerating all of
        # node_modules on Windows is both unnecessary and failure-prone.
        if ($RelativePath -imatch '(^|\\)node_modules$' -or
            $RelativePath -imatch '^packages\\[^\\]+\\dist$') {
          continue
        }
        if (($Entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
          Stop-A0 "BLOCKED_EXECUTION_TREE"
        }
        $PendingDirectories.Push($Entry.FullName)
        continue
      }
      if ($Entry -isnot [IO.FileInfo] -or
          (($Entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
        Stop-A0 "BLOCKED_EXECUTION_TREE"
      }
      $Hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Entry.FullName).Hash
      $Rows.Add(("{0}:{1}|{2}|{3}" -f $RelativePath.Length, $RelativePath, $Entry.Length, $Hash))
    }
  }
  if ($Rows.Count -eq 0) {
    Stop-A0 "BLOCKED_EXECUTION_TREE"
  }
  $SortedRows = @($Rows | Sort-Object -CaseSensitive)
  return Get-A0Sha256Text ($SortedRows -join "`0")
}

function Get-A0SensitiveEnvironmentKeys {
  $FixedKeys = @(
    "CLAUDE_CONFIG_DIR",
    "NODE_COMPILE_CACHE",
    "NODE_DEBUG",
    "NODE_ENV",
    "NODE_OPTIONS",
    "NODE_PATH",
    "NODE_REDIRECT_WARNINGS",
    "NODE_V8_COVERAGE",
    "npm_config_node_options",
    "npm_config_script_shell"
  )
  # PowerShell hashtables compare string keys case-insensitively by default.
  $Keys = @{}
  foreach ($Key in $FixedKeys) {
    $Keys[$Key] = $true
  }
  $EnvironmentTable = [Environment]::GetEnvironmentVariables(
    [EnvironmentVariableTarget]::Process
  )
  foreach ($KeyObject in $EnvironmentTable.Keys) {
    $Key = [string]$KeyObject
    if ($Key -match '^(?i:npm_config_)' -or
        $Key -match '(?i)(TOKEN|SECRET|PASSWORD|PASSWD|API_?KEY|CREDENTIAL)' -or
        $Key -match '^(?i:ANTHROPIC|CLAUDE|CCR|CODEXL|OPENAI|AZURE|AWS|GOOGLE|GCP|GEMINI)_') {
      $Keys[$Key] = $true
    }
  }
  return @($Keys.Keys)
}

function Get-A0GitEnvironmentKeys {
  $Keys = New-Object "Collections.Generic.List[string]"
  $EnvironmentTable = [Environment]::GetEnvironmentVariables(
    [EnvironmentVariableTarget]::Process
  )
  foreach ($KeyObject in $EnvironmentTable.Keys) {
    $Key = [string]$KeyObject
    if ($Key -match '^(?i:GIT_)') {
      $Keys.Add($Key)
    }
  }
  return @($Keys)
}

try {
  $CurrentStage = "INPUT"
  $Checkpoint = "INPUT"
  foreach ($Sha in @($MainSha, $CandidateSha, $InstructionSha, $ValidatedProductSha)) {
    if ($Sha -cnotmatch $ShaPattern) {
      Stop-A0 "BLOCKED_INPUT_CONTRACT"
    }
  }
  $SafeCandidateSha = $CandidateSha
  if ($MainSha -cne $CanonicalMainSha -or
      $ValidatedProductSha -cne $CanonicalValidatedProductSha -or
      $CandidateSha -cne $InstructionSha -or
      $PreparedCandidateRef -cne $CanonicalCandidateRef -or
      $PreparedMainRef -cne $CanonicalMainRef -or
      $TaskPath -cne $CanonicalTaskPath -or
      $EnvironmentAlias -cnotmatch $AliasPattern -or
      -not $ConfirmNoSeparateAccountOrVmRequired -or
      -not $ConfirmNoSameAccountConcurrentUse -or
      -not $AllowNpmNetworkAndLifecycle) {
    Stop-A0 "BLOCKED_INPUT_CONTRACT"
  }
  $SafeEnvironmentAlias = $EnvironmentAlias
  $CurrentStage = "HOST"
  $Checkpoint = "HOST"
  if (-not [Environment]::Is64BitOperatingSystem -or
      -not [Environment]::Is64BitProcess -or
      $PSVersionTable.PSEdition -cne "Desktop" -or
      $PSVersionTable.PSVersion.Major -ne 5 -or
      $PSVersionTable.PSVersion.Minor -ne 1 -or
      [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
    Stop-A0 "BLOCKED_WINDOWS_RUNTIME"
  }

  $PreparedGitDir = [IO.Path]::GetFullPath(
    (Resolve-Path -LiteralPath $PreparedGitDir -ErrorAction Stop).Path
  ).TrimEnd('\', '/')
  $WorkspaceBase = [IO.Path]::GetFullPath(
    (Join-Path $env:LOCALAPPDATA "CompanyCCR\validation-workspaces")
  ).TrimEnd('\', '/')
  $ValidationRoot = Split-Path -Parent $PreparedGitDir
  $CandidateWorkspaceId = Split-Path -Leaf $ValidationRoot
  if (-not [IO.Directory]::Exists($PreparedGitDir) -or
      (Split-Path -Leaf $PreparedGitDir) -cne "repo.git" -or
      (Split-Path -Parent $ValidationRoot).TrimEnd('\', '/') -ine $WorkspaceBase -or
      $CandidateWorkspaceId -cnotmatch '^[0-9a-f]{32}$') {
    Stop-A0 "BLOCKED_PREPARED_REPOSITORY"
  }
  $WorkspaceId = $CandidateWorkspaceId

  $CurrentStage = "TOOLCHAIN"
  $Checkpoint = "GIT_BIND"
  $GitExe = Resolve-A0Application "git.exe"
  $Checkpoint = "NODE_BIND"
  $NodeExe = Resolve-A0Application "node.exe"
  $NodeDirectory = Split-Path -Parent $NodeExe
  $NpmCli = Join-Path $NodeDirectory "node_modules\npm\bin\npm-cli.js"
  if (-not [IO.File]::Exists($NpmCli)) {
    Stop-A0 "BLOCKED_TOOLCHAIN_IDENTITY"
  }

  $CurrentStage = "HOST"
  $Checkpoint = "HOST"
  $ExecutionRoot = Join-Path $ValidationRoot "source"
  if ([IO.Directory]::Exists($ExecutionRoot) -or [IO.File]::Exists($ExecutionRoot)) {
    Stop-A0 "BLOCKED_WORKSPACE"
  }
  [void][IO.Directory]::CreateDirectory($ExecutionRoot)

  $GitEnvironmentRemove = Get-A0GitEnvironmentKeys
  $GitEnvironmentSet = @{
    "GIT_CONFIG_NOSYSTEM" = "1"
    "GIT_CONFIG_GLOBAL" = "NUL"
    "GIT_OPTIONAL_LOCKS" = "0"
    "GIT_TERMINAL_PROMPT" = "0"
  }
  $GitPrefix = @("--no-replace-objects", "--git-dir=$PreparedGitDir")
  function Invoke-A0Git {
    param(
      [Parameter(Mandatory = $true)][string[]]$GitArguments,
      [int]$TimeoutSeconds = 120
    )
    return Invoke-A0Native $GitExe ($GitPrefix + $GitArguments) `
      $ValidationRoot $TimeoutSeconds $GitEnvironmentSet $GitEnvironmentRemove
  }

  $CurrentStage = "SOURCE_PROVENANCE"
  $Checkpoint = "REFS"
  $BareResult = Invoke-A0Git -GitArguments @("rev-parse", "--is-bare-repository")
  if ((Get-A0SingleLine $BareResult "BLOCKED_PREPARED_REPOSITORY") -cne "true") {
    Stop-A0 "BLOCKED_PREPARED_REPOSITORY"
  }

  $CandidateRefResult = Invoke-A0Git -GitArguments @("rev-parse", "--verify", "$PreparedCandidateRef^{commit}")
  if ((Get-A0SingleLine $CandidateRefResult "BLOCKED_SOURCE_PROVENANCE") -cne $CandidateSha) {
    Stop-A0 "BLOCKED_SOURCE_PROVENANCE"
  }
  $MainRefResult = Invoke-A0Git -GitArguments @("rev-parse", "--verify", "$PreparedMainRef^{commit}")
  if ((Get-A0SingleLine $MainRefResult "BLOCKED_SOURCE_PROVENANCE") -cne $MainSha) {
    Stop-A0 "BLOCKED_SOURCE_PROVENANCE"
  }
  foreach ($CommitSha in @($InstructionSha, $ValidatedProductSha)) {
    $CommitResult = Invoke-A0Git -GitArguments @("rev-parse", "--verify", "$CommitSha^{commit}")
    if ((Get-A0SingleLine $CommitResult "BLOCKED_SOURCE_PROVENANCE") -cne $CommitSha) {
      Stop-A0 "BLOCKED_SOURCE_PROVENANCE"
    }
  }

  $AncestorResult = Invoke-A0Git -GitArguments @("merge-base", "--is-ancestor", $MainSha, $CandidateSha)
  Assert-A0NativeSuccess $AncestorResult "BLOCKED_SOURCE_PROVENANCE"

  $Checkpoint = "TASK"
  $TaskSpec = "${InstructionSha}:$TaskPath"
  $TaskResult = Invoke-A0Git -GitArguments @("show", $TaskSpec)
  Assert-A0NativeSuccess $TaskResult "BLOCKED_INSTRUCTION_LOAD"
  $RequiredTaskMetadata = @(
    '(?m)^id:\s*V1-S1-T00\s*$',
    '(?m)^stage:\s*V1-S1\s*$',
    '(?m)^primary_actor:\s*INTERNAL_VALIDATOR\s*$',
    '(?m)^execution_mode:\s*agent_only\s*$',
    '(?m)^candidate_role:\s*validation_overlay\s*$',
    '(?m)^tested_product_sha:\s*97b73a9f4e1fb23d406bb987d0785cefa1f99966\s*$',
    '(?m)^github_write_allowed:\s*false\s*$',
    '(?m)^merge_policy:\s*internal_pass_required\s*$',
    '(?m)^authorized_phase:\s*A0_ONLY\s*$'
  )
  foreach ($MetadataPattern in $RequiredTaskMetadata) {
    if ([string]$TaskResult.StdOut -cnotmatch $MetadataPattern) {
      Stop-A0 "BLOCKED_TASK_METADATA"
    }
  }

  $Checkpoint = "PRODUCT"
  $AllowedCandidatePaths = @(
    "AGENTS.md",
    "company/AGENTS.md",
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
    "company/scripts/t00-safe-config-save.mjs",
    "company/tasks/README.md",
    "company/tasks/TASK_TEMPLATE.md",
    "company/tasks/v1-s1/V1-S1-T00-CCR-RUNTIME-SANDBOX.md",
    "company/tasks/v1-s1/V1-S1-T02-WRAPPER-SAFE-CONFIG-SAVE.md",
    "company/tests/t00-a0-preflight-contract.test.mjs",
    "company/tests/t00-safe-config-save.test.mjs"
  )
  $CandidateDiffResult = Invoke-A0Git -GitArguments @(
    "diff", "--name-only", "-z", "--no-renames", $MainSha, $CandidateSha, "--"
  )
  Assert-A0NativeSuccess $CandidateDiffResult "BLOCKED_CANDIDATE_SCOPE"
  $ChangedPaths = @(
    ([string]$CandidateDiffResult.StdOut).Split(
      [char[]]@([char]0),
      [StringSplitOptions]::RemoveEmptyEntries
    )
  )
  if ($ChangedPaths.Count -eq 0) {
    Stop-A0 "BLOCKED_CANDIDATE_SCOPE"
  }
  foreach ($ChangedPath in $ChangedPaths) {
    if ($AllowedCandidatePaths -cnotcontains $ChangedPath) {
      Stop-A0 "BLOCKED_CANDIDATE_SCOPE"
    }
  }

  $ProductPaths = @(
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
  $DiffResult = Invoke-A0Git -GitArguments (@(
    "diff", "--quiet", "--no-ext-diff", "--no-textconv",
    $ValidatedProductSha, $CandidateSha, "--"
  ) + $ProductPaths)
  Assert-A0NativeSuccess $DiffResult "BLOCKED_PRODUCT_TREE_MISMATCH"
  $ProductVerified = $true

  $PinnedArtifacts = @(
    [PSCustomObject]@{ Path = $T02HelperRepositoryPath; Blob = $T02HelperBlob },
    [PSCustomObject]@{ Path = $T02TestRepositoryPath; Blob = $T02TestBlob }
  )
  foreach ($PinnedArtifact in $PinnedArtifacts) {
    $ArtifactResult = Invoke-A0Git -GitArguments @(
      "rev-parse", "--verify", "${CandidateSha}:$($PinnedArtifact.Path)"
    )
    if ((Get-A0SingleLine $ArtifactResult "BLOCKED_T02_ARTIFACT") -cne $PinnedArtifact.Blob) {
      Stop-A0 "BLOCKED_T02_ARTIFACT"
    }
  }
  $T02ArtifactVerified = $true

  $Checkpoint = "SCRIPT"
  $ScriptBlobResult = Invoke-A0Git -GitArguments @("rev-parse", "--verify", "${CandidateSha}:$ScriptRepositoryPath")
  $ExpectedScriptBlob = Get-A0SingleLine $ScriptBlobResult "BLOCKED_SCRIPT_IDENTITY"
  if ([string]::IsNullOrWhiteSpace($PSCommandPath) -or -not [IO.File]::Exists($PSCommandPath)) {
    Stop-A0 "BLOCKED_SCRIPT_IDENTITY"
  }
  $ActualScriptBlobResult = Invoke-A0Git -GitArguments @(
    "hash-object", "--no-filters", "--", $PSCommandPath
  )
  if ((Get-A0SingleLine $ActualScriptBlobResult "BLOCKED_SCRIPT_IDENTITY") -cne $ExpectedScriptBlob) {
    Stop-A0 "BLOCKED_SCRIPT_IDENTITY"
  }

  $Checkpoint = "ARCHIVE"
  $ArchivePath = Join-Path $ValidationRoot "validated-product.zip"
  $ArchiveResult = Invoke-A0Git -GitArguments @(
    "archive", "--format=zip", "--output=$ArchivePath", $ValidatedProductSha
  ) -TimeoutSeconds 300
  Assert-A0NativeSuccess $ArchiveResult "BLOCKED_SOURCE_ARCHIVE"
  $ArchiveItem = Get-Item -LiteralPath $ArchivePath -Force
  if ($ArchiveItem -isnot [IO.FileInfo] -or
      $ArchiveItem.Length -le 0 -or
      $ArchiveItem.Length -gt 268435456) {
    Stop-A0 "BLOCKED_SOURCE_ARCHIVE"
  }
  Expand-Archive -LiteralPath $ArchivePath -DestinationPath $ExecutionRoot -ErrorAction Stop

  foreach ($RequiredFile in @(
    (Join-Path $ExecutionRoot "package.json"),
    (Join-Path $ExecutionRoot "package-lock.json"),
    (Join-Path $ExecutionRoot "build\build.mjs")
  )) {
    if (-not [IO.File]::Exists($RequiredFile)) {
      Stop-A0 "BLOCKED_EXECUTION_TREE"
    }
  }
  $SourceFingerprintBefore = Get-A0SourceFingerprint $ExecutionRoot
  $SourceVerified = $true

  $CurrentStage = "TOOLCHAIN"
  $Checkpoint = "NODE_VERSION"
  $BuildEnvironmentRemove = @(
    (Get-A0SensitiveEnvironmentKeys) + (Get-A0GitEnvironmentKeys) |
      Select-Object -Unique
  )
  $NodeVersionResult = Invoke-A0Native $NodeExe @("--version") `
    $ExecutionRoot 120 @{} $BuildEnvironmentRemove
  $CandidateNodeVersion = Get-A0SingleLine $NodeVersionResult "BLOCKED_WINDOWS_RUNTIME"
  $NodeVersionMatch = [regex]::Match(
    $CandidateNodeVersion,
    '^v(?<major>[0-9]+)\.[0-9]+\.[0-9]+$',
    [Text.RegularExpressions.RegexOptions]::CultureInvariant
  )
  if (-not $NodeVersionMatch.Success -or
      [int]$NodeVersionMatch.Groups["major"].Value -lt 22) {
    Stop-A0 "BLOCKED_WINDOWS_RUNTIME"
  }
  $NodeVersion = $CandidateNodeVersion
  $NodeLtsResult = Invoke-A0Native $NodeExe @(
    "-p", "process.release.lts ? 'YES' : 'NO'"
  ) $ExecutionRoot 120 @{} $BuildEnvironmentRemove
  $CandidateNodeLts = Get-A0SingleLine $NodeLtsResult "BLOCKED_WINDOWS_RUNTIME"
  if ($CandidateNodeLts -cne "YES") {
    Stop-A0 "BLOCKED_WINDOWS_RUNTIME"
  }
  $NodeLts = $CandidateNodeLts
  $Checkpoint = "NPM_VERSION"
  $NpmVersionResult = Invoke-A0Native $NodeExe @($NpmCli, "--version") `
    $ExecutionRoot 120 @{} $BuildEnvironmentRemove
  $CandidateNpmVersion = Get-A0SingleLine $NpmVersionResult "BLOCKED_WINDOWS_RUNTIME"
  if ($CandidateNpmVersion -cnotmatch '^[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?$') {
    Stop-A0 "BLOCKED_WINDOWS_RUNTIME"
  }
  $NpmVersion = $CandidateNpmVersion
  $Checkpoint = "NODE_VERSION"
  $PlatformResult = Invoke-A0Native $NodeExe @("-p", "process.platform") `
    $ExecutionRoot 120 @{} $BuildEnvironmentRemove
  $ArchitectureResult = Invoke-A0Native $NodeExe @("-p", "process.arch") `
    $ExecutionRoot 120 @{} $BuildEnvironmentRemove
  if ((Get-A0SingleLine $PlatformResult "BLOCKED_WINDOWS_RUNTIME") -cne "win32" -or
      (Get-A0SingleLine $ArchitectureResult "BLOCKED_WINDOWS_RUNTIME") -cne "x64") {
    Stop-A0 "BLOCKED_WINDOWS_RUNTIME"
  }
  $ToolchainVerified = $true

  $NpmCache = Join-Path $ValidationRoot "npm-cache"
  $NpmLogs = Join-Path $ValidationRoot "npm-logs"
  $BuildTemp = Join-Path $ValidationRoot "build-temp"
  $NodeGyp = Join-Path $ValidationRoot "node-gyp"
  foreach ($Directory in @($NpmCache, $NpmLogs, $BuildTemp, $NodeGyp)) {
    [void][IO.Directory]::CreateDirectory($Directory)
  }
  $NpmUserConfig = Join-Path $ValidationRoot "npm-user-config"
  $NpmGlobalConfig = Join-Path $ValidationRoot "npm-global-config"
  [IO.File]::WriteAllText($NpmUserConfig, "", [Text.Encoding]::UTF8)
  [IO.File]::WriteAllText($NpmGlobalConfig, "", [Text.Encoding]::UTF8)

  $BuildEnvironmentSet = @{
    "npm_config_cache" = $NpmCache
    "npm_config_logs_dir" = $NpmLogs
    "npm_config_devdir" = $NodeGyp
    "npm_config_userconfig" = $NpmUserConfig
    "npm_config_globalconfig" = $NpmGlobalConfig
    "TEMP" = $BuildTemp
    "TMP" = $BuildTemp
  }

  $CurrentStage = "NPM_CI"
  $Checkpoint = "NPM_CI"
  Write-Output "A0 NOTICE: npm ci is permitted to access the configured registry/network."
  Write-Output "A0 NOTICE: dependency lifecycle scripts are permitted with current user privileges."
  $InstallResult = Invoke-A0Native $NodeExe @(
    $NpmCli,
    "ci",
    "--audit=false",
    "--fund=false",
    "--ignore-scripts=false"
  ) $ExecutionRoot 1800 $BuildEnvironmentSet $BuildEnvironmentRemove
  $NpmExecutionStarted = $InstallResult.Started
  Assert-A0NativeSuccess $InstallResult "BLOCKED_DEPENDENCY_INSTALL"
  $InstallPassed = $true

  $CurrentStage = "TYPECHECK"
  $Checkpoint = "TYPECHECK"
  $TypeScriptCli = Join-Path $ExecutionRoot "node_modules\typescript\bin\tsc"
  if (-not [IO.File]::Exists($TypeScriptCli)) {
    Stop-A0 "BLOCKED_INSTALL_INTEGRITY"
  }
  $TypecheckResult = Invoke-A0Native $NodeExe @($TypeScriptCli, "--noEmit") `
    $ExecutionRoot 900 $BuildEnvironmentSet $BuildEnvironmentRemove
  Assert-A0NativeSuccess $TypecheckResult "BLOCKED_TYPECHECK"
  $TypecheckPassed = $true

  $CurrentStage = "BUILD"
  $Checkpoint = "BUILD"
  $BuildScript = Join-Path $ExecutionRoot "build\build.mjs"
  $BuildResult = Invoke-A0Native $NodeExe @($BuildScript) `
    $ExecutionRoot 900 $BuildEnvironmentSet $BuildEnvironmentRemove
  Assert-A0NativeSuccess $BuildResult "BLOCKED_BUILD_ASSETS"
  $BuildPassed = $true

  $CurrentStage = "POST_BUILD"
  $Checkpoint = "ASSETS"
  if ((Get-A0SourceFingerprint $ExecutionRoot) -cne $SourceFingerprintBefore) {
    Stop-A0 "BLOCKED_BUILD_TREE_MUTATION"
  }
  $CliPath = Join-Path $ExecutionRoot "packages\cli\dist\main\cli.js"
  foreach ($BuiltFilePath in @($CliPath)) {
    if (-not [IO.File]::Exists($BuiltFilePath)) {
      Stop-A0 "BLOCKED_BUILD_ASSETS"
    }
    $BuiltFile = Get-Item -LiteralPath $BuiltFilePath -Force -ErrorAction Stop
    if ($BuiltFile -isnot [IO.FileInfo] -or
        (($BuiltFile.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
      Stop-A0 "BLOCKED_BUILD_ASSETS"
    }
  }
  $CliExists = $true

  $CurrentStage = "COMPLETE"
  $Checkpoint = "COMPLETE"
  $Result = "PASS"
  $Category = "NONE"
} catch {
  $FailureMessage = [string]$_.Exception.Message
  if ($FailureMessage -cmatch '^A0_BLOCK::(?<category>[A-Z0-9_]+)$') {
    $InternalCategory = [string]$Matches["category"]
  } else {
    $InternalCategory = "INTERNAL_ERROR"
  }
} finally {
  $ProgressPreference = $SavedProgressPreference
  $ErrorActionPreference = $SavedErrorActionPreference
}

if ($Result -cne "PASS") {
  $ExternalFailure = ConvertTo-A0ExternalFailure $CurrentStage $InternalCategory
  $ExternalPhase = $ExternalFailure.Phase
  $Category = $ExternalFailure.Category
}
$NpmEffect = $(if ($NpmExecutionStarted) { "YES" } else { "NO" })
$LifecycleEffect = $(if ($NpmExecutionStarted) { "ALLOW" } else { "NONE" })
$NetworkEffect = $LifecycleEffect

Write-Output ("A0 RESULT: {0}" -f $Result)
Write-Output "Role: INTERNAL_VALIDATOR"
Write-Output "Task ID: V1-S1-T00"
Write-Output "Session role: Attempt 3 A0 only"
Write-Output ("Instruction/Candidate SHA: {0}" -f $SafeCandidateSha)
Write-Output "Candidate role: validation_overlay"
Write-Output ("Validated product target: {0}" -f $CanonicalValidatedProductSha)
Write-Output ("Product build completed: {0}" -f $(if ($BuildPassed) { "YES" } else { "NO" }))
Write-Output ("Environment alias: {0}" -f $SafeEnvironmentAlias)
Write-Output ("Workspace ID: {0}" -f $WorkspaceId)
Write-Output ("Stopped stage: {0}" -f $CurrentStage)
Write-Output ("Sanitized checkpoint: {0}" -f $Checkpoint)
Write-Output ("Category: {0}" -f $Category)
Write-Output ("Source provenance: {0}" -f $(if ($SourceVerified) { "PASS" } else { "NOT_PASS" }))
Write-Output ("Candidate protected product/source equivalence: {0}" -f $(if ($ProductVerified) { "PASS" } else { "NOT_PASS" }))
Write-Output ("Toolchain: {0}" -f $(if ($ToolchainVerified) { "PASS" } else { "NOT_PASS" }))
Write-Output ("Node version: {0}" -f $NodeVersion)
Write-Output ("Node LTS: {0}" -f $NodeLts)
Write-Output ("npm version: {0}" -f $NpmVersion)
Write-Output ("npm ci: {0}" -f $(if ($InstallPassed) { "PASS" } else { "NOT_PASS" }))
Write-Output ("Typecheck: {0}" -f $(if ($TypecheckPassed) { "PASS" } else { "NOT_PASS" }))
Write-Output ("Build assets: {0}" -f $(if ($BuildPassed) { "PASS" } else { "NOT_PASS" }))
Write-Output ("CLI asset exists: {0}" -f $(if ($CliExists) { "YES" } else { "NO" }))
Write-Output ("T02 helper/test reviewed blobs: {0}" -f $(if ($T02ArtifactVerified) { "PASS" } else { "NOT_PASS" }))
Write-Output "Parent process environment mutation: NO"
Write-Output ("npm ci process: {0}" -f $(if ($NpmExecutionStarted) { "STARTED" } else { "NOT_STARTED" }))
Write-Output ("Dependency lifecycle/network: {0}" -f $(if ($NpmExecutionStarted) { "PERMITTED; ACTUAL USE NOT ASSERTED" } else { "NOT_STARTED" }))
Write-Output "Canonical Git fetch/network read: PASS (pre-script source verification)."
Write-Output "CCR service/Gateway: NOT_INVOKED_BY_A0"
Write-Output "H0/A1+: NOT_STARTED"
Write-Output "A0-requested GitHub/remote write: NONE"
Write-Output "A0-authored source/history: NONE"
Write-Output "A0-targeted existing shared checkout mutation: NONE"
Write-Output "Existing shared checkout final status: NOT_APPLICABLE"
Write-Output "Disposable local Git/workspace write: YES"
Write-Output "A0-requested CCR/service/UI/config action: NONE"
Write-Output "Dependency-child effects outside nonce: NOT_OBSERVED; NOT_CLAIMED"
Write-Output "Secrets/raw evidence included in this sanitized result: NO"
Write-Output "Next phase/Task started: NO"
Write-Output "npm logs, if created, remain only in the local nonce workspace."
Write-Output "Next action: STOP and return this sanitized result for review."

if ($Result -ceq "PASS") {
  Write-Output "A0_PASS_PAUSED_FOR_REVIEW"
  Write-Output "Process exit code: 0"
  Write-Output "A0|RESULT=PASS|FETCH=OK|SOURCE=OK|PRODUCT=OK|TOOL=OK|INSTALL=OK|TYPE=OK|BUILD=OK|NPM=YES|LIFE=ALLOW|NET=ALLOW|LOCAL=YES|SERVICE=NO|H0=NO|RAW=NO"
  exit 0
} else {
  Write-Output "Process exit code: 1"
  Write-Output (
    "A0|RESULT=BLOCKED|FETCH=OK|PHASE=$ExternalPhase|STEP=$Checkpoint|CATEGORY=$Category|" +
    "NPM=$NpmEffect|LIFE=$LifecycleEffect|NET=$NetworkEffect|LOCAL=YES|" +
    "SERVICE=NO|H0=NO|RAW=NO"
  )
  exit 1
}
