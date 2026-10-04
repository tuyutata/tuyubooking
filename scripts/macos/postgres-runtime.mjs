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
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  if (process.argv.length !== 2) fail('编译入口不接受额外参数');
  process.stdout.write(await buildPostgres() + '\n');
}
