#!/usr/bin/env node
// CI_BUILD: incremental
// 分机端 Windows CI 必须显式选择分机入口。
import { execFileSync } from 'node:child_process';
import { lstatSync, mkdtempSync, realpathSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { pathToFileURL } from 'node:url';

function required(value, message) { if (!value) throw new Error(message); }
function run(command, args, cwd) {
  execFileSync(command, args, { cwd, stdio: 'inherit', env: process.env });
}

let projectWork, projectOwned;
try {
  // 本身份独占源码外工程，Flutter工具只写本次任务目录。
  process.env.TUYUBOOKING_ROOT = realpathSync(process.cwd());
  const source = realpathSync('app');
  projectWork = mkdtempSync(join(realpathSync(process.env.RUNNER_TEMP || tmpdir()), 'tuyubooking-client-windows-ci-'));
  projectOwned = lstatSync(projectWork);
  const project = execFileSync(process.execPath, [join(source, 'scripts/project.mjs'), 'create',
    '--source-root', source, '--work-root', projectWork, '--platform', 'windows'],
    { encoding: 'utf8', env: process.env }).trim();
  required(process.platform === 'win32' && process.arch === 'x64', '途遇商家分机端 Windows CI 必须运行在 x86-64');
  run('git', ['submodule', 'status', '--recursive'], '.');
  run('flutter', ['pub', 'get', '--enforce-lockfile'], project);
  run('flutter', ['analyze'], project);
  run('flutter', ['test'], project);
  const { prepareNativeProject } = await import(pathToFileURL(join(source, 'scripts/project.mjs')).href);
  Object.assign(process.env, await prepareNativeProject({ source, work: projectWork, output: project, platform: 'windows' }));
  run('flutter', ['build', 'windows', '--release', '--target', 'lib/main_client.dart'], project);
} catch (error) {
  console.error(`途遇商家分机端 Windows CI 失败：${error.message}`);
  // SDK资源未安全释放时保留准确工作目录，禁止finally继续删除。
  if (error.retainSdkStage || error.status === 75) { projectOwned = null; process.exitCode = 75; }
  else process.exitCode = 1;
}

finally {
  if (projectOwned) {
    const current = lstatSync(projectWork);
    if (current.isSymbolicLink() || current.dev !== projectOwned.dev || current.ino !== projectOwned.ino) throw new Error('CI工程归属变化，保留现场');
    rmSync(projectWork, { recursive: true });
  }
}
