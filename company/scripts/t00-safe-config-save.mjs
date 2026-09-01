#!/usr/bin/env node

const { lstat, readFile } = await import("node:fs/promises");
const pathModule = await import("node:path");
const path = pathModule.default;
const { fileURLToPath } = await import("node:url");

const APP_NAME = "Claude Code Router";
const APP_VERSION = "3.0.22";
const CONFIG_DIR_NAME = "claude-code-router";
const SERVICE_STATE_FILE = "service.json";
const CLAUDE_APP_BACKUP_FILE = "claude-app-gateway-backup.json";
const RPC_PATH = "/api/ccr/rpc";
const WEB_AUTH_HEADER = "x-ccr-web-auth";
const WEB_AUTH_QUERY = "ccr_web_token";
const MAX_STATE_BYTES = 64 * 1024;
const MAX_RPC_BYTES = 8 * 1024 * 1024;
const LOCAL_AGENT_PROVIDER_API_KEY = "ccr-local-agent-login";
const PROFILE_AGENTS = new Set([
  "claude-code",
  "claude-design",
  "codex",
  "grok",
  "kilo",
  "kimi",
  "opencode",
  "pi",
  "workbuddy",
  "zcode"
]);
const READ_TIMEOUT_MS = 2_000;
const SAVE_TIMEOUT_MS = 30_000;
const STATE_KEYS = new Set([
  "host",
  "pid",
  "profileManaged",
  "serviceToken",
  "startedAt",
  "startGateway",
  "url"
]);
const PATH_OVERRIDE_KEYS = [
  "CCR_INTERNAL_APP_DATA_DIR",
  "CCR_INTERNAL_HOME_DIR",
  "CCR_INTERNAL_USER_DATA_DIR"
];
const UNSAFE_RUNTIME_ENV_KEYS = [
  "CCR_GATEWAY_ENTRY",
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
];

export const EXIT = Object.freeze({
  BLOCKED: 2,
  INVALID_ARGUMENTS: 64,
  MUTATION_FAILURE: 3,
  OK: 0
});

export class T02Error extends Error {
  constructor(category, { exitCode = EXIT.BLOCKED, save = "N" } = {}) {
    super(category);
    this.name = "T02Error";
    this.category = category;
    this.exitCode = exitCode;
    this.save = save;
    this.stack = undefined;
  }
}

function blocked(category) {
  throw new T02Error(category);
}

function mutationFailure(category, save = "Y") {
  throw new T02Error(category, { exitCode: EXIT.MUTATION_FAILURE, save });
}

function nonemptyString(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function isPlainObject(value) {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return false;
  }
  const prototype = Object.getPrototypeOf(value);
  return prototype === Object.prototype || prototype === null;
}

function hasOwn(value, key) {
  return Object.prototype.hasOwnProperty.call(value, key);
}

function readEnv(env, key) {
  const value = env?.[key];
  return typeof value === "string" ? value.trim() : "";
}

function hasRawEnvValue(env, key) {
  const value = env?.[key];
  return typeof value === "string" && value.length > 0;
}

function assertJsonSafe(value) {
  const seen = new Set();
  let nodes = 0;

  const visit = (candidate, depth) => {
    nodes += 1;
    if (nodes > 200_000 || depth > 100) {
      blocked("BLOCKED_CONFIG_SHAPE");
    }
    if (candidate === null || typeof candidate === "string" || typeof candidate === "boolean") {
      return;
    }
    if (typeof candidate === "number") {
      if (!Number.isFinite(candidate)) {
        blocked("BLOCKED_CONFIG_SHAPE");
      }
      return;
    }
    if (typeof candidate !== "object" || seen.has(candidate)) {
      blocked("BLOCKED_CONFIG_SHAPE");
    }
    seen.add(candidate);
    if (Array.isArray(candidate)) {
      for (let index = 0; index < candidate.length; index += 1) {
        if (!hasOwn(candidate, index)) {
          blocked("BLOCKED_CONFIG_SHAPE");
        }
        visit(candidate[index], depth + 1);
      }
    } else {
      if (!isPlainObject(candidate)) {
        blocked("BLOCKED_CONFIG_SHAPE");
      }
      for (const key of Reflect.ownKeys(candidate)) {
        if (typeof key !== "string" || key === "__proto__" || key === "prototype" || key === "constructor") {
          blocked("BLOCKED_CONFIG_SHAPE");
        }
        visit(candidate[key], depth + 1);
      }
    }
    seen.delete(candidate);
  };

  visit(value, 0);
}

function sortedJsonValue(value) {
  if (Array.isArray(value)) {
    return value.map(sortedJsonValue);
  }
  if (!isPlainObject(value)) {
    return value;
  }
  const result = {};
  for (const key of Object.keys(value).sort()) {
    result[key] = sortedJsonValue(value[key]);
  }
  return result;
}

export function canonicalJson(value) {
  assertJsonSafe(value);
  return JSON.stringify(sortedJsonValue(value));
}

function cloneJson(value) {
  assertJsonSafe(value);
  return JSON.parse(JSON.stringify(value));
}

function pointerPart(value) {
  return String(value).replaceAll("~", "~0").replaceAll("/", "~1");
}

function collectDiffPaths(before, after, base = "") {
  if (Object.is(before, after)) {
    return [];
  }
  if (Array.isArray(before) && Array.isArray(after)) {
    if (before.length !== after.length) {
      return [base || "/"];
    }
    return before.flatMap((value, index) => collectDiffPaths(value, after[index], `${base}/${index}`));
  }
  if (isPlainObject(before) && isPlainObject(after)) {
    const beforeKeys = Object.keys(before).sort();
    const afterKeys = Object.keys(after).sort();
    if (JSON.stringify(beforeKeys) !== JSON.stringify(afterKeys)) {
      return [base || "/"];
    }
    return beforeKeys.flatMap((key) => collectDiffPaths(before[key], after[key], `${base}/${pointerPart(key)}`));
  }
  return [base || "/"];
}

function normalizePathForComparison(value, pathApi, platform) {
  if (!nonemptyString(value)) {
    blocked("BLOCKED_APP_IDENTITY");
  }
  let normalized;
  try {
    normalized = pathApi.resolve(value.trim()).replace(/[\\/]+$/, "");
  } catch {
    blocked("BLOCKED_APP_IDENTITY");
  }
  return platform === "win32" ? normalized.toLowerCase() : normalized;
}

function resolveRuntimePaths({ env, pathApi, platform }) {
  if (platform !== "win32") {
    blocked("BLOCKED_RUNTIME_ENV");
  }
  for (const key of [...PATH_OVERRIDE_KEYS, ...UNSAFE_RUNTIME_ENV_KEYS]) {
    if (hasRawEnvValue(env, key)) {
      blocked("BLOCKED_RUNTIME_ENV");
    }
  }
  const appData = readEnv(env, "APPDATA");
  if (!appData || !pathApi.isAbsolute(appData)) {
    blocked("BLOCKED_RUNTIME_ENV");
  }
  const configDir = pathApi.join(appData, CONFIG_DIR_NAME);
  return {
    backupFile: pathApi.join(configDir, CLAUDE_APP_BACKUP_FILE),
    configDir,
    serviceFile: pathApi.join(configDir, SERVICE_STATE_FILE)
  };
}

async function readBoundedRegularFile(file, maxBytes, category) {
  let stat;
  try {
    stat = await lstat(file);
  } catch {
    blocked(category);
  }
  if (!stat.isFile() || stat.isSymbolicLink() || stat.size <= 0 || stat.size > maxBytes) {
    blocked(category);
  }
  let raw;
  try {
    raw = await readFile(file, "utf8");
  } catch {
    blocked(category);
  }
  if (Buffer.byteLength(raw, "utf8") > maxBytes) {
    blocked(category);
  }
  return raw;
}

async function pathAbsent(file, category) {
  try {
    await lstat(file);
    blocked(category);
  } catch (error) {
    if (error instanceof T02Error) {
      throw error;
    }
    if (error?.code !== "ENOENT") {
      blocked(category);
    }
  }
}

function validateServiceState(value, isProcessAlive) {
  if (!isPlainObject(value)) {
    blocked("BLOCKED_SERVICE_STATE");
  }
  const keys = Object.keys(value);
  if (keys.some((key) => !STATE_KEYS.has(key))) {
    blocked("BLOCKED_SERVICE_STATE");
  }
  for (const required of ["host", "pid", "profileManaged", "serviceToken", "startedAt", "startGateway", "url"]) {
    if (!hasOwn(value, required)) {
      blocked("BLOCKED_SERVICE_STATE");
    }
  }
  if (!Number.isSafeInteger(value.pid) || value.pid <= 0 || !isProcessAlive(value.pid)) {
    blocked("BLOCKED_SERVICE_STATE");
  }
  if (value.profileManaged !== false || value.startGateway !== false) {
    blocked("BLOCKED_SERVICE_STATE");
  }
  if (!nonemptyString(value.serviceToken) || value.serviceToken !== value.serviceToken.trim()) {
    blocked("BLOCKED_SERVICE_STATE");
  }
  if (!nonemptyString(value.startedAt) || !Number.isFinite(Date.parse(value.startedAt))) {
    blocked("BLOCKED_SERVICE_STATE");
  }
  if (!nonemptyString(value.url) || value.url.length > 4_096) {
    blocked("BLOCKED_SERVICE_STATE");
  }
  if (value.host !== "127.0.0.1") {
    blocked("BLOCKED_SERVICE_STATE");
  }
  return value;
}

async function readServiceState(file, isProcessAlive) {
  const raw = await readBoundedRegularFile(file, MAX_STATE_BYTES, "BLOCKED_SERVICE_STATE");
  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch {
    blocked("BLOCKED_SERVICE_STATE");
  }
  return { raw, value: validateServiceState(parsed, isProcessAlive) };
}

function parseManagementTarget(rawUrl) {
  let parsed;
  try {
    parsed = new URL(rawUrl);
  } catch {
    blocked("BLOCKED_NON_LOOPBACK");
  }
  if (
    parsed.protocol !== "http:" ||
    parsed.hostname !== "127.0.0.1" ||
    !parsed.port ||
    parsed.pathname !== "/" ||
    parsed.username ||
    parsed.password ||
    parsed.hash
  ) {
    blocked("BLOCKED_NON_LOOPBACK");
  }
  const port = Number(parsed.port);
  if (!Number.isInteger(port) || port <= 0 || port > 65_535) {
    blocked("BLOCKED_NON_LOOPBACK");
  }
  const keys = [...parsed.searchParams.keys()];
  const tokens = parsed.searchParams.getAll(WEB_AUTH_QUERY);
  if (keys.length !== 1 || keys[0] !== WEB_AUTH_QUERY || tokens.length !== 1 || !nonemptyString(tokens[0])) {
    blocked("BLOCKED_AUTH");
  }
  const authToken = tokens[0];
  if (authToken !== authToken.trim() || authToken.length > 4_096) {
    blocked("BLOCKED_AUTH");
  }
  const canonical = `http://127.0.0.1:${port}/?${new URLSearchParams([[WEB_AUTH_QUERY, authToken]]).toString()}`;
  if (parsed.href !== canonical) {
    blocked("BLOCKED_NON_LOOPBACK");
  }
  return { authToken, hostname: "127.0.0.1", port };
}

export async function directRpc(target, method, args, { mutation = false, timeoutMs = READ_TIMEOUT_MS } = {}) {
  // Several Node options take effect before user code or create output on exit.
  // T00 blocks them before spawn; this process-side check is defense in depth.
  for (const key of [...PATH_OVERRIDE_KEYS, ...UNSAFE_RUNTIME_ENV_KEYS]) {
    if (hasRawEnvValue(process.env, key)) {
      blocked("BLOCKED_RUNTIME_ENV");
    }
  }
  const body = JSON.stringify({ args, method });
  const bodyBytes = Buffer.byteLength(body, "utf8");
  if (bodyBytes <= 0 || bodyBytes > MAX_RPC_BYTES) {
    blocked("BLOCKED_CONFIG_SHAPE");
  }
  const { request } = await import("node:http");

  return new Promise((resolve, reject) => {
    let settled = false;
    let deadline;
    const fail = (category) => {
      if (settled) return;
      settled = true;
      clearTimeout(deadline);
      reject(mutation
        ? new T02Error("INDETERMINATE_SAVE", { exitCode: EXIT.MUTATION_FAILURE, save: "UNKNOWN" })
        : new T02Error(category));
    };
    const req = request({
      agent: false,
      family: 4,
      headers: {
        accept: "application/json",
        connection: "close",
        "content-length": String(bodyBytes),
        "content-type": "application/json",
        [WEB_AUTH_HEADER]: target.authToken
      },
      hostname: target.hostname,
      method: "POST",
      path: RPC_PATH,
      port: target.port,
      protocol: "http:"
    }, (response) => {
      const chunks = [];
      let bytes = 0;
      const contentType = String(response.headers["content-type"] ?? "").split(";", 1)[0].trim().toLowerCase();
      const contentEncoding = String(response.headers["content-encoding"] ?? "").toLowerCase();
      const contentLengthHeader = String(response.headers["content-length"] ?? "").trim();
      const contentLength = contentLengthHeader ? Number(contentLengthHeader) : undefined;
      if (
        response.statusCode !== 200 ||
        contentType !== "application/json" ||
        (contentEncoding && contentEncoding !== "identity") ||
        (contentLength !== undefined && (!Number.isSafeInteger(contentLength) || contentLength < 0 || contentLength > MAX_RPC_BYTES))
      ) {
        response.destroy();
        fail("RPC_FAILURE");
        return;
      }
      response.on("data", (chunk) => {
        bytes += chunk.length;
        if (bytes > MAX_RPC_BYTES) {
          response.destroy();
          fail("RPC_FAILURE");
          return;
        }
        chunks.push(chunk);
      });
      response.once("error", () => fail("RPC_FAILURE"));
      response.once("end", () => {
        if (settled) return;
        let payload;
        try {
          payload = JSON.parse(Buffer.concat(chunks).toString("utf8"));
        } catch {
          fail("RPC_FAILURE");
          return;
        }
        if (!isPlainObject(payload) || payload.ok !== true || !hasOwn(payload, "value")) {
          fail("RPC_FAILURE");
          return;
        }
        settled = true;
        clearTimeout(deadline);
        resolve(payload.value);
      });
    });
    deadline = setTimeout(() => req.destroy(), timeoutMs);
    deadline.unref();
    req.once("error", () => fail("RPC_FAILURE"));
    req.end(body);
  });
}

function validateAppInfo(value, expectedConfigDir, pathApi, platform) {
  if (!isPlainObject(value)) {
    blocked("BLOCKED_APP_IDENTITY");
  }
  if (value.name !== APP_NAME || value.version !== APP_VERSION || value.platform !== "win32" || value.desktop !== false) {
    blocked("BLOCKED_APP_IDENTITY");
  }
  const expected = normalizePathForComparison(expectedConfigDir, pathApi, platform);
  if (
    normalizePathForComparison(value.configDir, pathApi, platform) !== expected ||
    normalizePathForComparison(value.dataDir, pathApi, platform) !== expected
  ) {
    blocked("BLOCKED_APP_IDENTITY");
  }
}

function validateIdentity(value, state) {
  if (
    !isPlainObject(value) ||
    value.serviceTokenConfigured !== true ||
    value.serviceTokenMatches !== true ||
    !Number.isSafeInteger(value.pid) ||
    value.pid !== state.pid
  ) {
    blocked("BLOCKED_SERVICE_IDENTITY");
  }
}

function validateExternalFlag(value) {
  return value === undefined || value === false;
}

function validatePreGatewayStatus(value) {
  if (
    !isPlainObject(value) ||
    value.state !== "stopped" ||
    !validateExternalFlag(value.gatewayManagedExternally) ||
    !validateExternalFlag(value.coreManagedExternally) ||
    value.pid !== undefined ||
    value.endpoint !== "" ||
    value.coreEndpoint !== "" ||
    value.lastError !== undefined ||
    value.lastStartedAt !== undefined ||
    !Array.isArray(value.networkEndpoints) ||
    value.networkEndpoints.length !== 0
  ) {
    blocked("BLOCKED_GATEWAY_STATE");
  }
}

function isEnabledGlobalProfile(profile) {
  return profile.enabled === true && profile.scope === "global";
}

function activeGlobalProfile(profiles, agent) {
  return profiles.find((profile) => profile.agent === agent && isEnabledGlobalProfile(profile));
}

function synchronizedClaudeLegacy(legacy, profile) {
  if (!profile) return { ...legacy, enabled: false };
  return {
    ...legacy,
    enabled: true,
    fableModel: profile.fableModel ?? legacy.fableModel,
    haikuModel: profile.haikuModel ?? legacy.haikuModel,
    managedCompact: profile.managedCompact ?? legacy.managedCompact,
    model: profile.model,
    opusModel: profile.opusModel ?? legacy.opusModel,
    settingsFile: profile.settingsFile ?? legacy.settingsFile,
    sonnetModel: profile.sonnetModel ?? legacy.sonnetModel,
    smallFastModel: profile.smallFastModel ?? legacy.smallFastModel
  };
}

function synchronizedCodexLegacy(legacy, profile) {
  if (!profile) return { ...legacy, enabled: false };
  return {
    ...legacy,
    cliMiddleware: profile.cliMiddleware ?? legacy.cliMiddleware,
    codexCliPath: profile.codexCliPath ?? legacy.codexCliPath,
    codexHome: profile.codexHome ?? legacy.codexHome,
    configFormat: profile.configFormat ?? legacy.configFormat,
    configFile: profile.configFile ?? legacy.configFile,
    enabled: true,
    managedCompact: profile.managedCompact ?? legacy.managedCompact,
    model: profile.model,
    providerId: profile.providerId ?? legacy.providerId,
    providerName: profile.providerName ?? legacy.providerName,
    showAllSessions: profile.showAllSessions ?? legacy.showAllSessions
  };
}

function synchronizedProfileMirrors(profile) {
  const profileEnabled = profile.enabled !== false && profile.profiles.some((item) => item.enabled === true);
  const claudeProfile = profileEnabled ? activeGlobalProfile(profile.profiles, "claude-code") : undefined;
  const codexProfile = profileEnabled ? activeGlobalProfile(profile.profiles, "codex") : undefined;
  const claudeCode = synchronizedClaudeLegacy(profile.claudeCode, claudeProfile);
  const codex = synchronizedCodexLegacy(profile.codex, codexProfile);
  assertJsonSafe(claudeCode);
  assertJsonSafe(codex);
  return { claudeCode, codex, enabled: profileEnabled };
}

function assertProfileMirrorConsistency(profile) {
  const enabledGlobalByAgent = new Set();
  for (const item of profile.profiles) {
    if (!isEnabledGlobalProfile(item)) continue;
    if (enabledGlobalByAgent.has(item.agent)) blocked("BLOCKED_CONFIG_SHAPE");
    enabledGlobalByAgent.add(item.agent);
  }
  const expected = synchronizedProfileMirrors(profile);
  if (
    profile.enabled !== expected.enabled ||
    canonicalJson(profile.claudeCode) !== canonicalJson(expected.claudeCode) ||
    canonicalJson(profile.codex) !== canonicalJson(expected.codex)
  ) {
    blocked("BLOCKED_CONFIG_SHAPE");
  }
}

function validateRuntimeSurface(config) {
  const { gateway, proxy, mediaTools, toolHub, agent, contextArchive, Router } = config;
  if (
    !isPlainObject(gateway) ||
    gateway.enabled !== true ||
    gateway.host !== "127.0.0.1" ||
    gateway.coreHost !== "127.0.0.1" ||
    !Number.isInteger(gateway.port) || gateway.port <= 0 || gateway.port > 65_535 ||
    !Number.isInteger(gateway.corePort) || gateway.corePort <= 0 || gateway.corePort > 65_535 ||
    gateway.port === gateway.corePort ||
    !isPlainObject(proxy) || proxy.enabled !== false || proxy.systemProxy !== false || proxy.captureNetwork !== false ||
    !isPlainObject(mediaTools) || mediaTools.enabled !== false ||
    !Array.isArray(config.plugins) || config.plugins.length !== 0 ||
    !Array.isArray(config.providerPlugins) || config.providerPlugins.length !== 0 ||
    !isPlainObject(toolHub) || toolHub.enabled !== false || toolHub.browserAutomation !== false ||
    !Array.isArray(toolHub.mcpServers) || toolHub.mcpServers.length !== 0 ||
    !isPlainObject(agent) || !Array.isArray(agent.mcpServers) || agent.mcpServers.length !== 0 ||
    !isPlainObject(contextArchive) || contextArchive.enabled !== false ||
    !Array.isArray(config.virtualModelProfiles) || config.virtualModelProfiles.length !== 0 ||
    !isPlainObject(Router) || !Array.isArray(Router.rules) ||
    Router.rules.some((rule) => !isPlainObject(rule) || (rule.enabled !== false && rule.type === "script"))
  ) {
    blocked("BLOCKED_RUNTIME_SURFACE");
  }
}

function validateProviders(config) {
  if (!Array.isArray(config.Providers) || config.Providers.length === 0 || !nonemptyString(config.preferredProvider)) {
    blocked("BLOCKED_CONFIG_SHAPE");
  }
  let availableModels = 0;
  for (const provider of config.Providers) {
    // Stock loadAppConfig omits enabled for an enabled Provider and preserves
    // only explicit false. Reject a non-canonical true before save/reload.
    if (!isPlainObject(provider) || (provider.enabled !== undefined && provider.enabled !== false)) {
      blocked("BLOCKED_CONFIG_SHAPE");
    }
    if ([provider.api_key, provider.apiKey, provider.apikey].some((value) => value === LOCAL_AGENT_PROVIDER_API_KEY)) {
      blocked("BLOCKED_RUNTIME_SURFACE");
    }
    if (provider.autoFetchModels !== undefined && typeof provider.autoFetchModels !== "boolean") {
      blocked("BLOCKED_PROVIDER_AUTO_REFRESH");
    }
    const enabled = provider.enabled !== false;
    if (enabled && provider.autoFetchModels === true) {
      blocked("BLOCKED_PROVIDER_AUTO_REFRESH");
    }
    if (!Array.isArray(provider.models) || provider.models.some((model) => typeof model !== "string")) {
      blocked("BLOCKED_CONFIG_SHAPE");
    }
    if (matchesNvidiaPresetBaseUrl(provider.api_base_url ?? provider.baseUrl ?? provider.baseurl)) {
      const capabilities = provider.capabilities;
      const capability = Array.isArray(capabilities) && capabilities.length === 1 ? capabilities[0] : undefined;
      const capabilityKeys = isPlainObject(capability) ? Object.keys(capability) : [];
      if (
        !isPlainObject(capability) ||
        capability.type !== "openai_chat_completions" ||
        !nonemptyString(capability.baseUrl) ||
        !["preset", "detected"].includes(capability.source) ||
        (capability.endpoint !== undefined && !nonemptyString(capability.endpoint)) ||
        capabilityKeys.some((key) => !["baseUrl", "endpoint", "source", "type"].includes(key))
      ) {
        blocked("BLOCKED_CONFIG_SHAPE");
      }
    }
    if (enabled && nonemptyString(provider.name)) {
      availableModels += provider.models.filter(nonemptyString).length;
    }
  }
  if (availableModels === 0) {
    blocked("BLOCKED_CONFIG_SHAPE");
  }
}

function matchesNvidiaPresetBaseUrl(value) {
  if (!nonemptyString(value)) return false;
  try {
    const endpoint = new URL("https://integrate.api.nvidia.com/v1");
    const candidate = new URL(/^[a-z][a-z0-9+.-]*:\/\//i.test(value.trim()) ? value.trim() : `https://${value.trim()}`);
    if (candidate.protocol !== endpoint.protocol || candidate.host !== endpoint.host) return false;
    const endpointPath = endpoint.pathname.replace(/\/+$/, "") || "/";
    const candidatePath = candidate.pathname.replace(/\/+$/, "") || "/";
    return endpointPath === "/" || candidatePath === "/" || candidatePath === endpointPath ||
      candidatePath.startsWith(`${endpointPath}/`) || endpointPath.startsWith(`${candidatePath}/`);
  } catch {
    return false;
  }
}

function validateApiKeys(config) {
  if (typeof config.APIKEY !== "string" || !Array.isArray(config.APIKEYS)) {
    blocked("BLOCKED_CONFIG_SHAPE");
  }
  const reusable = nonemptyString(config.APIKEY) || config.APIKEYS.some((item) => isPlainObject(item) && nonemptyString(item.key));
  if (!reusable) {
    blocked("BLOCKED_CONFIG_SHAPE");
  }
}

export function validateAndBuildTarget(config) {
  assertJsonSafe(config);
  if (
    !isPlainObject(config) ||
    !isPlainObject(config.profile) ||
    typeof config.profile.enabled !== "boolean" ||
    !isPlainObject(config.profile.claudeCode) || typeof config.profile.claudeCode.enabled !== "boolean" ||
    !isPlainObject(config.profile.codex) || typeof config.profile.codex.enabled !== "boolean" ||
    hasOwn(config.profile.codex, "remoteFrontendMode") ||
    !Array.isArray(config.profile.profiles) || config.profile.profiles.length === 0 ||
    !isPlainObject(config.observability) ||
    typeof config.observability.requestLogs !== "boolean" ||
    typeof config.observability.agentAnalysis !== "boolean" ||
    !["all", "errors", "none"].includes(config.observability.requestLogBodyCapture)
  ) {
    blocked("BLOCKED_CONFIG_SHAPE");
  }

  if (
    config.observability.requestLogs !== false ||
    config.observability.agentAnalysis !== false ||
    config.observability.requestLogBodyCapture !== "none"
  ) {
    blocked("BLOCKED_RUNTIME_SURFACE");
  }

  const ids = new Set();
  for (const profile of config.profile.profiles) {
    const requiresRemoteFrontendMode = ["codex", "opencode", "kilo", "workbuddy", "zcode"].includes(profile?.agent);
    if (
      !isPlainObject(profile) ||
      !nonemptyString(profile.id) ||
      ids.has(profile.id) ||
      !nonemptyString(profile.agent) ||
      !PROFILE_AGENTS.has(profile.agent) ||
      typeof profile.enabled !== "boolean" ||
      !["global", "ccr", "custom"].includes(profile.scope) ||
      (requiresRemoteFrontendMode && (
        profile.remoteFrontendMode !== "app" ||
        hasOwn(profile, "coreMode") ||
        hasOwn(profile, "frontendMode")
      ))
    ) {
      blocked("BLOCKED_CONFIG_SHAPE");
    }
    ids.add(profile.id);
  }

  validateProviders(config);
  validateApiKeys(config);
  validateRuntimeSurface(config);
  assertProfileMirrorConsistency(config.profile);

  const target = cloneJson(config);
  const allowed = new Set([
    "/profile/claudeCode/enabled",
    "/profile/enabled"
  ]);

  target.profile.profiles.forEach((profile, index) => {
    if (profile.agent === "claude-code" && profile.enabled === true && profile.scope === "global") {
      profile.enabled = false;
      allowed.add(`/profile/profiles/${index}/enabled`);
    }
  });
  const synchronizedTarget = synchronizedProfileMirrors(target.profile);
  target.profile.enabled = synchronizedTarget.enabled;
  target.profile.claudeCode = synchronizedTarget.claudeCode;
  target.profile.codex = synchronizedTarget.codex;

  const diffPaths = collectDiffPaths(config, target);
  if (diffPaths.some((item) => !allowed.has(item))) {
    blocked("UNEXPECTED_CONFIG_DIFF");
  }
  if (canonicalJson(config.Providers) !== canonicalJson(target.Providers)) {
    blocked("UNEXPECTED_CONFIG_DIFF");
  }
  const beforeIds = config.profile.profiles.map((item) => item.id);
  const targetIds = target.profile.profiles.map((item) => item.id);
  if (JSON.stringify(beforeIds) !== JSON.stringify(targetIds)) {
    blocked("UNEXPECTED_CONFIG_DIFF");
  }
  const globalCount = target.profile.profiles.filter((item) => item.agent === "claude-code" && isEnabledGlobalProfile(item)).length;
  if (
    globalCount !== 0 ||
    target.observability.requestLogs !== false ||
    target.observability.agentAnalysis !== false ||
    target.observability.requestLogBodyCapture !== "none" ||
    canonicalJson(target.observability) !== canonicalJson(config.observability)
  ) {
    blocked("UNEXPECTED_CONFIG_DIFF");
  }
  return {
    changed: canonicalJson(config) !== canonicalJson(target),
    globalCount,
    target
  };
}

function defaultProcessAlive(pid) {
  try {
    process.kill(pid, 0);
    return true;
  } catch (error) {
    return error?.code === "EPERM";
  }
}

async function assertPortFree(host, port) {
  const { createServer } = await import("node:net");
  await new Promise((resolve, reject) => {
    const server = createServer();
    let settled = false;
    const finish = (error) => {
      if (settled) return;
      settled = true;
      if (error) reject(error);
      else resolve();
    };
    server.once("error", () => finish(new Error("occupied")));
    server.listen({ exclusive: true, host, port }, () => {
      server.close((error) => finish(error ?? undefined));
    });
  }).catch(() => blocked("BLOCKED_PORT_IN_USE"));
}

function validatePostGatewayStatus(value, config) {
  if (
    !isPlainObject(value) ||
    value.state !== "stopped" ||
    !validateExternalFlag(value.gatewayManagedExternally) ||
    !validateExternalFlag(value.coreManagedExternally) ||
    !Array.isArray(value.networkEndpoints) ||
    value.networkEndpoints.length !== 0 ||
    value.lastError !== undefined ||
    value.lastStartedAt !== undefined
  ) {
    mutationFailure("POSTCONDITION_FAILURE");
  }
  const expectedEndpoint = `http://${config.gateway.host}:${config.gateway.port}`;
  const expectedCoreEndpoint = `http://${config.gateway.coreHost}:${config.gateway.corePort}`;
  if (value.endpoint !== expectedEndpoint || value.coreEndpoint !== expectedCoreEndpoint) {
    mutationFailure("POSTCONDITION_FAILURE");
  }
  if (value.pid !== undefined) {
    mutationFailure("POSTCONDITION_FAILURE");
  }
  return "STOP";
}

function successPreflight(changed) {
  return `T02|RESULT=PASS|SERVICE=P|GW_PRE=STOP|RPC=P|APPLY=N|CHANGE=${changed ? "Y" : "N"}|TARGET_GLOBAL=0|TARGET_LOGS=OFF|TARGET_ANALYSIS=OFF|TARGET_BODY=NONE|AUTOFETCH=OFF|RAW=NO`;
}

function successSkip() {
  return "T02|RESULT=PASS|SERVICE=P|GW_PRE=STOP|RPC=P|APPLY=SKIP|CHANGE=N|GLOBAL=0|LOGS=OFF|ANALYSIS=OFF|BODY=NONE|PROVIDER=SAME|ONBOARDING=SAME|AUTOFETCH=OFF|RAW=NO";
}

function successApply(gatewayPost) {
  return `T02|RESULT=PASS|SERVICE=P|GW_PRE=STOP|GW_POST=${gatewayPost}|RPC=P|APPLY=P|CHANGE=Y|GLOBAL=0|LOGS=OFF|ANALYSIS=OFF|BODY=NONE|PROVIDER=SAME|ONBOARDING=SAME|AUTOFETCH=OFF|RAW=NO`;
}

function defaultPathApi(platform) {
  return platform === "win32" ? path.win32 : path;
}

export async function runSafeConfigSave({
  apply = false,
  env = process.env,
  isProcessAlive = defaultProcessAlive,
  pathApi,
  platform = process.platform,
  portChecker = assertPortFree,
  rpc = directRpc
} = {}) {
  const effectivePathApi = pathApi ?? defaultPathApi(platform);
  const runtimePaths = resolveRuntimePaths({ env, pathApi: effectivePathApi, platform });
  const initialState = await readServiceState(runtimePaths.serviceFile, (pid) => isProcessAlive(pid));
  await pathAbsent(runtimePaths.backupFile, "BLOCKED_STALE_BACKUP");
  const target = parseManagementTarget(initialState.value.url);

  const call = (method, args = [], options = {}) => rpc(target, method, args, options);
  const appInfo = await call("getAppInfo", []);
  validateAppInfo(appInfo, runtimePaths.configDir, effectivePathApi, platform);
  validateIdentity(await call("getServiceIdentity", [initialState.value.serviceToken]), initialState.value);
  validatePreGatewayStatus(await call("getGatewayStatus", []));
  const onboarding = await call("getOnboardingFinished", []);
  if (typeof onboarding !== "boolean") blocked("BLOCKED_CONFIG_SHAPE");
  const initialConfig = await call("getConfig", []);
  const initialPlan = validateAndBuildTarget(initialConfig);

  if (!apply) {
    return { exitCode: EXIT.OK, line: successPreflight(initialPlan.changed) };
  }
  if (!initialPlan.changed) {
    return { exitCode: EXIT.OK, line: successSkip() };
  }

  await portChecker(initialPlan.target.gateway.host, initialPlan.target.gateway.port);
  await portChecker(initialPlan.target.gateway.coreHost, initialPlan.target.gateway.corePort);

  const currentState = await readServiceState(runtimePaths.serviceFile, (pid) => isProcessAlive(pid));
  if (currentState.raw !== initialState.raw) blocked("BLOCKED_CONCURRENT_CHANGE");
  await pathAbsent(runtimePaths.backupFile, "BLOCKED_STALE_BACKUP");
  validateIdentity(await call("getServiceIdentity", [initialState.value.serviceToken]), initialState.value);
  validatePreGatewayStatus(await call("getGatewayStatus", []));
  const onboardingBeforeSave = await call("getOnboardingFinished", []);
  if (onboardingBeforeSave !== onboarding) blocked("BLOCKED_CONCURRENT_CHANGE");
  const configBeforeSave = await call("getConfig", []);
  if (canonicalJson(configBeforeSave) !== canonicalJson(initialConfig)) blocked("BLOCKED_CONCURRENT_CHANGE");
  const finalPlan = validateAndBuildTarget(configBeforeSave);
  if (canonicalJson(finalPlan.target) !== canonicalJson(initialPlan.target)) blocked("BLOCKED_CONCURRENT_CHANGE");

  await pathAbsent(runtimePaths.backupFile, "BLOCKED_STALE_BACKUP");

  let saveResult;
  try {
    saveResult = await call("saveConfig", [finalPlan.target, { applyProfile: false }], {
      mutation: true,
      timeoutMs: SAVE_TIMEOUT_MS
    });
  } catch (error) {
    if (error instanceof T02Error) throw error;
    mutationFailure("INDETERMINATE_SAVE", "UNKNOWN");
  }

  try {
    if (canonicalJson(saveResult) !== canonicalJson(finalPlan.target)) {
      mutationFailure("POSTCONDITION_FAILURE");
    }
    const postConfig = await call("getConfig", []);
    if (canonicalJson(postConfig) !== canonicalJson(finalPlan.target)) {
      mutationFailure("POSTCONDITION_FAILURE");
    }
    const onboardingAfter = await call("getOnboardingFinished", []);
    if (onboardingAfter !== onboarding) {
      mutationFailure("POSTCONDITION_FAILURE");
    }
    const gatewayPost = validatePostGatewayStatus(await call("getGatewayStatus", []), finalPlan.target);
    return { exitCode: EXIT.OK, line: successApply(gatewayPost) };
  } catch (error) {
    if (error instanceof T02Error && error.exitCode === EXIT.MUTATION_FAILURE) throw error;
    mutationFailure("POSTCONDITION_FAILURE");
  }
}

export function parseCliArgs(args) {
  if (args.length === 0) return { apply: false };
  if (args.length === 1 && args[0] === "--apply") return { apply: true };
  throw new T02Error("INVALID_ARGUMENTS", { exitCode: EXIT.INVALID_ARGUMENTS, save: "N" });
}

export function formatFailure(error) {
  const safe = error instanceof T02Error
    ? error
    : new T02Error("RPC_FAILURE");
  const result = safe.exitCode === EXIT.BLOCKED || safe.exitCode === EXIT.INVALID_ARGUMENTS ? "BLOCKED" : "FAIL";
  return {
    exitCode: safe.exitCode,
    line: `T02|RESULT=${result}|CATEGORY=${safe.category}|SAVE=${safe.save}|RAW=NO`
  };
}

export async function executeCli(args = process.argv.slice(2), options = {}) {
  try {
    const parsed = parseCliArgs(args);
    return await runSafeConfigSave({ ...options, apply: parsed.apply });
  } catch (error) {
    return formatFailure(error);
  }
}

const isMain = process.argv[1] && path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url));
if (isMain) {
  const result = await executeCli();
  process.stdout.write(`${result.line}\n`);
  process.exitCode = result.exitCode;
}
