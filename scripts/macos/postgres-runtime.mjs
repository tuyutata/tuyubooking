import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { createHash } from 'node:crypto';
import { lstat, mkdir, realpath, readdir, readFile, writeFile, copyFile } from 'node:fs/promises';
import { dirname, join, resolve, basename, isAbsolute, relative } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { buildLibraries, archivePlan } from './postgres-dependencies.mjs';

const exec = promisify(execFile);
const root = resolve(fileURLToPath(new URL('../..', import.meta.url)));
const fail = message => { throw new Error('PostgreSQL macOS：' + message); };
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
async function canonical(path, directory = false) {
  if (!isAbsolute(path) || resolve(path) !== path || await realpath(path) !== path) fail('路径不是准确真实绝对路径');
  const info = await lstat(path);
  if (directory ? !info.isDirectory() : !info.isFile() || !info.size) fail('路径类型不符');
  return path;
}
async function walk(path) {
  const files = [];
  for (const entry of await readdir(path, { withFileTypes: true })) {
    const file = join(path, entry.name);
    if (entry.isDirectory()) files.push(...await walk(file));
    else if (entry.isFile()) files.push(file);
    else if (!entry.isSymbolicLink()) fail('编译输出包含特殊文件');
  }
  return files;
}
const macho = async path => {
  const bytes = await readFile(path);
  if (bytes.length < 32 || bytes.readUInt32LE(0) !== 0xfeedfacf) return false;
  if (bytes.readUInt32LE(4) !== 0x0100000c) fail('运行时Mach-O必须为ARM64');
  return true;
};

// 完整动态链接闭包只接受本轮编译目录或显式交付工具对象；所有宿主路径在签名前移除。
export async function relocateRuntime({ destination, prefixes, environment, run }) {
  await canonical(destination, true);
  for (const prefix of prefixes) await canonical(prefix, true);
  for (const name of ['OTOOL', 'INSTALL_NAME_TOOL', 'CODESIGN']) await canonical(environment[name]);
  const originals = new Map((await walk(destination)).map(path => [path, path]));
  const queued = [...originals.keys()];
  for (let index = 0; index < queued.length; index++) {
    const file = queued[index]; if (!await macho(file)) continue;
    const original = originals.get(file);
    const identifier = file.endsWith('.dylib') || file.endsWith('.so')
      ? (await run(environment.OTOOL, ['-D', original])).stdout.split('\n').slice(1).find(Boolean)?.trim() : null;
    const listing = await run(environment.OTOOL, ['-L', original]);
    for (const row of listing.stdout.split('\n').slice(1)) {
      const dependency = row.trim().split(' (')[0];
      if (!dependency || dependency === identifier || dependency.startsWith('/usr/lib/') || dependency.startsWith('/System/Library/')) continue;
      let candidates;
      if (isAbsolute(dependency)) candidates = [dependency];
      else if (dependency.startsWith('@loader_path/')) candidates = [resolve(dirname(original), dependency.slice(13))];
      else if (dependency.startsWith('@rpath/')) candidates = prefixes.map(prefix => join(prefix, dependency.slice(7)));
      else fail('不支持的运行库链接形式');
      const matching = [];
      for (const candidate of candidates) {
        try {
          const canonical = await realpath(candidate);
          if (prefixes.some(prefix => canonical.startsWith(prefix + '/'))
            && (await lstat(canonical)).isFile()) matching.push(canonical);
        } catch (error) { if (error.code !== 'ENOENT' && error.code !== 'ENOTDIR') throw error; }
      }
      const source = [...new Set(matching)];
      if (source.length !== 1) fail('运行库来源缺失、不唯一或越界');
      const target = source[0].startsWith(destination + '/') ? source[0] : join(destination, 'lib', basename(source[0]));
      if (!originals.has(target)) {
        await copyFile(source[0], target); originals.set(target, source[0]); queued.push(target);
      } else if (originals.get(target) !== source[0]
        && hash(await readFile(originals.get(target))) !== hash(await readFile(source[0]))) fail('同名运行库原件冲突');
      const link = '@loader_path/' + relative(dirname(file), target);
      await run(environment.INSTALL_NAME_TOOL, ['-change', dependency, link, file]);
    }
    if (identifier) await run(environment.INSTALL_NAME_TOOL, ['-id', '@rpath/' + basename(file), file]);
    await run(environment.CODESIGN, ['--force', '--sign', '-', '--timestamp=none', file]);
  }
  for (const file of queued) {
    if (!await macho(file)) continue;
    const output = await run(environment.OTOOL, ['-L', file]);
    for (const row of output.stdout.split('\n').slice(1)) {
      const dependency = row.trim().split(' (')[0];
      if (dependency.startsWith('@loader_path/')) {
        const target = await realpath(resolve(dirname(file), dependency.slice(13)));
        if (!target.startsWith(destination + '/') || !(await lstat(target)).isFile()) fail('运行库相对链接越界或不存在');
        continue;
      }
      if (!dependency || dependency.startsWith('/usr/lib/')
        || dependency.startsWith('/System/Library/') || dependency === '@rpath/' + basename(file) && (file.endsWith('.dylib') || file.endsWith('.so'))) continue;
      fail('运行时仍含编译机依赖');
    }
  }
}


// PL/Perl保留原有功能，其核心模块从已交付解释器带入运行包；运行包不依赖编译机上的工具路径。
export async function copyPerlRuntime({ destination, perl, run }) {
  const prefix = dirname(dirname(await canonical(perl)));
  const output = await run(perl, ['-MConfig', '-e', 'print "$Config{privlibexp}\\n$Config{archlibexp}\\n$^V\\n"']);
  const [pure, architecture, version, ...extra] = output.stdout.trim().split('\n');
  if (version !== 'v5.42.3' || extra.length || pure === architecture) fail('PL/Perl核心版本或目录不符');
  const copyTree = async (source, target, ancestors = new Set(), exclude = null) => {
    const actual = await realpath(source);
    if (!actual.startsWith(prefix + '/') || ancestors.has(actual)) fail('PL/Perl模块链接越界或成环');
    const info = await lstat(actual);
    if (info.isDirectory()) {
      await mkdir(target);
      const next = new Set([...ancestors, actual]);
      for (const name of await readdir(actual)) {
        const child = join(actual, name);
        if (child !== exclude) await copyTree(child, join(target, name), next, exclude);
      }
    } else if (info.isFile()) await copyFile(actual, target);
    else fail('PL/Perl模块包含特殊文件');
  };
  for (const path of [pure, architecture]) await canonical(path, true);
  const directory = join(destination, 'share/perl'); await mkdir(directory, { recursive: true });
  await copyTree(pure, join(directory, 'pure'), new Set(), architecture);
  await copyTree(architecture, join(directory, 'arch'));
  if (!(await lstat(join(directory, 'pure/strict.pm'))).isFile()
    || !(await lstat(join(directory, 'arch/Config.pm'))).isFile()) fail('PL/Perl核心模块不完整');
  const legal = join(prefix, 'licenses');
  for (const name of ['COPYING', 'Artistic']) {
    await canonical(join(legal, name));
    await copyFile(join(legal, name), join(directory, name));
  }
}

export async function buildPostgres(environment = process.env, { run: supplied, libraries = buildLibraries, plan: getPlan = archivePlan,
  host = { platform: process.platform, architecture: process.arch } } = {}) {
  if (host.platform !== 'darwin' || host.architecture !== 'arm64') fail('编译仅支持macOS的ARM64宿主');
  for (const name of ['NODE', 'CC', 'CXX', 'AR', 'RANLIB', 'MAKE', 'LD', 'AS', 'NM', 'PERL', 'M4', 'BISON', 'FLEX',
    'TCLSH', 'XCRUN', 'CODESIGN', 'OTOOL', 'INSTALL_NAME_TOOL']) {
    const executable = await canonical(environment[name] ?? '');
    if (!((await lstat(executable)).mode & 0o111)) fail('编译入口不可执行：' + name);
  }
  const work = await canonical(environment.TUYUBOOKING_POSTGRES_WORK_DIR ?? '', true);
  const archives = await canonical(environment.TUYUBOOKING_POSTGRES_ARCHIVES ?? '', true);
  const destination = environment.TUYU_POSTGRES_DEST;
  if (!destination || !isAbsolute(destination) || resolve(destination) !== destination
    || destination === root || destination.startsWith(root + '/') || root.startsWith(destination + '/')
    || work === root || work.startsWith(root + '/') || root.startsWith(work + '/')) fail('编译输出必须为源码外规范目录');
  await canonical(dirname(destination), true);
  try { await lstat(destination); fail('本轮PostgreSQL输出已存在，拒绝覆盖'); }
  catch (error) { if (error.code !== 'ENOENT') throw error; }
  const gettext = await canonical(environment.GETTEXT_ROOT ?? '', true);
  const openssl = await canonical(environment.OPENSSL_ROOT ?? '', true);
  const perlRoot = dirname(dirname(environment.PERL));
  const env = { HOME: work, TMPDIR: work, LANG: 'C', LC_ALL: 'C', MACOSX_DEPLOYMENT_TARGET: '26.0',
    PATH: [...new Set(['NODE', 'CC', 'CXX', 'AR', 'RANLIB', 'MAKE', 'LD', 'AS', 'NM', 'PERL', 'M4', 'BISON', 'FLEX', 'TCLSH']
      .map(name => dirname(environment[name])))].join(':') + ':' + join(gettext, 'bin') + ':/usr/bin:/bin',
    ...Object.fromEntries(['CC', 'CXX', 'AR', 'RANLIB', 'MAKE', 'LD', 'AS', 'NM', 'PERL', 'M4', 'BISON', 'FLEX', 'TCLSH',
      'CODESIGN', 'OTOOL', 'INSTALL_NAME_TOOL'].map(name => [name, environment[name]])),
    DEVELOPER_DIR: environment.DEVELOPER_DIR,
    YACC: JSON.stringify(environment.BISON) + ' -y', LEX: environment.FLEX,
    TCL_LIBRARY: join(dirname(dirname(environment.TCLSH)), 'lib/tcl8.6'),
  };
  const run = (command, args, options = {}) => (supplied ?? exec)(command, args,
    { env, cwd: work, timeout: 3_600_000, maxBuffer: 16 * 1024 * 1024, ...options });
  const sdk = (await run(environment.XCRUN, ['--sdk', 'macosx', '--show-sdk-path'])).stdout.trim();
  await canonical(sdk, true);
  if (!environment.DEVELOPER_DIR || !sdk.startsWith(environment.DEVELOPER_DIR + '/')) fail('SDK不属于已交付Xcode');
  const prepared = await libraries({ archives, work, sdk, gettext, openssl, environment: env, run });
  const entry = (await getPlan()).archives.find(entry => entry.name === 'postgresql');
  const archive = prepared.inputs.get('postgresql');
  if (hash(await readFile(archive)) !== entry.sha256) fail('PostgreSQL完整原件摘要不符');
  const sourceParent = join(work, 'postgresql'); await mkdir(sourceParent);
  await run('/usr/bin/tar', ['-xkf', archive, '--no-same-owner', '-C', sourceParent]);
  const source = join(sourceParent, 'postgresql-' + entry.version); await canonical(source, true);
  await mkdir(destination); await mkdir(join(destination, 'lib'));
  const buildEnv = { ...prepared.environment, PG_SYSROOT: sdk, PKG_CONFIG: '', XML2_CONFIG: '',
    TCL_CONFIG_SH: join(sdk, 'System/Library/Frameworks/Tcl.framework/tclConfig.sh'),
  };
  await run('/bin/sh', [join(source, 'configure'), '--prefix=' + destination,
    '--datadir=' + join(destination, 'share/postgresql'), '--includedir=' + join(destination, 'include/postgresql'),
    '--libdir=' + join(destination, 'lib'), '--sysconfdir=' + join(destination, 'etc'),
    '--enable-nls', '--with-bonjour', '--with-gssapi', '--with-icu', '--with-ldap',
    '--with-libxml', '--with-libxslt', '--with-lz4', '--with-openssl', '--with-pam',
    '--with-perl', '--with-tcl', '--with-uuid=e2fs', '--with-zstd'],
    { cwd: source, env: buildEnv });
  await run(environment.MAKE, ['-j2'], { cwd: source, env: buildEnv });
  await run(environment.MAKE, ['install-world-bin'], { cwd: source, env: buildEnv });
  for (const name of ['postgres', 'initdb', 'pg_ctl', 'psql']) {
    const file = join(destination, 'bin', name); await canonical(file);
    if (!await macho(file) || !((await lstat(file)).mode & 0o111)) fail('PostgreSQL真实可执行文件缺失');
  }
  await copyPerlRuntime({ destination, perl: environment.PERL, run });
  await relocateRuntime({ destination, prefixes: [destination, prepared.prefix, perlRoot, gettext, openssl],
    environment: env, run });
  const legal = join(destination, 'licenses'); await mkdir(legal);
  const licenseRoot = join(root, 'licenses');
  const manifest = await readFile(join(licenseRoot, 'postgresql-MANIFEST.sha256'), 'utf8');
  for (const line of manifest.trim().split('\n')) {
    const match = /^([a-f0-9]{64})  ([A-Za-z0-9@_.-]+)$/u.exec(line);
    if (!match || hash(await readFile(join(licenseRoot, match[2]))) !== match[1]) fail('保留法律文件摘要不符');
  }
  const lock = JSON.parse(await readFile(new URL('./licenses.lock.json', import.meta.url)));
  const copied = new Set();
  for (const component of lock.components) for (const file of component.files) {
    if (!/^postgresql__[A-Za-z0-9@_.-]+$/u.test(file)) fail('法律文件路径不符');
    if (!copied.has(file)) { await copyFile(join(licenseRoot, file), join(legal, file)); copied.add(file); }
  }
  await writeFile(join(destination, 'THIRD_PARTY_COMPONENTS.txt'), lock.components.map(entry => entry.name).sort().join('\n') + '\n', { flag: 'wx' });
  const version = await run(join(destination, 'bin/postgres'), ['--version']);
  if (!/^postgres \(PostgreSQL\) 17\.11\s*$/u.test(version.stdout)) fail('PostgreSQL版本回读不符');
  const files = (await walk(destination)).sort();
  await writeFile(join(destination, 'MANIFEST.sha256'), (await Promise.all(files.map(async file =>
    hash(await readFile(file)) + '  ' + relative(destination, file)))).join('\n') + '\n', { flag: 'wx' });
  return destination;
}
if (!(process.env.NODE_TEST_CONTEXT && process.argv.length === 2) && process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  if (process.argv.length !== 2) fail('编译入口不接受额外参数');
  process.stdout.write(await buildPostgres() + '\n');
}

// 正式实现结束；仅直接使用 node --test 执行本文件时注册以下回归。
if (process.env.NODE_TEST_CONTEXT && process.argv.length === 2 && !process.execArgv.some(value=>/^(?:-e|--eval(?:=|$)|--input-type(?:=|$))/u.test(value)) && process.argv[1] && import.meta.url === (await import('node:url')).pathToFileURL((await import('node:path')).resolve(process.argv[1])).href) {
const {default:assert} = await import('node:assert/strict');
const { test } = await import('node:test');
const { mkdtemp, mkdir, readFile, writeFile, symlink, rm, realpath } = await import('node:fs/promises');
const { testRoot:tmpdir } = await import('../build.mjs');
const { join, dirname, basename } = await import('node:path');


const image = architecture => {
  const bytes = Buffer.alloc(32); bytes.writeUInt32LE(0xfeedfacf, 0);
  bytes.writeUInt32LE(architecture ?? 0x0100000c, 4); return bytes;
};
async function fixture(t) {
  const root = await realpath(await mkdtemp(join(tmpdir(), 'postgres-runtime-')));
  t.after(() => rm(root, { recursive: true, force: true }));
  const destination = join(root, 'runtime'), prefix = join(root, 'inputs');
  await mkdir(join(destination, 'bin'), { recursive: true });
  await mkdir(join(destination, 'lib'), { recursive: true });
  await mkdir(join(prefix, 'lib'), { recursive: true });
  const executable = join(destination, 'bin/postgres'), library = join(prefix, 'lib/libperl.dylib');
  await writeFile(executable, image(), { mode: 0o755 });
  await writeFile(library, image(), { mode: 0o755 });
  const links = new Map([[executable, [library, '/usr/lib/libSystem.B.dylib']], [library, [library, '/usr/lib/libSystem.B.dylib']]]);
  const ids = new Map([[library, library]]), calls = [];
  const environment = {};
  for (const name of ['OTOOL', 'INSTALL_NAME_TOOL', 'CODESIGN']) {
    environment[name] = join(root, name); await writeFile(environment[name], 'fixture executable', { mode: 0o755 });
  }
  const state = file => {
    if (!links.has(file) && basename(file) === 'libperl.dylib') {
      links.set(file, [...links.get(library)]); ids.set(file, ids.get(library));
    }
    return links.get(file) ?? [];
  };
  const run = async (command, args) => {
    calls.push({ command, args });
    const file = args.at(-1);
    if (command === environment.OTOOL) {
      if (args[0] === '-D') return { stdout: file + '\n' + (ids.get(file) ?? '') + '\n' };
      return { stdout: file + '\n' + state(file).map(item => '\t' + item + ' (compatibility version 1.0.0)').join('\n') + '\n' };
    }
    if (command === environment.INSTALL_NAME_TOOL) {
      if (args[0] === '-change') links.set(file, state(file).map(item => item === args[1] ? args[2] : item));
      if (args[0] === '-id') {
        state(file); const before = ids.get(file); links.set(file, state(file).map(item => item === before ? args[1] : item));
        ids.set(file, args[1]);
      }
    }
    return { stdout: '' };
  };
  return { root, input: { destination, prefixes: [destination, prefix], environment, run }, library, executable, links, calls };
}
test('动态闭包将真实运行库带入包内，修改相对链接并在修改后签名', async t => {
  const { input, executable, links, calls } = await fixture(t);
  await relocateRuntime(input);
  assert.deepEqual(await readFile(join(input.destination, 'lib/libperl.dylib')), image());
  assert.ok(links.get(executable).includes('@loader_path/../lib/libperl.dylib'));
  assert.equal(calls.filter(call => call.command === input.environment.CODESIGN).length, 2);
  const changed = calls.findIndex(call => call.command === input.environment.INSTALL_NAME_TOOL);
  const signed = calls.findIndex(call => call.command === input.environment.CODESIGN);
  assert.ok(changed >= 0 && signed > changed);
});
test('动态闭包拒绝源码外未交付库和同名原件冲突', async t => {
  const { root, input, executable, links } = await fixture(t);
  const outside = join(root, 'outside.dylib'); await writeFile(outside, image());
  links.set(executable, [outside]);
  await assert.rejects(relocateRuntime(input), /来源缺失、不唯一或越界/);
});
test('动态闭包拒绝缺失、链接越界、未解析rpath和非ARM64输出', async t => {
  for (const kind of ['missing', 'link', 'rpath', 'architecture']) {
    const { root, input, executable, library, links } = await fixture(t);
    if (kind === 'missing') links.set(executable, [join(root, 'absent')]);
    if (kind === 'link') {
      const outside = join(root, 'outside'); await writeFile(outside, image());
      await rm(library); await symlink(outside, library);
    }
    if (kind === 'rpath') links.set(executable, ['@rpath/missing.dylib']);
    if (kind === 'architecture') await writeFile(executable, image(0x01000007));
    await assert.rejects(relocateRuntime(input));
  }
});
test('相同rpath在两个输入根都存在时直接失败，不猜测运行库', async t => {
  const { root, input, executable, links } = await fixture(t);
  const second = join(root, 'second'); await mkdir(join(second, 'lib'), { recursive: true });
  await writeFile(join(second, 'lib/libperl.dylib'), image());
  input.prefixes.push(second); links.set(executable, ['@rpath/lib/libperl.dylib']);
  await assert.rejects(relocateRuntime(input), /不唯一/);
});

async function perlFixture(t) {
  const root = await realpath(await mkdtemp(join(tmpdir(), 'postgres-perl-')));
  t.after(() => rm(root, { recursive: true, force: true }));
  const prefix = join(root, 'perl'), destination = join(root, 'runtime');
  const pure = join(prefix, 'lib/5.42.3'), architecture = join(pure, 'darwin-2level'), perl = join(prefix, 'bin/perl');
  for (const path of [dirname(perl), architecture, destination, join(prefix, 'licenses')]) await mkdir(path, { recursive: true });
  await writeFile(perl, image(), { mode: 0o755 });
  await writeFile(join(pure, 'strict.pm'), 'preserved core module and comments');
  await writeFile(join(architecture, 'Config.pm'), 'preserved architecture module');
  for (const name of ['COPYING', 'Artistic']) await writeFile(join(prefix, 'licenses', name), 'original upstream ' + name);
  return { root, pure, architecture, input: { destination, perl,
    run: async () => ({ stdout: [pure, architecture, 'v5.42.3', ''].join('\n') }) } };
}
test('PL/Perl保留核心模块与上游许可，架构树只有一份', async t => {
  const { input } = await perlFixture(t);
  await copyPerlRuntime(input);
  assert.equal(await readFile(join(input.destination, 'share/perl/pure/strict.pm'), 'utf8'), 'preserved core module and comments');
  assert.equal(await readFile(join(input.destination, 'share/perl/arch/Config.pm'), 'utf8'), 'preserved architecture module');
  assert.equal(await readFile(join(input.destination, 'share/perl/Artistic'), 'utf8'), 'original upstream Artistic');
  await assert.rejects(readFile(join(input.destination, 'share/perl/pure/darwin-2level/Config.pm')), { code: 'ENOENT' });
});
test('PL/Perl版本、越界链接和缺失核心直接失败', async t => {
  for (const kind of ['version', 'link', 'core']) {
    const { root, pure, architecture, input } = await perlFixture(t);
    if (kind === 'version') input.run = async () => ({ stdout: [pure, architecture, 'v5.34.0', ''].join('\n') });
    if (kind === 'core') await rm(join(pure, 'strict.pm'));
    if (kind === 'link') {
      const outside = join(root, 'outside'); await writeFile(outside, 'outside');
      await symlink(outside, join(pure, 'outside.pm'));
    }
    await assert.rejects(copyPerlRuntime(input));
  }
});
test('PostgreSQL编译入口拒绝未支持宿主和未交付的相对工具，编译器不会先运行', async () => {
  let called = false;
  const run = async () => { called = true; return { stdout: '' }; };
  await assert.rejects(buildPostgres({}, { run, host: { platform: 'linux', architecture: 'arm64' } }), /仅支持macOS/);
  await assert.rejects(buildPostgres({ NODE: 'node' }, { run, host: { platform: 'darwin', architecture: 'arm64' } }), /准确真实绝对路径/);
  assert.equal(called, false);
});

test('包内同名动态库与交付原件字节不同则拒绝覆盖', async t => {
  const { input } = await fixture(t);
  await writeFile(join(input.destination, 'lib/libperl.dylib'), Buffer.concat([image(), Buffer.from('different')]));
  await assert.rejects(relocateRuntime(input), /同名运行库原件冲突/);
});

// 平台与架构分别描述；两种不支持的宿主都必须在工具交付和编译前失败。
test('PostgreSQL宿主拒绝仍覆盖错误平台与错误架构', async () => {
  const run = async () => assert.fail('不支持宿主不调用编译器');
  for (const host of [{ platform: 'linux', architecture: 'arm64' }, { platform: 'darwin', architecture: 'x64' }]) {
    await assert.rejects(buildPostgres({}, { run, host }), /编译仅支持macOS的ARM64宿主/u);
  }
});

}
