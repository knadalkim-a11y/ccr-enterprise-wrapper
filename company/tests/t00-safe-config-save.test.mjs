import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { once } from "node:events";
import { createServer } from "node:http";
import { mkdir, mkdtemp, readFile, readdir, rm, symlink, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import {
  EXIT,
  T02Error,
  canonicalJson,
  directRpc,
  executeCli,
  formatFailure,
  parseCliArgs,
  runSafeConfigSave,
  validateAndBuildTarget
} from "../scripts/t00-safe-config-save.mjs";

const TOKEN_CANARY = "WEB_AUTH_TOKEN_CANARY";
const SERVICE_TOKEN_CANARY = "SERVICE_TOKEN_CANARY";
const API_KEY_CANARY = "API_KEY_CANARY";
const PROVIDER_KEY_CANARY = "PROVIDER_KEY_CANARY";
const PROVIDER_URL_CANARY = "https://provider-secret.invalid/v1";
const MODEL_CANARY = "MODEL_ID_CANARY";
const SERVER_ERROR_CANARY = "SERVER_ERROR_CANARY";
const NO_OVERRIDE = Symbol("NO_OVERRIDE");
const HELPER_FILE = fileURLToPath(new URL("../scripts/t00-safe-config-save.mjs", import.meta.url));

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function makeConfig({ corePort = 45102, gatewayPort = 45101, globalScope = "global" } = {}) {
  const globalClaude = {
    agent: "claude-code",
    enabled: true,
    env: { CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY: "1" },
    fableModel: "fable-canary",
    haikuModel: "haiku-canary",
    id: "global-claude",
    managedCompact: false,
    model: MODEL_CANARY,
    name: "Global Claude",
    opusModel: "opus-canary",
    settingsFile: "C:\\PROFILE_SETTINGS_CANARY.json",
    sonnetModel: "sonnet-canary",
    smallFastModel: "small-fast-canary",
    surface: "cli"
  };
  if (globalScope !== undefined) globalClaude.scope = globalScope;

  return {
    APIKEY: API_KEY_CANARY,
    APIKEYS: [{ createdAt: "2026-09-01T00:00:00.000Z", id: "api-key-1", key: API_KEY_CANARY }],
    API_TIMEOUT_MS: 60_000,
    CUSTOM_ROUTER_PATH: "C:\\ROUTER_PATH_CANARY.js",
    HOST: "127.0.0.1",
    PORT: gatewayPort,
    Providers: [{
      api_base_url: PROVIDER_URL_CANARY,
      api_key: PROVIDER_KEY_CANARY,
      autoFetchModels: false,
      id: "provider-canary",
      models: [MODEL_CANARY],
      name: "provider-canary",
      type: "anthropic_messages"
    }],
    Router: {
      builtInRules: {
        "claude-code": { enabled: true },
        codex: { enabled: true }
      },
      fallback: { mode: "off", models: [MODEL_CANARY], retryCount: 1 },
      rules: []
    },
    agent: { mcpServers: [] },
    autoStart: false,
    botConfigs: [],
    botGateway: {
      acknowledgeEvents: false,
      args: [],
      authType: "",
      autoStartIntegration: true,
      command: "",
      createIntegration: false,
      credentials: {},
      cwd: "",
      enabled: false,
      forwardAllAgentMessages: true,
      handoff: {
        enabled: false,
        idleSeconds: 30,
        phoneBluetoothTargets: [],
        phoneWifiTargets: [],
        screenLock: true,
        userIdle: true
      },
      integrationConfig: {},
      integrationId: "",
      language: "auto",
      maxAttachmentBytes: 20 * 1024 * 1024,
      maxTurnTimeMs: 10 * 60 * 1000,
      mediaEnabled: true,
      messageChunkChars: 3500,
      platform: "none",
      pollIntervalMs: 2000,
      requestTimeoutMs: 600000,
      sessionIdleMinutes: 0,
      shellEnabled: false,
      sourceDir: "",
      startupTimeoutMs: 10000,
      stateDir: "",
      streamReplies: true,
      tenantId: "ccr"
    },
    contextArchive: {
      enabled: false,
      maxBytes: 512 * 1024 * 1024,
      maxSnapshotBytes: 32 * 1024 * 1024,
      maxSnapshots: 200,
      mcpEnabled: true,
      replayTimeoutMs: 60000,
      retentionDays: 30,
      storagePath: "",
      toolName: "ccr_history_ask"
    },
    gateway: {
      coreHost: "127.0.0.1",
      corePort,
      enabled: true,
      host: "127.0.0.1",
      port: gatewayPort
    },
    launchAtLogin: false,
    mediaTools: {
      allowedInputRoots: [],
      artifactTtlHours: 24,
      enabled: false,
      jobTimeoutMs: 600000,
      maxImageConcurrency: 2,
      maxVideoConcurrency: 1
    },
    observability: {
      agentAnalysis: false,
      requestLogBodyCapture: "none",
      requestLogMaxBodyBytes: 8_192,
      requestLogSuccessSampleRate: 1,
      requestLogs: false
    },
    overviewWidgets: [
      { enabled: true, id: "system-status", size: "4:1", type: "system-status", variant: "timeline" },
      { enabled: true, id: "metric-requests", metric: "requests", size: "1:1", type: "metric", variant: "card" }
    ],
    plugins: [],
    preferredProvider: "provider-canary",
    profile: {
      claudeCode: {
        enabled: true,
        fableModel: "fable-canary",
        haikuModel: "haiku-canary",
        managedCompact: false,
        model: MODEL_CANARY,
        opusModel: "opus-canary",
        settingsFile: "C:\\PROFILE_SETTINGS_CANARY.json",
        sonnetModel: "sonnet-canary",
        smallFastModel: "small-fast-canary"
      },
      codex: {
        cliMiddleware: true,
        codexCliPath: "",
        codexHome: "C:\\CODEX_HOME_CANARY",
        configFormat: "separate_profile_files",
        configFile: "C:\\CODEX_CONFIG_CANARY.toml",
        enabled: true,
        managedCompact: false,
        model: "codex-model-canary",
        providerId: "claude-code-router",
        providerName: "Claude Code Router",
        showAllSessions: false
      },
      enabled: true,
      profiles: [
        globalClaude,
        {
          ...globalClaude,
          enabled: true,
          id: "ccr-claude",
          name: "CCR Claude",
          scope: "ccr",
          settingsFile: "C:\\CCR_PROFILE_CANARY.json"
        },
        {
          ...globalClaude,
          enabled: true,
          id: "custom-claude",
          name: "Custom Claude",
          scope: "custom",
          settingsFile: "C:\\CUSTOM_PROFILE_CANARY.json"
        },
        {
          agent: "codex",
          cliMiddleware: true,
          codexCliPath: "",
          codexHome: "C:\\CODEX_HOME_CANARY",
          configFormat: "separate_profile_files",
          configFile: "C:\\CODEX_CONFIG_CANARY.toml",
          enabled: true,
          env: {},
          id: "global-codex",
          managedCompact: false,
          model: "codex-model-canary",
          name: "Global Codex",
          providerId: "claude-code-router",
          providerName: "Claude Code Router",
          remoteFrontendMode: "app",
          scope: "global",
          showAllSessions: false,
          surface: "cli"
        }
      ]
    },
    providerPlugins: [],
    proxy: {
      browserMode: true,
      captureNetwork: false,
      enabled: false,
      host: "127.0.0.1",
      mode: "gateway",
      port: 7890,
      systemProxy: false,
      targets: [{ host: "api.anthropic.com", paths: ["/v1/messages", "/v1/messages/count_tokens"] }],
      upstream: {
        custom: { password: "", port: 7890, server: "", username: "" },
        mode: "system"
      }
    },
    routerEndpoint: `http://127.0.0.1:${gatewayPort}`,
    theme: "dark",
    toolHub: {
      browserAutomation: false,
      enabled: false,
      llm: { apiKey: "", baseUrl: "https://api.openai.com/v1", model: "" },
      maxTools: 10,
      mcpServers: [],
      requestTimeoutMs: 60000
    },
    trayComponentVariants: {
      account: "bar",
      modelShare: "bars",
      rings: "rings",
      stats: "cards",
      tokenFlow: "line",
      tokenMix: "bars"
    },
    trayIcon: "random",
    trayProgressTargetTokens: 100000,
    trayWidgets: [
      { id: "source-tabs", type: "source-tabs" },
      { id: "header", type: "header" },
      { id: "account", type: "account", variant: "bar" }
    ],
    trayWindowModules: ["source-tabs", "header", "account", "footer"],
    virtualModelProfiles: []
  };
}

function makeSafeConfig(options) {
  const config = makeConfig(options);
  config.profile.profiles[0].enabled = false;
  config.profile.claudeCode.enabled = false;
  config.observability.requestLogs = false;
  config.observability.agentAnalysis = false;
  config.observability.requestLogBodyCapture = "none";
  return config;
}

function stockGlobalProfile(profile) {
  return profile.enabled === true && profile.scope !== "ccr" && profile.scope !== "custom";
}

function emulateStockSaveConfig(config) {
  const next = clone(config);
  next.Providers = next.Providers.map((provider) => {
    const normalized = { ...provider };
    if (normalized.enabled !== false) delete normalized.enabled;
    return normalized;
  });
  const activeByAgent = new Set();
  next.profile.profiles = next.profile.profiles.map((profile) => {
    const normalized = ["codex", "opencode", "kilo", "workbuddy", "zcode"].includes(profile.agent)
      ? (() => {
          const {
            coreMode: _coreMode,
            frontendMode: _frontendMode,
            remoteFrontendMode: _remoteFrontendMode,
            ...cleaned
          } = profile;
          return { ...cleaned, remoteFrontendMode: "app" };
        })()
      : profile;
    if (!stockGlobalProfile(normalized)) return normalized;
    if (!activeByAgent.has(normalized.agent)) {
      activeByAgent.add(normalized.agent);
      return normalized;
    }
    return { ...normalized, enabled: false };
  });
  next.profile.enabled = next.profile.enabled !== false && next.profile.profiles.some((profile) => profile.enabled === true);
  const claudeProfile = next.profile.enabled
    ? next.profile.profiles.find((profile) => profile.agent === "claude-code" && stockGlobalProfile(profile))
    : undefined;
  const codexProfile = next.profile.enabled
    ? next.profile.profiles.find((profile) => profile.agent === "codex" && stockGlobalProfile(profile))
    : undefined;
  const { remoteFrontendMode: _legacyRemoteFrontendMode, ...canonicalLegacyCodex } = next.profile.codex;
  next.profile.claudeCode = claudeProfile
    ? {
        ...next.profile.claudeCode,
        enabled: true,
        fableModel: claudeProfile.fableModel ?? next.profile.claudeCode.fableModel,
        haikuModel: claudeProfile.haikuModel ?? next.profile.claudeCode.haikuModel,
        managedCompact: claudeProfile.managedCompact ?? next.profile.claudeCode.managedCompact,
        model: claudeProfile.model,
        opusModel: claudeProfile.opusModel ?? next.profile.claudeCode.opusModel,
        settingsFile: claudeProfile.settingsFile ?? next.profile.claudeCode.settingsFile,
        sonnetModel: claudeProfile.sonnetModel ?? next.profile.claudeCode.sonnetModel,
        smallFastModel: claudeProfile.smallFastModel ?? next.profile.claudeCode.smallFastModel
      }
    : { ...next.profile.claudeCode, enabled: false };
  next.profile.codex = codexProfile
    ? {
        ...canonicalLegacyCodex,
        cliMiddleware: codexProfile.cliMiddleware ?? canonicalLegacyCodex.cliMiddleware,
        codexCliPath: codexProfile.codexCliPath ?? canonicalLegacyCodex.codexCliPath,
        codexHome: codexProfile.codexHome ?? canonicalLegacyCodex.codexHome,
        configFormat: codexProfile.configFormat ?? canonicalLegacyCodex.configFormat,
        configFile: codexProfile.configFile ?? canonicalLegacyCodex.configFile,
        enabled: true,
        managedCompact: codexProfile.managedCompact ?? canonicalLegacyCodex.managedCompact,
        model: codexProfile.model,
        providerId: codexProfile.providerId ?? canonicalLegacyCodex.providerId,
        providerName: codexProfile.providerName ?? canonicalLegacyCodex.providerName,
        showAllSessions: codexProfile.showAllSessions ?? canonicalLegacyCodex.showAllSessions
      }
    : { ...canonicalLegacyCodex, enabled: false };
  return next;
}

function emulatePinnedRuntimeRestart(previousConfig, nextConfig) {
  return (
    previousConfig.gateway.enabled !== nextConfig.gateway.enabled ||
    previousConfig.gateway.host !== nextConfig.gateway.host ||
    previousConfig.gateway.port !== nextConfig.gateway.port ||
    previousConfig.gateway.coreHost !== nextConfig.gateway.coreHost ||
    previousConfig.gateway.corePort !== nextConfig.gateway.corePort ||
    previousConfig.observability.requestLogs !== nextConfig.observability.requestLogs ||
    previousConfig.observability.agentAnalysis !== nextConfig.observability.agentAnalysis ||
    previousConfig.observability.requestLogBodyCapture !== nextConfig.observability.requestLogBodyCapture ||
    previousConfig.observability.requestLogMaxBodyBytes !== nextConfig.observability.requestLogMaxBodyBytes ||
    previousConfig.proxy.enabled !== nextConfig.proxy.enabled ||
    previousConfig.proxy.host !== nextConfig.proxy.host ||
    previousConfig.proxy.mode !== nextConfig.proxy.mode ||
    previousConfig.proxy.port !== nextConfig.proxy.port ||
    previousConfig.proxy.systemProxy !== nextConfig.proxy.systemProxy ||
    JSON.stringify(previousConfig.proxy.targets) !== JSON.stringify(nextConfig.proxy.targets) ||
    JSON.stringify(previousConfig.proxy.upstream) !== JSON.stringify(nextConfig.proxy.upstream) ||
    JSON.stringify(previousConfig.agent) !== JSON.stringify(nextConfig.agent) ||
    JSON.stringify(previousConfig.mediaTools) !== JSON.stringify(nextConfig.mediaTools) ||
    JSON.stringify(previousConfig.Providers) !== JSON.stringify(nextConfig.Providers) ||
    JSON.stringify(previousConfig.plugins) !== JSON.stringify(nextConfig.plugins) ||
    JSON.stringify(previousConfig.providerPlugins) !== JSON.stringify(nextConfig.providerPlugins) ||
    JSON.stringify(previousConfig.toolHub) !== JSON.stringify(nextConfig.toolHub) ||
    JSON.stringify(previousConfig.virtualModelProfiles) !== JSON.stringify(nextConfig.virtualModelProfiles)
  );
}

function emulateClaudeAppConfigChanged(config) {
  const reusableApiKey = config.APIKEY.trim() || config.APIKEYS.find((item) => item.key.trim())?.key;
  return config.gateway.enabled !== true || !reusableApiKey;
}

function emulatePinnedSaveGatewayAction(previousConfig, nextConfig) {
  return emulateClaudeAppConfigChanged(nextConfig) || emulatePinnedRuntimeRestart(previousConfig, nextConfig)
    ? "start"
    : "update";
}

function stoppedGateway() {
  return {
    coreEndpoint: "",
    endpoint: "",
    networkEndpoints: [],
    state: "stopped"
  };
}

function postGateway(config, state = "running") {
  return {
    coreEndpoint: `http://${config.gateway.coreHost}:${config.gateway.corePort}`,
    endpoint: `http://${config.gateway.host}:${config.gateway.port}`,
    networkEndpoints: [],
    ...(state === "running" ? { pid: process.pid } : {}),
    state
  };
}

async function listen(server) {
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  return server.address().port;
}

async function closeServer(server) {
  if (!server.listening) return;
  await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
}

function sendJson(response, statusCode, payload) {
  const body = JSON.stringify(payload);
  response.writeHead(statusCode, {
    "content-length": Buffer.byteLength(body),
    "content-type": "application/json; charset=utf-8"
  });
  response.end(body);
}

async function readRequestJson(request) {
  const chunks = [];
  for await (const chunk of request) chunks.push(chunk);
  const raw = Buffer.concat(chunks).toString("utf8");
  return { raw, value: JSON.parse(raw) };
}

async function createHarness({
  appInfoMutator,
  behavior = {},
  config = makeConfig(),
  envMutator,
  onboarding = false,
  stateMutator,
  urlOverride
} = {}) {
  const root = await mkdtemp(path.join(os.tmpdir(), "t02-wrapper-test-"));
  const configDir = path.join(root, "claude-code-router");
  const serviceFile = path.join(configDir, "service.json");
  const backupFile = path.join(configDir, "claude-app-gateway-backup.json");
  await mkdir(configDir, { recursive: true });

  const state = {
    calls: [],
    config: clone(config),
    methodCounts: new Map(),
    onboarding,
    requestViolations: [],
    saveCount: 0,
    savedArgs: undefined
  };

  const server = createServer((request, response) => {
    void (async () => {
      const { raw: requestRaw, value: requestBody } = await readRequestJson(request);
      const method = requestBody?.method;
      const args = requestBody?.args;
      state.calls.push({ args: clone(args), method, path: request.url });
      state.methodCounts.set(method, (state.methodCounts.get(method) ?? 0) + 1);

      if (request.method !== "POST") state.requestViolations.push("method");
      if (request.url !== "/api/ccr/rpc") state.requestViolations.push("path");
      if (request.headers["x-ccr-web-auth"] !== TOKEN_CANARY) state.requestViolations.push("auth");
      if (!String(request.headers["content-type"] ?? "").startsWith("application/json")) {
        state.requestViolations.push("content-type");
      }
      if (Number(request.headers["content-length"]) !== Buffer.byteLength(requestRaw, "utf8")) {
        state.requestViolations.push("content-length");
      }
      if (!Array.isArray(args) || typeof method !== "string") state.requestViolations.push("body");

      const callContext = {
        args,
        method,
        methodCount: state.methodCounts.get(method),
        request,
        response,
        serviceFile,
        state
      };
      if (await behavior.rawCall?.(callContext)) return;
      if (behavior.failMethod === method) {
        sendJson(response, 500, { error: { message: SERVER_ERROR_CANARY }, ok: false });
        return;
      }

      let value = await behavior.override?.(callContext) ?? NO_OVERRIDE;
      if (value === NO_OVERRIDE) {
        switch (method) {
          case "getAppInfo": {
            value = {
              configDir,
              dataDir: configDir,
              desktop: false,
              name: "Claude Code Router",
              platform: "win32",
              version: "3.0.22"
            };
            if (appInfoMutator) value = appInfoMutator(value);
            break;
          }
          case "getServiceIdentity":
            value = {
              pid: process.pid,
              serviceTokenConfigured: true,
              serviceTokenMatches: args[0] === SERVICE_TOKEN_CANARY
            };
            break;
          case "getGatewayStatus":
            value = state.saveCount > 0 ? postGateway(state.config, "stopped") : stoppedGateway();
            break;
          case "getOnboardingFinished":
            value = state.onboarding;
            break;
          case "getConfig":
            value = clone(state.config);
            break;
          case "saveConfig": {
            state.saveCount += 1;
            state.savedArgs = clone(args);
            const submitted = clone(args[0]);
            const returned = emulateStockSaveConfig(submitted);
            state.config = clone(returned);
            if (behavior.postSaveConfigMutator) {
              state.config = behavior.postSaveConfigMutator(clone(state.config));
            }
            value = behavior.saveResponseMutator
              ? behavior.saveResponseMutator(clone(returned))
              : returned;
            break;
          }
          default:
            sendJson(response, 400, { error: { message: SERVER_ERROR_CANARY }, ok: false });
            return;
        }
      }

      await behavior.afterCall?.({ ...callContext, value });
      sendJson(response, 200, { ok: true, value });
    })().catch(() => {
      if (!response.headersSent) sendJson(response, 500, { error: { message: SERVER_ERROR_CANARY }, ok: false });
      else response.destroy();
    });
  });
  const managementPort = await listen(server);

  let serviceState = {
    host: "127.0.0.1",
    pid: process.pid,
    profileManaged: false,
    serviceToken: SERVICE_TOKEN_CANARY,
    startedAt: "2026-09-01T00:00:00.000Z",
    startGateway: false,
    url: urlOverride ?? `http://127.0.0.1:${managementPort}/?ccr_web_token=${TOKEN_CANARY}`
  };
  if (stateMutator) serviceState = stateMutator(serviceState);
  await writeFile(serviceFile, `${JSON.stringify(serviceState, null, 2)}\n`, { mode: 0o600 });

  let env = {
    APPDATA: root,
    LOCALAPPDATA: path.join(root, "LOCALAPPDATA_DECOY")
  };
  if (envMutator) env = envMutator(env);

  return {
    backupFile,
    close: async () => {
      await closeServer(server);
      await rm(root, { force: true, recursive: true });
    },
    configDir,
    env,
    managementPort,
    options: {
      env,
      isProcessAlive: (pid) => pid === process.pid,
      pathApi: path.posix,
      platform: "win32",
      portChecker: async () => {}
    },
    root,
    server,
    serviceFile,
    serviceState,
    state
  };
}

function expectedInitialMethods() {
  return [
    "getAppInfo",
    "getServiceIdentity",
    "getGatewayStatus",
    "getOnboardingFinished",
    "getConfig"
  ];
}

function expectedApplyMethods() {
  return [
    ...expectedInitialMethods(),
    "getServiceIdentity",
    "getGatewayStatus",
    "getOnboardingFinished",
    "getConfig",
    "saveConfig",
    "getConfig",
    "getOnboardingFinished",
    "getGatewayStatus"
  ];
}

async function freePort() {
  const server = createServer();
  const port = await listen(server);
  await closeServer(server);
  return port;
}

test("CLI accepts only no argument or one exact --apply", async () => {
  assert.deepEqual(parseCliArgs([]), { apply: false });
  assert.deepEqual(parseCliArgs(["--apply"]), { apply: true });
  assert.throws(() => parseCliArgs(["--apply", "--apply"]), { category: "INVALID_ARGUMENTS" });

  const result = await executeCli(["--secret-argument-canary"]);
  assert.equal(result.exitCode, EXIT.INVALID_ARGUMENTS);
  assert.equal(result.line, "T02|RESULT=BLOCKED|CATEGORY=INVALID_ARGUMENTS|SAVE=N|RAW=NO");
  assert.doesNotMatch(result.line, /secret-argument-canary/);

  const childEnv = { ...process.env };
  delete childEnv.NODE_DEBUG;
  delete childEnv.NODE_OPTIONS;
  const child = spawnSync(process.execPath, [HELPER_FILE, "--secret-process-canary"], {
    encoding: "utf8",
    env: childEnv
  });
  assert.equal(child.status, EXIT.INVALID_ARGUMENTS);
  assert.equal(child.stdout, "T02|RESULT=BLOCKED|CATEGORY=INVALID_ARGUMENTS|SAVE=N|RAW=NO\n");
  assert.equal(child.stderr, "");
  assert.doesNotMatch(`${child.stdout}${child.stderr}`, /secret-process-canary/);
});

test("canonical JSON sorts object keys but preserves array order", () => {
  assert.equal(canonicalJson({ z: 1, a: { y: [3, 1, 2], x: true } }), '{"a":{"x":true,"y":[3,1,2]},"z":1}');
  assert.throws(() => canonicalJson([, 1]), { category: "BLOCKED_CONFIG_SHAPE" });
  assert.throws(() => canonicalJson({ value: Number.NaN }), { category: "BLOCKED_CONFIG_SHAPE" });
});

test("synthetic success fixture uses only complete stock AppConfig top-level fields", () => {
  const config = makeConfig();
  assert.deepEqual(Object.keys(config).sort(), [
    "APIKEY",
    "APIKEYS",
    "API_TIMEOUT_MS",
    "CUSTOM_ROUTER_PATH",
    "HOST",
    "PORT",
    "Providers",
    "Router",
    "agent",
    "autoStart",
    "botConfigs",
    "botGateway",
    "contextArchive",
    "gateway",
    "launchAtLogin",
    "mediaTools",
    "observability",
    "overviewWidgets",
    "plugins",
    "preferredProvider",
    "profile",
    "providerPlugins",
    "proxy",
    "routerEndpoint",
    "theme",
    "toolHub",
    "trayComponentVariants",
    "trayIcon",
    "trayProgressTargetTokens",
    "trayWidgets",
    "trayWindowModules",
    "virtualModelProfiles"
  ].sort());
  assert.equal(Object.hasOwn(config.Providers[0], "enabled"), false);
  assert.equal(config.profile.profiles[3].remoteFrontendMode, "app");
  const { target } = validateAndBuildTarget(config);
  assert.equal(canonicalJson(emulateStockSaveConfig(target)), canonicalJson(target));
});

test("independent pinned save decision keeps exact profile-only cleanup on updateConfig", () => {
  const config = makeConfig();
  const { target } = validateAndBuildTarget(config);
  assert.equal(emulateClaudeAppConfigChanged(target), false);
  assert.equal(emulatePinnedRuntimeRestart(config, target), false);
  assert.equal(emulatePinnedSaveGatewayAction(config, target), "update");

  const observabilityChange = clone(target);
  observabilityChange.observability.requestLogs = true;
  assert.equal(emulatePinnedSaveGatewayAction(target, observabilityChange), "start");

  const providerChange = clone(target);
  providerChange.Providers[0].models.push("RUNTIME_CHANGE_CANARY");
  assert.equal(emulatePinnedSaveGatewayAction(target, providerChange), "start");

  const noReusableKey = clone(target);
  noReusableKey.APIKEY = "";
  noReusableKey.APIKEYS = [];
  assert.equal(emulatePinnedSaveGatewayAction(target, noReusableKey), "start");
});

test("transform disables only an enabled canonical global Claude profile", () => {
  const config = makeConfig();
  const { changed, globalCount, target } = validateAndBuildTarget(config);
  assert.equal(changed, true);
  assert.equal(globalCount, 0);
  assert.equal(target.profile.profiles[0].enabled, false);
  assert.equal(target.profile.profiles[1].enabled, true);
  assert.equal(target.profile.profiles[2].enabled, true);
  assert.equal(target.profile.profiles[3].enabled, true);
  assert.equal(target.profile.claudeCode.enabled, false);
  assert.equal(target.profile.codex.enabled, true);
  assert.equal(target.profile.enabled, true);
  assert.deepEqual(target.observability, config.observability);
  assert.deepEqual(target.Providers, config.Providers);
  assert.deepEqual(target.Router, config.Router);
  assert.deepEqual(target.APIKEYS, config.APIKEYS);
  assert.deepEqual(target.profile.profiles.map(({ id }) => id), config.profile.profiles.map(({ id }) => id));
});

for (const scope of [undefined, "legacy-unknown"]) {
  test(`missing/noncanonical profile scope ${scope ?? "missing"} blocks before save`, () => {
    const config = makeConfig();
    if (scope === undefined) delete config.profile.profiles[0].scope;
    else config.profile.profiles[0].scope = scope;
    assert.throws(() => validateAndBuildTarget(config), { category: "BLOCKED_CONFIG_SHAPE" });
  });
}

test("unknown profile agent blocks before save", () => {
  const config = makeConfig();
  config.profile.profiles.push({
    agent: "unknown-agent",
    enabled: false,
    id: "unknown-agent-profile",
    scope: "custom"
  });
  assert.throws(() => validateAndBuildTarget(config), { category: "BLOCKED_CONFIG_SHAPE" });
});

test("missing Stock-canonical Codex remote frontend mode blocks before save", () => {
  const config = makeConfig();
  delete config.profile.profiles[3].remoteFrontendMode;
  assert.throws(() => validateAndBuildTarget(config), { category: "BLOCKED_CONFIG_SHAPE" });
});

for (const remoteFrontendMode of ["cli", "claude-code"]) {
  test(`non-fixed Codex remote frontend mode ${remoteFrontendMode} blocks before save`, () => {
    const config = makeConfig();
    config.profile.profiles[3].remoteFrontendMode = remoteFrontendMode;
    assert.throws(() => validateAndBuildTarget(config), { category: "BLOCKED_CONFIG_SHAPE" });
  });
}

test("Stock-stripped legacy Codex remote frontend mode blocks before save", () => {
  const config = makeConfig();
  config.profile.codex.remoteFrontendMode = "app";
  assert.throws(() => validateAndBuildTarget(config), { category: "BLOCKED_CONFIG_SHAPE" });
});

for (const profileField of ["coreMode", "frontendMode"]) {
  test(`Stock-stripped Codex profile field ${profileField} blocks before save`, () => {
    const config = makeConfig();
    config.profile.profiles[3][profileField] = "app";
    assert.throws(() => validateAndBuildTarget(config), { category: "BLOCKED_CONFIG_SHAPE" });
  });
}

for (const agent of ["codex", "opencode", "kilo", "workbuddy", "zcode"]) {
  test(`Codex-family fixed-point matrix for ${agent}`, () => {
    const base = makeConfig();
    const item = {
      ...base.profile.profiles[3],
      agent,
      enabled: false,
      id: `${agent}-fixed-point-matrix`,
      remoteFrontendMode: "app",
      scope: "ccr"
    };

    const canonical = clone(base);
    canonical.profile.profiles.push(clone(item));
    assert.doesNotThrow(() => validateAndBuildTarget(canonical));

    for (const mutation of [
      (profile) => { delete profile.remoteFrontendMode; },
      (profile) => { profile.remoteFrontendMode = "cli"; },
      (profile) => { profile.coreMode = "app"; },
      (profile) => { profile.frontendMode = "app"; }
    ]) {
      const noncanonical = clone(base);
      const changed = clone(item);
      mutation(changed);
      noncanonical.profile.profiles.push(changed);
      assert.throws(() => validateAndBuildTarget(noncanonical), { category: "BLOCKED_CONFIG_SHAPE" });
    }
  });
}

test("derived profile.enabled becomes false when cleanup removes the last enabled profile", () => {
  const config = makeConfig();
  config.profile.profiles = [config.profile.profiles[0]];
  config.profile.codex.enabled = false;
  const { target } = validateAndBuildTarget(config);
  assert.equal(target.profile.enabled, false);
  assert.equal(target.profile.claudeCode.enabled, false);
  assert.equal(target.profile.codex.enabled, false);
});

test("full source-derived legacy mirrors and single-global invariant are required", async (t) => {
  await t.test("Claude legacy mismatch", () => {
    const config = makeConfig();
    config.profile.claudeCode.settingsFile = "C:\\MISMATCH_CANARY.json";
    assert.throws(() => validateAndBuildTarget(config), { category: "BLOCKED_CONFIG_SHAPE" });
  });

  await t.test("Codex legacy mismatch", () => {
    const config = makeConfig();
    config.profile.codex.model = "MISMATCH_CANARY";
    assert.throws(() => validateAndBuildTarget(config), { category: "BLOCKED_CONFIG_SHAPE" });
  });

  await t.test("duplicate enabled global for one agent", () => {
    const config = makeConfig();
    config.profile.profiles.push({
      ...clone(config.profile.profiles[3]),
      id: "duplicate-global-codex",
      name: "Duplicate Global Codex"
    });
    assert.throws(() => validateAndBuildTarget(config), { category: "BLOCKED_CONFIG_SHAPE" });
  });
});

test("default mode performs the complete no-save preflight and never dispatches saveConfig", async (t) => {
  const harness = await createHarness();
  t.after(() => harness.close());
  const filesBefore = (await readdir(harness.root, { recursive: true })).sort();
  const stateBefore = await readFile(harness.serviceFile, "utf8");

  const result = await executeCli([], harness.options);
  assert.equal(result.exitCode, EXIT.OK);
  assert.equal(result.line, "T02|RESULT=PASS|SERVICE=P|GW_PRE=STOP|RPC=P|APPLY=N|CHANGE=Y|TARGET_GLOBAL=0|TARGET_LOGS=OFF|TARGET_ANALYSIS=OFF|TARGET_BODY=NONE|AUTOFETCH=OFF|RAW=NO");
  assert.equal(harness.state.saveCount, 0);
  assert.deepEqual(harness.state.calls.map(({ method }) => method), expectedInitialMethods());
  assert.deepEqual(harness.state.requestViolations, []);
  assert.equal(harness.state.calls.every(({ path: requestPath }) => requestPath === "/api/ccr/rpc"), true);
  assert.deepEqual((await readdir(harness.root, { recursive: true })).sort(), filesBefore);
  assert.equal(await readFile(harness.serviceFile, "utf8"), stateBefore);
});

test("profile-only apply rechecks guards, saves once, and keeps Gateway stopped", async (t) => {
  const harness = await createHarness();
  t.after(() => harness.close());

  const before = clone(harness.state.config);
  const filesBefore = (await readdir(harness.root, { recursive: true })).sort();
  const stateBefore = await readFile(harness.serviceFile, "utf8");
  const result = await executeCli(["--apply"], harness.options);
  assert.equal(result.exitCode, EXIT.OK);
  assert.match(result.line, /^T02\|RESULT=PASS\|SERVICE=P\|GW_PRE=STOP\|GW_POST=STOP\|RPC=P\|APPLY=P\|CHANGE=Y\|/);
  assert.equal(harness.state.saveCount, 1);
  assert.deepEqual(harness.state.calls.map(({ method }) => method), expectedApplyMethods());
  assert.deepEqual(harness.state.savedArgs[1], { applyProfile: false });
  assert.equal(harness.state.savedArgs.length, 2);
  assert.equal(harness.state.savedArgs[0].profile.profiles[0].enabled, false);
  assert.equal(harness.state.savedArgs[0].profile.profiles[1].enabled, true);
  assert.equal(harness.state.savedArgs[0].profile.profiles[2].enabled, true);
  assert.equal(harness.state.savedArgs[0].profile.profiles[3].enabled, true);
  assert.deepEqual(harness.state.savedArgs[0].Providers, before.Providers);
  assert.deepEqual(harness.state.savedArgs[0].Router, before.Router);
  assert.deepEqual(harness.state.savedArgs[0].APIKEYS, before.APIKEYS);
  assert.deepEqual(harness.state.requestViolations, []);
  assert.equal(harness.state.calls.some(({ method }) => [
    "applyProfile",
    "checkProviderConnectivity",
    "openProfile",
    "probeProvider",
    "restartGateway",
    "setOnboardingFinished",
    "startGateway"
  ].includes(method)), false);
  assert.deepEqual((await readdir(harness.root, { recursive: true })).sort(), filesBefore);
  assert.equal(await readFile(harness.serviceFile, "utf8"), stateBefore);
});

test("already-safe apply reports SKIP and does not count as a save", async (t) => {
  const harness = await createHarness({ config: makeSafeConfig() });
  t.after(() => harness.close());

  const result = await executeCli(["--apply"], harness.options);
  assert.equal(result.exitCode, EXIT.OK);
  assert.match(result.line, /\|APPLY=SKIP\|CHANGE=N\|/);
  assert.equal(harness.state.saveCount, 0);
  assert.deepEqual(harness.state.calls.map(({ method }) => method), expectedInitialMethods());
});

test("strict service state rejects a dead PID, missing start mode, and managed profiles", async (t) => {
  await t.test("dead PID", async (t) => {
    const harness = await createHarness();
    t.after(() => harness.close());
    const result = await executeCli([], { ...harness.options, isProcessAlive: () => false });
    assert.equal(result.line, "T02|RESULT=BLOCKED|CATEGORY=BLOCKED_SERVICE_STATE|SAVE=N|RAW=NO");
    assert.equal(harness.state.calls.length, 0);
  });

  for (const [name, mutate] of [
    ["missing host", (value) => { delete value.host; return value; }],
    ["non-loopback host", (value) => ({ ...value, host: "0.0.0.0" })],
    ["missing startGateway", (value) => { delete value.startGateway; return value; }],
    ["startGateway true", (value) => ({ ...value, startGateway: true })],
    ["profileManaged true", (value) => ({ ...value, profileManaged: true })],
    ["unexpected key", (value) => ({ ...value, unexpected: true })]
  ]) {
    await t.test(name, async (t) => {
      const harness = await createHarness({ stateMutator: mutate });
      t.after(() => harness.close());
      const result = await executeCli([], harness.options);
      assert.equal(result.line, "T02|RESULT=BLOCKED|CATEGORY=BLOCKED_SERVICE_STATE|SAVE=N|RAW=NO");
      assert.equal(harness.state.calls.length, 0);
    });
  }
});

test("service state must be a bounded regular file", async (t) => {
  await t.test("missing", async (t) => {
    const harness = await createHarness();
    t.after(() => harness.close());
    await rm(harness.serviceFile);
    const result = await executeCli([], harness.options);
    assert.equal(result.line, "T02|RESULT=BLOCKED|CATEGORY=BLOCKED_SERVICE_STATE|SAVE=N|RAW=NO");
  });

  await t.test("malformed", async (t) => {
    const harness = await createHarness();
    t.after(() => harness.close());
    await writeFile(harness.serviceFile, "{MALFORMED_STATE_CANARY");
    const result = await executeCli([], harness.options);
    assert.equal(result.line, "T02|RESULT=BLOCKED|CATEGORY=BLOCKED_SERVICE_STATE|SAVE=N|RAW=NO");
  });

  await t.test("symlink", async (t) => {
    const harness = await createHarness();
    t.after(() => harness.close());
    const target = path.join(harness.configDir, "state-target.json");
    await writeFile(target, await readFile(harness.serviceFile));
    await rm(harness.serviceFile);
    await symlink(target, harness.serviceFile);
    const result = await executeCli([], harness.options);
    assert.equal(result.line, "T02|RESULT=BLOCKED|CATEGORY=BLOCKED_SERVICE_STATE|SAVE=N|RAW=NO");
  });

  await t.test("oversized", async (t) => {
    const harness = await createHarness();
    t.after(() => harness.close());
    await writeFile(harness.serviceFile, "x".repeat(64 * 1024 + 1));
    const result = await executeCli([], harness.options);
    assert.equal(result.line, "T02|RESULT=BLOCKED|CATEGORY=BLOCKED_SERVICE_STATE|SAVE=N|RAW=NO");
  });
});

test("only the canonical numeric loopback management URL is accepted", async (t) => {
  const variants = [
    "http://127.0.0.1:3458/",
    "http://127.0.0.1:3458/?ccr_web_token=",
    "http://127.0.0.1/?ccr_web_token=token",
    "http://localhost:3458/?ccr_web_token=token",
    "http://192.168.1.10:3458/?ccr_web_token=token",
    "https://127.0.0.1:3458/?ccr_web_token=token",
    "http://user@127.0.0.1:3458/?ccr_web_token=token",
    "http://127.0.0.1:3458/rpc?ccr_web_token=token",
    "http://127.0.0.1:3458/?ccr_web_token=token#fragment",
    "http://127.0.0.1:3458/?ccr_web_token=token&extra=1",
    "http://127.0.0.1:3458/?ccr_web_token=one&ccr_web_token=two"
  ];
  for (const variant of variants) {
    await t.test(variant.split("?")[0], async (t) => {
      const harness = await createHarness({ urlOverride: variant });
      t.after(() => harness.close());
      const result = await executeCli([], harness.options);
      assert.equal(result.exitCode, EXIT.BLOCKED);
      assert.match(result.line, /^T02\|RESULT=BLOCKED\|CATEGORY=BLOCKED_(NON_LOOPBACK|AUTH)\|SAVE=N\|RAW=NO$/);
      assert.equal(harness.state.calls.length, 0);
    });
  }
});

test("runtime overrides/debug and a stale Claude App backup block before RPC", async (t) => {
  for (const [key, value] of [
    ["CCR_INTERNAL_APP_DATA_DIR", "override"],
    ["CCR_INTERNAL_HOME_DIR", "override"],
    ["CCR_INTERNAL_USER_DATA_DIR", "override"],
    ["CCR_GATEWAY_ENTRY", "gateway-entry-canary"],
    ["CCR_MODELS_JSON_PATH", "C:\\models-legacy-canary.json"],
    ["CCR_MODEL_CATALOG_PATH", "C:\\models-canary.json"],
    ["CCR_NODE_BIN", "node-bin-canary"],
    ["CCR_UPSTREAM_PROXY_URL", "http://proxy-canary.invalid"],
    ["CCR_WEB_ALLOWED_ORIGINS", "https://origin-canary.invalid"],
    ["CCR_WEB_AUTH_TOKEN", "web-auth-canary"],
    ["NODE_COMPILE_CACHE", "C:\\compile-cache-canary"],
    ["NODE_DEBUG", "http"],
    ["NODE_OPTIONS", "--require=preload-canary"],
    ["NODE_REDIRECT_WARNINGS", "C:\\warnings-canary.log"],
    ["NODE_V8_COVERAGE", "C:\\coverage-canary"],
    ["npm_config_node_options", "--require=preload-canary"],
    ["npm_config_script_shell", "C:\\shell-canary.exe"]
  ]) {
    await t.test(key, async (t) => {
      const harness = await createHarness({
        envMutator: (env) => ({ ...env, [key]: value })
      });
      t.after(() => harness.close());
      const result = await executeCli([], harness.options);
      assert.equal(result.line, "T02|RESULT=BLOCKED|CATEGORY=BLOCKED_RUNTIME_ENV|SAVE=N|RAW=NO");
      assert.equal(harness.state.calls.length, 0);
    });
  }

  for (const key of [
    "CCR_WEB_AUTH_TOKEN",
    "NODE_COMPILE_CACHE",
    "NODE_REDIRECT_WARNINGS",
    "NODE_V8_COVERAGE",
    "npm_config_node_options"
  ]) {
    await t.test(`${key} whitespace-only`, async (t) => {
      const harness = await createHarness({
        envMutator: (env) => ({ ...env, [key]: " " })
      });
      t.after(() => harness.close());
      const result = await executeCli([], harness.options);
      assert.equal(result.line, "T02|RESULT=BLOCKED|CATEGORY=BLOCKED_RUNTIME_ENV|SAVE=N|RAW=NO");
      assert.equal(harness.state.calls.length, 0);
    });
  }

  await t.test("stale backup", async (t) => {
    const harness = await createHarness();
    t.after(() => harness.close());
    await writeFile(harness.backupFile, "BACKUP_CANARY");
    const result = await executeCli([], harness.options);
    assert.equal(result.line, "T02|RESULT=BLOCKED|CATEGORY=BLOCKED_STALE_BACKUP|SAVE=N|RAW=NO");
    assert.equal(harness.state.calls.length, 0);
  });
});

test("pinned app and service identities are fail-closed", async (t) => {
  for (const [name, mutate] of [
    ["app name", (value) => ({ ...value, name: "Wrong App" })],
    ["app version", (value) => ({ ...value, version: "3.0.23" })],
    ["app platform", (value) => ({ ...value, platform: "linux" })],
    ["desktop mode", (value) => ({ ...value, desktop: true })],
    ["config root", (value) => ({ ...value, configDir: "C:\\APP_INFO_PATH_CANARY" })],
    ["data root", (value) => ({ ...value, dataDir: "C:\\APP_DATA_PATH_CANARY" })]
  ]) {
    await t.test(`${name} mismatch`, async (t) => {
      const harness = await createHarness({ appInfoMutator: mutate });
      t.after(() => harness.close());
      const result = await executeCli([], harness.options);
      assert.equal(result.line, "T02|RESULT=BLOCKED|CATEGORY=BLOCKED_APP_IDENTITY|SAVE=N|RAW=NO");
      assert.deepEqual(harness.state.calls.map(({ method }) => method), ["getAppInfo"]);
    });
  }

  await t.test("service PID mismatch", async (t) => {
    const behavior = {
      override: ({ method }) => method === "getServiceIdentity"
        ? { pid: process.pid + 1, serviceTokenConfigured: true, serviceTokenMatches: true }
        : NO_OVERRIDE
    };
    const harness = await createHarness({ behavior });
    t.after(() => harness.close());
    const result = await executeCli([], harness.options);
    assert.equal(result.line, "T02|RESULT=BLOCKED|CATEGORY=BLOCKED_SERVICE_IDENTITY|SAVE=N|RAW=NO");
  });

  for (const field of ["serviceTokenConfigured", "serviceTokenMatches"]) {
    await t.test(`${field} false`, async (t) => {
      const behavior = {
        override: ({ method }) => method === "getServiceIdentity"
          ? { pid: process.pid, serviceTokenConfigured: true, serviceTokenMatches: true, [field]: false }
          : NO_OVERRIDE
      };
      const harness = await createHarness({ behavior });
      t.after(() => harness.close());
      const result = await executeCli([], harness.options);
      assert.equal(result.line, "T02|RESULT=BLOCKED|CATEGORY=BLOCKED_SERVICE_IDENTITY|SAVE=N|RAW=NO");
    });
  }
});

test("unsafe pre-save Gateway and runtime surfaces block without save", async (t) => {
  for (const [name, status] of [
    ["already running", postGateway(makeConfig())],
    ["starting", { ...stoppedGateway(), state: "starting" }],
    ["external gateway", { ...stoppedGateway(), gatewayManagedExternally: true }],
    ["external core", { ...stoppedGateway(), coreManagedExternally: true }],
    ["stale PID", { ...stoppedGateway(), pid: process.pid }],
    ["stale error", { ...stoppedGateway(), lastError: SERVER_ERROR_CANARY }],
    ["stale start time", { ...stoppedGateway(), lastStartedAt: "2026-09-01T00:00:00.000Z" }],
    ["stale endpoint", { ...stoppedGateway(), endpoint: "http://127.0.0.1:45101" }],
    ["stale core endpoint", { ...stoppedGateway(), coreEndpoint: "http://127.0.0.1:45102" }],
    ["network endpoint", {
      ...stoppedGateway(),
      networkEndpoints: [{ address: "192.168.1.10", endpoint: "http://192.168.1.10:45101", interfaceName: "lan" }]
    }]
  ]) {
    await t.test(`Gateway ${name}`, async (t) => {
      const behavior = {
        override: ({ method }) => method === "getGatewayStatus" ? status : NO_OVERRIDE
      };
      const harness = await createHarness({ behavior });
      t.after(() => harness.close());
      const result = await executeCli(["--apply"], harness.options);
      assert.equal(result.line, "T02|RESULT=BLOCKED|CATEGORY=BLOCKED_GATEWAY_STATE|SAVE=N|RAW=NO");
      assert.equal(harness.state.saveCount, 0);
    });
  }

  for (const [name, mutate] of [
    ["non-loopback core", (config) => { config.gateway.coreHost = "0.0.0.0"; }],
    ["proxy", (config) => { config.proxy.enabled = true; }],
    ["proxy capture", (config) => { config.proxy.captureNetwork = true; }],
    ["media", (config) => { config.mediaTools.enabled = true; }],
    ["plugins", (config) => { config.plugins.push({ id: "plugin-canary" }); }],
    ["provider plugins", (config) => { config.providerPlugins.push({ id: "provider-plugin-canary" }); }],
    ["Tool Hub", (config) => { config.toolHub.enabled = true; }],
    ["agent MCP", (config) => { config.agent.mcpServers.push({ name: "mcp-canary" }); }],
    ["context archive", (config) => { config.contextArchive.enabled = true; }],
    ["virtual model profile", (config) => { config.virtualModelProfiles.push({ id: "virtual-canary" }); }],
    ["enabled Router script", (config) => { config.Router.rules.push({ enabled: true, id: "script-canary", type: "script" }); }]
  ]) {
    await t.test(name, async (t) => {
      const config = makeConfig();
      mutate(config);
      const harness = await createHarness({ config });
      t.after(() => harness.close());
      const result = await executeCli(["--apply"], harness.options);
      assert.equal(result.line, "T02|RESULT=BLOCKED|CATEGORY=BLOCKED_RUNTIME_SURFACE|SAVE=N|RAW=NO");
      assert.equal(harness.state.saveCount, 0);
    });
  }

  for (const [name, mutate] of [
    ["request logs", (config) => { config.observability.requestLogs = true; }],
    ["agent analysis", (config) => { config.observability.agentAnalysis = true; }],
    ["request body capture", (config) => { config.observability.requestLogBodyCapture = "all"; }]
  ]) {
    await t.test(`${name} is not already safe`, async (t) => {
      const config = makeConfig();
      mutate(config);
      const harness = await createHarness({ config });
      t.after(() => harness.close());
      const result = await executeCli(["--apply"], harness.options);
      assert.equal(result.line, "T02|RESULT=BLOCKED|CATEGORY=BLOCKED_RUNTIME_SURFACE|SAVE=N|RAW=NO");
      assert.equal(harness.state.saveCount, 0);
    });
  }
});

test("Provider auto-fetch matrix is fail-closed and Provider state is never modified", async (t) => {
  await t.test("NVIDIA preset capability fixed point is exact", () => {
    const canonical = makeConfig();
    canonical.Providers[0].api_base_url = "https://integrate.api.nvidia.com/v1";
    canonical.Providers[0].capabilities = [{
      baseUrl: "https://integrate.api.nvidia.com/v1",
      source: "preset",
      type: "openai_chat_completions"
    }];
    assert.doesNotThrow(() => validateAndBuildTarget(canonical));

    const noncanonical = clone(canonical);
    noncanonical.Providers[0].capabilities.push({
      baseUrl: "https://integrate.api.nvidia.com/v1",
      source: "detected",
      type: "anthropic_messages"
    });
    assert.throws(() => validateAndBuildTarget(noncanonical), { category: "BLOCKED_CONFIG_SHAPE" });
  });

  for (const key of ["api_key", "apiKey", "apikey"]) {
    for (const disabled of [false, true]) {
      await t.test(`local-agent Provider ${key} disabled=${disabled} blocks normalization`, () => {
        const config = makeConfig();
        config.Providers[0][key] = "ccr-local-agent-login";
        if (disabled) config.Providers[0].enabled = false;
        assert.throws(() => validateAndBuildTarget(config), { category: "BLOCKED_RUNTIME_SURFACE" });
      });
    }
  }

  await t.test("disabled local-agent alias blocks RPC apply before save", async (t) => {
    const config = makeConfig();
    config.Providers[0].apiKey = "ccr-local-agent-login";
    config.Providers[0].enabled = false;
    const harness = await createHarness({ config });
    t.after(() => harness.close());
    const result = await executeCli(["--apply"], harness.options);
    assert.equal(result.line, "T02|RESULT=BLOCKED|CATEGORY=BLOCKED_RUNTIME_SURFACE|SAVE=N|RAW=NO");
    assert.equal(harness.state.saveCount, 0);
  });

  await t.test("enabled-absent plus auto-fetch true blocks", async (t) => {
    const config = makeConfig();
    config.Providers[0].autoFetchModels = true;
    const harness = await createHarness({ config });
    t.after(() => harness.close());
    const result = await executeCli(["--apply"], harness.options);
    assert.equal(result.line, "T02|RESULT=BLOCKED|CATEGORY=BLOCKED_PROVIDER_AUTO_REFRESH|SAVE=N|RAW=NO");
  });

  await t.test("disabled true is allowed and preserved", () => {
    const config = makeConfig();
    config.Providers.push({
      autoFetchModels: true,
      enabled: false,
      models: [],
      name: "disabled-provider"
    });
    const { target } = validateAndBuildTarget(config);
    assert.deepEqual(target.Providers, config.Providers);
  });

  await t.test("non-boolean blocks", () => {
    const config = makeConfig();
    config.Providers[0].autoFetchModels = "false";
    assert.throws(() => validateAndBuildTarget(config), { category: "BLOCKED_PROVIDER_AUTO_REFRESH" });
  });

  await t.test("non-canonical explicit enabled true blocks", () => {
    const config = makeConfig();
    config.Providers[0].enabled = true;
    assert.throws(() => validateAndBuildTarget(config), { category: "BLOCKED_CONFIG_SHAPE" });
  });
});

test("fallback or incomplete config is rejected before save", async (t) => {
  const harness = await createHarness({ config: {} });
  t.after(() => harness.close());
  const result = await executeCli(["--apply"], harness.options);
  assert.equal(result.line, "T02|RESULT=BLOCKED|CATEGORY=BLOCKED_CONFIG_SHAPE|SAVE=N|RAW=NO");
  assert.equal(harness.state.saveCount, 0);
});

test("a concurrent config change is detected on the second snapshot before save", async (t) => {
  const behavior = {
    override: ({ method, methodCount, state }) => {
      if (method === "getConfig" && methodCount === 2) {
        const changed = clone(state.config);
        changed.Router.sentinel = "CONCURRENT_CHANGE_CANARY";
        return changed;
      }
      return NO_OVERRIDE;
    }
  };
  const harness = await createHarness({ behavior });
  t.after(() => harness.close());
  const result = await executeCli(["--apply"], harness.options);
  assert.equal(result.line, "T02|RESULT=BLOCKED|CATEGORY=BLOCKED_CONCURRENT_CHANGE|SAVE=N|RAW=NO");
  assert.equal(harness.state.saveCount, 0);
});

test("a concurrent raw service-state change is detected before save", async (t) => {
  const behavior = {
    afterCall: async ({ method, methodCount, serviceFile }) => {
      if (method === "getConfig" && methodCount === 1) {
        const parsed = JSON.parse(await readFile(serviceFile, "utf8"));
        parsed.startedAt = "2026-09-01T00:00:01.000Z";
        await writeFile(serviceFile, `${JSON.stringify(parsed, null, 2)}\n`);
      }
    }
  };
  const harness = await createHarness({ behavior });
  t.after(() => harness.close());
  const result = await executeCli(["--apply"], harness.options);
  assert.equal(result.line, "T02|RESULT=BLOCKED|CATEGORY=BLOCKED_CONCURRENT_CHANGE|SAVE=N|RAW=NO");
  assert.equal(harness.state.saveCount, 0);
});

test("identity, Gateway, onboarding, and backup are rechecked immediately before save", async (t) => {
  const cases = [
    {
      category: "BLOCKED_SERVICE_IDENTITY",
      name: "identity",
      override: ({ method, methodCount }) => method === "getServiceIdentity" && methodCount === 2
        ? { pid: process.pid + 1, serviceTokenConfigured: true, serviceTokenMatches: true }
        : NO_OVERRIDE
    },
    {
      category: "BLOCKED_GATEWAY_STATE",
      name: "Gateway",
      override: ({ method, methodCount, state }) => method === "getGatewayStatus" && methodCount === 2
        ? postGateway(state.config)
        : NO_OVERRIDE
    },
    {
      category: "BLOCKED_CONCURRENT_CHANGE",
      name: "onboarding",
      override: ({ method, methodCount }) => method === "getOnboardingFinished" && methodCount === 2
        ? true
        : NO_OVERRIDE
    }
  ];
  for (const item of cases) {
    await t.test(item.name, async (t) => {
      const harness = await createHarness({ behavior: { override: item.override } });
      t.after(() => harness.close());
      const result = await executeCli(["--apply"], harness.options);
      assert.equal(result.line, `T02|RESULT=BLOCKED|CATEGORY=${item.category}|SAVE=N|RAW=NO`);
      assert.equal(harness.state.saveCount, 0);
    });
  }

  await t.test("backup appears during final pre-save window", async (t) => {
    let backupFile;
    const behavior = {
      afterCall: async ({ method, methodCount }) => {
        if (method === "getConfig" && methodCount === 2) await writeFile(backupFile, "CONCURRENT_BACKUP_CANARY");
      }
    };
    const harness = await createHarness({ behavior });
    backupFile = harness.backupFile;
    t.after(() => harness.close());
    const result = await executeCli(["--apply"], harness.options);
    assert.equal(result.line, "T02|RESULT=BLOCKED|CATEGORY=BLOCKED_STALE_BACKUP|SAVE=N|RAW=NO");
    assert.equal(harness.state.saveCount, 0);
  });
});

test("post-save config and Gateway postconditions are enforced", async (t) => {
  await t.test("immediate save response mismatch", async (t) => {
    const behavior = {
      saveResponseMutator: (config) => {
        config.Router.sentinel = "SAVE_RESPONSE_MUTATION_CANARY";
        return config;
      }
    };
    const harness = await createHarness({ behavior });
    t.after(() => harness.close());
    const result = await executeCli(["--apply"], harness.options);
    assert.equal(result.line, "T02|RESULT=FAIL|CATEGORY=POSTCONDITION_FAILURE|SAVE=Y|RAW=NO");
    assert.equal(harness.state.saveCount, 1);
  });

  await t.test("unexpected config diff", async (t) => {
    const behavior = {
      postSaveConfigMutator: (config) => {
        config.Router.sentinel = "POST_SAVE_MUTATION_CANARY";
        return config;
      }
    };
    const harness = await createHarness({ behavior });
    t.after(() => harness.close());
    const result = await executeCli(["--apply"], harness.options);
    assert.equal(result.line, "T02|RESULT=FAIL|CATEGORY=POSTCONDITION_FAILURE|SAVE=Y|RAW=NO");
    assert.equal(harness.state.saveCount, 1);
  });

  await t.test("unsafe Gateway endpoint", async (t) => {
    const behavior = {
      override: ({ method, state }) => method === "getGatewayStatus" && state.saveCount > 0
        ? { ...postGateway(state.config, "stopped"), endpoint: "http://0.0.0.0:9999" }
        : NO_OVERRIDE
    };
    const harness = await createHarness({ behavior });
    t.after(() => harness.close());
    const result = await executeCli(["--apply"], harness.options);
    assert.equal(result.line, "T02|RESULT=FAIL|CATEGORY=POSTCONDITION_FAILURE|SAVE=Y|RAW=NO");
    assert.equal(harness.state.saveCount, 1);
  });

  await t.test("unexpected network endpoint", async (t) => {
    const behavior = {
      override: ({ method, state }) => method === "getGatewayStatus" && state.saveCount > 0
        ? {
            ...postGateway(state.config, "stopped"),
            networkEndpoints: [{ address: "192.168.1.10", endpoint: "http://192.168.1.10:9999", interfaceName: "lan" }]
          }
        : NO_OVERRIDE
    };
    const harness = await createHarness({ behavior });
    t.after(() => harness.close());
    const result = await executeCli(["--apply"], harness.options);
    assert.equal(result.line, "T02|RESULT=FAIL|CATEGORY=POSTCONDITION_FAILURE|SAVE=Y|RAW=NO");
  });

  await t.test("stopped Gateway with stale PID", async (t) => {
    const behavior = {
      override: ({ method, state }) => method === "getGatewayStatus" && state.saveCount > 0
        ? { ...postGateway(state.config, "stopped"), pid: process.pid }
        : NO_OVERRIDE
    };
    const harness = await createHarness({ behavior });
    t.after(() => harness.close());
    const result = await executeCli(["--apply"], harness.options);
    assert.equal(result.line, "T02|RESULT=FAIL|CATEGORY=POSTCONDITION_FAILURE|SAVE=Y|RAW=NO");
  });

  for (const [name, mutate] of [
    ["running", (config) => postGateway(config, "running")],
    ["running without PID", (config) => ({ ...postGateway(config, "stopped"), state: "running" })],
    ["starting", (config) => ({ ...postGateway(config, "stopped"), state: "starting" })],
    ["error", (config) => ({ ...postGateway(config, "stopped"), lastError: SERVER_ERROR_CANARY, state: "error" })],
    ["external gateway", (config) => ({ ...postGateway(config, "stopped"), gatewayManagedExternally: true })],
    ["external core", (config) => ({ ...postGateway(config, "stopped"), coreManagedExternally: true })],
    ["unexpected start time", (config) => ({ ...postGateway(config, "stopped"), lastStartedAt: "2026-09-01T00:00:00.000Z" })],
    ["wrong core endpoint", (config) => ({ ...postGateway(config, "stopped"), coreEndpoint: "http://127.0.0.1:9999" })]
  ]) {
    await t.test(`unsafe ${name} state`, async (t) => {
      const behavior = {
        override: ({ method, state }) => method === "getGatewayStatus" && state.saveCount > 0
          ? mutate(state.config)
          : NO_OVERRIDE
      };
      const harness = await createHarness({ behavior });
      t.after(() => harness.close());
      const result = await executeCli(["--apply"], harness.options);
      assert.equal(result.line, "T02|RESULT=FAIL|CATEGORY=POSTCONDITION_FAILURE|SAVE=Y|RAW=NO");
      assert.equal(result.line.includes(SERVER_ERROR_CANARY), false);
      assert.equal(harness.state.saveCount, 1);
    });
  }

  await t.test("stopped Gateway with stale error", async (t) => {
    const behavior = {
      override: ({ method, state }) => method === "getGatewayStatus" && state.saveCount > 0
        ? { ...postGateway(state.config, "stopped"), lastError: "STALE_ERROR_CANARY" }
        : NO_OVERRIDE
    };
    const harness = await createHarness({ behavior });
    t.after(() => harness.close());
    const result = await executeCli(["--apply"], harness.options);
    assert.equal(result.line, "T02|RESULT=FAIL|CATEGORY=POSTCONDITION_FAILURE|SAVE=Y|RAW=NO");
    assert.equal(harness.state.saveCount, 1);
  });
});

test("occupied Gateway port blocks immediately before save", async (t) => {
  const occupied = createServer();
  const gatewayPort = await listen(occupied);
  t.after(() => closeServer(occupied));
  const corePort = await freePort();
  const harness = await createHarness({ config: makeConfig({ corePort, gatewayPort }) });
  t.after(() => harness.close());

  const result = await executeCli(["--apply"], { ...harness.options, portChecker: undefined });
  assert.equal(result.line, "T02|RESULT=BLOCKED|CATEGORY=BLOCKED_PORT_IN_USE|SAVE=N|RAW=NO");
  assert.equal(harness.state.saveCount, 0);
});

test("read RPC rejects redirects and non-exact JSON media types without following", async (t) => {
  for (const [name, responder] of [
    ["redirect", ({ response }) => {
      response.writeHead(302, { location: "http://127.0.0.1:1/REDIRECT_CANARY" });
      response.end();
    }],
    ["JSONP media type", ({ response }) => {
      const body = JSON.stringify({ ok: true, value: { name: "SHOULD_NOT_PARSE_CANARY" } });
      response.writeHead(200, {
        "content-length": Buffer.byteLength(body),
        "content-type": "application/jsonp"
      });
      response.end(body);
    }]
  ]) {
    await t.test(name, async (t) => {
      const behavior = {
        rawCall: async (context) => {
          if (context.method !== "getAppInfo") return false;
          responder(context);
          return true;
        }
      };
      const harness = await createHarness({ behavior });
      t.after(() => harness.close());
      const result = await executeCli([], harness.options);
      assert.equal(result.line, "T02|RESULT=BLOCKED|CATEGORY=RPC_FAILURE|SAVE=N|RAW=NO");
      assert.deepEqual(harness.state.calls.map(({ method }) => method), ["getAppInfo"]);
    });
  }
});

test("save disconnect, malformed response, HTTP error, and oversized response are indeterminate and never retried", async (t) => {
  const cases = [
    ["disconnect", ({ response }) => response.destroy()],
    ["malformed JSON", ({ response }) => {
      response.writeHead(200, { "content-type": "application/json" });
      response.end("{MALFORMED_SAVE_RESPONSE_CANARY");
    }],
    ["HTTP error", ({ response }) => sendJson(response, 500, { error: { message: SERVER_ERROR_CANARY }, ok: false })],
    ["oversized declared response", ({ response }) => {
      response.writeHead(200, {
        "content-length": String(8 * 1024 * 1024 + 1),
        "content-type": "application/json"
      });
      response.end();
    }]
  ];
  for (const [name, responder] of cases) {
    await t.test(name, async (t) => {
      const behavior = {
        rawCall: async (context) => {
          if (context.method !== "saveConfig") return false;
          context.state.saveCount += 1;
          responder(context);
          return true;
        }
      };
      const harness = await createHarness({ behavior });
      t.after(() => harness.close());
      const result = await executeCli(["--apply"], harness.options);
      assert.equal(result.line, "T02|RESULT=FAIL|CATEGORY=INDETERMINATE_SAVE|SAVE=UNKNOWN|RAW=NO");
      assert.equal(result.exitCode, EXIT.MUTATION_FAILURE);
      assert.equal(harness.state.saveCount, 1);
      assert.equal(harness.state.calls.filter(({ method }) => method === "saveConfig").length, 1);
    });
  }
});

test("mutation timeout is indeterminate, fixed-output, and never retried", async (t) => {
  let requests = 0;
  const server = createServer((request) => {
    requests += 1;
    void readRequestJson(request);
  });
  const port = await listen(server);
  t.after(() => closeServer(server));

  let captured;
  try {
    await directRpc(
      { authToken: TOKEN_CANARY, hostname: "127.0.0.1", port },
      "saveConfig",
      [{ secret: API_KEY_CANARY }, { applyProfile: false }],
      { mutation: true, timeoutMs: 40 }
    );
    assert.fail("mutation timeout should reject");
  } catch (error) {
    captured = error;
  }
  assert.ok(captured instanceof T02Error);
  assert.equal(captured.category, "INDETERMINATE_SAVE");
  assert.equal(captured.save, "UNKNOWN");
  assert.equal(requests, 1);
  const formatted = formatFailure(captured);
  assert.deepEqual(formatted, {
    exitCode: EXIT.MUTATION_FAILURE,
    line: "T02|RESULT=FAIL|CATEGORY=INDETERMINATE_SAVE|SAVE=UNKNOWN|RAW=NO"
  });
});

test("server errors and all fixed capsules exclude secret and raw canaries", async (t) => {
  const harness = await createHarness({ behavior: { failMethod: "getConfig" } });
  t.after(() => harness.close());
  const result = await executeCli([], harness.options);
  assert.equal(result.line, "T02|RESULT=BLOCKED|CATEGORY=RPC_FAILURE|SAVE=N|RAW=NO");

  const forbidden = [
    TOKEN_CANARY,
    SERVICE_TOKEN_CANARY,
    API_KEY_CANARY,
    PROVIDER_KEY_CANARY,
    PROVIDER_URL_CANARY,
    MODEL_CANARY,
    SERVER_ERROR_CANARY,
    harness.root,
    harness.serviceState.url
  ];
  for (const canary of forbidden) assert.equal(result.line.includes(canary), false);
});

test("APPDATA is authoritative and restored LOCALAPPDATA is not consulted", async (t) => {
  const harness = await createHarness();
  t.after(() => harness.close());
  const decoyDir = path.join(harness.env.LOCALAPPDATA, "claude-code-router");
  await mkdir(decoyDir, { recursive: true });
  await writeFile(path.join(decoyDir, "service.json"), "LOCALAPPDATA_DECOY_SECRET");

  const result = await executeCli([], harness.options);
  assert.equal(result.exitCode, EXIT.OK);
  assert.equal(harness.state.saveCount, 0);
});
