#!/usr/bin/env node
import { remoteEnvironment as productRemoteEnvironment } from '../../../build.mjs';
if(process.env.GITHUB_ACTIONS==='true'&&String(process.env.GITHUB_WORKFLOW||'').startsWith('tuyubooking.'))Object.assign(process.env,productRemoteEnvironment());
// CI_BUILD: incremental
// TUYUBOOKING_APP_ROOT_CONTRACT: 主机端 CI 显式选择 tuyubooking/app 的主机入口。

import { execFileSync } from 'node:child_process';
import { lstatSync, mkdtempSync, realpathSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { temporaryRoot } from '../../../build.mjs';
const tmpdir=()=>temporaryRoot('host-macos','ci');
import { preparePostgresRuntime } from '../../postgres-runtime.mjs';

function required(value, message) { if (!value) throw new Error(message); }

function run(command, args, cwd) {
  execFileSync(command, args, { cwd, stdio: 'inherit', env: process.env });
}

let projectWork, projectOwned;
try {
  // 本身份独占源码外工程，Flutter工具只写本次任务目录。
  process.env.TUYUBOOKING_ROOT = realpathSync(process.cwd());
  const source = realpathSync('app');
  projectWork = mkdtempSync(join(realpathSync(process.env.RUNNER_TEMP || tmpdir()), 'tuyubooking-host-macos-ci-'));
  projectOwned = lstatSync(projectWork);
  const project = execFileSync(process.execPath, [join(source, 'scripts/project.mjs'), 'create',
    '--source-root', source, '--work-root', projectWork, '--platform', 'macos'],
    { encoding: 'utf8', env: process.env }).trim();
  required(process.platform === 'darwin' && process.arch === 'arm64', '途遇商家主机端 macOS CI 必须运行在 ARM64');
  run('git', ['submodule', 'status', '--recursive'], '.');
  run('flutter', ['pub', 'get', '--enforce-lockfile'], project);
  // 锁定Git原件与原生安装件只装入本轮Pub实际视图，源码根保持只读。
  process.env.CARGO_TARGET_DIR ||= join(projectWork, 'cargo');
  run(process.execPath, [join(source, 'scripts/project.mjs'), 'native',
    '--source-root', source, '--work-root', projectWork, '--output', project,
    '--platform', 'macos'], process.cwd());
  run('flutter', ['analyze'], project);
  run('flutter', ['test'], project);
  run('flutter', ['build', 'macos', '--release', '--target', 'lib/main_host.dart'], project);
  // 真数据库集成测试前完成所属产品运行时交付，禁止读取源码内旧发行件。
  process.env.TUYU_POSTGRES_BIN = await preparePostgresRuntime('macos', projectWork);
  run('cargo', ['fmt', '--all', '--check'], '.');
  run('cargo', ['test', '--workspace', '--locked'], '.');
} catch (error) {
  console.error(`途遇商家主机端 macOS CI 失败：${error.message}`);
  if (error.status === 75) projectOwned = null;
  process.exitCode = error.status === 75 ? 75 : 1;
}

finally {
  if (projectOwned) {
    const current = lstatSync(projectWork);
    if (current.isSymbolicLink() || current.dev !== projectOwned.dev || current.ino !== projectOwned.ino) throw new Error('CI工程归属变化，保留现场');
    rmSync(projectWork, { recursive: true });
  }
}
