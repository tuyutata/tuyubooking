[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$Bundle,
  [switch]$SkipRuntimeExecution,
  [switch]$RequireAuthenticode
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-PeMachine([string]$Path) {
  $bytes = [IO.File]::ReadAllBytes($Path)
  if ($bytes.Length -lt 64 -or $bytes[0] -ne 0x4d -or $bytes[1] -ne 0x5a) {
    throw "Not a PE file: $Path"
  }
  $peOffset = [BitConverter]::ToInt32($bytes, 0x3c)
  if ($peOffset -lt 0 -or $peOffset + 6 -gt $bytes.Length) {
    throw "Invalid PE header: $Path"
  }
  [BitConverter]::ToUInt16($bytes, $peOffset + 4)
}

$runtime = Join-Path $Bundle 'postgresql'
$native = Join-Path $Bundle 'tuyubooking_native.dll'
$business = Join-Path $Bundle 'business'
$required = @('tuyubooking.exe', 'flutter_windows.dll', 'tuyubooking_native.dll',
  'postgresql\bin\postgres.exe', 'postgresql\bin\initdb.exe',
  'postgresql\bin\pg_ctl.exe', 'postgresql\bin\psql.exe',
  'postgresql\MANIFEST.sha256', 'business\python\python.exe',
  'business\node\node.exe', 'business\php\php.exe', 'business\php\php-cgi.exe',
  'business\nginx\nginx.exe', 'business\voyant\operator\.output\server\index.mjs',
  'business\voyant\operator\.output\migration\migrate.mjs',
  'business\voyant\operator\.output\migrations\meta\_journal.json',
  'business\tuyu_frappe_runtime.py', 'business\tuyu_hi_events_runtime.py', 'business\runtime.lock.json',
  'business\tuyu_runtime_common.py', 'business\tuyu_hi_events_runtime.py', 'business\runtime.lock.json',
  'business\tuyu_voyant_runtime.py', 'business\tuyu_hi_events_runtime.py', 'business\runtime.lock.json',
  'business\tuyu_https_proxy.py',
  'business\hi_events\backend\vendor\autoload.php',
  'business\hi_events\frontend\dist\server\entry.server.js',
  'business\bench\apps\frappe\LICENSE', 'business\bench\apps\erpnext\license.txt',
  'business\bench\apps\hrms\license.txt', 'business\bench\apps\kamra\license.txt',
  'business\bench\apps\ury\license.txt')
foreach ($relative in $required) {
  if (-not (Test-Path -LiteralPath (Join-Path $Bundle $relative))) {
    throw "Missing release file: $relative"
  }
}
$pythonVersion = & (Join-Path $business 'python\python.exe') --version 2>&1
if ($LASTEXITCODE -ne 0 -or $pythonVersion -notmatch '^Python 3\.14\.') {
  throw "Unexpected business Python version: $pythonVersion"
}
$nodeVersion = & (Join-Path $business 'node\node.exe') --version 2>&1
if ($LASTEXITCODE -ne 0 -or $nodeVersion -notmatch '^v24\.') {
  throw "Unexpected business Node.js version: $nodeVersion"
}
$phpVersion = & (Join-Path $business 'php\php.exe') --version 2>&1
if ($LASTEXITCODE -ne 0 -or $phpVersion -notmatch '^PHP 8\.4\.') {
  throw "Unexpected business PHP version: $phpVersion"
}
$businessLock = Get-Content -LiteralPath (Join-Path $business 'runtime.lock.json') -Raw | ConvertFrom-Json
if ($businessLock.network_install_allowed -ne $false -or $businessLock.database_name -ne 'tuyubooking') {
  throw 'Invalid offline single-database business runtime lock.'
}

Get-ChildItem -LiteralPath $Bundle -File -Recurse |
  Where-Object { $_.Extension -in @('.exe', '.dll') } |
  ForEach-Object {
    if ((Get-PeMachine $_.FullName) -ne 0x8664) {
      throw "Non-x86-64 PE file: $($_.FullName)"
    }
  }

$dumpbin = Get-Command dumpbin.exe -ErrorAction Stop
$exports = & $dumpbin.Source /nologo /exports $native | Out-String
foreach ($symbol in @('tuyubooking_contract', 'tuyubooking_start', 'tuyubooking_sr25519_sign')) {
  if ($exports -notmatch "\b$symbol\b") {
    throw "Missing native export: $symbol"
  }
}

if (-not $SkipRuntimeExecution) {
  $version = & (Join-Path $runtime 'bin\postgres.exe') --version 2>&1
  if ($LASTEXITCODE -ne 0 -or $version -notmatch 'PostgreSQL\) 17\.11') {
    throw "Unexpected PostgreSQL version output: $version"
  }
}

$manifest = Join-Path $runtime 'MANIFEST.sha256'
foreach ($line in Get-Content -LiteralPath $manifest) {
  if ($line -notmatch '^([0-9a-f]{64}) \*(.+)$') {
    throw "Invalid PostgreSQL manifest line: $line"
  }
  $file = Join-Path $runtime $Matches[2].Replace('/', '\')
  $actual = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actual -ne $Matches[1]) {
    throw "PostgreSQL manifest mismatch: $($Matches[2])"
  }
}

if ($RequireAuthenticode) {
  Get-ChildItem -LiteralPath $Bundle -File -Recurse |
    Where-Object { $_.Extension -in @('.exe', '.dll') } |
    ForEach-Object {
      if ((Get-AuthenticodeSignature -LiteralPath $_.FullName).Status -ne 'Valid') {
        throw "Invalid Authenticode signature: $($_.FullName)"
      }
    }
}
Write-Host "Verified TuyuBooking Windows x86-64 bundle: $Bundle"
