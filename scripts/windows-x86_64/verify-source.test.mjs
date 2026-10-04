import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdirSync, mkdtempSync, realpathSync, readdirSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { peImports, verifyRuntime } from './verify-source.mjs';

// 人工PE保留真实节表和导入表布局；校验器读取完整二进制结构而非脚本字符串。
function pe(dependency) {
  const data = Buffer.alloc(1536);
  data.writeUInt16LE(0x5a4d); data.writeUInt32LE(64, 0x3c);
  data.writeUInt32LE(0x4550, 64); data.writeUInt16LE(0x8664, 68); data.writeUInt16LE(1, 70); data.writeUInt16LE(240, 84);
  data.writeUInt16LE(0x20b, 88); data.writeUInt32LE(512, 148); data.writeUInt32LE(16, 196);
  data.writeUInt32LE(0x1000, 340); data.writeUInt32LE(1024, 344); data.writeUInt32LE(512, 348);
  if (dependency) {
    data.writeUInt32LE(0x1000, 208); data.writeUInt32LE(40, 212);
    data.writeUInt32LE(0x1064, 524); data.write(dependency + '\0', 612);
  }
  data.write('postgres (PostgreSQL) 17.11', 1000);
  return data;
}
test('PE导入表正常、截断、错架构及越界RVA', () => {
  assert.deepEqual(peImports(pe()), []);
  assert.deepEqual(peImports(pe('kernel32.dll')), ['kernel32.dll']);
  assert.throws(() => peImports(Buffer.alloc(10)), /字节范围/u);
  let data = pe(); data.writeUInt16LE(0xaa64, 68); assert.throws(() => peImports(data), /x86-64/u);
  data = pe('kernel32.dll'); data.writeUInt32LE(0xfffffff0, 524); assert.throws(() => peImports(data), /RVA/u);
  data = pe('../kernel32.dll'); assert.throws(() => peImports(data), /DLL导入名称/u);
  data = pe('kernel32.dll'); data.writeUInt32LE(20, 212); assert.throws(() => peImports(data), /终止项/u);
  data = pe(); data.writeUInt16LE(97, 70); assert.throws(() => peImports(data), /节表/u);
});
function fixture(t, dependency) {
  const parent = realpathSync(mkdtempSync(join(tmpdir(), 'tuyubooking-pg-pe-')));
  t.after(() => rmSync(parent, { recursive: true, force: true }));
  const root = join(parent, 'runtime'); mkdirSync(join(root, 'bin'), { recursive: true });
  const files = {};
  for (const name of ['postgres', 'initdb', 'pg_ctl', 'psql']) files['bin/' + name + '.exe'] = pe(dependency);
  files['server_license.txt'] = Buffer.from('official-license-test');
  files['commandlinetools_3rd_party_licenses.txt'] = Buffer.from('third-party-license-test');
  const manifest = [];
  for (const [path, bytes] of Object.entries(files)) {
    writeFileSync(join(root, path), bytes);
    manifest.push(createHash('sha256').update(bytes).digest('hex') + ' *' + path);
  }
  writeFileSync(join(root, 'MANIFEST.sha256'), manifest.join('\n') + '\n');
  return { parent, root };
}
test('完整运行时验真闭合系统导入且不写入输入', t => {
  const { root } = fixture(t, 'kernel32.dll');
  const before = readFileSync(join(root, 'MANIFEST.sha256'));
  assert.equal(verifyRuntime(root), root);
  assert.deepEqual(readdirSync(root).sort(), ['MANIFEST.sha256', 'bin', 'commandlinetools_3rd_party_licenses.txt', 'server_license.txt']);
  assert.deepEqual(readFileSync(join(root, 'MANIFEST.sha256')), before);
});
test('输入链接、额外文件、清单穿越、丢失文件与篡改均失败', t => {
  const { parent, root } = fixture(t);
  assert.throws(() => verifyRuntime('relative/path'), /源码外/u);
  assert.throws(() => verifyRuntime(root, { productRoot: parent }), /源码外/u);
  writeFileSync(join(root, 'extra'), 'extra'); assert.throws(() => verifyRuntime(root), /一一对应/u);
  rmSync(join(root, 'extra'));
  const manifest = readFileSync(join(root, 'MANIFEST.sha256'), 'utf8');
  writeFileSync(join(root, 'MANIFEST.sha256'), manifest + '0'.repeat(64) + ' *../outside\n');
  assert.throws(() => verifyRuntime(root), /清单路径/u);
  writeFileSync(join(root, 'MANIFEST.sha256'), manifest);
  writeFileSync(join(root, 'bin/psql.exe'), pe('unknown.dll')); assert.throws(() => verifyRuntime(root), /摘要/u);
  rmSync(join(root, 'bin/psql.exe')); assert.throws(() => verifyRuntime(root), /缺少文件/u);
  if (process.platform !== 'win32') {
    symlinkSync(join(root, 'bin/initdb.exe'), join(root, 'bin/psql.exe'));
    assert.throws(() => verifyRuntime(root), /路径链接/u);
  }
});
test('未闭合非系统DLL不得被清单或合法PE掩盖', t => {
  const { root } = fixture(t, 'unknown.dll');
  assert.throws(() => verifyRuntime(root), /未闭合DLL/u);
});

test('Windows交付脚本在成功消息前执行PE、DLL和清单验真且拒绝缺显式Node', () => {
  const source = readFileSync(new URL('./build_runtime.ps1', import.meta.url), 'utf8');
  assert.match(source, /TUYUBOOKING_NODE_BIN/u);
  assert.match(source, /verify-source[.]mjs/u);
  assert.ok(source.indexOf("'verify-source.mjs'") < source.indexOf('Write-Host "Materialized PostgreSQL'));
  assert.match(source, /\$LASTEXITCODE -ne 0.*throw 'PostgreSQL final runtime/u);
});
