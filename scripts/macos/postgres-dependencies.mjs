import { createHash } from 'node:crypto';
import { lstat, realpath, readFile, writeFile, mkdir, readdir } from 'node:fs/promises';
import { join, resolve, isAbsolute } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(fileURLToPath(new URL('../..', import.meta.url)));
const fail = message => { throw new Error('PostgreSQL编译闭包：' + message); };
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const readlinePatches = Object.freeze([
  ['readline83-001', '8.3.1', '21f0a03106dbe697337cd25c70eb0edbaa2bdb6d595b45f83285cdd35bac84de'],
  ['readline83-002', '8.3.2', 'e27364396ba9f6debf7cbaaf1a669e2b2854241ae07f7eca74ca8a8ba0c97472'],
  ['readline83-003', '8.3.3', '72dee13601ce38f6746eb15239999a7c56f8e1ff5eb1ec8153a1f213e4acdb29'],
]);
export async function archivePlan() {
  const lock = JSON.parse(await readFile(new URL('./licenses.lock.json', import.meta.url)));
  const selected = lock.components.filter(entry => !['gettext', 'openssl@3'].includes(entry.name));
  if (selected.length !== 6 || new Set(selected.map(entry => entry.name)).size !== 6) fail('六项源码归档清单不完整');
  const names = { 'icu4c@78': 'icu4c', 'postgresql@17': 'postgresql' };
  const archives = selected.map(entry => ({ ecosystem: 'native', name: names[entry.name] ?? entry.name,
    version: entry.name === 'readline' ? entry.installed_version.split('.').slice(0, 2).join('.') : entry.installed_version, url: entry.source_url, sha256: entry.source_sha256 }));
  for (const entry of archives) {
    // 只登记实测官方分发宿主；不保存GitHub临时签名地址，完整SHA-256仍逐字节校验。
    if (entry.name === 'icu4c') entry.redirectOrigins = ['https://release-assets.githubusercontent.com'];
    if (['lz4', 'zstd'].includes(entry.name)) entry.redirectOrigins = ['https://codeload.github.com'];
  }
  archives.push(...readlinePatches.map(([name, version, sha256]) => ({ ecosystem: 'native', name, version,
    sha256, url: 'https://ftp.gnu.org/gnu/readline/readline-8.3-patches/' + name })));
  for (const entry of archives) {
    if (!/^[a-f0-9]{64}$/u.test(entry.sha256) || !/^\d+\.\d+(?:\.\d+)?$/u.test(entry.version)
      || !entry.url.startsWith('https://')) fail('官方固定来源或摘要不完整');
  }
  return { archives, unmanaged: [] };
}

// GNU官方context补丁只按完整上下文唯一匹配；不调用系统patch，不接受模糊匹配或任意路径。
export function applyReadlinePatch(files, text) {
  const rows = text.split('\n'); let file = null, hunks = 0;
  const result = new Map(files);
  for (let index = 0; index < rows.length; index++) {
    const header = /^--- ([a-z][a-z0-9_.]*)(?:\t| )/u.exec(rows[index]);
    if (header) {
      file = header[1];
      if (!['input.c', 'display.c', 'isearch.c', 'patchlevel'].includes(file) || !result.has(file)) fail('补丁目标不属于Readline闭集');
      continue;
    }
    if (rows[index] !== '***************') continue;
    if (!file || !/^\*\*\* \d+(?:,\d+)? \*\*\*\*$/u.test(rows[++index])) fail('补丁旧范围无效');
    const before = [];
    while (index + 1 < rows.length && !/^--- \d+(?:,\d+)? ----$/u.test(rows[index + 1])) {
      const line = rows[++index];
      if (!/^(?:  |! |- )/u.test(line)) fail('补丁旧正文无效');
      before.push(line.slice(2) + '\n');
    }
    if (!/^--- \d+(?:,\d+)? ----$/u.test(rows[++index])) fail('补丁新范围无效');
    const after = [], unchanged = [];
    while (index + 1 < rows.length && /^(?:  |! |\+ )/u.test(rows[index + 1])) {
      const line = rows[++index]; after.push(line.slice(2) + '\n');
      if (line.startsWith('  ')) unchanged.push(line.slice(2) + '\n');
      else if (line.startsWith('! ')) unchanged.push(line.slice(2) + '\n');
    }
    if (!before.length) before.push(...unchanged);
    if (!after.length) {
      // 删除型context补丁只保留旧正文中的上下文行。
      fail('Readline闭集不包含删除型空新正文');
    }
    const old = before.join(''), current = result.get(file);
    if (!old || current.indexOf(old) < 0 || current.indexOf(old, current.indexOf(old) + 1) >= 0) fail('补丁原文缺失或不唯一');
    result.set(file, current.replace(old, after.join(''))); hunks++;
  }
  if (!hunks || !result.get('patchlevel').endsWith(text.match(/\n! ([123])\n?$/u)?.[1] + '\n')) fail('Readline补丁级别不符');
  return result;
}

async function outside(path) {
  if (!isAbsolute(path) || path !== resolve(path) || path === root || path.startsWith(root + '/')
    || root.startsWith(path + '/')) fail('编译闭包路径必须为源码外规范绝对路径');
  if (await realpath(path) !== path || !(await lstat(path)).isDirectory()) fail('源码外目录不存在或包含链接');
  return path;
}
async function ordinary(path) {
  const stat = await lstat(path);
  if (!stat.isFile() || stat.isSymbolicLink() || await realpath(path) !== path || !stat.size) fail('编译原件必须是准确普通文件');
}

// 所有原件由调用方按此产品锁供给；本模块只读原件并在本轮工作根编译，不自行建立永久下载库。
export async function buildLibraries({ archives, work, sdk, gettext, openssl, environment, run, plan: getPlan = archivePlan }) {
  await outside(archives); await outside(work);
  if (archives.startsWith(work + '/') || work.startsWith(archives + '/') || archives === work) fail('原件与编译工作目录必须隔离');
  for (const prefix of [gettext, openssl]) {
    await outside(prefix);
    if (prefix === work || prefix.startsWith(work + '/')) fail('受控工具原件不得进入可写编译目录');
  }
  const plan = await getPlan(), inputs = new Map();
  for (const entry of plan.archives) {
    const path = join(archives, entry.sha256 + '.blob'); await ordinary(path);
    if (digest(await readFile(path)) !== entry.sha256) fail('源码或补丁完整SHA-256不符');
    inputs.set(entry.name, path);
  }
  for (const name of ['MAKE', 'CC', 'CXX', 'AR', 'RANLIB', 'PERL', 'BISON', 'FLEX']) {
    const path = environment[name]; if (!path || !isAbsolute(path)) fail('缺少已交付编译入口：' + name);
    await ordinary(path);
    if (!((await lstat(path)).mode & 0o111)) fail('编译入口不可执行：' + name);
  }
  await outside(sdk);
  const unpack = join(work, 'sources'), prefix = join(work, 'prefix');
  await mkdir(unpack); await mkdir(prefix);
  const env = { ...environment, CC: environment.CC, CXX: environment.CXX,
    CFLAGS: '-O2 -fPIC -isysroot ' + JSON.stringify(sdk), CXXFLAGS: '-O2 -fPIC -isysroot ' + JSON.stringify(sdk),
    CPPFLAGS: '-I' + JSON.stringify(prefix + '/include'), LDFLAGS: '-L' + JSON.stringify(prefix + '/lib') + ' -isysroot ' + JSON.stringify(sdk),
    PKG_CONFIG: '', PKG_CONFIG_PATH: '', CONFIG_SITE: '', XML_CATALOG_FILES: '',
  };
  const roots = new Map([['krb5', 'krb5-1.22.2'], ['icu4c', 'icu'], ['readline', 'readline-8.3'],
    ['lz4', 'lz4-1.10.0'], ['zstd', 'zstd-1.5.7']]);
  for (const [name, directory] of roots) {
    const destination = join(unpack, name); await mkdir(destination);
    const listing = await run('/usr/bin/tar', ['-tf', inputs.get(name)], { cwd: work, env });
    if (listing.stdout.split('\n').filter(Boolean).some(path => path.startsWith('/') || path.includes('\\')
      || path.replace(/\/$/u, '').split('/').some(part => ['.', '..', ''].includes(part)))) fail('归档路径越界');
    await run('/usr/bin/tar', ['-xkf', inputs.get(name), '--no-same-owner', '-C', destination], { cwd: work, env });
    const source = join(destination, directory);
    if (await realpath(source) !== source) fail('库源码根被链接替换');
    if (name === 'readline') {
      let files = new Map(await Promise.all(['input.c', 'display.c', 'isearch.c', 'patchlevel']
        .map(async file => [file, await readFile(join(source, file), 'utf8')])));
      for (const [patch] of readlinePatches) files = applyReadlinePatch(files, await readFile(inputs.get(patch), 'utf8'));
      for (const [file, text] of files) await writeFile(join(source, file), text);
    }
    const cwd = name === 'krb5' ? join(source, 'src') : name === 'icu4c' ? join(source, 'source') : source;
    if (!['lz4', 'zstd'].includes(name)) {
      const command = name === 'icu4c' ? join(cwd, 'runConfigureICU') : join(cwd, 'configure');
      const args = [command, ...(name === 'icu4c' ? ['MacOSX'] : []), '--prefix=' + prefix, '--disable-shared', '--enable-static',
        ...(name === 'krb5' ? ['--without-system-verto', '--without-libedit'] : []),
        ...(name === 'icu4c' ? ['--disable-tests', '--disable-samples'] : [])];
      await run('/bin/sh', args, { cwd, env });
    }
    const specific = name === 'lz4' ? ['-C', 'lib', 'BUILD_SHARED=no', 'PREFIX=' + prefix]
      : name === 'zstd' ? ['-C', 'lib', 'BUILD_SHARED=0', 'BUILD_STATIC=1', 'PREFIX=' + prefix] : [];
    await run(environment.MAKE, ['-j2', ...specific], { cwd, env });
    await run(environment.MAKE, [...specific, 'install'], { cwd, env });
  }
  for (const file of ['lib/libgssapi_krb5.a', 'lib/libicuuc.a', 'lib/libreadline.a', 'lib/liblz4.a', 'lib/libzstd.a']) {
    await ordinary(join(prefix, file));
  }
  await writeFile(join(work, 'sources.json'), JSON.stringify(plan.archives), { flag: 'wx', mode: 0o444 });
  return { prefix, inputs, environment: { ...env,
    CPPFLAGS: env.CPPFLAGS + ' -I' + JSON.stringify(gettext + '/include') + ' -I' + JSON.stringify(openssl + '/include') + ' -I' + JSON.stringify(sdk + '/usr/include/libxml2'),
    LDFLAGS: env.LDFLAGS + ' -L' + JSON.stringify(gettext + '/lib') + ' -L' + JSON.stringify(openssl + '/lib'),
    ICU_CFLAGS: '-I' + JSON.stringify(prefix + '/include'), ICU_LIBS: '-L' + JSON.stringify(prefix + '/lib') + ' -licui18n -licuuc -licudata -lc++',
    KRB5_CONFIG: join(prefix, 'bin/krb5-config'), XML2_CFLAGS: '-I' + JSON.stringify(sdk + '/usr/include/libxml2'), XML2_LIBS: '-lxml2',
  } };
}
