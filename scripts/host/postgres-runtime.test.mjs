// 使用最小二进制头验证输入边界；测试替身不作为真实数据库编译验收。
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createHash } from 'node:crypto';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, realpathSync, rmSync, symlinkSync } from 'node:fs';
import { join } from 'node:path';
import { testRoot as tmpdir } from '../build.mjs';
import { verifyPostgresInput, preparePostgresRuntime } from './postgres-runtime.mjs';
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
function fixture(t, platform = 'macos') {
  const work = realpathSync(mkdtempSync(join(tmpdir(), 'host-postgres-')));
  t.after(() => rmSync(work, { recursive: true, force: true }));
  const root = join(work, 'database'), bin = join(root, 'bin'); mkdirSync(bin, { recursive: true });
  const bytes = Buffer.alloc(64);
  if (platform === 'macos') { bytes.writeUInt32LE(0xfeedfacf); bytes.writeUInt32LE(0x0100000c, 4); }
  else { Buffer.from('7f454c46', 'hex').copy(bytes); bytes[4] = 2; bytes[5] = 1; bytes.writeUInt16LE(platform === 'linux-arm' ? 183 : 62, 18); }
  for (const name of ['postgres', 'initdb', 'pg_ctl', 'psql']) writeFileSync(join(bin, name), bytes, { mode: 0o755 });
  const manifest = join(root, 'MANIFEST.sha256');
  const seal = () => writeFileSync(manifest, ['postgres', 'initdb', 'pg_ctl', 'psql'].map(name => hash(readFileSync(join(bin, name))) + '  ./bin/' + name).join('\n') + '\n');
  seal(); return { work, root, bin, manifest, seal, run: () => 'postgres (PostgreSQL) 17.11\n' };
}
test('完整清单、准确架构和同版输入可直接消费，不下载或重编译', async t => {
  for (const platform of ['macos', 'linux-arm', 'linux-amd']) {
    const f = fixture(t, platform);
    assert.equal(verifyPostgresInput(f.bin, platform, { run: f.run }), f.bin);
    assert.equal(await preparePostgresRuntime(platform, f.work, { TUYU_POSTGRES_BIN: f.bin }, {
      run: f.run, fetcher: () => assert.fail('不得下载'), compileMac: () => assert.fail('不得编译'),
    }), f.bin);
  }
});
test('拒绝文件漂移、额外文件、重复路径、清单越界、错误架构和版本', t => {
  for (const kind of ['bytes', 'extra', 'duplicate', 'escape', 'architecture', 'version']) {
    const f = fixture(t);
    if (kind === 'bytes') writeFileSync(join(f.bin, 'psql'), 'wrong');
    if (kind === 'extra') writeFileSync(join(f.root, 'extra'), 'extra');
    if (kind === 'duplicate') writeFileSync(f.manifest, readFileSync(f.manifest, 'utf8') + readFileSync(f.manifest, 'utf8').split('\n')[0] + '\n');
    if (kind === 'escape') writeFileSync(f.manifest, '0'.repeat(64) + '  ../outside\n');
    if (kind === 'architecture') { const bytes = readFileSync(join(f.bin, 'psql')); bytes.writeUInt32LE(0x01000007, 4); writeFileSync(join(f.bin, 'psql'), bytes); f.seal(); }
    assert.throws(() => verifyPostgresInput(f.bin, 'macos', { run: kind === 'version' ? () => 'postgres (PostgreSQL) 17.10' : f.run }));
  }
});
test('拒绝运行包链接越界和核心程序链接，保留原输入', t => {
  const f = fixture(t), outside = join(f.work, 'outside'); writeFileSync(outside, 'outside');
  symlinkSync(outside, join(f.root, 'link'));
  assert.throws(() => verifyPostgresInput(f.bin, 'macos', { run: f.run }), /越界/);
  rmSync(join(f.root, 'link')); rmSync(join(f.bin, 'psql')); symlinkSync(join(f.bin, 'postgres'), join(f.bin, 'psql'));
  assert.throws(() => verifyPostgresInput(f.bin, 'macos', { run: f.run }));
});
test('拒绝未知平台、旧工作目录及缺少准确编译入口，不执行命令', async t => {
  const f = fixture(t), run = () => assert.fail('不得执行命令');
  await assert.rejects(preparePostgresRuntime('other', f.work, {}, { run }), /平台无效/);
  await assert.rejects(preparePostgresRuntime('windows', f.work, {}, { run }));
  await assert.rejects(preparePostgresRuntime('linux-arm', f.work, {}, { run }), /目录已存在/);
});
