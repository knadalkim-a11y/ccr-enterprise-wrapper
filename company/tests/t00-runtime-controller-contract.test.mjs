import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { fileURLToPath } from "node:url";

const SCRIPT_PATH = fileURLToPath(new URL("../scripts/t00-runtime-controller.ps1", import.meta.url));
const TASK_PATH = fileURLToPath(
  new URL("../tasks/v1-s1/V1-S1-T00-CCR-RUNTIME-SANDBOX.md", import.meta.url)
);
const T02_TASK_PATH = fileURLToPath(
  new URL("../tasks/v1-s1/V1-S1-T02-WRAPPER-SAFE-CONFIG-SAVE.md", import.meta.url)
);
const PROJECT_STATE_PATH = fileURLToPath(new URL("../project-state.yml", import.meta.url));
const STATUS_PATH = fileURLToPath(new URL("../docs/STATUS.md", import.meta.url));
const GATE_PATH = fileURLToPath(new URL("../gates/V1-S1.md", import.meta.url));
const HELPER_PATH = fileURLToPath(new URL("../scripts/t00-safe-config-save.mjs", import.meta.url));
const HELPER_TEST_PATH = fileURLToPath(new URL("./t00-safe-config-save.test.mjs", import.meta.url));

const [script, task, t02Task, projectState, status, gate, helper, helperTest] = await Promise.all([
  readFile(SCRIPT_PATH, "utf8"),
  readFile(TASK_PATH, "utf8"),
  readFile(T02_TASK_PATH, "utf8"),
  readFile(PROJECT_STATE_PATH, "utf8"),
  readFile(STATUS_PATH, "utf8"),
  readFile(GATE_PATH, "utf8"),
  readFile(HELPER_PATH),
  readFile(HELPER_TEST_PATH)
]);

// These are source-contract checks. They do not claim Windows runtime, ACL,
// service ownership, isolation, or T02 internal PASS. Attempt 4 supplies that
// Evidence only after a separately Human-approved exact head runs internally.

const IMPLEMENTATION_PATHS = [
  "company/scripts/t00-runtime-controller.ps1",
  "company/tests/t00-runtime-controller-contract.test.mjs",
  "company/tasks/v1-s1/V1-S1-T00-CCR-RUNTIME-SANDBOX.md",
  "company/tasks/v1-s1/V1-S1-T02-WRAPPER-SAFE-CONFIG-SAVE.md",
  "company/project-state.yml",
  "company/docs/STATUS.md",
  "company/gates/V1-S1.md"
];

function hasAll(...patterns) {
  for (const pattern of patterns) assert.match(script, pattern);
}

function gitBlobHash(content) {
  const header = Buffer.from(`blob ${content.length}\0`);
  return createHash("sha1").update(header).update(content).digest("hex");
}

function powershellArray(name) {
  const match = script.match(new RegExp(`\\$script:${name} = @\\(\\n(?<body>[\\s\\S]*?)\\n\\)`));
  assert.ok(match, `${name} must be parseable`);
  return [...match.groups.body.matchAll(/^\s+"([^"]+)",?$/gm)].map((entry) => entry[1]);
}

function powershellSection(name, nextName) {
  const start = script.indexOf(`function ${name} {`);
  const end = script.indexOf(`function ${nextName} {`, start + 1);
  assert.notEqual(start, -1, `${name} must exist`);
  assert.notEqual(end, -1, `${nextName} must follow ${name}`);
  return script.slice(start, end);
}

test("controller declares the frozen authority and exactly seven implementation paths", () => {
  hasAll(
    /DefaultParameterSetName = "Prepare"/,
    /ParameterSetName = "Run"/,
    /ParameterSetName = "CleanupBackup"/,
    /6d0d6f2aeca02e33261c062eac5aab360805222b/,
    /e6fe7e3b00dd42311cb30d88472949b03d18a2aa/,
    /97b73a9f4e1fb23d406bb987d0785cefa1f99966/,
    /refs\/internal-validation\/v1-s1-t00-candidate/,
    /refs\/internal-validation\/v1-s1-t00-main/,
    /ConfirmStockGetAppInfoResidualRisk/,
    /ConfirmNoSameAccountConcurrentUse/,
    /AllowNpmNetworkAndLifecycle/,
    /ApproveSingleSaveIfChangeY/
  );
  assert.deepEqual(powershellArray("ImplementationAllowedPaths"), IMPLEMENTATION_PATHS);
  assert.equal(new Set(powershellArray("ImplementationAllowedPaths")).size, 7);
});

test("Prepare verifies source scope and builds the full validated-product archive", () => {
  hasAll(
    /rev-parse", "--verify", "\$PreparedCandidateRef\^\{commit\}"/,
    /rev-parse", "--verify", "\$PreparedMainRef\^\{commit\}"/,
    /merge-base", "--is-ancestor"/,
    /Get-T00GitChangedPaths[^\n]+\$ImplementationBaseSha \$CandidateSha/,
    /\$script:ImplementationAllowedPaths -cnotcontains \$ChangedPath/,
    /Get-T00GitChangedPaths[^\n]+\$MainSha \$CandidateSha/,
    /\$script:TaskAllowedPaths -cnotcontains \$ChangedPath/,
    /"diff", "--quiet", "--no-ext-diff", "--no-textconv"/,
    /"archive", "--format=zip", "--output=\$ProductArchive", \$ValidatedProductSha/,
    /"archive", "--format=zip", "--output=\$ArtifactArchive", \$CandidateSha/,
    /Get-T00GitEnvironmentKeys\) -KillTreeOnTimeout/,
    /\$script:PrepareWorkspaceId = \$Workspace\.Id/,
    /Assert-T00PrivateAcl \$ValidationRoot \$HostContext\.Identity\.Sid -RequireProtected/,
    /Assert-T00PrivateAcl \$FullGitDir \$HostContext\.Identity\.Sid/,
    /\$script:PrepareLocalWriteAttempted = \$true/,
    /\$script:PrepareNpmInstallAttempted = \$true/,
    /\$script:PrepareNpmEffectsAllowed = \$true/,
    /\$script:PrepareTypecheckAttempted = \$true/,
    /\$script:PrepareBuildAttempted = \$true/,
    /node_modules\\npm\\bin\\npm-cli\.js/,
    /"ci", "--audit=false", "--fund=false", "--ignore-scripts=false"/,
    /node_modules\\typescript\\bin\\tsc/,
    /\$Tsc, "--noEmit"/,
    /build\\build\.mjs/
  );
  assert.doesNotMatch(script, /"archive", "--format=zip", "--output=\$ProductArchive", \$CandidateSha/);
  assert.doesNotMatch(script, /"ls-tree"/);
  assert.match(script, /WORKSPACE ID: \{0\}[\s\S]*?LOCAL WORKSPACE WRITE ATTEMPTED/);
  assert.match(script, /NPM NETWORK PERMISSION:[\s\S]*?ACTUAL NETWORK CONNECTION: NOT_OBSERVED/);
  assert.match(script, /NPM LIFECYCLE PERMISSION:[\s\S]*?ACTUAL LIFECYCLE CHILD EXECUTION: NOT_OBSERVED/);
  assert.match(script, new RegExp(gitBlobHash(helper)));
  assert.match(script, new RegExp(gitBlobHash(helperTest)));
});

test("prepared manifest binds the complete runtime and parses the exact hashed JSON bytes", () => {
  hasAll(
    /\[IO\.File\]::ReadAllBytes\(\$Item\.FullName\)/,
    /Get-T00Sha256Bytes \$Bytes/,
    /\[Text\.Encoding\]::UTF8\.GetString\(\$Bytes\) \| ConvertFrom-Json/,
    /Get-T00SourceSeal/,
    /Get-T00TreeSeal/,
    /Get-T00WorkspaceLinks/,
    /\$Junctions\.Count -ne \$AllowedLinks\.Count/,
    /packages\\core\\models\.json/,
    /createRequire/,
    /better_sqlite3\.node/,
    /new Database\(":memory:"\)/,
    /workspaceLinks = @\(\$LinkRows\)/,
    /rows = @\(\$RuntimeSeal\.Rows\)/,
    /packageLockHash/,
    /controllerBlob = \$ControllerBlob/,
    /helperBlob = \$HelperBlob/,
    /powerShellHash/,
    /whereHash/,
    /nodeHash/
  );
  assert.match(script, /Assert-T00RuntimeSeal \$Manifest[^\n]+/);
  assert.ok((script.match(/Assert-T00RuntimeSeal \$Manifest/g) ?? []).length >= 2);
});

test("handoff is one-shot, no-profile, digest-bound, and Human-gated", () => {
  hasAll(
    /New-T00BootstrapCommand/,
    / -NoProfile -Command /,
    /PRE_EXECUTION_HANDOFF_BLOCKED/,
    /Get-T00GitBlobSha1 \$PSCommandPath/,
    /`\$p=@\{Run=`\$true;ManifestPath=/,
    /& `\$cp @p/,
    /run-consumed\.marker/,
    /H0\|AUTH=P\|MODELS=P\|DESKTOP=P\|CONCURRENT=N\|CLIENTS=CLOSED\|SAVE=Y_IF_CHANGE/,
    /SONNET NEXT ACTION: EXIT COMPLETELY; DO NOT RUN H0 OR THE COMMAND\./
  );
  assert.doesNotMatch(script, / -NonInteractive -Command /);
  assert.doesNotMatch(script, /Invoke-Expression|ScriptBlock\.Create/);
  assert.doesNotMatch(script, /PrepareCommitted/);
});

test("runtime child environment isolates LOCALAPPDATA and binds stock discovery executables", () => {
  hasAll(
    /SandboxRoot = Join-Path \$HostContext\.AppData \("CompanyCCR\\runtime-localappdata\\" \+ \$Workspace\)/,
    /ExpectedSandboxRoot = Get-T00FullPath \(Join-Path \$HostContext\.AppData/,
    /"LOCALAPPDATA" = \$LocalAppData/,
    /"APPDATA" = \$HostContext\.AppData/,
    /"USERPROFILE" = \$HostContext\.UserProfile/,
    /"SystemRoot" = \$HostContext\.SystemRoot/,
    /"windir" = \$HostContext\.SystemRoot/,
    /System32\\WindowsPowerShell\\v1\.0\\powershell\.exe/,
    /System32\\where\.exe/,
    /Assert-T00NoStartupOverrides/,
    /controllerDirectNativeProcessesBounded = \$true/,
    /stockGetAppInfoDescendantsBoundedByController = \$false/,
    /stockGetAppInfoResidualRiskReviewed = \$true/
  );
  assert.doesNotMatch(script, /\$env:[A-Za-z_][A-Za-z0-9_]*\s*=/);
  assert.ok((script.match(/Assert-T00NoStartupOverrides/g) ?? []).length >= 5);
});

test("controller declares fail-closed backup, ACL, and invariant checks", () => {
  for (const id of [
    "enterprise-settings",
    "claude-root",
    "claude-meta",
    "claude-library",
    "ccr-config",
    "ccr-config-wal",
    "ccr-config-shm"
  ]) assert.match(script, new RegExp(`"${id}"`));
  hasAll(
    /DirectorySecurity/,
    /SetAccessRuleProtection\(\$true, \$false\)/,
    /S-1-5-18/,
    /Get-T00PathStateNoFollow/,
    /Microsoft\.PowerShell\.Management\\Get-ChildItem -LiteralPath \$Current -Force -ErrorAction Stop/,
    /Assert-T00NoReparseAncestors/,
    /\$AmbiguousGenericRuntime = \$IsGenericRuntime -and \[string\]::IsNullOrWhiteSpace\(\$CommandLine\)/,
    /companyccr\[\\\\\/\]validation-workspaces/,
    /serve\\s\+--daemon-child/,
    /Copy-T00RecoveryFile/,
    /Assert-T00BackupMatchesBaseline/,
    /Get-T00EnterpriseSnapshot/,
    /Set-T00Phase "DURING"/,
    /Assert-T00EnterpriseSame/,
    /ISOLATION_BREACH/,
    /Set-T00Phase "CLEANUP"/
  );
  assert.doesNotMatch(script, /Get-ChildItem[^\r\n]*-Recurse/);
  assert.doesNotMatch(script, /Remove-Item[^\r\n]*-Recurse/);
  const absence = powershellSection("Test-T00PathAbsent", "Set-T00FirstFailure");
  assert.doesNotMatch(absence, /File\]::Exists|Directory\]::Exists/);
  const deletion = powershellSection("Remove-T00TreeNoFollow", "Get-T00SourceSeal");
  assert.ok((deletion.match(/Assert-T00NoReparseAncestors/g) ?? []).length >= 2);
  assert.equal(
    (script.match(/\$Entries\.Add\(\[PSCustomObject\]\[ordered\]@\{/g) ?? []).length,
    2,
    "in-memory recovery entries must expose JSON field names under Windows PowerShell 5.1"
  );
});

test("fresh service ownership combines state, PID, listener, RPC, and stopped Gateway", () => {
  const rpc = powershellSection("Invoke-T00Rpc", "Assert-T00GatewayStopped");
  hasAll(
    /"start", "--host", "127\.0\.0\.1", "--port"/,
    /"--no-open", "--no-gateway"/,
    /service-start\.lock/,
    /profileManaged -isnot \[bool\]/,
    /startGateway -isnot \[bool\]/,
    /Get-T00ProcessIdentity/,
    /ProcessCreationTime/,
    /\$Connections = @\(NetTCPIP\\Get-NetTCPConnection -ErrorAction Stop\)/,
    /\[string\]\$_\.State -ceq "Listen" -and \[int\]\$_\.LocalPort -eq \$Port/,
    /getServiceIdentity/,
    /getGatewayStatus/,
    /getAppInfo/,
    /\$script:GetAppInfoUncertain = \$false/,
    /\$RequestDispatched = \$true/,
    /if \(\$Method -ceq "getAppInfo" -and \$RequestDispatched\)/,
    /\$ResponseValidated = \$false[\s\S]*?ConvertFrom-Json[\s\S]*?\$ResponseValidated = \$true[\s\S]*?finally \{\s+if \(\$Method -ceq "getAppInfo" -and \$RequestDispatched -and -not \$ResponseValidated\)/,
    /Set-T00HelperGetAppInfoUncertainty \$Result/,
    /configDbFile/,
    /Assert-T00GatewayStopped/,
    /ValidateSet\("PRE_SAVE", "POST_SAVE", "CLEANUP"\)/,
    /\$Status\.networkEndpoints -isnot \[Array\]/,
    /\$EmptyEndpoints = \$Status\.endpoint -ceq "" -and \$Status\.coreEndpoint -ceq ""/,
    /\$ConfiguredEndpoints = \$Status\.endpoint -ceq \("http:\/\/127\.0\.0\.1:\{0\}" -f \$GatewayPort\)/,
    /if \(-not \$State\.ApplyStarted\) \{[\s\S]*?-GatewayEndpointMode "PRE_SAVE"[\s\S]*?\} else \{\s+\$CurrentGatewayPorts = Get-T00GatewayPorts/,
    /\$GatewayEndpointMode = if \(\$State\.SavePassed\) \{ "POST_SAVE" \} else \{ "CLEANUP" \}/,
    /-GatewayEndpointMode "POST_SAVE"[\s\S]*?-ExpectedGatewayPorts \$State\.GatewayPorts/,
    /Test-T00BoundProcessAlive/,
    /Stop-T00 "BLOCKED_SERVICE_IDENTITY"/
  );
  const uncertaintyArm = rpc.indexOf("$RequestDispatched = $true");
  const requestWrite = rpc.indexOf("$RequestStream.Write(");
  assert.notEqual(uncertaintyArm, -1);
  assert.notEqual(requestWrite, -1);
  assert.ok(uncertaintyArm < requestWrite);
  assert.match(
    script,
    /Get-T00ServiceBinding[\s\S]*?Assert-T00RuntimeSeal[\s\S]*?Invoke-T00Native \$NodeExe @\(\$CliPath, "stop"\)/
  );
});

test("existing T02 helper is admitted twice but applies only after exact CHANGE=Y", () => {
  hasAll(
    /Assert-T00HelperAdmission/,
    /Invoke-T00HelperPreflight/,
    /Invoke-T00HelperApply/,
    /if \(\$Change -cne "Y"\) \{ Stop-T00 "BLOCKED_CHANGE_REQUIRED" \}/,
    /\$HelperPath, "--apply"/,
    /FAIL_SAVE_UNKNOWN/,
    /BLOCKED_T02_APPLY/,
    /SAVE=\(\?<save>N\|Y\|UNKNOWN\)/,
    /TARGET_GLOBAL=0/,
    /TARGET_LOGS=OFF/,
    /TARGET_ANALYSIS=OFF/,
    /TARGET_BODY=NONE/,
    /AUTOFETCH=OFF/,
    /GLOBAL=0/,
    /BODY=NONE/,
    /PROVIDER=SAME/,
    /ONBOARDING=SAME/
  );
  assert.equal((script.match(/\$State\.ApplyStarted = \$true/g) ?? []).length, 1);
  assert.match(
    script,
    /if \(\$null -eq \$Failure -or \$Failure\.Save -ceq "UNKNOWN"\)[\s\S]*?Stop-T00 "BLOCKED_T02_APPLY"/
  );
});

test("run mode declares outer-finally cleanup before H2 and compact Evidence", () => {
  const cleanup = powershellSection("Invoke-T00RunCleanup", "Invoke-T00RunMode");
  const runMode = powershellSection("Invoke-T00RunMode", "Invoke-T00CleanupBackupMode");
  assert.equal((cleanup.match(/Set-T00FirstFailure[^\n]*-Override/g) ?? []).length, 2);
  assert.equal((cleanup.match(/Remove-T00RuntimeSandbox \$State \$Manifest \$HostContext/g) ?? []).length, 2);
  assert.match(cleanup, /DuringSame = \$false\n\s+Set-T00FirstFailure \$State \$Failure -Override/);
  assert.match(cleanup, /AfterSame = \$false\n\s+Set-T00FirstFailure \$State \(Get-T00Failure \$_\) -Override/);
  assert.match(
    cleanup,
    /if \(\$script:GetAppInfoUncertain\) \{[\s\S]*?\$State\.ManualRecovery = \$true[\s\S]*?return\s+\}\s+if \(-not \$State\.ServiceMayExist\) \{\s+if \(-not \(Remove-T00RuntimeSandbox/
  );
  assert.ok(
    cleanup.indexOf("if ($script:GetAppInfoUncertain)") <
      cleanup.indexOf('Invoke-T00Native $NodeExe @($CliPath, "stop")')
  );
  assert.match(
    runMode,
    /try \{[\s\S]*?\$State\.ServiceMayExist = \$true[\s\S]*?\} finally \{[\s\S]*?Invoke-T00RunCleanup/
  );
  assert.ok(runMode.indexOf("Invoke-T00RunCleanup") < runMode.indexOf('Set-T00Phase "H2"'));
  const afterH2 = runMode.slice(runMode.indexOf("if ($H2Passed)"));
  const h2Invariant = afterH2.indexOf("Assert-T00EnterpriseSame");
  const h2Backup = afterH2.indexOf("Assert-T00RecoveryBackupRetained");
  const finalPass = afterH2.indexOf("$Pass =");
  assert.notEqual(h2Invariant, -1);
  assert.notEqual(h2Backup, -1);
  assert.notEqual(finalPass, -1);
  assert.ok(h2Invariant < h2Backup);
  assert.ok(h2Backup < finalPass);
  assert.match(runMode, /\$State\.H2AfterSame/);
  assert.match(runMode, /\$State\.BackupVerifiedAfterH2/);
  hasAll(
    /Wait-T00BoundProcessExit/,
    /ServiceStateAbsent/,
    /PortsFree/,
    /Remove-T00TreeNoFollow \$SandboxRoot/,
    /H2\|AUTH=P\|MODELS=P\|DESKTOP=P\|CLIENTS=CLOSED\|RECOVERY=N/,
    /Assert-T00NoRelevantWriters \$HostContext\.Identity\.Name[\s\S]*?Assert-T00EnterpriseSame \$State\.Baseline/,
    /\$State\.BackupCreationAttempted = \$true[\s\S]*?New-T00RecoveryBackup/,
    /VERIFIED_RETAINED/,
    /PARTIAL_OR_UNKNOWN/,
    /T00R\|PASS\|A4\|H=/,
    /T00R\|BLOCKED\|A4\|H=/,
    /B=R\|RAW=N/,
    /run-report\.json/,
    /recovery-cleanup-ticket\.json/
  );
  assert.ok(
    runMode.indexOf("$State.BackupCreationAttempted = $true") <
      runMode.indexOf("New-T00RecoveryBackup")
  );
  assert.match(runMode, /T00 RUNTIME RESULT: PASS/);
  assert.match(script, /T00 RUNTIME RESULT: BLOCKED/);
  assert.match(runMode, /run-success\.marker/);
  assert.ok(
    runMode.indexOf("Write-T00BytesAtomic $RunSuccessPath $RunSuccessBytes") <
      runMode.indexOf('Write-Output "T00 RUNTIME RESULT: PASS"')
  );
  assert.match(runMode, /if \(\$State\.RunSuccessCommitted\)/);
  assert.doesNotMatch(script, /Write-Output\s+\$StartResult\.(?:StdOut|StdErr)/);
  assert.doesNotMatch(script, /Write-Output\s+\$StopResult\.(?:StdOut|StdErr)/);
});

test("post-Gate backup deletion is exact, separately approved, and double-checked", () => {
  hasAll(
    /ConfirmPostGateRecoveryNo/,
    /ConfirmDeleteRecoveryBackup/,
    /t00-recovery-cleanup-v1/,
    /t00-recovery-manifest-v1/,
    /recovery-cleanup-consumed\.marker/,
    /run-success\.marker/,
    /Assert-T00RunSuccessMarker/,
    /Assert-T00PostGateServiceAbsent/,
    /Get-T00RecoveryTreeValidation/,
    /\$First\.TreeDigest -cne \$Second\.TreeDigest/,
    /Remove-T00TreeNoFollow \$RecoveryRoot/,
    /T00 BACKUP CLEANUP RESULT: PASS/,
    /T00 BACKUP CLEANUP RESULT: BLOCKED/,
    /T00C\|PASS\|H=\$\(\$script:SafeHeadPrefix\)\|B=D\|RAW=N/,
    /T00C\|BLOCKED\|H=\$\(\$script:SafeHeadPrefix\)\|C=BLOCKED_POST_GATE_CLEANUP\|B=R\|RAW=N/
  );
  assert.equal((script.match(/Remove-T00TreeNoFollow \$RecoveryRoot/g) ?? []).length, 1);
  const postGate = script.slice(
    script.indexOf("function Invoke-T00CleanupBackupMode {"),
    script.indexOf("\ntry {\n  if ($PSCmdlet.ParameterSetName")
  );
  assert.ok((postGate.match(/Assert-T00RunSuccessMarker/g) ?? []).length >= 2);
});

test("native execution and user-facing failure surface stay bounded and sanitized", () => {
  hasAll(
    /Diagnostics\.ProcessStartInfo/,
    /UseShellExecute = \$false/,
    /RedirectStandardOutput = \$true/,
    /RedirectStandardError = \$true/,
    /CaptureLimitChars/,
    /TimeoutSeconds/,
    /OutputTruncated/,
    /if \(\$Tree\) \{\s+if \(\$Process\.HasExited\) \{[\s\S]*?\$Succeeded = \$false/,
    /Invoke-T00SafeNativeProcessCleanup/,
    /\$CleanupSucceeded = \$false\s+\$CleanupSucceeded = Invoke-T00SafeNativeProcessCleanup/,
    /if \(-not \$CleanupSucceeded\) \{\s+\$script:FailureCleanupCode = "N"[\s\S]*?\$script:NativeCleanupUncertain = \$true/,
    /\$EarlyCleanupStatus = if \(\$script:NativeCleanupUncertain\) \{ "NOT_PASS" \} else \{ "NOT_REQUIRED" \}/,
    /\$EarlyCleanupCode = if \(\$script:NativeCleanupUncertain\) \{ "N" \} else \{ "P" \}/,
    /Write-T00ReadableRunFailure \$Failure "NONE_BEFORE_ATTEMPT" \$EarlyCleanupStatus[\s\S]*?\[bool\]\$script:NativeCleanupUncertain/,
    /\$script:FailureBackupCode, \$EarlyCleanupCode\)/,
    /Get-T00Failure/,
    /AllowedCategories/,
    /RAW=N/
  );
  assert.doesNotMatch(script, /\bStart-Process\b|\bInvoke-Expression\b|ScriptBlock\.Create/);
  assert.doesNotMatch(script, /\bSet-ExecutionPolicy\b|\s-ExecutionPolicy\b/);
  assert.doesNotMatch(script, /\b(?:Out-File|Set-Content|Add-Content)\b/);
  assert.doesNotMatch(script, /\bWrite-(?:Host|Error|Warning|Verbose|Debug)\b/);
  assert.doesNotMatch(script, /2>&1/);

  const allowedCategories = new Set(powershellArray("AllowedCategories"));
  const emittedCategories = new Set(
    [...script.matchAll(/Stop-T00 "([A-Z0-9_]+)"/g)].map((match) => match[1])
  );
  for (const category of emittedCategories) assert.ok(allowedCategories.has(category), category);
  for (const match of script.matchAll(/Write-Output\s+"([^"]*)"/g)) {
    assert.match(match[1], /^[\x00-\x7F]*$/);
  }
});

test("same-head governance records ready_internal without claiming Attempt 4 execution", () => {
  assert.match(task, /^status:\s*ready_internal$/m);
  assert.match(task, /^candidate_sha:\s*pending_exact_runtime_head$/m);
  assert.match(task, /^instruction_sha:\s*same_as_candidate$/m);
  assert.match(task, /^implementation_base_sha:\s*e6fe7e3b00dd42311cb30d88472949b03d18a2aa$/m);
  assert.match(
    task,
    /^authorized_phase:\s*ATTEMPT_4_PREPARE_AND_H0_RUNTIME_AFTER_EXACT_HEAD_HUMAN_APPROVAL$/m
  );
  assert.match(task, /^human_decision:\s*pending$/m);
  assert.match(task, /Runtime controller: IMPLEMENTED \/ EXTERNAL_REVIEW_PASS/);
  assert.match(task, /Decision: APPROVE_SEVEN_FILE_CONTROLLER_IMPLEMENTATION/);
  assert.match(task, /Implementation base SHA: e6fe7e3b00dd42311cb30d88472949b03d18a2aa/);
  assert.match(task, /Attempt 4 -Prepare \/ H0 \/ A1\+ \/ T01 \/ merge: NOT_AUTHORIZED_BY_THIS_DECISION/);
  assert.match(task, /Attempt 4: NOT_STARTED/);
  assert.match(t02Task, /^status:\s*external_pass$/m);
  assert.match(t02Task, /^candidate_sha:\s*final_repair_pr_head_supplied_by_human_gate_owner$/m);
  assert.match(t02Task, /^instruction_sha:\s*same_as_candidate$/m);
  assert.match(t02Task, /^human_decision:\s*pending$/m);
  assert.match(t02Task, /helper runtime `NOT_STARTED`/);
  assert.match(projectState, /^current:\n\s+stage:\s*V1-S1\n\s+task_id:\s*V1-S1-T00$/m);
  assert.match(projectState, /^\s+status:\s*ready_internal$/m);
  assert.match(projectState, /^\s+last_passed_gate:\s*V1-S0$/m);
  assert.match(status, /Machine status: `ready_internal`/);
  assert.match(
    status,
    /executable phase: `ATTEMPT_4_PREPARE_AND_H0_RUNTIME_AFTER_EXACT_HEAD_HUMAN_APPROVAL`/
  );
  assert.match(status, /Runtime controller: `IMPLEMENTED \/ EXTERNAL_REVIEW_PASS`/);
  assert.match(gate, /Attempt 4 `NOT_STARTED`/);
  assert.match(gate, /ATTEMPT_4_PREPARE_AND_H0_RUNTIME_AFTER_EXACT_HEAD_HUMAN_APPROVAL/);
  assert.match(gate, /Last passed Gate:\s*`V1-S0`/);
  assert.match(gate, /Human decision[\s\S]*?`PENDING`/);
});

test(
  "Windows PowerShell 5.1 parser accepts the controller",
  { skip: process.platform !== "win32" },
  () => {
    const escapedPath = SCRIPT_PATH.replaceAll("'", "''");
    const command = [
      "$tokens = $null",
      "$errors = $null",
      `[System.Management.Automation.Language.Parser]::ParseFile('${escapedPath}', [ref]$tokens, [ref]$errors) | Out-Null`,
      "if ($errors.Count -ne 0) { $errors | ForEach-Object { Write-Error $_ }; exit 1 }"
    ].join("; ");
    const parsed = spawnSync(
      "powershell.exe",
      ["-NoProfile", "-NonInteractive", "-Command", command],
      { encoding: "utf8" }
    );
    assert.equal(parsed.status, 0, `${parsed.stdout}\n${parsed.stderr}`);
  }
);
