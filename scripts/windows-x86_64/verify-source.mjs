import { createHash } from 'node:crypto';
import { lstatSync, readFileSync, readdirSync, realpathSync } from 'node:fs';
import { isAbsolute, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../..', import.meta.url));
const fail = message => { throw new Error('PostgreSQL运行时验真：' + message); };
const inside = (parent, path) => { const part = relative(parent, path); return !part || (!part.startsWith('..' + sep) && part !== '..' && !isAbsolute(part)); };

// PE32+及导入表都受完整字节边界约束；截断、错误架构、越界RVA和未终止DLL名称立即失败。
export function peImports(bytes) {
  const range = (offset, size) => {
    if (!Number.isSafeInteger(offset) || !Number.isSafeInteger(size) || offset < 0 || size < 0
      || offset + size > bytes.length) fail('PE字节范围无效');
    return offset;
  };
  range(0, 64);
  if (bytes.readUInt16LE(0) !== 0x5a4d) fail('缺少MZ头');
  const header = bytes.readUInt32LE(0x3c); range(header, 24);
  if (bytes.readUInt32LE(header) !== 0x00004550 || bytes.readUInt16LE(header + 4) !== 0x8664) fail('必须是x86-64 PE');
  const count = bytes.readUInt16LE(header + 6), optionalSize = bytes.readUInt16LE(header + 20);
  if (!count || count > 96 || optionalSize < 128) fail('PE节表或可选头无效');
  const optional = header + 24; range(optional, optionalSize);
  if (bytes.readUInt16LE(optional) !== 0x20b) fail('必须是PE32+');
  const directories = bytes.readUInt32LE(optional + 108);
  if (directories < 2 || 112 + Math.min(directories, 16) * 8 > optionalSize) fail('PE数据目录无效');
  const sections = optional + optionalSize; range(sections, count * 40);
  const headersSize = bytes.readUInt32LE(optional + 60);
  const mapped = (rva, size) => {
    if (rva < headersSize) return range(rva, size);
    for (let index = 0; index < count; index++) {
      const at = sections + index * 40;
      const address = bytes.readUInt32LE(at + 12), rawSize = bytes.readUInt32LE(at + 16), raw = bytes.readUInt32LE(at + 20);
      const distance = rva - address;
      if (distance >= 0 && distance + size <= rawSize) return range(raw + distance, size);
    }
    fail('导入表RVA不在文件节内');
  };
  const rva = bytes.readUInt32LE(optional + 120), size = bytes.readUInt32LE(optional + 124);
  if (!rva && !size) return [];
  if (!rva || size < 20 || size > 16 * 1024 * 1024) fail('导入表长度无效');
  mapped(rva, size);
  const imports = [];
  for (let offset = 0; offset + 20 <= size; offset += 20) {
    const at = mapped(rva + offset, 20);
    const descriptor = [0, 4, 8, 12, 16].map(part => bytes.readUInt32LE(at + part));
    if (descriptor.every(value => value === 0)) return imports;
    const nameRva = descriptor[3];
    if (!nameRva) fail('DLL导入名称缺失');
    let name = '', ended = false;
    for (let index = 0; index <= 255; index++) {
      const char = bytes[mapped(nameRva + index, 1)];
      if (!char) { ended = true; break; }
      if (char > 127) fail('DLL导入名称非ASCII');
      name += String.fromCharCode(char);
    }
    if (!ended || !/^[a-z0-9_.-]+\.(?:dll|drv)$/iu.test(name)) fail('DLL导入名称无效');
    imports.push(name.toLowerCase());
  }
  fail('导入表没有终止项');
}

const systemDLLs = new Set(('advapi32.dll bcrypt.dll comctl32.dll comdlg32.dll crypt32.dll gdi32.dll iphlpapi.dll kernel32.dll '
  + 'msimg32.dll msvcrt.dll ole32.dll oleacc.dll oleaut32.dll pdh.dll rpcrt4.dll secur32.dll shell32.dll shlwapi.dll '
  + 'user32.dll uxtheme.dll version.dll winmm.dll winspool.drv wldap32.dll ws2_32.dll').split(' '));

export function verifyRuntime(input, { productRoot = root } = {}) {
  if (!isAbsolute(input) || resolve(input) !== input || realpathSync(input) !== input
    || !lstatSync(input).isDirectory() || inside(productRoot, input) || inside(input, productRoot)) fail('必须提供源码外规范真实目录');
  const paths = [];
  function visit(directory) {
    for (const name of readdirSync(directory)) {
      const path = join(directory, name), stat = lstatSync(path);
      if (stat.isSymbolicLink() || realpathSync(path) !== path) fail('运行时禁止路径链接');
      if (stat.isDirectory()) visit(path);
      else if (stat.isFile()) paths.push(relative(input, path).split(sep).join('/'));
      else fail('运行时包含特殊文件');
    }
  }
  visit(input);
  const files = new Set(paths);
  for (const path of ['bin/postgres.exe', 'bin/initdb.exe', 'bin/pg_ctl.exe', 'bin/psql.exe',
    'server_license.txt', 'commandlinetools_3rd_party_licenses.txt', 'MANIFEST.sha256']) {
    if (!files.has(path)) fail('缺少文件：' + path);
  }
  for (const path of paths) if (path === 'bin/stackbuilder.exe' || /^bin\/wx[^/]*\.dll$/iu.test(path)
    || /^lib\/(?:plperl|plpython3|pltcl|bool_plperl|hstore_plperl|hstore_plpython3|jsonb_plperl|jsonb_plpython3|ltree_plpython3)\.dll$/u.test(path)) {
    fail('存在已裁剪解释器或StackBuilder');
  }
  const manifest = new Map();
  for (const line of readFileSync(join(input, 'MANIFEST.sha256'), 'utf8').split(/\r?\n/u).filter(Boolean)) {
    const match = /^([a-f0-9]{64}) [ *](.+)$/u.exec(line);
    if (!match || match[2].startsWith('/') || match[2].includes('\\')
      || match[2].split('/').some(part => !part || part === '.' || part === '..')
      || match[2] === 'MANIFEST.sha256' || manifest.has(match[2])) fail('清单路径无效或重复');
    manifest.set(match[2], match[1]);
  }
  if (manifest.size !== files.size - 1 || [...files].some(path => path !== 'MANIFEST.sha256' && !manifest.has(path))) fail('清单与实际文件不一一对应');
  for (const [path, digest] of manifest) {
    if (!files.has(path) || createHash('sha256').update(readFileSync(join(input, path))).digest('hex') !== digest) fail('清单摘要不符：' + path);
  }
  const bundled = new Set(paths.filter(path => /^(?:bin|lib)\//u.test(path)).map(path => path.split('/').at(-1).toLowerCase()));
  for (const path of paths.filter(path => /^(?:bin|lib)\/.*\.(?:exe|dll)$/iu.test(path))) {
    for (const dependency of peImports(readFileSync(join(input, path)))) {
      if (!dependency.startsWith('api-ms-win-') && !dependency.startsWith('ext-ms-win-')
        && !systemDLLs.has(dependency) && !bundled.has(dependency)) fail('未闭合DLL依赖：' + dependency);
    }
  }
  if (!readFileSync(join(input, 'bin/postgres.exe')).includes(Buffer.from('postgres (PostgreSQL) 17.11'))) fail('PostgreSQL版本字符串不符');
  return input;
}
if (!(process.env.NODE_TEST_CONTEXT && process.argv.length === 2) && process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    if (process.argv.length !== 3) fail('需要且仅接受一个运行时目录');
    process.stdout.write(verifyRuntime(process.argv[2]) + '\n');
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}

// 正式实现结束；仅直接使用 node --test 执行本文件时注册以下回归。
if (process.env.NODE_TEST_CONTEXT && process.argv.length === 2 && !process.execArgv.some(value=>/^(?:-e|--eval(?:=|$)|--input-type(?:=|$))/u.test(value)) && process.argv[1] && import.meta.url === (await import('node:url')).pathToFileURL((await import('node:path')).resolve(process.argv[1])).href) {
const {default:test} = await import('node:test');
const {default:assert} = await import('node:assert/strict');
const { createHash } = await import('node:crypto');
const { mkdirSync, mkdtempSync, realpathSync, readdirSync, readFileSync, rmSync, symlinkSync, writeFileSync } = await import('node:fs');
const { join } = await import('node:path');
const { testRoot:tmpdir } = await import('../build.mjs');


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

}
