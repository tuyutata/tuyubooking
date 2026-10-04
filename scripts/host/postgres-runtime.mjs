// 主机CI与Release只消费源码外、同版、完整验真的PostgreSQL；产品拥有原件与编译入口。
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, lstatSync, mkdirSync, readFileSync, realpathSync, readdirSync, writeFileSync } from 'node:fs';
import { dirname, isAbsolute, join, resolve, sep } from 'node:path';
import { archivePlan } from '../macos/postgres-dependencies.mjs';
import { buildPostgres } from '../macos/postgres-runtime.mjs';
import { verifyRuntime as verifyWindows } from '../windows-x86_64/verify-source.mjs';

const productRoot = resolve(import.meta.dirname, '../..');
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const fail = message => { throw Error('主机PostgreSQL输入：' + message); };
const inside = (parent, path) => path === parent || path.startsWith(parent + sep);
function directory(path) {
  if (!path || !isAbsolute(path) || resolve(path) !== path || realpathSync(path) !== path
    || !lstatSync(path).isDirectory() || inside(productRoot, path) || inside(path, productRoot)) fail('必须是源码外规范目录');
  return path;
}
function executable(path) {
  const info = path && lstatSync(path);
  if (!path || !isAbsolute(path) || resolve(path) !== path || realpathSync(path) !== path
    || !info.isFile() || info.isSymbolicLink() || process.platform !== 'win32' && !(info.mode & 0o111)) fail('必须交付准确可执行入口');
  return path;
}

// 清单与真实文件一一对应，链接只能指向本运行包；不能用四个非空占位文件代替数据库。
export function verifyPostgresInput(bin, platform, { run = execFileSync } = {}) {
  directory(bin);
  if (!['macos', 'windows', 'linux-arm', 'linux-amd'].includes(platform) || dirname(bin) === productRoot) fail('平台无效');
  const root = directory(dirname(bin));
  if (platform === 'windows') verifyWindows(root);
  const files = new Set(), links = [];
  const walk = parent => {
    for (const name of readdirSync(parent)) {
      const path = join(parent, name), info = lstatSync(path);
      if (info.isSymbolicLink()) {
        const target = realpathSync(path);
        if (!inside(root, target) || !lstatSync(target).isFile()) fail('运行包链接越界或不是文件');
        links.push(path);
      } else if (info.isDirectory()) walk(path);
      else if (info.isFile()) files.add(path);
      else fail('运行包包含特殊文件');
    }
  };
  walk(root);
  const manifestFile = join(root, 'MANIFEST.sha256');
  const records = new Map();
  for (const line of readFileSync(manifestFile, 'utf8').split(/\r?\n/u).filter(Boolean)) {
    const match = /^([a-f0-9]{64}) [ *](.+)$/u.exec(line);
    // sha256sum的官方相对清单允许一个./前缀，规范化后仍拒绝越界及重复。
    if (match) match[2] = match[2].replace(/^\.\//u, '');
    if (!match || match[2].includes('\\') || match[2].startsWith('/')
      || match[2].split('/').some(part => !part || part === '.' || part === '..')) fail('清单路径无效');
    const path = join(root, match[2]);
    if (path === manifestFile || records.has(path) || !files.has(path)
      || digest(readFileSync(path)) !== match[1]) fail('清单内容缺失、重复或漂移');
    records.set(path, match[1]);
  }
  if (records.size !== files.size - 1 || [...files].some(path => path !== manifestFile && !records.has(path))) fail('清单与文件不完整对应');
  for (const name of ['postgres', 'initdb', 'pg_ctl', 'psql']) {
    const path = executable(join(bin, name + (platform === 'windows' ? '.exe' : '')));
    if (!records.has(path)) fail('核心程序不在清单');
    if (platform !== 'windows') {
      const bytes = readFileSync(path);
      const valid = bytes.length >= 64 && (platform === 'macos'
        ? bytes.readUInt32LE(0) === 0xfeedfacf && bytes.readUInt32LE(4) === 0x0100000c
        : bytes.subarray(0, 4).toString('hex') === '7f454c46' && bytes[4] === 2 && bytes[5] === 1
          && bytes.readUInt16LE(18) === (platform === 'linux-arm' ? 183 : 62));
      if (!valid) fail('核心程序架构无效');
    }
  }
  const version = run(join(bin, 'postgres' + (platform === 'windows' ? '.exe' : '')),
    ['--version'], { encoding: 'utf8', timeout: 10000 }).trim();
  if (version !== 'postgres (PostgreSQL) 17.11') fail('数据库版本不符');
  return bin;
}

// 独立CI按本产品锁下载；本机调用方可直接交付唯一原件，不要求私有控制台。
async function acquire(entry, directory, fetcher) {
  const path = join(directory, entry.sha256 + '.blob');
  if (!existsSync(path)) {
    let url = new URL(entry.url), response;
    for (let count = 0; count < 5; count++) {
      response = await fetcher(url.href, { redirect: 'manual', signal: AbortSignal.timeout(60000) });
      if (![301, 302, 303, 307, 308].includes(response.status)) break;
      const next = new URL(response.headers.get('location'), url);
      if (next.protocol !== 'https:' || next.username || next.password || next.hash
        || next.origin !== new URL(entry.url).origin && !(entry.redirectOrigins ?? []).includes(next.origin)) fail('原件跳转来源无效');
      url = next;
    }
    if (!response?.ok || !response.body) fail('官方原件下载失败');
    const chunks = []; let size = 0;
    for await (const chunk of response.body) {
      size += chunk.length;
      if (size > 128 * 1024 * 1024) fail('官方原件过大');
      chunks.push(chunk);
    }
    const bytes = Buffer.concat(chunks);
    if (digest(bytes) !== entry.sha256) fail('官方原件摘要不符');
    writeFileSync(path, bytes, { flag: 'wx', mode: 0o444 });
  }
  const info = lstatSync(path);
  if (!info.isFile() || info.isSymbolicLink() || realpathSync(path) !== path || digest(readFileSync(path)) !== entry.sha256) fail('已有原件漂移');
}

export async function preparePostgresRuntime(platform, work, environment = process.env, {
  run = execFileSync, fetcher = fetch, compileMac = buildPostgres,
} = {}) {
  directory(work);
  if (!['macos', 'windows', 'linux-arm', 'linux-amd'].includes(platform)) fail('平台无效');
  if (environment.TUYU_POSTGRES_BIN) return verifyPostgresInput(environment.TUYU_POSTGRES_BIN, platform, { run });
  const runtimeParent = join(work, 'runtime');
  if (existsSync(runtimeParent)) fail('本轮运行包目录已存在');
  mkdirSync(runtimeParent);
  const destination = join(runtimeParent, 'postgresql');
  const env = { ...environment, NODE: process.execPath, TUYUBOOKING_NODE_BIN: process.execPath,
    TUYU_POSTGRES_DEST: destination, TUYUBOOKING_WORK_DIR: work,
    TUYUBOOKING_DEPENDENCY_DIR: join(work, 'dependencies'), TUYUBOOKING_BUILD_DIR: join(work, 'postgres-build') };
  if (platform === 'macos') {
    const archives = environment.TUYUBOOKING_POSTGRES_ARCHIVES || join(work, 'postgres-archives');
    if (!environment.TUYUBOOKING_POSTGRES_ARCHIVES) mkdirSync(archives);
    directory(archives);
    for (const entry of (await archivePlan()).archives) await acquire(entry, archives, fetcher);
    env.TUYUBOOKING_POSTGRES_ARCHIVES = archives;
    env.TUYUBOOKING_POSTGRES_WORK_DIR = join(work, 'postgres-build');
    mkdirSync(env.TUYUBOOKING_POSTGRES_WORK_DIR);
    await compileMac(env);
  } else if (platform === 'windows') {
    const shell = executable(environment.TUYUBOOKING_POWERSHELL_BIN);
    run(shell, ['-NoProfile', '-NonInteractive', '-File', join(productRoot, 'scripts/windows-x86_64/build_runtime.ps1'),
      '-Destination', destination], { env, cwd: productRoot, stdio: 'inherit' });
  } else if (['linux-arm', 'linux-amd'].includes(platform)) {
    const shell = executable(environment.TUYUBOOKING_SHELL_BIN);
    run(shell, [join(productRoot, 'scripts', platform, 'build_runtime.sh')],
      { env, cwd: productRoot, stdio: 'inherit' });
  } else fail('平台无效');
  return verifyPostgresInput(join(destination, 'bin'), platform, { run });
}
