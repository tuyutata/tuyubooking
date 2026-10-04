#!/usr/bin/env node
// RELEASE_BUILD: full; CARGO_INCREMENTAL=0
// 当前入口按产品与平台验真 CI 来源，并创建对应的 GitHub Release 资产。

import { execFileSync, spawnSync } from "node:child_process";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const identity = Object.freeze({
  product: "tuyubooking", platform: "client-ios", prefix: "tuyubooking-client-ios-v",
  ciTitle: "途遇商家端 · 分机 iOS · CI", workflow: "tuyubooking.client-ios.release",
  asset: "tuyubooking-client-ios.ipa",
});

function required(value, message) { if (!value) throw new Error(message); }
function githubJSON(args) { return JSON.parse(execFileSync("gh", args, { encoding: "utf8", env: process.env })); }
function parseVersion(value) {
  const match = /^(0|[1-9]\d*)\.(0|[1-9]\d{0,1})\.(0|[1-9]\d{0,1})$/.exec(value || "");
  required(match, `iOS 软件版本无效：${value || "(empty)"}`); return match.slice(1).map(Number);
}
function baseInputs() {
  const value = { repository: process.env.GITHUB_REPOSITORY, source: process.env.SOURCE_SHA, ciRunID: process.env.CI_RUN_ID };
  required(value.repository === "tuyutata/tuyubooking", "途遇商家仓库身份无效");
  required(/^[0-9a-f]{40}$/.test(value.source || ""), "iOS Release 源提交无效");
  required(/^[1-9][0-9]*$/.test(value.ciRunID || ""), "iOS CI Run ID 无效"); return value;
}
function inputs() {
  const value = { ...baseInputs(), version: process.env.SOFTWARE_VERSION, tag: process.env.VERSION_TAG };
  parseVersion(value.version); required(value.tag === `${identity.prefix}${value.version}`, "iOS Tag 无效"); return value;
}
function verify(value) {
  required(execFileSync("git", ["rev-parse", "HEAD"], { encoding: "utf8" }).trim() === value.source, "iOS 源码提交不一致");
  const run = githubJSON(["api", `repos/${value.repository}/actions/runs/${value.ciRunID}`]);
  required(String(run?.id) === value.ciRunID && run?.head_sha === value.source && run?.head_branch === "main"
    && run?.event === "workflow_dispatch" && run?.status === "completed" && run?.conclusion === "success"
    && String(run?.display_title || '') === identity.ciTitle && String(run?.path || "").endsWith("/tuyubooking-client-ios-ci.yml"), "iOS CI Run 身份不一致");
}
function context(value) { writeFileSync("release-context.json", `${JSON.stringify({ repository: value.repository, product_id: identity.product, platform: identity.platform, software_flow: "release", software_version: value.version, version_tag: value.tag, source_sha: value.source, ci_run_id: Number(value.ciRunID), workflow: identity.workflow }, null, 2)}\n`); }
function publish(value) {
  const root = process.env.RELEASE_DIR; required(root, "iOS Release 资产目录缺失");
  const assets = [identity.asset, "release-manifest.json", "SHA256SUMS"].map((name) => join(root, name)); assets.forEach((path) => required(existsSync(path), `iOS Release 资产缺失：${path}`));
  required(spawnSync("gh", ["release", "view", value.tag, "--repo", value.repository], { stdio: "ignore" }).status !== 0, "iOS 正式 Release 已存在，禁止覆盖");
  required(spawnSync("gh", ["api", `repos/${value.repository}/git/ref/tags/${value.tag}`], { stdio: "ignore" }).status !== 0, "iOS 正式 Tag 已存在，禁止覆盖");
  execFileSync("gh", ["release", "create", value.tag, ...assets, "--repo", value.repository, "--title", "途遇商家端 · Release · 分机 iOS", "--notes", `途遇商家分机端 iOS ${value.version}；SOURCE_SHA:${value.source}`, "--latest=false"], { stdio: "inherit", env: process.env });
}

try {
  const command = process.argv[2];
  const value = inputs(); if (command === "verify-release-source") verify(value); else if (command === "write-context") context(value); else if (command === "publish-release") publish(value); else throw new Error(`iOS Release 子命令未登记：${command || "(empty)"}`);
} catch (error) { console.error(error.message); process.exitCode = 1; }
