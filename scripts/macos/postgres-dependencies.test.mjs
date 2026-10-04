import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createHash } from 'node:crypto';
import { mkdtemp, mkdir, readFile, writeFile, symlink, rm, realpath } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, basename } from 'node:path';
import { archivePlan, applyReadlinePatch, buildLibraries } from './postgres-dependencies.mjs';

const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const patch = level => [
  '--- patchlevel\t2026-01-01', '***************', '*** 1 ****',
  '! ' + (level - 1), '--- 1 ----', '! ' + level, '',
].join('\n');
test('产品固定锁导出六份官方源码与三份GNU补丁，工具原件不重复进入依赖计划', async () => {
  const plan = await archivePlan();
  assert.equal(plan.archives.length, 9);
  assert.deepEqual(plan.unmanaged, []);
  assert.equal(new Set(plan.archives.map(entry => entry.name)).size, 9);
  assert.ok(!plan.archives.some(entry => ['gettext', 'openssl', 'openssl@3'].includes(entry.name)));
  for (const entry of plan.archives) {
    assert.equal(new URL(entry.url).protocol, 'https:');
    assert.match(entry.sha256, /^[a-f0-9]{64}$/u);
  }
  assert.equal(plan.archives.find(entry => entry.name === 'postgresql').version, '17.11');
  assert.equal(plan.archives.find(entry => entry.name === 'readline').version, '8.3');
  assert.deepEqual(plan.archives.find(entry => entry.name === 'icu4c').redirectOrigins, ['https://release-assets.githubusercontent.com']);
  for (const name of ['lz4','zstd']) assert.deepEqual(plan.archives.find(entry => entry.name === name).redirectOrigins, ['https://codeload.github.com']);
  assert.deepEqual(plan.archives.filter(entry => entry.name.startsWith('readline83')).map(entry => entry.version),
    ['8.3.1', '8.3.2', '8.3.3']);
});
test('GNUcontext补丁逐级修改准确原文，不污染原件并拒绝缺失、重复和越界目标', () => {
  const original = new Map([['patchlevel', '0\n']]);
  let files = original;
  for (let level = 1; level <= 3; level++) files = applyReadlinePatch(files, patch(level));
  assert.equal(files.get('patchlevel'), '3\n');
  assert.equal(original.get('patchlevel'), '0\n');
  assert.throws(() => applyReadlinePatch(new Map([['patchlevel', '4\n']]), patch(1)), /原文缺失/);
  assert.throws(() => applyReadlinePatch(new Map([['patchlevel', '0\n0\n']]), patch(1)), /不唯一/);
  assert.throws(() => applyReadlinePatch(original, patch(1).replace('patchlevel\t', 'outside.c\t')), /目标/);
  assert.throws(() => applyReadlinePatch(original, ''), /补丁级别/);
});
test('GNU插入型补丁以完整新正文上下文恢复省略旧正文，不使用行号模糊匹配', () => {
  const text = [
    '--- input.c\t2026-01-01', '***************', '*** 120,121 ****', '--- 120,122 ----',
    '  before', '+ inserted', '  after', '',
    ...patch(1).split('\n'),
  ].join('\n');
  const files = applyReadlinePatch(new Map([['input.c', 'header\nbefore\nafter\n'], ['patchlevel', '0\n']]), text);
  assert.equal(files.get('input.c'), 'header\nbefore\ninserted\nafter\n');
});

async function fixture(t, fault = '') {
  const root = await realpath(await mkdtemp(join(tmpdir(), 'postgres-libraries-')));
  t.after(() => rm(root, { recursive: true, force: true }));
  const archives = join(root, 'archives'), work = join(root, 'work'), sdk = join(root, 'sdk');
  const gettext = join(root, 'tools/gettext'), openssl = join(root, 'tools/openssl');
  for (const directory of [archives, work, sdk, gettext, openssl]) await mkdir(directory, { recursive: true });
  const environment = {};
  for (const name of ['MAKE', 'CC', 'CXX', 'AR', 'RANLIB', 'PERL', 'BISON', 'FLEX']) {
    environment[name] = join(root, name); await writeFile(environment[name], 'verified executable', { mode: 0o755 });
  }
  const production = await archivePlan();
  const bytes = new Map(), plan = { archives: production.archives.map(entry => {
    const data = Buffer.from(entry.name.startsWith('readline83') ? patch(Number(entry.name.at(-1))) : entry.name);
    const next = { ...entry, sha256: hash(data) }; bytes.set(next.sha256, { entry: next, data }); return next;
  }), unmanaged: [] };
  for (const [digest, { data }] of bytes) await writeFile(join(archives, digest + '.blob'), data);
  if (fault === 'sha') await writeFile(join(archives, plan.archives[0].sha256 + '.blob'), 'changed');
  if (fault === 'link') {
    const path = join(archives, plan.archives[0].sha256 + '.blob');
    await rm(path); await symlink(environment.MAKE, path);
  }
  const calls = [], roots = { krb5: 'krb5-1.22.2', icu4c: 'icu', readline: 'readline-8.3', lz4: 'lz4-1.10.0', zstd: 'zstd-1.5.7' };
  const run = async (command, args, options) => {
    calls.push({ command, args, options });
    if (fault === 'compiler' && args.includes('-j2')) throw Error('compiler failed');
    if (command === '/usr/bin/tar') {
      const input = args.find(value => value.endsWith('.blob'));
      const name = bytes.get(basename(input, '.blob')).entry.name;
      if (args.includes('-tf')) return { stdout: fault === 'traversal' ? '../escape\n' : roots[name] + '/\n' };
      const destination = join(args[args.indexOf('-C') + 1], roots[name]);
      await mkdir(destination, { recursive: true });
      if (name === 'readline') {
        for (const file of ['input.c', 'display.c', 'isearch.c']) await writeFile(join(destination, file), 'retained upstream\n');
        await writeFile(join(destination, 'patchlevel'), '0\n');
      }
    }
    if (args.includes('install')) {
      const prefix = join(work, 'prefix'); await mkdir(join(prefix, 'lib'), { recursive: true });
      await mkdir(join(prefix, 'bin'), { recursive: true });
      for (const file of ['libgssapi_krb5.a', 'libicuuc.a', 'libreadline.a', 'liblz4.a', 'libzstd.a']) {
        if (fault !== 'output') await writeFile(join(prefix, 'lib', file), 'compiled library');
      }
      await writeFile(join(prefix, 'bin/krb5-config'), 'verified compiled config', { mode: 0o755 });
    }
    return { stdout: '' };
  };
  return { input: { archives, work, sdk, gettext, openssl, environment, run, plan: async () => plan }, calls };
}
test('受控闭包生成静态库与真实源码回执，保留GNU官方补丁结果', async t => {
  const { input, calls } = await fixture(t);
  const result = await buildLibraries(input);
  assert.equal(JSON.parse(await readFile(join(input.work, 'sources.json'))).length, 9);
  assert.equal(await readFile(join(input.work, 'sources/readline/readline-8.3/patchlevel'), 'utf8'), '3\n');
  assert.equal(calls.filter(call => call.args.includes('-j2')).length, 5);
  assert.ok(calls.filter(call => call.args.includes('-j2')).every(call => call.command === input.environment.MAKE));
  assert.equal(result.environment.PKG_CONFIG, '');
  assert.equal(result.environment.KRB5_CONFIG, join(result.prefix, 'bin/krb5-config'));
});
for (const fault of ['sha', 'link', 'traversal', 'compiler', 'output']) {
  test('编译闭包拒绝篡改、链接、越界或编译失败：' + fault, async t => {
    const { input, calls } = await fixture(t, fault);
    await assert.rejects(buildLibraries(input));
    if (['sha', 'link'].includes(fault)) assert.equal(calls.length, 0);
    await assert.rejects(readFile(join(input.work, 'sources.json')), { code: 'ENOENT' });
  });
}
test('编译闭包拒绝原件与可写工作根重叠以及非规范源码路径', async t => {
  const { input } = await fixture(t);
  await assert.rejects(buildLibraries({ ...input, work: input.archives }), /隔离/);
  await assert.rejects(buildLibraries({ ...input, work: input.work + '/..' }), /规范绝对路径/);
  await assert.rejects(buildLibraries({ ...input, environment: { ...input.environment, CC: 'clang' } }), /已交付编译入口/);
});
