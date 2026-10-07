#!/usr/bin/env node
import { remoteEnvironment as productRemoteEnvironment } from '../../../build.mjs';
if(process.env.GITHUB_ACTIONS==='true'&&String(process.env.GITHUB_WORKFLOW||'').startsWith('tuyubooking.'))Object.assign(process.env,productRemoteEnvironment());
// RELEASE_BUILD: full; CARGO_INCREMENTAL=0；正式包固定使用分机端入口。
import { execFileSync, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const identity = Object.freeze({
  product: 'tuyubooking', platform: 'client-macos', prefix: 'tuyubooking-client-macos-v',
  ciTitle: '途遇商家端 · 分机 macOS · CI', workflow: 'tuyubooking.client-macos.release',
  artifact: 'tuyubooking-client-macos.zip',
});
const root = process.cwd();
const output = join(process.env.RUNNER_TEMP || '/tmp', 'tuyubooking-client-release');
function required(value, message) { if (!value) throw new Error(message); }
function run(file, args, cwd = root) { execFileSync(file, args, { cwd, stdio: 'inherit', env: process.env }); }
function hash(path) { return createHash('sha256').update(readFileSync(path)).digest('hex'); }
function githubJSON(args) { return JSON.parse(execFileSync('gh', args, { encoding: 'utf8', env: process.env })); }
function inputs() {
  const value = { repository: process.env.GITHUB_REPOSITORY, source: process.env.SOURCE_SHA, ciRunID: process.env.CI_RUN_ID, version: process.env.SOFTWARE_VERSION, tag: process.env.VERSION_TAG };
  required(value.repository === 'tuyutata/tuyubooking', '途遇商家仓库身份无效');
  required(/^[0-9a-f]{40}$/u.test(value.source || ''), 'macOS Release 源提交无效');
  required(/^[1-9][0-9]*$/u.test(value.ciRunID || ''), 'macOS CI Run ID 无效');
  required(/^\d+\.\d{1,2}\.\d{1,2}$/u.test(value.version || ''), 'macOS 版本无效');
  required(value.tag === `${identity.prefix}${value.version}`, 'macOS Tag 无效');
  return value;
}
function verify(value) {
  required(process.platform === 'darwin' && process.arch === 'arm64', '途遇商家分机端 macOS Release 必须运行在 ARM64');
  required(execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' }).trim() === value.source, 'macOS 源码提交不一致');
  const info = githubJSON(['api', `repos/${value.repository}/actions/runs/${value.ciRunID}`]);
  required(String(info?.id) === value.ciRunID && info?.head_sha === value.source && info?.head_branch === 'main' && info?.event === 'workflow_dispatch' && info?.status === 'completed' && info?.conclusion === 'success' && String(info?.display_title || '') === identity.ciTitle && String(info?.path || '').endsWith('/tuyubooking-client-macos-ci.yml'), 'macOS CI Run 身份不一致');
  required(spawnSync('gh', ['release', 'view', value.tag, '--repo', value.repository], { stdio: 'ignore' }).status !== 0, 'macOS 正式 Release 已存在，禁止覆盖');
}
function manifest(value) {
  const asset = join(output, identity.artifact); required(existsSync(asset), 'macOS 正式资产不存在');
  const body = { product_id: identity.product, platform: identity.platform, software_version: value.version, git_commit_sha: value.source, ci_run_id: Number(value.ciRunID), assets: [{ name: identity.artifact, sha256: hash(asset) }] };
  const path = join(output, 'release-manifest.json'); writeFileSync(path, `${JSON.stringify(body, null, 2)}\n`);
  writeFileSync(join(output, 'SHA256SUMS'), `${hash(asset)}  ${identity.artifact}\n${hash(path)}  release-manifest.json\n`);
}
function build(value) {
  verify(value); rmSync(output, { recursive: true, force: true }); mkdirSync(output, { recursive: true });
  run('flutter', ['pub', 'get', '--enforce-lockfile'], join(root, 'app'));
  run('flutter', ['test'], join(root, 'app'));
  run('flutter', ['build', 'macos', '--release', '--target', 'lib/main_client.dart', `--build-name=${value.version}`], join(root, 'app'));
  const products = join(root, 'app/build/macos/Build/Products/Release');
  const names = readdirSync(products).filter((name) => name.endsWith('.app'));
  required(names.length === 1, 'macOS Release App 数量无效');
  run('ditto', ['-c', '-k', '--keepParent', join(products, names[0]), join(output, identity.artifact)]); manifest(value);
}
function publish(value) { run('gh', ['release', 'create', value.tag, '--repo', value.repository, '--title', `途遇商家分机端 macOS ${value.version}`, '--notes', `SOURCE_SHA:${value.source}`, ...[identity.artifact, 'release-manifest.json', 'SHA256SUMS'].map((name) => join(output, name))]); }
try { const value = inputs(); const command = process.argv[2]; if (command === 'build-release') build(value); else if (command === 'publish-release') publish(value); else if (command === 'verify-release-source') verify(value); else throw new Error(`macOS Release 子命令未登记：${command || '(empty)'}`); } catch (error) { console.error(error.message); process.exitCode = 1; }
