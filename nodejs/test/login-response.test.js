"use strict";

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const { parseLoginResponse } = require("../index.js");

describe("parseLoginResponse", () => {
  it("result=1 时报告成功", () => {
    const r = parseLoginResponse('{"result":1,"msg":"认证成功"}');
    assert.equal(r.success, true);
  });

  it("result=1 时消息包含服务端 msg 字段", () => {
    const r = parseLoginResponse('{"result":1,"msg":"Authentication success"}');
    assert.equal(r.success, true);
    assert.ok(r.message.includes("Authentication success"));
  });

  it("result=0 时报告失败并携带 msg", () => {
    const r = parseLoginResponse('{"result":0,"msg":"用户名或密码错误"}');
    assert.equal(r.success, false);
    assert.ok(r.message.includes("用户名或密码错误"));
  });

  it("result=0 且无 msg 时失败消息不为空", () => {
    const r = parseLoginResponse('{"result":0}');
    assert.equal(r.success, false);
    assert.ok(r.message.length > 0);
  });

  it("非 JSON 响应时原样返回文本并标记失败", () => {
    const r = parseLoginResponse("some raw portal text");
    assert.equal(r.success, false);
    assert.ok(r.message.includes("some raw portal text"));
  });

  it("空字符串时标记失败", () => {
    const r = parseLoginResponse("");
    assert.equal(r.success, false);
  });
});
