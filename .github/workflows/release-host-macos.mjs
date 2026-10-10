#!/usr/bin/env node
import {bookingRelease} from './release-client-android.mjs';
// 本仓本目标的完整自动化只由同名Workflow调用；版本与产物均在GitHub生成。
import { createHash } from 'node:crypto';
import { spawnSync, execFileSync } from 'node:child_process';
import { appendFileSync, copyFileSync, createReadStream, existsSync, lstatSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { basename, dirname, isAbsolute, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

export const owner = Object.freeze({
  "product": "tuyubooking",
  "platform": "host-macos",
  "repository": "tuyutata/tuyubooking",
  "version_source": {
    "kind": "pubspec",
    "path": "app/pubspec.yaml"
  },
  "required_assets": [],
  "asset_locations": [
    "$RELEASE_DIR",
    "$RUNNER_TEMP/tuyubooking-host-release"
  ],
  "asset_patterns": [
    "*.tgz",
    "*.zip",
    "*.ipa",
    "*.apk",
    "*.aab",
    "*.json",
    "SHA256SUMS",
    "tuyubooking-host-macos.zip"
  ],
  "required_patterns": [
    "tuyubooking-host-macos.zip",
    "release-manifest.json",
    "SHA256SUMS"
  ]
});
const commands = Object.freeze({
  "2": {
    "shell": "bash",
    "source": "# 安装后先验真，再统一准备目标平台缓存与受控修订。\nflutter --version --machine >/dev/null\nplatform=\"macos\"\nflutter --version >/dev/null"
  },
  "3": {
    "shell": "bash",
    "source": "set -euo pipefail\n\nnode \"$GITHUB_WORKSPACE/.github/workflows/release-host-macos.mjs\" action package build-release"
  },
  "1": {
    "shell": "bash",
    "source": "printf 'version=3.47.2\n' >> \"$GITHUB_OUTPUT\""
  }
});
const actions = Object.freeze({
  "package": {
    "source": "#!/usr/bin/env node\nimport { execFileSync, spawnSync } from 'node:child_process';\nimport { createHash } from 'node:crypto';\nimport { cpSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';\nimport { dirname, join } from 'node:path';\nimport { preparePostgresRuntime } from '__PRODUCT_URL__.github/workflows/release-host-macos.mjs__END_URL__';\nconst identity = Object.freeze({ product: 'tuyubooking', platform: 'host-macos', prefix: 'tuyubooking-host-macos-v',   artifact: 'tuyubooking-host-macos.zip' });\nconst root = process.cwd(); const output = join(process.env.RUNNER_TEMP || '/tmp', 'tuyubooking-host-release');\nfunction required(value, message) { if (!value) throw new Error(message); }\n\n\nfunction run(file, args, cwd = root) { execFileSync(file, args, { cwd, stdio: 'inherit', env: process.env }); }\nfunction hash(path) { return createHash('sha256').update(readFileSync(path)).digest('hex'); }\nfunction inputs() { return {repository:process.env.GITHUB_REPOSITORY,source:process.env.SOURCE_SHA,sourceSHA:process.env.SOURCE_SHA,version:process.env.SOFTWARE_VERSION,tag:process.env.VERSION_TAG,runID:process.env.GITHUB_RUN_ID,runId:process.env.GITHUB_RUN_ID}; }\nfunction verify(value) { if (execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim() !== process.env.SOURCE_SHA) throw new Error('本仓源码提交不一致'); }\n\nfunction manifest(value) { const asset = join(output, identity.artifact); required(existsSync(asset), 'macOS 正式资产不存在'); const body = { product_id: identity.product, platform: identity.platform, software_version: value.version, git_commit_sha: value.source, producer_run_id: Number(value.runID), assets: [{ name: identity.artifact, sha256: hash(asset) }] }; const manifestPath = join(output, 'release-manifest.json'); writeFileSync(manifestPath, `${JSON.stringify(body, null, 2)}\\n`); writeFileSync(join(output, 'SHA256SUMS'), `${[`${hash(asset)}  ${identity.artifact}`, `${hash(manifestPath)}  release-manifest.json`].sort().join('\\n')}\\n`); }\nasync function build(value) { verify(value); mkdirSync(output); run('git', ['submodule', 'status', '--recursive']); const work = join(output, 'work'); mkdirSync(work); process.env.TUYUBOOKING_ROOT = root; process.env.CARGO_TARGET_DIR = join(work, 'cargo'); const sourceApp = join(root, 'app'); const application = execFileSync(process.execPath, [join(sourceApp, 'scripts/project.mjs'), 'create', '--source-root', sourceApp, '--work-root', work, '--platform', 'macos'], { encoding: 'utf8', env: process.env }).trim(); run('flutter', ['pub', 'get', '--enforce-lockfile'], application); run(process.execPath, [join(sourceApp, 'scripts/project.mjs'), 'native', '--source-root', sourceApp, '--work-root', work, '--output', application, '--platform', 'macos']); process.env.TUYU_POSTGRES_BIN = await preparePostgresRuntime('macos', work); run('cargo', ['test', '--workspace', '--locked'], root); run('cargo', ['build', '--release', '--locked', '-p', 'tuyubooking-native'], root); run('flutter', ['build', 'macos', '--release', '--target', 'lib/main_host.dart', `--build-name=${value.version}`, '--dart-define=TUYU_SERVE_URL=https://serve.tuyulove.com'], application); const products = join(application, 'build/macos/Build/Products/Release'); const appNames = readdirSync(products).filter((name) => name.endsWith('.app')); required(appNames.length === 1, 'macOS Release App 数量无效'); const app = join(products, appNames[0]); cpSync(dirname(process.env.TUYU_POSTGRES_BIN), join(app, 'Contents/Resources/postgresql'), { recursive: true }); const executableName = execFileSync('/usr/libexec/PlistBuddy', ['-c', 'Print :CFBundleExecutable', join(app, 'Contents/Info.plist')], { encoding: 'utf8' }).trim(); const executable = join(app, 'Contents/MacOS', executableName); const librarySource = join(process.env.CARGO_TARGET_DIR, 'release/libtuyubooking_native.dylib'); required(existsSync(executable) && existsSync(librarySource), 'macOS 原生二进制未生成'); required(execFileSync('lipo', ['-archs', executable], { encoding: 'utf8' }).trim() === 'arm64', 'macOS App 不是纯 ARM64'); required(execFileSync('lipo', ['-archs', librarySource], { encoding: 'utf8' }).trim() === 'arm64', 'macOS Rust 动态库不是纯 ARM64'); const frameworks = join(app, 'Contents/Frameworks'); mkdirSync(frameworks, { recursive: true }); cpSync(librarySource, join(frameworks, 'libtuyubooking_native.dylib')); run('codesign', ['--force', '--deep', '--sign', '-', app]); run('codesign', ['--verify', '--deep', '--strict', app]); run('ditto', ['-c', '-k', '--keepParent', app, join(output, identity.artifact)]); manifest(value); }\n\n\nconst command=process.argv[2];\nif(command==='build-release'){await build({...inputs(),build:process.env.GITHUB_RUN_NUMBER});}else{throw new Error('本仓组包动作无效');}\n",
    "shell": "node"
  }
});
const shaPattern = /^[0-9a-f]{40}$/u;
const fail = message => { throw new Error(message); };
const root = fileURLToPath(new URL('../../', import.meta.url));
const workflowPath = `.github/workflows/release-${owner.platform}.yml`;
const prefix = `${owner.product}-${owner.platform}-v`;

export function context(environment = process.env) {
  const number = name => {
    const value = environment[name];
    if (!/^[1-9][0-9]*$/u.test(value || '') || !Number.isSafeInteger(Number(value))) fail('GitHub运行坐标无效');
    return Number(value);
  };
  if (environment.GITHUB_ACTIONS !== 'true' || environment.GITHUB_REPOSITORY !== owner.repository
    || environment.GITHUB_REF !== 'refs/heads/main' || environment.GITHUB_EVENT_NAME !== 'workflow_dispatch'
    || !shaPattern.test(environment.GITHUB_SHA || '')
    || environment.GITHUB_WORKFLOW_REF !== `${owner.repository}/${workflowPath}@refs/heads/main`) fail('所属GitHub运行身份无效');
  return { repository: owner.repository, product_id: owner.product, platform: owner.platform,
    source_sha: environment.GITHUB_SHA, run_id: number('GITHUB_RUN_ID'),
    run_number: number('GITHUB_RUN_NUMBER'), run_attempt: number('GITHUB_RUN_ATTEMPT'), workflow: workflowPath };
}

export async function request(path, { method = 'GET', body, raw = false, size, fetch: send = globalThis.fetch } = {}) {
  const token = process.env.GH_TOKEN || process.env.GITHUB_TOKEN;
  if (!token || /[\s\u0000-\u001f\u007f]/u.test(token)) fail('缺少GitHub任务令牌');
  const url = path.startsWith('https://') ? new URL(path) : new URL(`https://api.github.com/repos/${owner.repository}/${path}`);
  if (!['api.github.com', 'uploads.github.com'].includes(url.hostname) || url.protocol !== 'https:' || url.username || url.password || !url.pathname.startsWith(`/repos/${owner.repository}/`)) fail('GitHub接口地址无效');
  const headers = { Authorization: `Bearer ${token}`, Accept: raw ? 'application/octet-stream' : 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2026-03-10', 'User-Agent': owner.product };
  if (body !== undefined) headers['Content-Type'] = body?.pipe ? 'application/octet-stream' : 'application/json';
  if(body?.pipe){if(!Number.isSafeInteger(size)||size<=0)fail('资产上传长度无效');headers['Content-Length']=String(size);}
  let response = await send(url, { method, headers, redirect: raw ? 'manual' : 'error', signal: AbortSignal.timeout(300_000),
    ...(body === undefined ? {} : { body: body?.pipe ? body : JSON.stringify(body), ...(body?.pipe ? { duplex: 'half' } : {}) }) });
  if(raw&&response.status===302){
    const location=new URL(response.headers.get('location'));
    if(location.protocol!=='https:'||location.username||location.password)fail('正式资产回读地址无效');
    response=await send(location,{method:'GET',redirect:'error',credentials:'omit',signal:AbortSignal.timeout(300_000)});
  }
  if (response.status === 404) return null;
  if (!response.ok) fail(`GitHub接口失败：${response.status}，操作未确认`);
  if (raw) return response;
  return response.status === 204 ? {} : response.json();
}

export async function pages(path, field = null, api = request) {
  const rows = [];
  for (let page = 1; ; page++) {
    const data = await api(`${path}${path.includes('?') ? '&' : '?'}per_page=100&page=${page}`);
    const values = field ? data?.[field] : data;
    if (!Array.isArray(values)) fail('GitHub分页数据无效');
    rows.push(...values);
    if (values.length < 100) return rows;
  }
}

function seedVersion() {
  const source = owner.version_source;
  if (source.kind === 'sequence') return '0.0.0';
  const text = readFileSync(join(root, source.path), 'utf8');
  if (source.kind === 'json') return String(JSON.parse(text).version);
  if (source.kind === 'spec') {
    const matches = [...text.matchAll(/^\s*spec_version:\s*(\d+)\s*,\s*$/gm)];
    if (matches.length !== 1) fail('Runtime版本真源不唯一');
    return matches[0][1];
  }
  if (source.kind === 'cargo') {
    const value = /^\[package\][\s\S]*?^version\s*=\s*"(\d+\.\d+\.\d+)"/mu.exec(text)?.[1];
    if (!value) fail('本仓Cargo版本真源无效');
    return value;
  }
  const value = /^version:\s*(\d+\.\d+\.\d+)(?:\+\d+)?\s*$/mu.exec(text)?.[1];
  if (!value) fail('本仓软件版本真源无效');
  return value;
}

export function nextVersion(seed, versions, protocol = false, runNumber = 1) {
  if (protocol) {
    if (!/^\d+$/u.test(seed) || versions.some(value => !/^\d+$/u.test(value))) fail('协议版本无效');
    const value = Math.max(Number(seed), ...versions.map(Number)) + (versions.length ? 1 : 0);
    if (!Number.isSafeInteger(value) || value < 1 || value > 0xffffffff) fail('协议版本越界');
    return String(value);
  }
  const parse = value => {
    const match = /^(0|[1-9]\d*)\.(0|[1-9]\d?)\.(0|[1-9]\d?)$/u.exec(value);
    if (!match) fail('软件版本无效');
    const parts=match.slice(1).map(Number);if(parts.some(value=>!Number.isSafeInteger(value)))fail('软件版本越界');return parts;
  };
  const values = [seed, ...versions].map(parse).sort((a,b) => a[0]-b[0] || a[1]-b[1] || a[2]-b[2]);
  let [major, minor, patch] = values.at(-1);
  if (versions.length) { if (++patch > 99) { patch = 0; if (++minor > 99) { minor = 0; major++; } } }
  if(!Number.isSafeInteger(runNumber)||runNumber<1)fail('版本运行序号无效');
  const initial=parse(seed),floor=BigInt(initial[0])*10000n+BigInt(initial[1])*100n+BigInt(initial[2])+BigInt(runNumber-1);
  const historical=BigInt(major)*10000n+BigInt(minor)*100n+BigInt(patch);
  if(floor>historical){major=Number(floor/10000n);minor=Number(floor/100n%100n);patch=Number(floor%100n);}
  if(![major,minor,patch].every(Number.isSafeInteger))fail('软件版本越界');
  return `${major}.${minor}.${patch}`;
}

function output(name, value, file = process.env.GITHUB_OUTPUT) {
  if (!file || /[\r\n]/u.test(String(value))) fail('GitHub步骤输出无效');
  appendFileSync(file, `${name}=${value}\n`);
}

export async function prepare() {
  const identity = context();
  const releases = await pages('releases');
  const versions = [];
  for (const release of releases) {
    if (release.draft || release.prerelease || !String(release.tag_name).startsWith(prefix)) continue;
    const notes = (await bookingRelease(release,owner.platform,tag=>request('git/ref/tags/'+encodeURIComponent(tag))));
    if (!notes || notes.platform !== owner.platform) continue;
    const run = await request(`actions/runs/${notes.run_id}`);
    if (run?.status === 'completed' && run.conclusion === 'success' && run.path === workflowPath) versions.push(notes.version);
  }
  const version = nextVersion(seedVersion(), versions, owner.version_source.kind === 'spec', identity.run_number);
  const tag = `${prefix}${version}-r${identity.run_id}-a${identity.run_attempt}`;
  for (const [name,value] of Object.entries({version, tag, source_sha:identity.source_sha,
    run_id:identity.run_id, run_attempt:identity.run_attempt, run_number:identity.run_number})) output(name,value);
}

function runVersion() {
  const identity = context();
  const version = process.env.RELEASE_VERSION;
  const tag = process.env.RELEASE_TAG;
  nextVersion(version, [], owner.version_source.kind === 'spec');
  if (tag !== `${prefix}${version}-r${identity.run_id}-a${identity.run_attempt}`) fail('本次版本与Tag不一致');
  return {...identity, version, tag};
}

export function job() {
  const identity = runVersion();
  if (execFileSync('git', ['rev-parse','HEAD'], {cwd:root,encoding:'utf8'}).trim() !== identity.source_sha) fail('检出源码不符');
  const work = join(process.env.RUNNER_TEMP, owner.product, owner.platform, String(identity.run_id), String(identity.run_attempt), process.env.GITHUB_JOB);
  mkdirSync(work,{recursive:true});
  const variables = {RELEASE_WORK:work, RELEASE_ASSETS_DIR:join(work,'assets'), SOURCE_SHA:identity.source_sha,
    SOFTWARE_VERSION:identity.version, VERSION_TAG:identity.tag, BUILD_NUMBER:String(identity.run_number),
    CARGO_HOME:join(work,'cargo-home'), CARGO_TARGET_DIR:join(work,'cargo'), PUB_CACHE:join(work,'pub'),
    GRADLE_USER_HOME:join(work,'gradle'), npm_config_cache:join(work,'npm'), XDG_CACHE_HOME:join(work,'cache'),
    TMPDIR:join(work,'tmp'), TMP:join(work,'tmp'), TEMP:join(work,'tmp')};
  for (const path of ['cargo-home','cargo','pub','gradle','npm','cache','tmp','assets']) mkdirSync(join(work,path),{recursive:true});
  for (const [name,value] of Object.entries(variables)) { process.env[name]=value; output(name,value,process.env.GITHUB_ENV); }
}

export function step(key) {
  runVersion();
  const value = commands[key];
  if (!value || !['bash','pwsh'].includes(value.shell)) fail('本目标构建步骤无效');
  const directory = join(process.env.RELEASE_WORK,'commands');mkdirSync(directory,{recursive:true});
  const file = join(directory, value.shell === 'pwsh' ? 'step.ps1' : 'step.sh');
  writeFileSync(file, value.shell === 'bash' ? 'set -euo pipefail\n'+value.source : "$ErrorActionPreference = 'Stop'\n"+value.source,{mode:0o700});
  const result = spawnSync(value.shell === 'pwsh' ? 'pwsh' : 'bash', value.shell === 'pwsh' ? ['-NoProfile','-File',file] : [file],
    {cwd:process.cwd(),env:process.env,stdio:'inherit'});
  rmSync(file,{force:true});
  if (result.error || result.status !== 0) fail(`本仓构建步骤失败：${key}`);
}

export function action(name, args) {
  runVersion();
  const value = actions[name];if (!value) fail('本目标动作无效');
  const directory = join(process.env.RELEASE_WORK,'commands');mkdirSync(directory,{recursive:true});
  const file = join(directory,value.shell === 'bash'?'action.sh':'action.mjs');
  const source=value.source.replace(/__PRODUCT_URL__([^'"\s]+)__END_URL__/gu,(_,path)=>pathToFileURL(join(root,path)).href);
  writeFileSync(file,source,{mode:0o700});
  const result=spawnSync(value.shell==='bash'?'bash':process.execPath,[file,...args],{cwd:root,env:process.env,stdio:'inherit'});
  rmSync(file,{force:true});if(result.error||result.status!==0)fail(`本仓动作失败：${name}`);
}

function regular(path) {
  const stat=lstatSync(path);if(!stat.isFile()||stat.isSymbolicLink()||stat.size<=0)fail('正式产物不是非空普通文件');return stat;
}
async function digestFile(path) { const hash=createHash('sha256');for await(const bytes of createReadStream(path))hash.update(bytes);return hash.digest('hex'); }
function assetName(name) { if(!name||name!==basename(name)||/[\u0000-\u001f\u007f]/u.test(name))fail('正式资产文件名无效');return name; }

export async function collect(paths) {
  const identity=runVersion(),destination=process.env.RELEASE_ASSETS_DIR;
  if(!destination||!paths.length)fail('本仓没有完整产物');mkdirSync(destination,{recursive:true});
  const files=[];
  for(const path of paths){const file=resolve(path),stat=regular(file),name=assetName(basename(file));
    if(files.some(row=>row.name===name))fail('正式资产重名');
    const target=join(destination,name);if(file!==target)copyFileSync(file,target);
    files.push({name,size:stat.size,sha256:await digestFile(target)});
  }
  if(owner.required_assets.some(name=>!files.some(row=>row.name===name)))fail('本目标必要产物缺失');
  const metadata={schema:1,...identity,assets:files};
  writeFileSync(join(destination,'automation.json'),JSON.stringify(metadata,null,2)+'\n');
  output('assets',destination);return metadata;
}

export async function collectProduced() {
  const paths=[],seen=new Set();
  const expand=value=>value.replace(/\$\{([A-Z_]+)\}|\$([A-Z_]+)/gu,(_,a,b)=>process.env[a||b]||'');
  for(const location of owner.asset_locations){
    const path=expand(location);if(!path||!existsSync(path))continue;
    const candidates=lstatSync(path).isDirectory()?readdirSync(path).map(name=>join(path,name)):[path];
    for(const candidate of candidates){if(!lstatSync(candidate).isFile()||seen.has(resolve(candidate)))continue;
      const name=basename(candidate);if(!owner.asset_patterns.some(pattern=>new RegExp('^'+pattern.replace(/[.+?^${}()|[\]\\]/gu,'\\$&').replaceAll('*','.*')+'$','u').test(name)))continue;
      seen.add(resolve(candidate));paths.push(candidate);
    }
  }
  if(owner.required_patterns.some(pattern=>!paths.some(path=>new RegExp('^'+pattern.replace(/[.+?^${}()|[\]\\]/gu,'\\$&').replaceAll('*','.*')+'$','u').test(basename(path)))))fail('本目标完整正式资产缺失');
  return collect(paths);
}



export async function publish(directory) {
  const identity=runVersion();const metadata=JSON.parse(readFileSync(join(directory,'automation.json'),'utf8'));
  if(Object.entries(identity).some(([key,value])=>metadata[key]!==value)||!Array.isArray(metadata.assets)||!metadata.assets.length)fail('完整产物身份无效');
  const files=metadata.assets;
  if(readdirSync(directory).sort().join('\0')!==[...files.map(value=>value.name),'automation.json'].sort().join('\0'))fail('产物目录与完整资产集合不符');
  for(const file of files){const path=join(directory,assetName(file.name));if(regular(path).size!==file.size||await digestFile(path)!==file.sha256)fail('正式产物在交付前改变');}
  if(await request(`git/ref/tags/${encodeURIComponent(identity.tag)}`)!==null)fail('本次Tag已经存在');
  await request('git/refs',{method:'POST',body:{ref:`refs/tags/${identity.tag}`,sha:identity.source_sha}});
  const release=await request('releases',{method:'POST',body:{tag_name:identity.tag,target_commitish:identity.source_sha,
    name:`${owner.product} · ${owner.platform} · ${identity.version}`,draft:false,prerelease:false,make_latest:'false',
    body:`${owner.product} · ${owner.platform} · ${identity.version}\nSource: ${identity.source_sha}\nRun: ${identity.run_id} / ${identity.run_attempt}`}});
  if(!Number.isSafeInteger(release?.id)||!release.upload_url)fail('正式Release创建未确认');
  for(const file of files){const url=new URL(release.upload_url.replace(/\{.*$/u,''));url.searchParams.set('name',file.name);
    const asset=await request(url.href,{method:'POST',body:createReadStream(join(directory,file.name)),size:file.size});
    if(asset?.name!==file.name||asset.size!==file.size||asset.state!=='uploaded')fail('正式资产上传未确认');
    const response=await request(asset.url,{raw:true});if(!response?.body)fail('正式资产回读失败');
    const hash=createHash('sha256');let size=0;for await(const bytes of response.body){hash.update(bytes);size+=bytes.length;if(size>file.size)fail('正式资产回读超过声明大小');}
    if(size!==file.size||hash.digest('hex')!==file.sha256)fail('GitHub资产逐件回读不一致');
  }
  const readback=await request(`releases/${release.id}`);if((await bookingRelease(readback,owner.platform,tag=>request('git/ref/tags/'+encodeURIComponent(tag))))?.run_id!==identity.run_id||readback.draft||readback.prerelease
    ||readback.assets?.length!==files.length)fail('完整正式Release回查失败');
  for(const file of files){const asset=readback.assets.find(value=>value.name===file.name);if(!asset||asset.state!=='uploaded'||asset.size!==file.size||asset.digest!==`sha256:${file.sha256}`)fail('完整正式资产证明回查失败');}
  output('verified','true');output('release_id',release.id);output('tag',identity.tag);
}

function ownedRun(run) {
  // 每个目标只处理自身现行Workflow；文件缺失不能证明历史任务归属。
  return Number.isSafeInteger(run?.id)&&run.id>0&&run.path===workflowPath
    &&run.head_branch==='main'&&run.event==='workflow_dispatch'
    &&(!run.repository||run.repository.full_name===owner.repository);
}

export function cleanupPlan(runs,current,result) {
  if(!['success','failed'].includes(result)||!ownedRun(current)||!Number.isFinite(Date.parse(current.created_at)))fail('清理所属任务身份无效');
  const earlier=run=>Date.parse(run.created_at)<Date.parse(current.created_at)
    ||Date.parse(run.created_at)===Date.parse(current.created_at)&&run.id<current.id;
  return runs.filter(run=>ownedRun(run)&&run.id!==current.id&&run.status==='completed'&&earlier(run)
    &&(run.conclusion==='success'?'success':'failed')===result).sort((a,b)=>a.id-b.id);
}

async function remove(path,api) { await api(path,{method:'DELETE'});const readPath=path.replace(/^git\/refs\//u,'git/ref/');if(await api(readPath)!==null)fail('删除回查仍存在，清理失败'); }
async function removeRunRelease(run,releases,api) {
  for(const release of releases){
    const metadata=(await bookingRelease(release,owner.platform,tag=>api('git/ref/tags/'+encodeURIComponent(tag))));
    if(!metadata||metadata.run_id!==run.id)continue;
    if(metadata.source_sha!==run.head_sha)fail('正式Release与所属Run不一致');
    const tag=metadata.tag;
    const again=await api(`actions/runs/${run.id}`);
    if(again&&again.id!==Number(process.env.GITHUB_RUN_ID)
      &&(again.status!=='completed'||again.run_attempt!==run.run_attempt||again.conclusion!==run.conclusion))fail('所属任务已变化，停止清理');
    await remove(`releases/${release.id}`,api);
    const beforeTag=await api(`actions/runs/${run.id}`);
    if(beforeTag&&beforeTag.id!==Number(process.env.GITHUB_RUN_ID)
      &&(beforeTag.status!=='completed'||beforeTag.run_attempt!==run.run_attempt||beforeTag.conclusion!==run.conclusion))fail('所属任务已变化，停止清理');
    await remove(`git/refs/tags/${encodeURIComponent(tag)}`,api);
  }
}
export async function cleanup(result,identity=context(),api=request) {
  const current=await api(`actions/runs/${identity.run_id}`);
  const plan=cleanupPlan(await pages('actions/runs','workflow_runs',api),current,result);
  const releases=await pages('releases',null,api),removed=[];
  for(const row of plan){const run=await api(`actions/runs/${row.id}`);if(!run){removed.push(row.id);continue;}
    if(run.run_attempt!==row.run_attempt||cleanupPlan([run],current,result).length!==1)continue;
    await removeRunRelease(run,releases,api);
    // 失败若只形成Tag也按它的准确Run坐标处理，不能留下同类孤立产物。
    const tags=await api(`git/matching-refs/tags/${prefix}`);
    if(!Array.isArray(tags))fail('所属Tag集合无效');
    for(const reference of tags){
      const tag=String(reference.ref||'').slice('refs/tags/'.length);
      if(!String(reference.ref||'').startsWith('refs/tags/'+prefix)
        ||!new RegExp(`-r${run.id}-a[1-9][0-9]*$`,'u').test(tag)||Number(tag.slice(tag.lastIndexOf('-a')+2))>run.run_attempt)continue;
      if(reference.object?.type!=='commit'||reference.object.sha!==run.head_sha)fail('所属Tag来源已改变，停止清理');
      const again=await api(`actions/runs/${run.id}`);
      if(!again||cleanupPlan([again],current,result).length!==1)fail('所属任务已改变，停止清理');
      await remove(`git/refs/tags/${encodeURIComponent(tag)}`,api);
    }
    for(const asset of await pages(`actions/runs/${run.id}/artifacts`,'artifacts',api)){
      if(!Number.isSafeInteger(asset.id)||asset.id<=0)fail('所属Artifact坐标无效');
      const again=await api(`actions/runs/${run.id}`);if(!again||again.status!=='completed'||again.run_attempt!==run.run_attempt||again.conclusion!==run.conclusion)fail('历史任务已变化，停止清理');
      await remove(`actions/artifacts/${asset.id}`,api);
    }
    const final=await api(`actions/runs/${run.id}`);
    if(final&&(final.run_attempt!==run.run_attempt||cleanupPlan([final],current,result).length!==1))fail('历史任务状态改变，停止清理');
    if(final)await remove(`actions/runs/${run.id}`,api);removed.push(run.id);
  }
  return removed;
}

export function precedingResult(needs) {
  if(!needs||typeof needs!=='object'||Array.isArray(needs)||!Object.keys(needs).length)fail('前置任务结果缺失');
  return Object.values(needs).every(value=>value?.result==='success')?'success':'failed';
}
async function discardCurrent(identity,api) {
  for(const release of await pages('releases',null,api)){
    const metadata=(await bookingRelease(release,owner.platform,tag=>api('git/ref/tags/'+encodeURIComponent(tag))));
    if(metadata?.run_id===identity.run_id&&metadata.run_attempt===identity.run_attempt)
      await removeRunRelease({id:identity.run_id,head_sha:identity.source_sha},[release],api);
  }
  const tag=process.env.RELEASE_TAG;
  if(tag&&tag.startsWith(prefix)&&tag.endsWith(`-r${identity.run_id}-a${identity.run_attempt}`)){
    const path=`git/refs/tags/${encodeURIComponent(tag)}`;
    if(await api(path.replace(/^git\/refs\//u,'git/ref/'))!==null)await remove(path,api);
  }
}
export async function finish(needs=JSON.parse(process.env.RELEASE_NEEDS||'null'),api=request,identity=context()) {
  const result=precedingResult(needs),errors=[];
  const attempt=async action=>{try{return await action();}catch(error){errors.push(error);return null;}};
  let removed;
  if(result==='success') {
    removed=await attempt(()=>cleanup('success',identity,api));
    if(errors.length) {
      await attempt(()=>discardCurrent(identity,api));
      await attempt(()=>cleanup('failed',identity,api));
    }
  } else {
    // 本次撤销失败也必须尝试清理同目标旧失败；各项真实错误均保留。
    await attempt(()=>discardCurrent(identity,api));
    removed=await attempt(()=>cleanup('failed',identity,api));
  }
  if(errors.length)throw new AggregateError(errors,'本目标最后处理失败：'+errors.map(error=>error.message).join('；'));
  if(process.env.GITHUB_STEP_SUMMARY)appendFileSync(process.env.GITHUB_STEP_SUMMARY,`本目标${result==='success'?'成功':'失败'}；已清理同类旧Run：${removed.join('、')||'无'}。\n`);
  if(result==='failed')fail('前置任务未全部成功');
}

// 本目标实际构建与组包接口。
async function productCommand() { return false; }


// macOS/Windows主机PostgreSQL归自动化本身准备并验真，不调用本机Build。
const librariesInternals=await(async()=>{
const {createHash}=await import('node:crypto');
const {lstat,realpath,readFile,writeFile,mkdir,readdir}=await import('node:fs/promises');
const {join,resolve,isAbsolute}=await import('node:path');
const {fileURLToPath}=await import('node:url');

const root = resolve(fileURLToPath(new URL('../..', import.meta.url)));
const fail = message => { throw new Error('PostgreSQL编译闭包：' + message); };
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const readlinePatches = Object.freeze([
  ['readline83-001', '8.3.1', '21f0a03106dbe697337cd25c70eb0edbaa2bdb6d595b45f83285cdd35bac84de'],
  ['readline83-002', '8.3.2', 'e27364396ba9f6debf7cbaaf1a669e2b2854241ae07f7eca74ca8a8ba0c97472'],
  ['readline83-003', '8.3.3', '72dee13601ce38f6746eb15239999a7c56f8e1ff5eb1ec8153a1f213e4acdb29'],
]);
async function archivePlan() {
  const lock = JSON.parse(await readFile(join(root, 'host/database/licenses-macos.lock.json')));
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
function applyReadlinePatch(files, text) {
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
async function buildLibraries({ archives, work, sdk, gettext, openssl, environment, run, plan: getPlan = archivePlan }) {
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


return {archivePlan,applyReadlinePatch,buildLibraries};
})();
const postgresInternals=await(async()=>{
const {execFile}=await import('node:child_process');
const {promisify}=await import('node:util');
const {createHash}=await import('node:crypto');
const {lstat,mkdir,realpath,readdir,readFile,writeFile,copyFile}=await import('node:fs/promises');
const {dirname,join,resolve,basename,isAbsolute,relative}=await import('node:path');
const {fileURLToPath,pathToFileURL}=await import('node:url');
const {buildLibraries,archivePlan}=librariesInternals;

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
async function relocateRuntime({ destination, prefixes, environment, run }) {
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
async function copyPerlRuntime({ destination, perl, run }) {
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

async function buildPostgres(environment = process.env, { run: supplied, libraries = buildLibraries, plan: getPlan = archivePlan,
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
  const lock = JSON.parse(await readFile(join(root, 'host/database/licenses-macos.lock.json')));
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

return {relocateRuntime,copyPerlRuntime,buildPostgres};
})();
const windowsInternals=await(async()=>{
const {createHash}=await import('node:crypto');
const {lstatSync,readFileSync,readdirSync,realpathSync}=await import('node:fs');
const {isAbsolute,join,relative,resolve,sep}=await import('node:path');
const {fileURLToPath}=await import('node:url');

const root = fileURLToPath(new URL('../..', import.meta.url));
const fail = message => { throw new Error('PostgreSQL运行时验真：' + message); };
const inside = (parent, path) => { const part = relative(parent, path); return !part || (!part.startsWith('..' + sep) && part !== '..' && !isAbsolute(part)); };

// PE32+及导入表都受完整字节边界约束；截断、错误架构、越界RVA和未终止DLL名称立即失败。
function peImports(bytes) {
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

function verifyRuntime(input, { productRoot = root } = {}) {
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

return {peImports,verifyRuntime};
})();
const WINDOWS_POSTGRES_RUNTIME_SOURCE="[CmdletBinding()]\nparam(\n  [Parameter(Mandatory = $true)]\n  [string]$Destination,\n  [switch]$SkipRuntimeExecution\n)\n\n$ErrorActionPreference = 'Stop'\nSet-StrictMode -Version Latest\n\nif ($env:OS -ne 'Windows_NT') {\n  throw 'Windows x86-64 is required to materialize the release runtime.'\n}\n\n$architecture = if ($env:PROCESSOR_ARCHITEW6432) {\n  $env:PROCESSOR_ARCHITEW6432\n} else {\n  $env:PROCESSOR_ARCHITECTURE\n}\nif ($architecture -ne 'AMD64') {\n  throw \"Windows x86-64 is required; found $architecture.\"\n}\n\nif (Test-Path -LiteralPath $Destination) {\n  throw \"Runtime destination already exists: $Destination\"\n}\n\n# 产品锁决定PostgreSQL原件；普通开发者和CI使用同一依赖缓存合同。\n$root = (Resolve-Path $env:GITHUB_WORKSPACE).Path\n$workRoot = if ($env:TUYUBOOKING_WORK_DIR) { $env:TUYUBOOKING_WORK_DIR } else {\n  Join-Path $root 'target\\host-windows\\build\\runtime'\n}\n$dependencyRoot = if ($env:TUYUBOOKING_DEPENDENCY_DIR) { $env:TUYUBOOKING_DEPENDENCY_DIR } else {\n  Join-Path $workRoot 'dependencies'\n}\n# 当前可写路径必须归产品host-windows的target，并逐级拒绝重解析点。\n$targetBoundary = [System.IO.Path]::GetFullPath((Join-Path $root 'target\\host-windows'))\nforeach ($value in @($workRoot, $dependencyRoot, $Destination)) {\n  $full = [System.IO.Path]::GetFullPath($value)\n  if (![System.IO.Path]::IsPathRooted($value) -or $full -ne $value -or !$full.StartsWith($targetBoundary + [System.IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw '产品可写目录必须归本平台target' }\n  $ancestor = $full\n  while ($ancestor) {\n    if (Test-Path -LiteralPath $ancestor) {\n      $item = Get-Item -LiteralPath $ancestor -Force\n      if (!$item.PSIsContainer -or ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) { throw '产品输出路径不能经过链接或非目录' }\n    }\n    $ancestor = [System.IO.Path]::GetDirectoryName($ancestor)\n  }\n}\n$env:TEMP = Join-Path $workRoot 'tmp'\n$env:TMP = $env:TEMP\nNew-Item -ItemType Directory -Force -Path $env:TEMP | Out-Null\n$lock = Get-Content -LiteralPath (Join-Path $root 'host\\database\\postgresql-windows.lock.json') -Raw | ConvertFrom-Json\n$included = @('bin', 'lib', 'share', 'server_license.txt', 'commandlinetools_3rd_party_licenses.txt')\nif ($lock.component -ne 'postgresql' -or $lock.version -ne '17.11' -or\n    $lock.platform -ne 'windows-x86_64' -or $lock.source_root -ne 'pgsql' -or\n    -not $lock.source_sha256 -or $lock.source_sha256 -notmatch '^[a-f0-9]{64}$') {\n  throw 'Unexpected PostgreSQL runtime archive metadata.'\n}\n$uri = [Uri]$lock.source_url\nif ($uri.Scheme -ne 'https' -or -not [string]::IsNullOrEmpty($uri.UserInfo) -or\n    -not [string]::IsNullOrEmpty($uri.Fragment)) {\n  throw 'The locked PostgreSQL archive must use credential-free HTTPS.'\n}\nNew-Item -ItemType Directory -Path $dependencyRoot -Force | Out-Null\n$archive = if ($env:POSTGRES_SOURCE_ARCHIVE) { $env:POSTGRES_SOURCE_ARCHIVE } else {\n  Join-Path $dependencyRoot ([System.IO.Path]::GetFileName($uri.AbsolutePath))\n}\nif (-not (Test-Path -LiteralPath $archive -PathType Leaf)) {\n  $pending = \"$archive.pending.$PID\"\n  for ($attempt = 1; $attempt -le 3; $attempt++) {\n    Remove-Item -LiteralPath $pending -Force -ErrorAction SilentlyContinue\n    try {\n      Invoke-WebRequest -Uri $uri -OutFile $pending -MaximumRedirection 8\n      if ((Get-FileHash -LiteralPath $pending -Algorithm SHA256).Hash.ToLowerInvariant() -eq $lock.source_sha256) {\n        Move-Item -LiteralPath $pending -Destination $archive\n        break\n      }\n    } catch {\n      if ($attempt -eq 3) { throw }\n    }\n  }\n  Remove-Item -LiteralPath $pending -Force -ErrorAction SilentlyContinue\n}\nif ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $lock.source_sha256) {\n  throw 'PostgreSQL archive SHA256 differs from the runtime lock.'\n}\n$directory = Split-Path $Destination -Parent\n$dependency = [pscustomobject]@{\n  archive = $archive\n  extraction = (Join-Path $directory 'postgresql-extracted')\n  destination = $Destination\n  sourceRoot = $lock.source_root\n  sourceSize = [int64]$lock.source_size\n  included = $included\n}\nif ((Get-Item -LiteralPath $dependency.archive).Length -ne $dependency.sourceSize) {\n  throw 'PostgreSQL archive size differs from the runtime lock.'\n}\nif (Test-Path -LiteralPath $dependency.extraction) {\n  throw \"PostgreSQL extraction destination already exists: $($dependency.extraction)\"\n}\ntry {\n  Expand-Archive -LiteralPath $dependency.archive -DestinationPath $dependency.extraction\n  $Source = Join-Path $dependency.extraction $dependency.sourceRoot\n  foreach ($relative in @('bin', 'lib', 'share')) {\n    if (-not (Test-Path -LiteralPath (Join-Path $Source $relative) -PathType Container)) {\n      throw \"Missing PostgreSQL archive directory: pgsql/$relative\"\n    }\n  }\n  $required = @('bin\\postgres.exe', 'bin\\initdb.exe', 'bin\\pg_ctl.exe',\n    'bin\\psql.exe', 'server_license.txt', 'commandlinetools_3rd_party_licenses.txt')\n  foreach ($relative in $required) {\n    if (-not (Test-Path -LiteralPath (Join-Path $Source $relative) -PathType Leaf)) {\n      throw \"Missing PostgreSQL archive file: pgsql/$relative\"\n    }\n  }\n  New-Item -ItemType Directory -Path $Destination | Out-Null\n  foreach ($relative in $dependency.included) {\n    Copy-Item -LiteralPath (Join-Path $Source $relative) -Destination $Destination -Recurse\n  }\n  # 保全唯一改过的PostgreSQL测试工具；产品保留源码继续由既有打包器交付。\n  $testUtils = Join-Path $root 'host\\tests\\PostgreSQL-Test-Utils.pm'\n  if (-not (Test-Path -LiteralPath $testUtils -PathType Leaf)) { throw 'Missing retained PostgreSQL test utility.' }\n  Copy-Item -LiteralPath $testUtils -Destination (Join-Path $Destination 'lib\\pgxs\\src\\test\\perl\\PostgreSQL\\Test\\Utils.pm') -Force\n  # 延续既有服务端裁剪范围，不随官方完整归档引入额外解释器或 StackBuilder。\n  foreach ($relative in @('bin\\stackbuilder.exe', 'lib\\plperl.dll', 'lib\\plpython3.dll',\n    'lib\\pltcl.dll', 'lib\\bool_plperl.dll', 'lib\\hstore_plperl.dll',\n    'lib\\hstore_plpython3.dll', 'lib\\jsonb_plperl.dll', 'lib\\jsonb_plpython3.dll',\n    'lib\\ltree_plpython3.dll')) {\n    $excluded = Join-Path $Destination $relative\n    if (Test-Path -LiteralPath $excluded) { Remove-Item -LiteralPath $excluded -Force }\n  }\n  Get-ChildItem -LiteralPath (Join-Path $Destination 'bin') -Filter 'wx*.dll' -File |\n    Remove-Item -Force\n} finally {\n  if (Test-Path -LiteralPath $dependency.extraction) {\n    Remove-Item -LiteralPath $dependency.extraction -Recurse -Force\n  }\n}\n\n$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\\Installer\\vswhere.exe'\nif (-not (Test-Path -LiteralPath $vswhere)) {\n  throw 'Visual Studio 2022 vswhere.exe was not found.'\n}\n$installation = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath\nif (-not $installation) {\n  throw 'Visual Studio C++ x64 tools were not found.'\n}\n$crtDirectory = Get-ChildItem -LiteralPath (Join-Path $installation 'VC\\Redist\\MSVC') -Directory |\n  Sort-Object Name -Descending |\n  ForEach-Object { Join-Path $_.FullName 'x64\\Microsoft.VC143.CRT' } |\n  Where-Object { Test-Path -LiteralPath (Join-Path $_ 'vcruntime140.dll') } |\n  Select-Object -First 1\nif (-not $crtDirectory) {\n  throw 'Microsoft VC143 x64 redistributable directory was not found.'\n}\nforeach ($name in @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {\n  Copy-Item -LiteralPath (Join-Path $crtDirectory $name) -Destination (Join-Path $Destination 'bin')\n}\n$redistRoot = Split-Path (Split-Path $crtDirectory -Parent) -Parent\n$redistLicense = Get-ChildItem -LiteralPath $redistRoot -Filter 'license*.rtf' -File -Recurse |\n  Select-Object -First 1\nif ($redistLicense) {\n  Copy-Item -LiteralPath $redistLicense.FullName -Destination (Join-Path $Destination 'Microsoft-Visual-CPP-Runtime-LICENSE.rtf')\n}\n\nif (-not $SkipRuntimeExecution) {\n  $version = & (Join-Path $Destination 'bin\\postgres.exe') --version 2>&1\n  if ($LASTEXITCODE -ne 0 -or $version -notmatch 'PostgreSQL\\) 17\\.11') {\n    throw \"Unexpected PostgreSQL version output: $version\"\n  }\n}\n\n# 官方归档没有产品清单；复制 VC143 后为实际交付文件生成最终 SHA256 清单。\n$manifest = Join-Path $Destination 'MANIFEST.sha256'\n$prefix = $Destination.TrimEnd('\\') + '\\'\n$lines = Get-ChildItem -LiteralPath $Destination -File -Recurse |\n  Where-Object { $_.FullName -ne $manifest } |\n  Sort-Object FullName |\n  ForEach-Object {\n    $relative = $_.FullName.Substring($prefix.Length).Replace('\\', '/')\n    $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()\n    \"$hash *$relative\"\n  }\nSet-Content -LiteralPath $manifest -Value $lines -Encoding Ascii\n# 只有完整PE架构、DLL闭包及逐文件清单验真通过才交付；缺显式Node立即失败。\nif (-not $env:TUYUBOOKING_NODE_BIN -or -not [System.IO.Path]::IsPathRooted($env:TUYUBOOKING_NODE_BIN) -or\n    -not (Test-Path -LiteralPath $env:TUYUBOOKING_NODE_BIN -PathType Leaf)) {\n  throw 'PostgreSQL runtime verification requires an explicit Node executable.'\n}\n$nodeInfo = Get-Item -LiteralPath $env:TUYUBOOKING_NODE_BIN\nif (($nodeInfo.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Node executable must not be a link.' }\n$verifiedDestination = (Resolve-Path -LiteralPath $Destination).Path\n& $env:TUYUBOOKING_NODE_BIN (Join-Path $root '.github/workflows/release-host-windows.mjs') action verify-runtime $verifiedDestination\nif ($LASTEXITCODE -ne 0) { throw 'PostgreSQL final runtime PE, DLL, or checksum verification failed.' }\nWrite-Host \"Materialized PostgreSQL 17.11 Windows x86-64 runtime: $Destination\"\n";
const postgresRuntime = await (async()=>{
const { execFileSync }=await import("node:child_process");
const { createHash }=await import("node:crypto");
const { existsSync, lstatSync, mkdirSync, readFileSync, realpathSync, readdirSync, writeFileSync, unlinkSync }=await import("node:fs");
const { dirname, isAbsolute, join, resolve, sep }=await import("node:path");
const {archivePlan}=librariesInternals;
const {buildPostgres}=postgresInternals;
const {verifyRuntime:verifyWindows}=windowsInternals;

const productRoot = resolve(import.meta.dirname, '../..');
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const fail = message => { throw Error('主机PostgreSQL输入：' + message); };
const inside = (parent, path) => path === parent || path.startsWith(parent + sep);
function directory(path) {
  if (!path || !isAbsolute(path) || resolve(path) !== path || realpathSync(path) !== path
    || !lstatSync(path).isDirectory() || inside(productRoot, path) || inside(path, productRoot)) fail('必须是源码外规范目录');
  return path;
}
function executable(path) {
  const info = path && lstatSync(path);
  if (!path || !isAbsolute(path) || resolve(path) !== path || realpathSync(path) !== path
    || !info.isFile() || info.isSymbolicLink() || process.platform !== 'win32' && !(info.mode & 0o111)) fail('必须交付准确可执行入口');
  return path;
}

// 清单与真实文件一一对应，链接只能指向本运行包；不能用四个非空占位文件代替数据库。
function verifyPostgresInput(bin, platform, { run = execFileSync } = {}) {
  directory(bin);
  if (!['macos', 'windows', 'linux-arm', 'linux-amd'].includes(platform) || dirname(bin) === productRoot) fail('平台无效');
  const root = directory(dirname(bin));
  if (platform === 'windows') verifyWindows(root);
  const files = new Set(), links = [];
  const walk = parent => {
    for (const name of readdirSync(parent)) {
      const path = join(parent, name), info = lstatSync(path);
      if (info.isSymbolicLink()) {
        const target = realpathSync(path);
        if (!inside(root, target) || !lstatSync(target).isFile()) fail('运行包链接越界或不是文件');
        links.push(path);
      } else if (info.isDirectory()) walk(path);
      else if (info.isFile()) files.add(path);
      else fail('运行包包含特殊文件');
    }
  };
  walk(root);
  const manifestFile = join(root, 'MANIFEST.sha256');
  const records = new Map();
  for (const line of readFileSync(manifestFile, 'utf8').split(/\r?\n/u).filter(Boolean)) {
    const match = /^([a-f0-9]{64}) [ *](.+)$/u.exec(line);
    // sha256sum的官方相对清单允许一个./前缀，规范化后仍拒绝越界及重复。
    if (match) match[2] = match[2].replace(/^\.\//u, '');
    if (!match || match[2].includes('\\') || match[2].startsWith('/')
      || match[2].split('/').some(part => !part || part === '.' || part === '..')) fail('清单路径无效');
    const path = join(root, match[2]);
    if (path === manifestFile || records.has(path) || !files.has(path)
      || digest(readFileSync(path)) !== match[1]) fail('清单内容缺失、重复或漂移');
    records.set(path, match[1]);
  }
  if (records.size !== files.size - 1 || [...files].some(path => path !== manifestFile && !records.has(path))) fail('清单与文件不完整对应');
  for (const name of ['postgres', 'initdb', 'pg_ctl', 'psql']) {
    const path = executable(join(bin, name + (platform === 'windows' ? '.exe' : '')));
    if (!records.has(path)) fail('核心程序不在清单');
    if (platform !== 'windows') {
      const bytes = readFileSync(path);
      const valid = bytes.length >= 64 && (platform === 'macos'
        ? bytes.readUInt32LE(0) === 0xfeedfacf && bytes.readUInt32LE(4) === 0x0100000c
        : bytes.subarray(0, 4).toString('hex') === '7f454c46' && bytes[4] === 2 && bytes[5] === 1
          && bytes.readUInt16LE(18) === (platform === 'linux-arm' ? 183 : 62));
      if (!valid) fail('核心程序架构无效');
    }
  }
  const version = run(join(bin, 'postgres' + (platform === 'windows' ? '.exe' : '')),
    ['--version'], { encoding: 'utf8', timeout: 10000 }).trim();
  if (version !== 'postgres (PostgreSQL) 17.11') fail('数据库版本不符');
  return bin;
}

async function acquire(entry, directory, fetcher) {
  const path = join(directory, entry.sha256 + '.blob');
  if (!existsSync(path)) {
    let url = new URL(entry.url), response;
    for (let count = 0; count < 5; count++) {
      response = await fetcher(url.href, { redirect: 'manual', signal: AbortSignal.timeout(60000) });
      if (![301, 302, 303, 307, 308].includes(response.status)) break;
      const next = new URL(response.headers.get('location'), url);
      if (next.protocol !== 'https:' || next.username || next.password || next.hash
        || next.origin !== new URL(entry.url).origin && !(entry.redirectOrigins ?? []).includes(next.origin)) fail('原件跳转来源无效');
      url = next;
    }
    if (!response?.ok || !response.body) fail('官方原件下载失败');
    const chunks = []; let size = 0;
    for await (const chunk of response.body) {
      size += chunk.length;
      if (size > 128 * 1024 * 1024) fail('官方原件过大');
      chunks.push(chunk);
    }
    const bytes = Buffer.concat(chunks);
    if (digest(bytes) !== entry.sha256) fail('官方原件摘要不符');
    writeFileSync(path, bytes, { flag: 'wx', mode: 0o444 });
  }
  const info = lstatSync(path);
  if (!info.isFile() || info.isSymbolicLink() || realpathSync(path) !== path || digest(readFileSync(path)) !== entry.sha256) fail('已有原件漂移');
}

async function preparePostgresRuntime(platform, work, environment = process.env, {
  run = execFileSync, fetcher = fetch, compileMac = buildPostgres,
} = {}) {
  directory(work);
  if (!['macos', 'windows', 'linux-arm', 'linux-amd'].includes(platform)) fail('平台无效');
  if (environment.TUYU_POSTGRES_BIN) return verifyPostgresInput(environment.TUYU_POSTGRES_BIN, platform, { run });
  const runtimeParent = join(work, 'runtime');
  if (existsSync(runtimeParent)) fail('本轮运行包目录已存在');
  mkdirSync(runtimeParent);
  const destination = join(runtimeParent, 'postgresql');
  const env = { ...environment, NODE: process.execPath, TUYUBOOKING_NODE_BIN: process.execPath,
    TUYU_POSTGRES_DEST: destination, TUYUBOOKING_WORK_DIR: work,
    TUYUBOOKING_DEPENDENCY_DIR: join(work, 'dependencies'), TUYUBOOKING_BUILD_DIR: join(work, 'postgres-build') };
  if (platform === 'macos') {
    const archives = environment.TUYUBOOKING_POSTGRES_ARCHIVES || join(work, 'postgres-archives');
    if (!environment.TUYUBOOKING_POSTGRES_ARCHIVES) mkdirSync(archives);
    directory(archives);
    for (const entry of (await archivePlan()).archives) await acquire(entry, archives, fetcher);
    env.TUYUBOOKING_POSTGRES_ARCHIVES = archives;
    env.TUYUBOOKING_POSTGRES_WORK_DIR = join(work, 'postgres-build');
    mkdirSync(env.TUYUBOOKING_POSTGRES_WORK_DIR);
    await compileMac(env);
  } else if (platform === 'windows') {
    const shell = executable(environment.TUYUBOOKING_POWERSHELL_BIN);
    const command=join(work,'postgres-runtime.ps1');
    writeFileSync(command,WINDOWS_POSTGRES_RUNTIME_SOURCE,{flag:'wx'});
    try { run(shell, ['-NoProfile','-NonInteractive','-File',command,'-Destination',destination], {env,cwd:productRoot,stdio:'inherit'}); }
    finally { unlinkSync(command); }
  } else if (['linux-arm', 'linux-amd'].includes(platform)) {
    const shell = executable(environment.TUYUBOOKING_SHELL_BIN);
    run(env.TUYUBOOKING_NODE_BIN||process.execPath,[join(productRoot,'.github/workflows',`release-host-${platform}.mjs`),'action','runtime'],
      {env,cwd:productRoot,stdio:'inherit'});
  } else fail('平台无效');
  return verifyPostgresInput(join(destination, 'bin'), platform, { run });
}


return {preparePostgresRuntime,verifyPostgresInput};
})();
export const preparePostgresRuntime=postgresRuntime.preparePostgresRuntime;
export const verifyPostgresInput=postgresRuntime.verifyPostgresInput;

const direct=process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url);
const testing=direct&&Boolean(process.env.NODE_TEST_CONTEXT)&&process.argv.length===2;
if(direct&&!testing){
  try{const [command,...args]=process.argv.slice(2);
    if(command==='prepare')await prepare();else if(command==='job')job();else if(command==='step')step(args[0]);
    else if(command==='action')action(args[0],args.slice(1));else if(command==='collect')await collect(args);
    else if(command==='collect-produced')await collectProduced();else if(command==='publish')await publish(args[0]);else if(command==='finish')await finish();
    else if(!await productCommand(command,args))fail('自动化命令无效');
  }catch(error){console.error(error.message);process.exitCode=1;}
}

if(testing){
  const {default:assert}=await import('node:assert/strict');const {default:test}=await import('node:test');

  test('旧入口不能成为任一现行平台的清理归属证明',()=>{
    const current={id:9,path:workflowPath,head_branch:'main',event:'workflow_dispatch',created_at:'2026-01-02T00:00:00Z'};
    const old={...current,id:1,status:'completed',conclusion:'success',created_at:'2026-01-01T00:00:00Z'};
    for(const path of ['.github/workflows/release.yml',`.github/workflows/${owner.product}-${owner.platform}-ci.yml`,'.github/workflows/deleted.yml'])
      assert.deepEqual(cleanupPlan([{...old,path}],current,'success'),[]);
  });
  test('撤销当前产物失败仍处理旧失败且最终失败',async()=>{
    const current={id:9,path:workflowPath,head_branch:'main',event:'workflow_dispatch',created_at:'2026-01-02T00:00:00Z'};
    let releases=0,history=0;
    const api=async path=>{
      if(path.startsWith('releases?')){if(++releases===1)throw Error('撤销中断');return [];}
      if(path==='actions/runs/9')return current;
      if(path.startsWith('actions/runs?')){history++;return {workflow_runs:[]};}
      throw Error('未声明请求');
    };
    await assert.rejects(finish({build:{result:'failure'}},api,{run_id:9}),/撤销中断/);
    assert.equal(history,1);assert.equal(releases,2);
  });
  test('清理旧失败Run同时回收其多个Attempt的准确孤立Tag',async()=>{
    const old={id:2,run_attempt:2,path:workflowPath,head_branch:'main',event:'workflow_dispatch',head_sha:'a'.repeat(40),status:'completed',conclusion:'failure',created_at:'2026-01-01T00:00:00Z'},current={...old,id:9,status:'in_progress',created_at:'2026-01-02T00:00:00Z'};
    const deleted=new Set(),tags=[1,2].map(attempt=>({ref:`refs/tags/${prefix}1.0.0-r2-a${attempt}`,object:{type:'commit',sha:old.head_sha}}));
    const api=async(path,options={})=>{
      if(options.method==='DELETE'){deleted.add(path);return {};}
      if(deleted.has(path)||deleted.has(path.replace('git/ref/','git/refs/')))return null;
      if(path.startsWith('actions/runs?'))return {workflow_runs:[old,current]};
      if(path.startsWith('releases?')||path.includes('/artifacts?'))return path.includes('/artifacts?')?{artifacts:[]}:[];
      if(path.startsWith('git/matching-refs/'))return tags;
      if(path==='actions/runs/2')return old;if(path==='actions/runs/9')return current;
      throw Error('未声明的请求');
    };
    assert.deepEqual(await cleanup('failed',{run_id:9},api),[2]);assert.equal([...deleted].filter(path=>path.startsWith('git/refs/')).length,2);
  });
  test('全部前置成功才成功，其余结论一律失败',()=>{
    assert.equal(precedingResult({build:{result:'success'},publish:{result:'success'}}),'success');
    for(const result of ['failure','cancelled','skipped','timed_out',undefined])assert.equal(precedingResult({build:{result}}),'failed');
    assert.throws(()=>precedingResult({}));
  });
  test('当前Run尚在运行也能清理同目标旧结果，保护其它目标和活动任务',()=>{
    const row=(id,conclusion='success',status='completed',path=workflowPath)=>({id,conclusion,status,path,head_branch:'main',event:'workflow_dispatch',created_at:new Date(1700000000000+id*1000).toISOString()});
    const current=row(6,null,'in_progress');const rows=[row(1),row(2,'failure'),row(3,'success','in_progress'),row(4,'success','completed','.github/workflows/release-other.yml'),current,row(7)];
    assert.deepEqual(cleanupPlan(rows,current,'success').map(row=>row.id),[1]);
    assert.deepEqual(cleanupPlan(rows,current,'failed').map(row=>row.id),[2]);
  });
  test('软件版本进位与协议版本边界',()=>{
    assert.equal(nextVersion('1.0.0',['1.99.99']),'2.0.0');assert.equal(nextVersion('9',['9'],true),'10');
    assert.throws(()=>nextVersion(String(0xffffffff),[String(0xffffffff)],true));
  });
  test('历史完整分页不截断超过1000条记录',async()=>{
    const rows=Array.from({length:1005},(_,id)=>({id}));const api=async path=>rows.slice((Number(/page=(\d+)$/u.exec(path)[1])-1)*100,Number(/page=(\d+)$/u.exec(path)[1])*100);
    assert.equal((await pages('releases',null,api)).length,1005);
  });
  test('失败清理只删除所属旧失败产物及Run，成功和活动任务独立保留',async()=>{
    const row=(id,conclusion,status='completed')=>({id,run_attempt:1,conclusion,status,path:workflowPath,head_branch:'main',event:'workflow_dispatch',repository:{full_name:owner.repository},head_sha:'a'.repeat(40),created_at:new Date(1700000000000+id*1000).toISOString()});
    const current=row(10,null,'in_progress'),rows=[row(1,'success'),row(2,'failure'),row(3,null,'in_progress'),current];
    const gone=new Set(),removed=[];
    const api=async(path,options={})=>{
      if(options.method==='DELETE'){removed.push(path);gone.add(path);return {};}
      if(gone.has(path))return null;
      if(path.startsWith('actions/runs?'))return {workflow_runs:rows};
      if(path.startsWith('releases?')||path.startsWith('git/matching-refs/'))return [];
      if(path.startsWith('actions/runs/2/artifacts?'))return {artifacts:[{id:20}]};
      if(path==='actions/artifacts/20')return {id:20};
      const match=/^actions\/runs\/(\d+)$/u.exec(path);if(match)return rows.find(row=>row.id===Number(match[1]))??null;
      throw Error('未声明的模拟接口：'+path);
    };
    assert.deepEqual(await cleanup('failed',{run_id:10},api),[2]);
    assert.deepEqual(removed,['actions/artifacts/20','actions/runs/2']);
  });

  test('GitHub运行序号保证成功历史清理后版本不会回到初始值',()=>{
    assert.equal(nextVersion('1.0.0',[],false,4),'1.0.3');
    assert.equal(nextVersion('1.99.99',[],false,2),'2.0.0');
    assert.equal(nextVersion('1.0.0',['3.0.0'],false,4),'3.0.1');
    assert.throws(()=>nextVersion('1.0.0',[],false,0));
  });

}
