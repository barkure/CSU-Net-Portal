"use strict";

const { describe, it, beforeEach, afterEach } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { createState } = require("../index.js");

describe("createState", () => {
  let originalArgv;
  let originalEnv;
  let tmpDir;

  beforeEach(() => {
    originalArgv = process.argv;
    originalEnv = { ...process.env };
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "csu-config-test-"));
    delete process.env.CSU_USERNAME;
    delete process.env.CSU_PASSWORD;
    delete process.env.CSU_TYPE;
    delete process.env.CSU_INTERVAL;
  });

  afterEach(() => {
    process.argv = originalArgv;
    process.env = originalEnv;
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it("loads saved credentials when no CLI or env override is provided", () => {
    const configFile = path.join(tmpDir, "config.env");
    const logFile = path.join(tmpDir, "csu-autoauth.log");
    fs.writeFileSync(
      configFile,
      [
        'USERNAME="saved_user"',
        'PASSWORD="saved_password"',
        "TYPE=2",
        "INTERVAL=30"
      ].join("\n") + "\n"
    );

    process.argv = [
      "node",
      "index.js",
      "--once",
      "--config",
      configFile,
      "--log-file",
      logFile
    ];

    const state = createState();

    assert.equal(state.config.USERNAME, "saved_user");
    assert.equal(state.config.PASSWORD, "saved_password");
    assert.equal(state.config.TYPE, "2");
    assert.equal(state.config.INTERVAL, 30);
    assert.equal(state.once, true);
  });

  it("lets CLI values override saved config", () => {
    const configFile = path.join(tmpDir, "config.env");
    fs.writeFileSync(
      configFile,
      [
        'USERNAME="saved_user"',
        'PASSWORD="saved_password"',
        "TYPE=2",
        "INTERVAL=30"
      ].join("\n") + "\n"
    );

    process.argv = [
      "node",
      "index.js",
      "--config",
      configFile,
      "--username",
      "cli_user",
      "--password",
      "cli_password",
      "--type",
      "telecom",
      "--interval",
      "5"
    ];

    const state = createState();

    assert.equal(state.config.USERNAME, "cli_user");
    assert.equal(state.config.PASSWORD, "cli_password");
    assert.equal(state.config.TYPE, "3");
    assert.equal(state.config.INTERVAL, 5);
  });
});
