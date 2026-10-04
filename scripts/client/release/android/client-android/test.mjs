import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

test('tuyubooking.client-android.release的client-android远端Job物理独立', () => {
  const source = readFileSync(new URL('./execute.mjs', import.meta.url), 'utf8');
  assert.ok(source.includes('{"pipeline":"tuyubooking.client-android.release","job":"client-android"}'));
  assert.match(source, /function runExactWorkflowStep\(index\)/u);
  assert.match(source, /function requireExactRemoteJobEnvironment\(\)/u);
});

test('途遇商家主机与分机共用源码种子但各平台独立从1.0.0发布', () => {
  const pubspec = readFileSync(new URL('../../../../../app/pubspec.yaml', import.meta.url), 'utf8');
  assert.match(pubspec, /^version: 1\.0\.0\+1$/mu);
});
