#!/usr/bin/env node
// 商家Voyant使用官方middleware输出；所有请求与WebSocket升级都先通过TLS。
import { readFile } from 'node:fs/promises';
import { createServer } from 'node:https';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const [entry, certificate, privateKey, rawPort] = process.argv.slice(2);
if (!entry || !certificate || !privateKey || ![entry, certificate, privateKey].every(path.isAbsolute)
    || !/^[1-9][0-9]*$/.test(rawPort ?? '') || Number(rawPort) > 65535
    || process.argv.length !== 6) {
  throw new Error('Voyant HTTPS requires absolute middleware/certificate/key paths and a valid port');
}
const tls = { cert: await readFile(certificate), key: await readFile(privateKey), minVersion: 'TLSv1.2' };
const runtime = await import(pathToFileURL(entry).href);
if (typeof runtime.middleware !== 'function') throw new Error('Voyant middleware export is missing');
const server = createServer(tls, runtime.middleware);
server.on('upgrade', (request, socket, head) => {
  // 未声明WebSocket处理器时关闭连接，不构造第二个明文服务器。
  if (typeof runtime.handleUpgrade === 'function') runtime.handleUpgrade(request, socket, head);
  else socket.destroy();
});
server.listen(Number(rawPort), '127.0.0.1');
let stopping = false;
for (const signal of ['SIGTERM', 'SIGINT']) process.on(signal, () => {
  if (stopping) return;
  stopping = true;
  server.close(() => process.exit(0));
  setTimeout(() => { server.closeAllConnections(); process.exit(1); }, 10000).unref();
});
