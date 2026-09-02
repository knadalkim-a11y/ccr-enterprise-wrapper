import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { fileURLToPath } from "node:url";

const SCRIPT_PATH = fileURLToPath(new URL("../scripts/t00-a0-preflight.ps1", import.meta.url));
const TASK_PATH = fileURLToPath(
  new URL("../tasks/v1-s1/V1-S1-T00-CCR-RUNTIME-SANDBOX.md", import.meta.url)
);
const T02_HELPER_PATH = fileURLToPath(new URL("../scripts/t00-safe-config-save.mjs", import.meta.url));
const T02_TEST_PATH = fileURLToPath(new URL("./t00-safe-config-save.test.mjs", import.meta.url));
const POST_A0_DESIGN_PATHS = [
  "company/project-state.yml",
  "company/scripts/t00-runtime-controller.ps1",
  "company/tests/t00-runtime-controller-contract.test.mjs"
];
const [script, taskSource, t02Helper, t02Test] = await Promise.all([
  readFile(SCRIPT_PATH, "utf8"),
  readFile(TASK_PATH, "utf8"),
  readFile(T02_HELPER_PATH),
  readFile(T02_TEST_PATH)
]);

// Static source-contract checks only. The conditional Windows test parses with
// Windows PowerShell 5.1. Attempt 3's exact e16 internal A0 Evidence is recorded in
// the Task; this external test does not independently rerun or broaden that result.

function hasAll(...patterns) {
  for (const pattern of patterns) {
    assert.match(script, pattern);
  }
}

function gitBlobHash(content) {
  const header = Buffer.from(`blob ${content.length}\0`);
  return createHash("sha1").update(header).update(content).digest("hex");
}

test("A0 declares the complete immutable handoff contract", () => {
  hasAll(
    /\$PreparedGitDir\b/,
    /\$PreparedCandidateRef\b/,
    /\$PreparedMainRef\b/,
    /\$MainSha\b/,
    /\$CandidateSha\b/,
    /\$InstructionSha\b/,
    /\$ValidatedProductSha\b/,
    /\$TaskPath\b/,
    /\$EnvironmentAlias\b/,
    /\$ConfirmNoSeparateAccountOrVmRequired\b/,
    /\$ConfirmNoSameAccountConcurrentUse\b/,
    /\$AllowNpmNetworkAndLifecycle\b/
  );
  assert.match(script, /\$CandidateSha -cne \$InstructionSha/);
  assert.match(script, /refs\/internal-validation\/v1-s1-t00-candidate/);
  assert.match(script, /refs\/internal-validation\/v1-s1-t00-main/);
  assert.match(script, /\$SafeEnvironmentAlias = \$EnvironmentAlias/);
  assert.match(script, /company\/tasks\/v1-s1\/V1-S1-T00-CCR-RUNTIME-SANDBOX\.md/);
});

test("A0 source declares prepared-repository reads and no listed shared-Git mutation", () => {
  hasAll(
    /--no-replace-objects/,
    /rev-parse", "--is-bare-repository/,
    /--git-dir=\$PreparedGitDir/,
    /\$PreparedCandidateRef\^\{commit\}/,
    /\$PreparedMainRef\^\{commit\}/,
    /merge-base", "--is-ancestor/,
    /"GIT_OPTIONAL_LOCKS" = "0"/,
    /"GIT_TERMINAL_PROMPT" = "0"/,
    /Get-A0GitEnvironmentKeys/,
    /\^\(\?i:GIT_\)/
  );
  assert.doesNotMatch(script, /"(?:fetch|checkout|switch|pull|prune)"/i);
});

test("A0 pins candidate scope, protected paths, and the validated build plane", () => {
  hasAll(
    /id:\\s\*V1-S1-T00/,
    /stage:\\s\*V1-S1/,
    /primary_actor:\\s\*INTERNAL_VALIDATOR/,
    /execution_mode:\\s\*agent_only/,
    /candidate_role:\\s\*validation_overlay/,
    /tested_product_sha:\\s\*97b73a9f4e1fb23d406bb987d0785cefa1f99966/,
    /github_write_allowed:\\s\*false/,
    /merge_policy:\\s\*internal_pass_required/,
    /authorized_phase:\\s\*A0_ONLY/,
    /\$AllowedCandidatePaths/,
    /"diff", "--name-only", "-z", "--no-renames", \$MainSha, \$CandidateSha/,
    /\$AllowedCandidatePaths -cnotcontains \$ChangedPath/,
    /company\/scripts\/t00-safe-config-save\.mjs/,
    /company\/tests\/t00-safe-config-save\.test\.mjs/,
    /"packages"/,
    /"build"/,
    /"package\.json"/,
    /"package-lock\.json"/,
    /"npm-shrinkwrap\.json"/,
    /"\.npmrc"/,
    /"\.gitignore"/,
    /"\.gitattributes"/,
    /"tsconfig\.json"/,
    /"tsconfig\.node\.json"/,
    /"tests\/e2e"/,
    /--no-ext-diff/,
    /--no-textconv/
  );

  const taskAllowedBlock = taskSource.match(
    /^allowed_paths:\n(?<body>(?:  - .+\n)+)forbidden_paths:/m
  );
  assert.ok(taskAllowedBlock, "Task allowed_paths block must be parseable");
  const currentTaskAllowed = [
    ...taskAllowedBlock.groups.body.matchAll(/^  - (.+)$/gm)
  ].map((match) => match[1]);
  const scriptAllowedBlock = script.match(
    /\$AllowedCandidatePaths = @\(\n(?<body>(?:    "[^"]+",?\n)+)  \)/
  );
  assert.ok(scriptAllowedBlock, "script candidate allowlist must be parseable");
  const actualAllowed = [
    ...scriptAllowedBlock.groups.body.matchAll(/    "([^"]+)"/g)
  ].map((match) => match[1]);
  const historicalA0Allowed = currentTaskAllowed.filter(
    (candidatePath) => !POST_A0_DESIGN_PATHS.includes(candidatePath)
  );
  assert.deepEqual(actualAllowed, historicalA0Allowed);
  assert.deepEqual(
    currentTaskAllowed.filter((candidatePath) => POST_A0_DESIGN_PATHS.includes(candidatePath)),
    POST_A0_DESIGN_PATHS
  );
});

test("A0 verifies its own candidate bytes and materializes a nonce archive", () => {
  hasAll(
    /company\/scripts\/t00-a0-preflight\.ps1/,
    /"hash-object", "--no-filters", "--", \$PSCommandPath/,
    /"archive", "--format=zip"/,
    /"archive", "--format=zip", "--output=\$ArchivePath", \$ValidatedProductSha/,
    /Expand-Archive -LiteralPath \$ArchivePath/,
    /LOCALAPPDATA/,
    /validation-workspaces/,
    /\$CandidateWorkspaceId -cnotmatch '\^\[0-9a-f\]\{32\}\$'/,
    /\$WorkspaceId = \$CandidateWorkspaceId/,
    /\(Split-Path -Leaf \$PreparedGitDir\) -cne "repo\.git"/,
    /Get-A0SourceFingerprint \$ExecutionRoot/,
    /Validated product target:/,
    /Candidate role: validation_overlay/,
    /Product build completed:/,
    /Collections\.Generic\.Stack\[string\]/,
    /\$RelativePath -imatch '\(\^\|\\\\\)node_modules\$'/,
    /\$RelativePath -imatch '\^packages\\\\\[\^\\\\\]\+\\\\dist\$'/
  );
  assert.doesNotMatch(script, /\[Guid\]::NewGuid/);
  assert.doesNotMatch(script, /"archive", "--format=zip", "--output=\$ArchivePath", \$CandidateSha/);
  assert.doesNotMatch(script, /Get-ChildItem[^\r\n]*-Recurse/);
});

test("A0 binds Git and Node explicitly and invokes the sibling npm CLI with Node", () => {
  hasAll(
    /Resolve-A0Application "git\.exe"/,
    /Resolve-A0Application "node\.exe"/,
    /node_modules\\npm\\bin\\npm-cli\.js/,
    /Invoke-A0Native \$NodeExe @\(\$NpmCli, "--version"\)/,
    /\$NodeVersionMatch\.Groups\["major"\]\.Value -lt 22/,
    /process\.release\.lts \? 'YES' : 'NO'/,
    /\$CandidateNodeLts -cne "YES"/
  );
  assert.doesNotMatch(script, /Get-Command\s+.*npm(?:\.cmd|\.ps1)?/i);
});

test("A0 pins the separately reviewed T02 helper and test blobs", () => {
  assert.match(script, new RegExp(gitBlobHash(t02Helper)));
  assert.match(script, new RegExp(gitBlobHash(t02Test)));
  hasAll(
    /T02 helper\/test reviewed blobs:/,
    /\$T02ArtifactVerified = \$true/,
    /BLOCKED_T02_ARTIFACT/
  );
});

test("native runner source declares the PS5.1 timeout, capture, and cleanup contract", () => {
  hasAll(
    /Diagnostics\.ProcessStartInfo/,
    /UseShellExecute = \$false/,
    /RedirectStandardOutput = \$true/,
    /RedirectStandardError = \$true/,
    /\.ReadAsync\(/,
    /CaptureLimitChars/,
    /Stop-A0ProcessTree/,
    /taskkill\.exe/,
    /\$TaskkillInfo\.RedirectStandardOutput = \$true/,
    /\$TaskkillInfo\.RedirectStandardError = \$true/,
    /\/PID \$\(\$Process\.Id\) \/T \/F/,
    /\$Process\.Kill\(\)/,
    /CleanupSucceeded/,
    /ExitCode = \$ExitCode/,
    /StdErr = \$StdErrBuilder\.ToString\(\)/,
    /BLOCKED_NATIVE_COMMAND_TIMEOUT/,
    /BLOCKED_NATIVE_CLEANUP/,
    /Category = "BLOCKED_CLEANUP"/,
    /BLOCKED_NATIVE_OUTPUT_LIMIT/
  );
  hasAll(
    /\$RunnerFault = \$false/,
    /\$RunnerFault = \$LaunchSucceeded/,
    /RunnerFault = \$RunnerFault/,
    /if \(\$Invocation\.RunnerFault\)/,
    /BLOCKED_NATIVE_RUNNER/,
    /Phase = "FINAL"; Category = "INTERNAL_ERROR"/
  );
  assert.match(
    script,
    /if \(\$LaunchSucceeded\) \{[\s\S]*?if \(-not \$Process\.HasExited\)[\s\S]*?\$CleanupSucceeded = \$false/
  );
  assert.equal((script.match(/ReadToEndAsync/g) ?? []).length, 2);
  assert.doesNotMatch(script, /MaxCaptureChars|LogLabel/);
  assert.doesNotMatch(script, /2>&1/);
  assert.doesNotMatch(script, /Start-Process\b/);
});

test("npm effects are explicit and children receive private npm paths plus scrubbed sensitive env", () => {
  hasAll(
    /npm ci is permitted to access the configured registry\/network/,
    /dependency lifecycle scripts are permitted with current user privileges/,
    /"ci",\s*"--audit=false",\s*"--fund=false",\s*"--ignore-scripts=false"/s,
    /"--ignore-scripts=false"/,
    /"npm_config_cache"/,
    /"npm_config_userconfig"/,
    /"npm_config_globalconfig"/,
    /"NODE_ENV"/,
    /"NODE_OPTIONS"/,
    /"NODE_PATH"/,
    /\^\(\?i:npm_config_\)/,
    /\(TOKEN\|SECRET\|PASSWORD\|PASSWD\|API_\?KEY\|CREDENTIAL\)/,
    /Parent process environment mutation: NO/
  );
  assert.doesNotMatch(script, /--install-links|--loglevel|--progress/);
  assert.ok(
    script.indexOf("$BuildEnvironmentRemove = @(") <
      script.indexOf('$NodeVersionResult = Invoke-A0Native $NodeExe'),
    "the scrub list must be applied before the first Node process"
  );
  assert.ok(
    script.indexOf("(Get-A0GitEnvironmentKeys)") <
      script.indexOf('$NodeVersionResult = Invoke-A0Native $NodeExe'),
    "inherited Git overrides must be scrubbed before the first Node process"
  );
  assert.match(
    script,
    /Invoke-A0Native \$NodeExe @\("--version"\)[\s\S]*?\$ExecutionRoot 120 @\{\} \$BuildEnvironmentRemove/
  );
});

test("A0 source declares install, direct typecheck, asset build, and stop markers", () => {
  hasAll(
    /"ci"/,
    /node_modules\\typescript\\bin\\tsc/,
    /@\(\$TypeScriptCli, "--noEmit"\)/,
    /build\\build\.mjs/,
    /packages\\cli\\dist\\main\\cli\.js/,
    /PSEdition -cne "Desktop"/,
    /PSVersion\.Major -ne 5/,
    /PSVersion\.Minor -ne 1/,
    /CCR service\/Gateway: NOT_INVOKED_BY_A0/,
    /H0\/A1\+: NOT_STARTED/,
    /Next action: STOP/,
    /A0\|RESULT=PASS/,
    /A0\|RESULT=BLOCKED/,
    /A0_PASS_PAUSED_FOR_REVIEW/,
    /FETCH=OK\|SOURCE=OK\|PRODUCT=OK\|TOOL=OK\|INSTALL=OK\|TYPE=OK\|BUILD=OK\|NPM=YES\|LIFE=ALLOW\|NET=ALLOW\|LOCAL=YES\|SERVICE=NO\|H0=NO\|RAW=NO/,
    /FETCH=OK\|PHASE=\$ExternalPhase\|STEP=\$Checkpoint\|CATEGORY=\$Category\|.*NPM=\$NpmEffect\|LIFE=\$LifecycleEffect\|NET=\$NetworkEffect\|LOCAL=YES\|.*SERVICE=NO\|H0=NO\|RAW=NO/s,
    /A0-targeted existing shared checkout mutation: NONE/,
    /Existing shared checkout final status: NOT_APPLICABLE/,
    /Disposable local Git\/workspace write: YES/,
    /A0-requested CCR\/service\/UI\/config action: NONE/,
    /Dependency-child effects outside nonce: NOT_OBSERVED; NOT_CLAIMED/,
    /Canonical Git fetch\/network read: PASS/
  );
  assert.match(script, /Secrets\/raw evidence included in this sanitized result: NO/);
  assert.match(script, /Write-Output "A0_PASS_PAUSED_FOR_REVIEW"[\s\S]*?Process exit code: 0[\s\S]*?A0\|RESULT=PASS[\s\S]*?exit 0/);
  assert.match(script, /Process exit code: 1[\s\S]*?A0\|RESULT=BLOCKED[\s\S]*?exit 1/);
  assert.doesNotMatch(script, /\b(?:Get-Process|Stop-Process|Start-Service|Stop-Service)\b/);
  assert.doesNotMatch(script, /\bConnect agent\b|\bLet's start\b/i);
});

test("blocked results expose only an allowlisted sanitized checkpoint", () => {
  const actual = new Set(
    [...script.matchAll(/\$Checkpoint = "([A-Z_]+)"/g)].map((match) => match[1])
  );
  assert.deepEqual(
    actual,
    new Set([
      "INPUT",
      "HOST",
      "GIT_BIND",
      "NODE_BIND",
      "REFS",
      "TASK",
      "PRODUCT",
      "SCRIPT",
      "ARCHIVE",
      "NODE_VERSION",
      "NPM_VERSION",
      "NPM_CI",
      "TYPECHECK",
      "BUILD",
      "ASSETS",
      "COMPLETE"
    ])
  );
  hasAll(/Sanitized checkpoint:/, /Node version:/, /Node LTS:/, /npm version:/);
  assert.match(script, /Workspace ID:/);
  assert.ok(
    script.indexOf("$WorkspaceId = $CandidateWorkspaceId") >
      script.indexOf("$CandidateWorkspaceId -cnotmatch"),
    "the workspace ID must be exposed only after allowlist validation"
  );
  assert.ok(
    script.indexOf("$NodeVersion = $CandidateNodeVersion") >
      script.indexOf("$NodeVersionMatch.Success"),
    "the Node version must be exposed only after format validation"
  );
  assert.ok(
    script.indexOf("$NpmVersion = $CandidateNpmVersion") >
      script.indexOf("$CandidateNpmVersion -cnotmatch"),
    "the npm version must be exposed only after format validation"
  );
  assert.match(script, /if \(\$NpmExecutionStarted\) \{ "YES" \} else \{ "NO" \}/);
  assert.match(script, /if \(\$NpmExecutionStarted\) \{ "ALLOW" \} else \{ "NONE" \}/);
});

test(
  "Windows PowerShell 5.1 parser accepts the script",
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

test("all user-facing result strings are ASCII-safe", () => {
  for (const match of script.matchAll(/Write-Output\s+"([^"]*)"/g)) {
    assert.match(match[1], /^[\x00-\x7F]*$/);
  }
});
