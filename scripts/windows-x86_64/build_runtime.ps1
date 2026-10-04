[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$Destination,
  [switch]$SkipRuntimeExecution
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($env:OS -ne 'Windows_NT') {
  throw 'Windows x86-64 is required to materialize the release runtime.'
}

$architecture = if ($env:PROCESSOR_ARCHITEW6432) {
  $env:PROCESSOR_ARCHITEW6432
} else {
  $env:PROCESSOR_ARCHITECTURE
}
if ($architecture -ne 'AMD64') {
  throw "Windows x86-64 is required; found $architecture."
}

if (Test-Path -LiteralPath $Destination) {
  throw "Runtime destination already exists: $Destination"
}

# 产品锁决定PostgreSQL原件；普通开发者和CI使用同一依赖缓存合同。
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$workRoot = if ($env:TUYUBOOKING_WORK_DIR) { $env:TUYUBOOKING_WORK_DIR } else {
  Join-Path ([System.IO.Path]::GetTempPath()) 'tuyubooking\windows'
}
$dependencyRoot = if ($env:TUYUBOOKING_DEPENDENCY_DIR) { $env:TUYUBOOKING_DEPENDENCY_DIR } else {
  Join-Path $workRoot 'dependencies'
}
$lock = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'postgresql.runtime.lock.json') -Raw | ConvertFrom-Json
$included = @('bin', 'lib', 'share', 'server_license.txt', 'commandlinetools_3rd_party_licenses.txt')
if ($lock.component -ne 'postgresql' -or $lock.version -ne '17.11' -or
    $lock.platform -ne 'windows-x86_64' -or $lock.source_root -ne 'pgsql' -or
    -not $lock.source_sha256 -or $lock.source_sha256 -notmatch '^[a-f0-9]{64}$') {
  throw 'Unexpected PostgreSQL runtime archive metadata.'
}
$uri = [Uri]$lock.source_url
if ($uri.Scheme -ne 'https' -or -not [string]::IsNullOrEmpty($uri.UserInfo) -or
    -not [string]::IsNullOrEmpty($uri.Fragment)) {
  throw 'The locked PostgreSQL archive must use credential-free HTTPS.'
}
New-Item -ItemType Directory -Path $dependencyRoot -Force | Out-Null
$archive = if ($env:POSTGRES_SOURCE_ARCHIVE) { $env:POSTGRES_SOURCE_ARCHIVE } else {
  Join-Path $dependencyRoot ([System.IO.Path]::GetFileName($uri.AbsolutePath))
}
if (-not (Test-Path -LiteralPath $archive -PathType Leaf)) {
  $pending = "$archive.pending.$PID"
  for ($attempt = 1; $attempt -le 3; $attempt++) {
    Remove-Item -LiteralPath $pending -Force -ErrorAction SilentlyContinue
    try {
      Invoke-WebRequest -Uri $uri -OutFile $pending -MaximumRedirection 8
      if ((Get-FileHash -LiteralPath $pending -Algorithm SHA256).Hash.ToLowerInvariant() -eq $lock.source_sha256) {
        Move-Item -LiteralPath $pending -Destination $archive
        break
      }
    } catch {
      if ($attempt -eq 3) { throw }
    }
  }
  Remove-Item -LiteralPath $pending -Force -ErrorAction SilentlyContinue
}
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $lock.source_sha256) {
  throw 'PostgreSQL archive SHA256 differs from the runtime lock.'
}
$directory = Split-Path $Destination -Parent
$dependency = [pscustomobject]@{
  archive = $archive
  extraction = (Join-Path $directory 'postgresql-extracted')
  destination = $Destination
  sourceRoot = $lock.source_root
  sourceSize = [int64]$lock.source_size
  included = $included
}
if ((Get-Item -LiteralPath $dependency.archive).Length -ne $dependency.sourceSize) {
  throw 'PostgreSQL archive size differs from the runtime lock.'
}
if (Test-Path -LiteralPath $dependency.extraction) {
  throw "PostgreSQL extraction destination already exists: $($dependency.extraction)"
}
try {
  Expand-Archive -LiteralPath $dependency.archive -DestinationPath $dependency.extraction
  $Source = Join-Path $dependency.extraction $dependency.sourceRoot
  foreach ($relative in @('bin', 'lib', 'share')) {
    if (-not (Test-Path -LiteralPath (Join-Path $Source $relative) -PathType Container)) {
      throw "Missing PostgreSQL archive directory: pgsql/$relative"
    }
  }
  $required = @('bin\postgres.exe', 'bin\initdb.exe', 'bin\pg_ctl.exe',
    'bin\psql.exe', 'server_license.txt', 'commandlinetools_3rd_party_licenses.txt')
  foreach ($relative in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $Source $relative) -PathType Leaf)) {
      throw "Missing PostgreSQL archive file: pgsql/$relative"
    }
  }
  New-Item -ItemType Directory -Path $Destination | Out-Null
  foreach ($relative in $dependency.included) {
    Copy-Item -LiteralPath (Join-Path $Source $relative) -Destination $Destination -Recurse
  }
  # 保全唯一改过的PostgreSQL测试工具；产品保留源码继续由既有打包器交付。
  $testUtils = Join-Path $root 'scripts\windows-x86_64\PostgreSQL-Test-Utils.pm'
  if (-not (Test-Path -LiteralPath $testUtils -PathType Leaf)) { throw 'Missing retained PostgreSQL test utility.' }
  Copy-Item -LiteralPath $testUtils -Destination (Join-Path $Destination 'lib\pgxs\src\test\perl\PostgreSQL\Test\Utils.pm') -Force
  # 延续既有服务端裁剪范围，不随官方完整归档引入额外解释器或 StackBuilder。
  foreach ($relative in @('bin\stackbuilder.exe', 'lib\plperl.dll', 'lib\plpython3.dll',
    'lib\pltcl.dll', 'lib\bool_plperl.dll', 'lib\hstore_plperl.dll',
    'lib\hstore_plpython3.dll', 'lib\jsonb_plperl.dll', 'lib\jsonb_plpython3.dll',
    'lib\ltree_plpython3.dll')) {
    $excluded = Join-Path $Destination $relative
    if (Test-Path -LiteralPath $excluded) { Remove-Item -LiteralPath $excluded -Force }
  }
  Get-ChildItem -LiteralPath (Join-Path $Destination 'bin') -Filter 'wx*.dll' -File |
    Remove-Item -Force
} finally {
  if (Test-Path -LiteralPath $dependency.extraction) {
    Remove-Item -LiteralPath $dependency.extraction -Recurse -Force
  }
}

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path -LiteralPath $vswhere)) {
  throw 'Visual Studio 2022 vswhere.exe was not found.'
}
$installation = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $installation) {
  throw 'Visual Studio C++ x64 tools were not found.'
}
$crtDirectory = Get-ChildItem -LiteralPath (Join-Path $installation 'VC\Redist\MSVC') -Directory |
  Sort-Object Name -Descending |
  ForEach-Object { Join-Path $_.FullName 'x64\Microsoft.VC143.CRT' } |
  Where-Object { Test-Path -LiteralPath (Join-Path $_ 'vcruntime140.dll') } |
  Select-Object -First 1
if (-not $crtDirectory) {
  throw 'Microsoft VC143 x64 redistributable directory was not found.'
}
foreach ($name in @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
  Copy-Item -LiteralPath (Join-Path $crtDirectory $name) -Destination (Join-Path $Destination 'bin')
}
$redistRoot = Split-Path (Split-Path $crtDirectory -Parent) -Parent
$redistLicense = Get-ChildItem -LiteralPath $redistRoot -Filter 'license*.rtf' -File -Recurse |
  Select-Object -First 1
if ($redistLicense) {
  Copy-Item -LiteralPath $redistLicense.FullName -Destination (Join-Path $Destination 'Microsoft-Visual-CPP-Runtime-LICENSE.rtf')
}

if (-not $SkipRuntimeExecution) {
  $version = & (Join-Path $Destination 'bin\postgres.exe') --version 2>&1
  if ($LASTEXITCODE -ne 0 -or $version -notmatch 'PostgreSQL\) 17\.11') {
    throw "Unexpected PostgreSQL version output: $version"
  }
}

# 官方归档没有产品清单；复制 VC143 后为实际交付文件生成最终 SHA256 清单。
$manifest = Join-Path $Destination 'MANIFEST.sha256'
$prefix = $Destination.TrimEnd('\') + '\'
$lines = Get-ChildItem -LiteralPath $Destination -File -Recurse |
  Where-Object { $_.FullName -ne $manifest } |
  Sort-Object FullName |
  ForEach-Object {
    $relative = $_.FullName.Substring($prefix.Length).Replace('\', '/')
    $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash *$relative"
  }
Set-Content -LiteralPath $manifest -Value $lines -Encoding Ascii
# 只有完整PE架构、DLL闭包及逐文件清单验真通过才交付；缺显式Node立即失败。
if (-not $env:TUYUBOOKING_NODE_BIN -or -not [System.IO.Path]::IsPathRooted($env:TUYUBOOKING_NODE_BIN) -or
    -not (Test-Path -LiteralPath $env:TUYUBOOKING_NODE_BIN -PathType Leaf)) {
  throw 'PostgreSQL runtime verification requires an explicit Node executable.'
}
$nodeInfo = Get-Item -LiteralPath $env:TUYUBOOKING_NODE_BIN
if (($nodeInfo.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Node executable must not be a link.' }
$verifiedDestination = (Resolve-Path -LiteralPath $Destination).Path
& $env:TUYUBOOKING_NODE_BIN (Join-Path $PSScriptRoot 'verify-source.mjs') $verifiedDestination
if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL final runtime PE, DLL, or checksum verification failed.' }
Write-Host "Materialized PostgreSQL 17.11 Windows x86-64 runtime: $Destination"
