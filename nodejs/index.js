#!/usr/bin/env node
"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");
const readline = require("readline");
const { spawnSync } = require("child_process");

process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0";

const color = {
  reset: "\x1b[0m",
  dim: "\x1b[2m",
  red: "\x1b[31m",
  green: "\x1b[32m",
  yellow: "\x1b[33m",
  blue: "\x1b[34m",
  cyan: "\x1b[36m"
};

const defaultConfig = {
  USERNAME: "",
  PASSWORD: "",
  TYPE: "",
  INTERVAL: 10
};

const networkAliases = new Map([
  ["1", "1"],
  ["cmcc", "1"],
  ["cmccn", "1"],
  ["mobile", "1"],
  ["2", "2"],
  ["unicom", "2"],
  ["unicomn", "2"],
  ["3", "3"],
  ["telecom", "3"],
  ["telecomn", "3"],
  ["4", "4"],
  ["campus", "4"],
  ["campusnet", "4"],
  ["direct", "4"]
]);

const netSuffixMap = {
  1: "cmccn",
  2: "unicomn",
  3: "telecomn",
  4: ""
};

let lastHeartbeatWidth = 0;

function getDefaultPaths() {
  if (process.platform === "win32") {
    const configRoot = process.env.APPDATA || path.join(os.homedir(), "AppData", "Roaming");
    const dataRoot = process.env.LOCALAPPDATA || configRoot;
    return {
      configFile: path.join(configRoot, "csu-autoauth", "config.env"),
      dataDir: path.join(dataRoot, "csu-autoauth"),
      logFile: path.join(dataRoot, "csu-autoauth", "csu-autoauth.log")
    };
  }

  const configRoot = process.env.XDG_CONFIG_HOME || path.join(os.homedir(), ".config");
  const dataRoot = process.env.XDG_DATA_HOME || path.join(os.homedir(), ".local", "share");
  return {
    configFile: path.join(configRoot, "csu-autoauth", "config.env"),
    dataDir: path.join(dataRoot, "csu-autoauth"),
    logFile: path.join(dataRoot, "csu-autoauth", "csu-autoauth.log")
  };
}

function printHelp() {
  console.log(`csu-autoauth

Usage:
  csu-autoauth
  csu-autoauth --username <value> --password <value> --type <value> [--interval <seconds>]
  csu-autoauth -u <value> -p <value> -t <value> [-i <seconds>]

Options:
  -u, --username <value>   Student number
  -p, --password <value>   Password
  -t, --type <value>       1/2/3/4 or cmcc/unicom/telecom/campus
  -i, --interval <value>   Check interval in seconds, default 10
  -h, --help               Show this help
  --config <path>          Custom config file path
  --log-file <path>        Custom log file path
  --no-save                Do not persist config changes
  --reset                  Clear saved config and run setup again
`);
}

function parseArgs(argv) {
  const parsed = {
    USERNAME: undefined,
    PASSWORD: undefined,
    TYPE: undefined,
    INTERVAL: undefined,
    configFile: undefined,
    logFile: undefined,
    noSave: false,
    reset: false,
    help: false
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];

    if (arg === "--help" || arg === "-h") {
      parsed.help = true;
      continue;
    }

    if (arg === "--no-save") {
      parsed.noSave = true;
      continue;
    }

    if (arg === "--reset") {
      parsed.reset = true;
      continue;
    }

    const next = argv[index + 1];
    if (next === undefined) {
      throw new Error(`Missing value for ${arg}`);
    }

    switch (arg) {
      case "-u":
      case "--username":
        parsed.USERNAME = next;
        break;
      case "-p":
      case "--password":
        parsed.PASSWORD = next;
        break;
      case "-t":
      case "--type":
        parsed.TYPE = next;
        break;
      case "-i":
      case "--interval":
        parsed.INTERVAL = next;
        break;
      case "--config":
        parsed.configFile = next;
        break;
      case "--log-file":
        parsed.logFile = next;
        break;
      default:
        throw new Error(`Unknown argument: ${arg}`);
    }

    index += 1;
  }

  return parsed;
}

function timestamp() {
  const now = new Date();
  const pad = (value) => String(value).padStart(2, "0");
  return [
    now.getFullYear(),
    pad(now.getMonth() + 1),
    pad(now.getDate())
  ].join("-") + " " + [pad(now.getHours()), pad(now.getMinutes()), pad(now.getSeconds())].join(":");
}

function stripAnsi(text) {
  return text.replace(/\x1b\[[0-9;]*m/g, "");
}

function styleLogLine(currentTimestamp, message) {
  const styledTimestamp = `${color.dim}[${currentTimestamp}]${color.reset}`;

  if (message.startsWith("Start monitoring")) {
    return `${styledTimestamp} ${color.cyan}${message}${color.reset}`;
  }

  if (message === "Network up") {
    return `${styledTimestamp} ${color.green}${message}${color.reset}`;
  }

  if (message === "Network down") {
    return `${styledTimestamp} ${color.red}${message}${color.reset}`;
  }

  if (message === "Triggering authentication...") {
    return `${styledTimestamp} ${color.yellow}${message}${color.reset}`;
  }

  if (message.startsWith("Authenticating as:")) {
    return `${styledTimestamp} ${color.blue}${message}${color.reset}`;
  }

  if (message.startsWith("Login response:")) {
    return `${styledTimestamp} ${color.cyan}${message}${color.reset}`;
  }

  return `${styledTimestamp} ${message}`;
}

function clearHeartbeat(logToStdout) {
  if (!logToStdout || !process.stdout.isTTY || lastHeartbeatWidth === 0) {
    return;
  }

  process.stdout.write(`\r${" ".repeat(lastHeartbeatWidth)}\r`);
  lastHeartbeatWidth = 0;
}

function showHeartbeat(status, interval, logToStdout) {
  if (!logToStdout || !process.stdout.isTTY) {
    return;
  }

  const currentTimestamp = timestamp();
  const statusColor =
    status === "up" ? color.green : status === "down" ? color.red : color.yellow;
  const statusText = status === "up" ? "Online" : status === "down" ? "Offline" : "Checking";
  const line =
    `${color.dim}[${currentTimestamp}]${color.reset} ` +
    `${statusColor}${statusText}${color.reset} ` +
    `${color.dim}(next check in ${interval}s)${color.reset}`;

  lastHeartbeatWidth = stripAnsi(line).length;
  process.stdout.write(`\r${line}`);
}

function parseEnvFile(filePath) {
  if (!fs.existsSync(filePath)) {
    return {};
  }

  const content = fs.readFileSync(filePath, "utf8");
  const result = {};

  for (const rawLine of content.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) {
      continue;
    }

    const separatorIndex = line.indexOf("=");
    if (separatorIndex === -1) {
      continue;
    }

    const key = line.slice(0, separatorIndex).trim();
    let value = line.slice(separatorIndex + 1).trim();

    if (
      (value.startsWith("\"") && value.endsWith("\"")) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }

    result[key] = value;
  }

  return result;
}

function escapeEnvValue(value) {
  return `"${String(value).replace(/\\/g, "\\\\").replace(/"/g, "\\\"")}"`;
}

function normalizeType(value) {
  if (value === undefined || value === null || value === "") {
    return "";
  }

  const normalized = networkAliases.get(String(value).trim().toLowerCase());
  return normalized || "";
}

function normalizeInterval(value) {
  if (value === undefined || value === null || value === "") {
    return Number.NaN;
  }

  return Number.parseInt(String(value), 10);
}

function normalizeConfig(rawConfig) {
  return {
    USERNAME: String(rawConfig.USERNAME ?? "").trim(),
    PASSWORD: String(rawConfig.PASSWORD ?? ""),
    TYPE: normalizeType(rawConfig.TYPE),
    INTERVAL: normalizeInterval(rawConfig.INTERVAL)
  };
}

function validateConfig(config, configFile) {
  if (!config.USERNAME || !config.PASSWORD) {
    throw new Error(`Missing USERNAME or PASSWORD in ${configFile}`);
  }

  if (!Object.prototype.hasOwnProperty.call(netSuffixMap, config.TYPE)) {
    throw new Error(`TYPE must be one of 1, 2, 3, 4 in ${configFile}`);
  }

  if (!Number.isInteger(config.INTERVAL) || config.INTERVAL <= 0) {
    throw new Error(`INTERVAL must be a positive integer in ${configFile}`);
  }
}

function saveConfig(configFile, config) {
  fs.mkdirSync(path.dirname(configFile), { recursive: true });
  const content = [
    `USERNAME=${escapeEnvValue(config.USERNAME)}`,
    `PASSWORD=${escapeEnvValue(config.PASSWORD)}`,
    `TYPE=${config.TYPE}`,
    `INTERVAL=${config.INTERVAL}`
  ].join("\n") + "\n";

  fs.writeFileSync(configFile, content, "utf8");
}

function clearSavedConfig(configFile) {
  if (fs.existsSync(configFile)) {
    fs.rmSync(configFile, { force: true });
  }
}

function ask(question, options = {}) {
  const { silent = false } = options;

  return new Promise((resolve) => {
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });

    if (silent) {
      rl.question(question, (answer) => {
        rl.close();
        console.log();
        resolve(answer.trim());
      });

      rl._writeToOutput = function writeToOutput(text) {
        if (rl.stdoutMuted) {
          rl.output.write("*");
          return;
        }
        rl.output.write(text);
      };
      rl.stdoutMuted = true;
      return;
    }

    rl.question(question, (answer) => {
      rl.close();
      resolve(answer.trim());
    });
  });
}

async function ensureConfig(state) {
  const missingRequired =
    !state.config.USERNAME ||
    !state.config.PASSWORD ||
    !Object.prototype.hasOwnProperty.call(netSuffixMap, state.config.TYPE) ||
    !Number.isInteger(state.config.INTERVAL) ||
    state.config.INTERVAL <= 0;

  if (!missingRequired) {
    return;
  }

  if (!process.stdin.isTTY || !process.stdout.isTTY) {
    throw new Error("Missing required config. Run with --username --password --type, or use an interactive terminal.");
  }

  console.log(`Configuration not found or incomplete: ${state.configFile}`);
  console.log("First-time setup");

  if (!state.config.USERNAME) {
    state.config.USERNAME = await ask("Student number: ");
  }

  if (!state.config.PASSWORD) {
    state.config.PASSWORD = await ask("Password: ", { silent: true });
  }

  while (!Object.prototype.hasOwnProperty.call(netSuffixMap, state.config.TYPE)) {
    const type = await ask("Network type (1=CMCC, 2=Unicom, 3=Telecom, 4=Campus) [Default 1]: ");
    state.config.TYPE = normalizeType(type || "1");
  }

  while (!Number.isInteger(state.config.INTERVAL) || state.config.INTERVAL <= 0) {
    const interval = await ask("Check interval in seconds [Default 10]: ");
    state.config.INTERVAL = normalizeInterval(interval || String(defaultConfig.INTERVAL));
  }

  if (!state.noSave) {
    saveConfig(state.configFile, state.config);
    console.log(`Saved configuration to ${state.configFile}`);
  }
}

function createLogger(state) {
  fs.mkdirSync(path.dirname(state.logFile), { recursive: true });
  if (!fs.existsSync(state.logFile)) {
    fs.writeFileSync(state.logFile, "");
  }

  return function log(message) {
    const currentTimestamp = timestamp();
    const line = `[${currentTimestamp}] ${message}`;
    if (state.logToStdout) {
      clearHeartbeat(state.logToStdout);
      console.log(styleLogLine(currentTimestamp, message));
    }
    rotateLogIfNeeded(state.logFile);
    fs.appendFileSync(state.logFile, `${line}\n`, "utf8");
  };
}

function getUserAccount(config) {
  const suffix = netSuffixMap[config.TYPE] ?? "";
  return suffix ? `${config.USERNAME}@${suffix}` : config.USERNAME;
}

function parseLoginResponse(text) {
  if (!text) {
    return { success: false, message: "" };
  }
  try {
    const data = JSON.parse(text);
    if (data.result === 1 || data.result === "1") {
      return { success: true, message: data.msg || "Login successful" };
    }
    return { success: false, message: data.msg || text };
  } catch {
    return { success: false, message: text };
  }
}

const DEFAULT_MAX_LOG_SIZE = 5 * 1024 * 1024;

function rotateLogIfNeeded(logFile, maxSize = DEFAULT_MAX_LOG_SIZE) {
  try {
    const stat = fs.statSync(logFile);
    if (stat.size >= maxSize) {
      fs.renameSync(logFile, `${logFile}.1`);
      fs.writeFileSync(logFile, "");
    }
  } catch {
    // file may not exist yet
  }
}

function runCurl(args) {
  const command = process.platform === "win32" ? "curl.exe" : "curl";
  const result = spawnSync(command, args, {
    encoding: "utf8"
  });

  if (result.error) {
    return {
      ok: false,
      stdout: "",
      stderr: result.error.message
    };
  }

  return {
    ok: result.status === 0,
    stdout: result.stdout || "",
    stderr: result.stderr || ""
  };
}

async function testOnline() {
  const curlResult = runCurl([
    "-fsS",
    "--max-time",
    "5",
    "http://captive.apple.com/hotspot-detect.html"
  ]);

  if (curlResult.ok) {
    return curlResult.stdout.includes("Success");
  }

  try {
    const response = await fetch("http://captive.apple.com/hotspot-detect.html", {
      method: "GET",
      signal: AbortSignal.timeout(5000)
    });

    if (!response.ok) {
      return false;
    }

    const text = await response.text();
    return text.includes("Success");
  } catch {
    return false;
  }
}

async function login(config, log) {
  const userAccount = getUserAccount(config);
  const loginUrl = "https://10.1.1.1:802/eportal/portal/login";

  log(`Authenticating as: ${userAccount}`);

  const curlResult = runCurl([
    "-k",
    "-fsS",
    "-G",
    loginUrl,
    "--data-urlencode",
    `user_account=${userAccount}`,
    "--data-urlencode",
    `user_password=${config.PASSWORD}`
  ]);

  if (curlResult.ok) {
    const parsed = parseLoginResponse(curlResult.stdout.trim());
    log(parsed.success ? `Login successful: ${parsed.message}` : `Login failed: ${parsed.message}`);
    return;
  }

  if (curlResult.stdout || curlResult.stderr) {
    const curlMessage = `${curlResult.stdout}${curlResult.stderr}`.trim();
    if (curlMessage) {
      const parsed = parseLoginResponse(curlMessage);
      log(parsed.success ? `Login successful: ${parsed.message}` : `Login failed: ${parsed.message}`);
      return;
    }
  }

  try {
    const url = new URL(loginUrl);
    url.searchParams.set("user_account", userAccount);
    url.searchParams.set("user_password", config.PASSWORD);
    const response = await fetch(url, {
      method: "GET",
      signal: AbortSignal.timeout(5000)
    });
    const text = await response.text();
    const parsed = parseLoginResponse(text);
    log(parsed.success ? `Login successful: ${parsed.message}` : `Login failed: ${parsed.message}`);
  } catch (error) {
    log(`Login failed: ${error.message}`);
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function createState() {
  const args = parseArgs(process.argv.slice(2));
  const defaults = getDefaultPaths();
  const configFile = path.resolve(args.configFile || process.env.CONFIG_FILE || defaults.configFile);
  const dataDir = path.resolve(process.env.DATA_DIR || defaults.dataDir);
  const logFile = path.resolve(args.logFile || process.env.LOG_FILE || path.join(dataDir, "csu-autoauth.log"));
  const fileConfig = parseEnvFile(configFile);
  const overrideConfig = {
    USERNAME: args.USERNAME ?? process.env.CSU_USERNAME ?? defaultConfig.USERNAME,
    PASSWORD: args.PASSWORD ?? process.env.CSU_PASSWORD ?? defaultConfig.PASSWORD,
    TYPE: args.TYPE ?? process.env.CSU_TYPE ?? defaultConfig.TYPE,
    INTERVAL: args.INTERVAL ?? process.env.CSU_INTERVAL ?? defaultConfig.INTERVAL
  };
  const config = normalizeConfig({
    ...defaultConfig,
    ...fileConfig,
    USERNAME: overrideConfig.USERNAME ?? fileConfig.USERNAME ?? defaultConfig.USERNAME,
    PASSWORD: overrideConfig.PASSWORD ?? fileConfig.PASSWORD ?? defaultConfig.PASSWORD,
    TYPE: overrideConfig.TYPE ?? fileConfig.TYPE ?? defaultConfig.TYPE,
    INTERVAL: overrideConfig.INTERVAL ?? fileConfig.INTERVAL ?? defaultConfig.INTERVAL
  });

  return {
    config,
    overrideConfig,
    configFile,
    logFile,
    logToStdout: process.env.LOG_TO_STDOUT !== "0",
    noSave: args.noSave,
    reset: args.reset,
    help: args.help
  };
}

async function main() {
  const state = createState();
  if (state.help) {
    printHelp();
    return;
  }

  if (state.reset) {
    clearSavedConfig(state.configFile);
    state.config = normalizeConfig({
      ...defaultConfig,
      ...state.overrideConfig
    });
  }

  await ensureConfig(state);

  if (!state.noSave) {
    saveConfig(state.configFile, state.config);
  }

  validateConfig(state.config, state.configFile);
  const log = createLogger(state);
  log("init CSU Network Portal");
  log(`Start monitoring network status, interval ${state.config.INTERVAL}s`);

  let lastStatus = "";

  while (true) {
    if (await testOnline()) {
      const currentStatus = "up";
      if (lastStatus !== currentStatus) {
        log("Network up");
        lastStatus = currentStatus;
      }
    } else {
      const currentStatus = "down";
      if (lastStatus !== currentStatus) {
        log("Network down");
        lastStatus = currentStatus;
      }
      log("Triggering authentication...");
      await login(state.config, log);
    }

    showHeartbeat(lastStatus, state.config.INTERVAL, state.logToStdout);
    await sleep(state.config.INTERVAL * 1000);
  }
}

async function run() {
  try {
    await main();
  } catch (error) {
    console.error(error.message);
    process.exit(1);
  }
}

if (require.main === module) {
  run();
}

module.exports = {
  main,
  run,
  parseLoginResponse,
  rotateLogIfNeeded
};
