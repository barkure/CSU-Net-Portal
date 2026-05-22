"use strict";

const fs = require("fs");
const path = require("path");
const readline = require("readline");

process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0";

const envFile = process.env.ENV_FILE || path.join(__dirname, ".env");
const dataDir = process.env.DATA_DIR || path.join(__dirname, "log");
const logFile = process.env.LOG_FILE || path.join(dataDir, "csu-autoauth.log");
const logToStdout = process.env.LOG_TO_STDOUT !== "0";

const defaultConfig = {
  USERNAME: "",
  PASSWORD: "",
  TYPE: "1",
  INTERVAL: 10
};

const config = loadConfig();

const netSuffixMap = {
  "1": "cmccn",
  "2": "unicomn",
  "3": "telecomn",
  "4": ""
};

const color = {
  reset: "\x1b[0m",
  dim: "\x1b[2m",
  red: "\x1b[31m",
  green: "\x1b[32m",
  yellow: "\x1b[33m",
  blue: "\x1b[34m",
  cyan: "\x1b[36m"
};

let lastHeartbeatWidth = 0;

function timestamp() {
  const now = new Date();
  const pad = (value) => String(value).padStart(2, "0");
  return [
    now.getFullYear(),
    pad(now.getMonth() + 1),
    pad(now.getDate())
  ].join("-") + " " + [pad(now.getHours()), pad(now.getMinutes()), pad(now.getSeconds())].join(":");
}

function initLogFile() {
  fs.mkdirSync(dataDir, { recursive: true });
  if (!fs.existsSync(logFile)) {
    fs.writeFileSync(logFile, "");
  }
}

function log(message) {
  const currentTimestamp = timestamp();
  const line = `[${currentTimestamp}] ${message}`;
  if (logToStdout) {
    clearHeartbeat();
    console.log(styleLogLine(currentTimestamp, message));
  }
  fs.appendFileSync(logFile, `${line}\n`, "utf8");
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

function clearHeartbeat() {
  if (!logToStdout || !process.stdout.isTTY || lastHeartbeatWidth === 0) {
    return;
  }

  process.stdout.write(`\r${" ".repeat(lastHeartbeatWidth)}\r`);
  lastHeartbeatWidth = 0;
}

function showHeartbeat(status) {
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
    `${color.dim}(next check in ${config.INTERVAL}s)${color.reset}`;

  lastHeartbeatWidth = line.replace(/\x1b\[[0-9;]*m/g, "").length;
  process.stdout.write(`\r${line}`);
}

function validateConfig() {
  if (!config.USERNAME || !config.PASSWORD) {
    throw new Error(`Missing USERNAME or PASSWORD in ${envFile}`);
  }

  if (!Number.isInteger(config.INTERVAL) || config.INTERVAL <= 0) {
    throw new Error(`INTERVAL must be a positive integer in ${envFile}`);
  }
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

function normalizeConfig(rawConfig) {
  const interval = Number.parseInt(String(rawConfig.INTERVAL ?? defaultConfig.INTERVAL), 10);

  return {
    USERNAME: String(rawConfig.USERNAME ?? "").trim(),
    PASSWORD: String(rawConfig.PASSWORD ?? ""),
    TYPE: String(rawConfig.TYPE ?? defaultConfig.TYPE).trim() || defaultConfig.TYPE,
    INTERVAL: interval
  };
}

function loadConfig() {
  const fileConfig = parseEnvFile(envFile);
  return normalizeConfig({
    ...defaultConfig,
    ...fileConfig,
    USERNAME: process.env.CSU_USERNAME ?? fileConfig.USERNAME ?? defaultConfig.USERNAME,
    PASSWORD: process.env.CSU_PASSWORD ?? fileConfig.PASSWORD ?? defaultConfig.PASSWORD,
    TYPE: process.env.CSU_TYPE ?? fileConfig.TYPE ?? defaultConfig.TYPE,
    INTERVAL: process.env.CSU_INTERVAL ?? fileConfig.INTERVAL ?? defaultConfig.INTERVAL
  });
}

function escapeEnvValue(value) {
  return `"${String(value).replace(/\\/g, "\\\\").replace(/"/g, "\\\"")}"`;
}

function saveConfig() {
  fs.mkdirSync(path.dirname(envFile), { recursive: true });
  const content = [
    `USERNAME=${escapeEnvValue(config.USERNAME)}`,
    `PASSWORD=${escapeEnvValue(config.PASSWORD)}`,
    `TYPE=${escapeEnvValue(config.TYPE)}`,
    `INTERVAL=${config.INTERVAL}`
  ].join("\n") + "\n";

  fs.writeFileSync(envFile, content, "utf8");
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

async function ensureConfig() {
  const envExists = fs.existsSync(envFile);
  const needsSetup =
    !config.USERNAME ||
    !config.PASSWORD ||
    !Object.prototype.hasOwnProperty.call(netSuffixMap, config.TYPE) ||
    !Number.isInteger(config.INTERVAL) ||
    config.INTERVAL <= 0;

  if (!needsSetup) {
    return;
  }

  console.log(`Configuration not found or incomplete: ${envFile}`);
  console.log("First-time setup");

  if (!config.USERNAME) {
    config.USERNAME = await ask("Student number: ");
  }

  if (!config.PASSWORD) {
    config.PASSWORD = await ask("Password: ", { silent: true });
  }

  if (!envExists || !Object.prototype.hasOwnProperty.call(netSuffixMap, config.TYPE)) {
    config.TYPE = "";
  }

  while (!Object.prototype.hasOwnProperty.call(netSuffixMap, config.TYPE)) {
    config.TYPE = await ask("Network type (1=CMCC, 2=Unicom, 3=Telecom, 4=Campus) [Default 1]: ");
    if (!config.TYPE) {
      config.TYPE = defaultConfig.TYPE;
    }
  }

  if (!envExists) {
    config.INTERVAL = Number.NaN;
  }

  while (!Number.isInteger(config.INTERVAL) || config.INTERVAL <= 0) {
    const interval = await ask("Check interval in seconds [Default 10]: ");
    config.INTERVAL = Number.parseInt(interval || String(defaultConfig.INTERVAL), 10);
  }

  saveConfig();
  console.log(`Saved configuration to ${envFile}`);
}

function getUserAccount() {
  const suffix = netSuffixMap[String(config.TYPE)] ?? "";
  return suffix ? `${config.USERNAME}@${suffix}` : config.USERNAME;
}

async function testOnline() {
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

async function login() {
  const userAccount = getUserAccount();
  const url = new URL("https://10.1.1.1:802/eportal/portal/login");
  url.searchParams.set("user_account", userAccount);
  url.searchParams.set("user_password", config.PASSWORD);

  log(`Authenticating as: ${userAccount}`);

  try {
    const response = await fetch(url, {
      method: "GET",
      signal: AbortSignal.timeout(5000)
    });
    const text = await response.text();
    log(`Login response: ${text}`);
  } catch (error) {
    log(`Login response: ${error.message}`);
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function main() {
  await ensureConfig();
  validateConfig();
  initLogFile();
  log(`init CSU Network Portal`);
  log(`Start monitoring network status, interval ${config.INTERVAL}s`);

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
      await login();
    }

    showHeartbeat(lastStatus);
    await sleep(config.INTERVAL * 1000);
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
