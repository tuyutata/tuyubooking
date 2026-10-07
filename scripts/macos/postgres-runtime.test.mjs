import assert from 'node:assert/strict';
import { test } from 'node:test';
import { mkdtemp, mkdir, readFile, writeFile, symlink, rm, realpath } from 'node:fs/promises';
import { testRoot as tmpdir } from '../build.mjs';
import { join, dirname, basename } from 'node:path';
import { relocateRuntime, copyPerlRuntime, buildPostgres } from './postgres-runtime.mjs';

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
