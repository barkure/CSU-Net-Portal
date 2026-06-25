"use strict";

const { describe, it, before, after } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { rotateLogIfNeeded } = require("../index.js");

describe("rotateLogIfNeeded", () => {
  let tmpDir;
  let logFile;

  before(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "csu-log-test-"));
    logFile = path.join(tmpDir, "test.log");
  });

  after(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it("文件未超阈值时不轮转", () => {
    fs.writeFileSync(logFile, "small content");
    rotateLogIfNeeded(logFile, 1024 * 1024);
    assert.ok(fs.existsSync(logFile));
    assert.ok(!fs.existsSync(`${logFile}.1`));
    assert.equal(fs.readFileSync(logFile, "utf8"), "small content");
  });

  it("文件超过阈值时轮转为 .1", () => {
    const bigContent = "x".repeat(100);
    fs.writeFileSync(logFile, bigContent);
    rotateLogIfNeeded(logFile, 50);
    assert.ok(fs.existsSync(`${logFile}.1`));
    assert.equal(fs.readFileSync(`${logFile}.1`, "utf8"), bigContent);
  });

  it("轮转后原日志文件为空", () => {
    const bigContent = "x".repeat(100);
    fs.writeFileSync(logFile, bigContent);
    rotateLogIfNeeded(logFile, 50);
    assert.equal(fs.readFileSync(logFile, "utf8"), "");
  });

  it("已存在 .1 文件时轮转会覆盖它", () => {
    fs.writeFileSync(`${logFile}.1`, "old rotated content");
    const bigContent = "y".repeat(100);
    fs.writeFileSync(logFile, bigContent);
    rotateLogIfNeeded(logFile, 50);
    assert.equal(fs.readFileSync(`${logFile}.1`, "utf8"), bigContent);
  });

  it("日志文件不存在时不抛出异常", () => {
    const nonExistent = path.join(tmpDir, "nonexistent.log");
    assert.doesNotThrow(() => rotateLogIfNeeded(nonExistent, 50));
  });
});
