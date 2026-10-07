#!/usr/bin/env node
import { remoteEnvironment as productRemoteEnvironment } from '../../../../build.mjs';
if(process.env.GITHUB_ACTIONS==='true'&&String(process.env.GITHUB_WORKFLOW||'').startsWith('tuyubooking.'))Object.assign(process.env,productRemoteEnvironment());
import { spawnSync as runExactProcess } from 'node:child_process';
function validateCandidate(){const value=process.env;
if(!/^[0-9a-f]{40}$/.test(value.SOURCE_SHA||'')||!/^[1-9][0-9]*$/.test(value.CI_RUN_ID||'')||!/^\d+\.\d{1,2}\.\d{1,2}$/.test(value.SOFTWARE_VERSION||'')||value.VERSION_TAG!=='tuyubooking-client-android-v'+value.SOFTWARE_VERSION)throw Error('准确Release候选无效');}

// 本文件只执行 tuyubooking.client-android.release 的 client-android Job；阶段编号由本仓唯一 Workflow 固定，禁止接收其它身份。
export const EXACT_REMOTE_JOB_IDENTITY = Object.freeze({"pipeline":"tuyubooking.client-android.release","job":"client-android"});

function requireExactRemoteJobEnvironment() {
  const expected = 'tuyutata/tuyubooking';
  if (!expected || process.env.GITHUB_REPOSITORY !== expected) {
    throw new Error('准确远端Job仓库身份无效');
  }
}
const workflowSteps = Object.freeze({
  "0": {
    "shell": "bash",
    "source": "printf 'version=3.47.2\n' >> \"$GITHUB_OUTPUT\""
  },
  "1": {
    "shell": "bash",
    "source": "# 安装后先验真，再统一准备目标平台缓存与受控修订。\nflutter --version --machine >/dev/null\nplatform=\"android\"\nflutter --version >/dev/null\n"
  },
  "2": {
    "shell": "bash",
    "source": "node \"$GITHUB_WORKSPACE/scripts/client/release/android/client-android/execute.mjs\" validate-inputs"
  },
  "3": {
    "shell": "bash",
    "source": "sdkmanager \"platforms;android-36\" \"build-tools;36.0.0\" \"platform-tools\" \"cmdline-tools;22.0\""
  },
  "4": {
    "shell": "bash",
    "source": "set -euo pipefail\n# 本次Release独占源码外工程，后续签名只读取此工程输出。\nproject_work=\"$RUNNER_TEMP/tuyubooking-android-project\"\nmkdir \"$project_work\"\nproject_work=\"$(cd \"$project_work\" && pwd -P)\"\nTUYUBOOKING_PROJECT_ROOT=\"$(node \"$GITHUB_WORKSPACE/app/scripts/project.mjs\" create --source-root \"$GITHUB_WORKSPACE/app\" --work-root \"$project_work\" --platform android)\"\n# 单独导出，保留工程创建失败的退出状态。\nexport TUYUBOOKING_PROJECT_ROOT\nprintf 'TUYUBOOKING_PROJECT_ROOT=%s\\n' \"$TUYUBOOKING_PROJECT_ROOT\" >> \"$GITHUB_ENV\"\ncd \"$TUYUBOOKING_PROJECT_ROOT\"\nset -euo pipefail\numask 077\ncd \"$TUYUBOOKING_PROJECT_ROOT\"\nflutter pub get --offline --enforce-lockfile\nflutter analyze\nflutter test\n# 原生库绑定同一锁定SDK与本轮Pub视图；回执只含固定的公开路径字段。\nsdk_environment=\"$project_work/sdk-environment.json\"\nnode \"$GITHUB_WORKSPACE/app/scripts/project.mjs\" native --source-root \"$GITHUB_WORKSPACE/app\" --work-root \"$project_work\" --output \"$TUYUBOOKING_PROJECT_ROOT\" --platform android >\"$sdk_environment\"\nwhile IFS= read -r -d '' key && IFS= read -r -d '' value; do\n  export \"$key=$value\"\ndone < <(node --input-type=module - \"$sdk_environment\" <<'NODE_NATIVE_ENV'\nimport {readFileSync} from 'node:fs';\nconst allowed=new Set(['CITIZENSDK_ANDROID_CORE_DIR','CITIZENSDK_ANDROID_BUILD_DIR','CITIZENSDK_SOURCE_DIR']);\nconst value=JSON.parse(readFileSync(process.argv[2],'utf8'));\nfor(const [key,path] of Object.entries(value)) {\n if(!allowed.has(key)||typeof path!=='string'||/[\\x00-\\x1f]/.test(path)) throw Error('SDK公开路径回执无效');\n process.stdout.write(key+'\\0'+path+'\\0');\n}\nNODE_NATIVE_ENV\n)\nflutter build apk --release --target lib/main_client.dart --target-platform android-arm64 --build-name=\"$SOFTWARE_VERSION\"\nflutter build appbundle --release --target lib/main_client.dart --target-platform android-arm64 --build-name=\"$SOFTWARE_VERSION\"\ncd \"$GITHUB_WORKSPACE\"\nwork=\"$RUNNER_TEMP/tuyubooking-client-android-signing\"\nrm -rf \"$work\" \"$RELEASE_DIR\"\nmkdir -p \"$work\" \"$RELEASE_DIR/payload\"\ntrap 'rm -rf \"$work\"' EXIT\npython3 - \"$work\" <<'PY'\nimport base64, os, pathlib, re, sys\nroot = pathlib.Path(sys.argv[1]); fields = {}\nfor raw in os.environ.get(\"APP_KEY\", \"\").splitlines():\n    line = raw.strip()\n    if not line or line.startswith(\"#\"): continue\n    name, sep, value = line.partition(\"=\")\n    if not sep or name.strip() in fields or not value.strip(): raise SystemExit(\"APP_KEY 行格式无效\")\n    fields[name.strip()] = value.strip()\nif set(fields) - {\"keystore\", \"password\", \"alias\", \"keyPassword\"}: raise SystemExit(\"APP_KEY 包含未登记字段\")\nalias = fields.get(\"alias\", \"upload\")\nif not re.fullmatch(r\"[A-Za-z0-9._-]{1,128}\", alias): raise SystemExit(\"APP_KEY alias 无效\")\ntry: key = base64.b64decode(fields[\"keystore\"], validate=True); password = fields[\"password\"]\nexcept (KeyError, ValueError) as exc: raise SystemExit(\"APP_KEY 缺少有效签名材料\") from exc\nif not 1024 <= len(key) <= 32 * 1024 * 1024: raise SystemExit(\"APP_KEY keystore 大小无效\")\n(root / \"release.keystore\").write_bytes(key); (root / \"password\").write_text(password)\n(root / \"key-password\").write_text(fields.get(\"keyPassword\", password)); (root / \"alias\").write_text(alias)\nPY\nexport TUYU_ANDROID_STORE_PASSWORD=\"$(cat \"$work/password\")\"\nexport TUYU_ANDROID_KEY_PASSWORD=\"$(cat \"$work/key-password\")\"\nalias=\"$(cat \"$work/alias\")\"\napksigner=\"$ANDROID_HOME/build-tools/36.1.0/apksigner\"\n\"$apksigner\" sign --ks \"$work/release.keystore\" --ks-pass env:TUYU_ANDROID_STORE_PASSWORD --key-pass env:TUYU_ANDROID_KEY_PASSWORD --v4-signing-enabled false --ks-key-alias \"$alias\" --out \"$RELEASE_DIR/payload/tuyubooking-client.apk\" \"$TUYUBOOKING_PROJECT_ROOT/build/app/outputs/flutter-apk/app-release.apk\"\ncp \"$TUYUBOOKING_PROJECT_ROOT/build/app/outputs/bundle/release/app-release.aab\" \"$RELEASE_DIR/payload/tuyubooking-client.aab\"\nzip -d \"$RELEASE_DIR/payload/tuyubooking-client.aab\" 'META-INF/*' >/dev/null || true\njarsigner -keystore \"$work/release.keystore\" -storepass:env TUYU_ANDROID_STORE_PASSWORD -keypass:env TUYU_ANDROID_KEY_PASSWORD \"$RELEASE_DIR/payload/tuyubooking-client.aab\" \"$alias\"\n\"$apksigner\" verify --verbose \"$RELEASE_DIR/payload/tuyubooking-client.apk\"\njarsigner -verify \"$RELEASE_DIR/payload/tuyubooking-client.aab\"\ntest \"$(apkanalyzer manifest application-id \"$RELEASE_DIR/payload/tuyubooking-client.apk\")\" = com.tuyulove.tuyubooking\n(cd \"$RELEASE_DIR/payload\" && zip -X \"$RELEASE_DIR/tuyubooking-client-android.zip\" tuyubooking-client.apk tuyubooking-client.aab)\n"
  },
  "5": {
    "shell": "bash",
    "source": "node <<'NODE'\nconst { createHash } = require('node:crypto'); const fs = require('node:fs'); const root = process.env.RELEASE_DIR;\nconst hash = (name) => createHash('sha256').update(fs.readFileSync(`${root}/${name}`)).digest('hex');\nconst asset = 'tuyubooking-client-android.zip';\nconst manifest = { product_id: 'tuyubooking', platform: 'client-android', software_version: process.env.SOFTWARE_VERSION, git_commit_sha: process.env.SOURCE_SHA, ci_run_id: Number(process.env.CI_RUN_ID), package_name: 'com.tuyulove.tuyubooking', assets: [{ name: asset, sha256: hash(asset) }] };\nfs.writeFileSync(`${root}/release-manifest.json`, `${JSON.stringify(manifest, null, 2)}\\n`);\nfs.writeFileSync(`${root}/SHA256SUMS`, `${hash(asset)}  ${asset}\\n${hash('release-manifest.json')}  release-manifest.json\\n`);\nNODE\nnode \"$GITHUB_WORKSPACE/scripts/client/release/android/index.mjs\" publish-release\n"
  }
});
function runExactWorkflowStep(index){requireExactRemoteJobEnvironment();if(!/^(?:0|[1-9][0-9]*)$/.test(String(index||''))||!Object.hasOwn(workflowSteps,String(index)))throw new Error('准确远端Job阶段无效');const step=workflowSteps[String(index)];const command=step.shell==='pwsh'?'pwsh':(process.platform==='win32'?'bash':'/bin/bash');const args=step.shell==='pwsh'?['-NoLogo','-NoProfile','-NonInteractive','-Command',step.source]:['--noprofile','--norc','-e','-o','pipefail','-c',step.source];const result=runExactProcess(command,args,{cwd:process.cwd(),env:process.env,stdio:'inherit'});if(result.error)throw new Error('准确远端Job阶段无法启动');if(result.status!==0)process.exitCode=Number.isInteger(result.status)?result.status:1;}

requireExactRemoteJobEnvironment();
validateCandidate();
if(process.argv[2]==='validate-inputs') process.exit(0);
if(process.argv[2]!=='workflow-step')throw new Error('准确Release Job只接受workflow-step');
runExactWorkflowStep(process.argv[3]);
