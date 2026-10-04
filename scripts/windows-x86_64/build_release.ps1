[CmdletBinding()]
param(
  [string]$TuyuServeUrl = $env:TUYU_SERVE_URL,
  [string]$CertificateThumbprint = $env:TUYU_WINDOWS_CERTIFICATE_THUMBPRINT
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not $TuyuServeUrl -or $TuyuServeUrl -notmatch '^https://') {
  throw 'TUYU_SERVE_URL must be an HTTPS URL.'
}

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$workRoot = if ($env:TUYUBOOKING_WORK_DIR) { $env:TUYUBOOKING_WORK_DIR } else {
  Join-Path ([System.IO.Path]::GetTempPath()) 'tuyubooking\host\windows'
}
$buildRoot = if ($env:TUYUBOOKING_BUILD_DIR) { $env:TUYUBOOKING_BUILD_DIR } else { Join-Path $workRoot 'build' }
$dependencyRoot = if ($env:TUYUBOOKING_DEPENDENCY_DIR) { $env:TUYUBOOKING_DEPENDENCY_DIR } else { Join-Path $workRoot 'dependencies' }
$artifactRoot = if ($env:TUYUBOOKING_ARTIFACT_DIR) { $env:TUYUBOOKING_ARTIFACT_DIR } else { Join-Path $workRoot 'artifacts' }
$desktop = Join-Path $workRoot 'flutter-project'
$businessSource = if ($env:TUYU_BUSINESS_RUNTIME_SOURCE) { $env:TUYU_BUSINESS_RUNTIME_SOURCE } else {
  Join-Path $artifactRoot 'business\windows-x86_64'
}
$stage = Join-Path $workRoot ("tuyubooking-windows-" + [Guid]::NewGuid().ToString('N'))
$runtimeStage = Join-Path $stage 'postgresql'
$flutterBuild = Join-Path $buildRoot 'flutter'
$release = Join-Path $flutterBuild 'windows\x64\runner\Release'
$archive = Join-Path $artifactRoot 'TuyuBooking-Windows-x86_64.zip'
New-Item -ItemType Directory -Path $workRoot, $buildRoot, $dependencyRoot, $artifactRoot -Force | Out-Null
$env:CARGO_TARGET_DIR = Join-Path $buildRoot 'cargo'
if (Test-Path -LiteralPath $desktop) { Remove-Item -LiteralPath $desktop -Recurse -Force }
$env:TUYUBOOKING_ROOT = $root
& node (Join-Path $root 'scripts\sdk-dependencies.mjs') prepare --platform windows --output $desktop --offline $(if ($env:TUYUBOOKING_OFFLINE) { $env:TUYUBOOKING_OFFLINE } else { 'false' })
if ($LASTEXITCODE -ne 0) { throw 'TuyuBooking SDK dependency preparation failed.' }
# 同一Git SDK的Windows安装件只装入Pub实际消费视图。
& node (Join-Path $root 'app\scripts\project.mjs') native --source-root (Join-Path $root 'app') --work-root $workRoot --output $desktop --platform windows | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'TuyuBooking SDK native preparation failed; work directory retained.' }
if (Test-Path -LiteralPath $archive) {
  throw "Release archive already exists: $archive"
}
New-Item -ItemType Directory -Path $stage | Out-Null
try {
  & (Join-Path $PSScriptRoot 'build_runtime.ps1') -Destination $runtimeStage

  Push-Location $desktop
  try {
    flutter config --build-dir=([System.IO.Path]::GetRelativePath($desktop, $flutterBuild)) | Out-Null
    flutter test
    flutter build windows --no-pub --release --dart-define="TUYU_SERVE_URL=$TuyuServeUrl"
  } finally {
    Pop-Location
  }

  $env:TUYU_POSTGRES_BIN = Join-Path $runtimeStage 'bin'
  Push-Location $root
  try {
    cargo test --workspace
    rustup target add x86_64-pc-windows-msvc
    cargo build --release --target x86_64-pc-windows-msvc -p tuyubooking-native
  } finally {
    Pop-Location
  }

  Copy-Item -LiteralPath (Join-Path $env:CARGO_TARGET_DIR 'x86_64-pc-windows-msvc\release\tuyubooking_native.dll') -Destination $release
  Copy-Item -LiteralPath $runtimeStage -Destination (Join-Path $release 'postgresql') -Recurse
  $businessDestination = Join-Path $release 'business'
  Copy-Item -LiteralPath $businessSource -Destination $businessDestination -Recurse
  $businessPython = Join-Path $businessDestination 'python\python.exe'
  if (-not (Test-Path -LiteralPath $businessPython)) { throw 'Offline business runtime is missing Python.' }
  $pythonVersion = & $businessPython --version 2>&1
  if ($LASTEXITCODE -ne 0 -or $pythonVersion -notmatch '^Python 3\.14\.') { throw "Business runtime must use Python 3.14: $pythonVersion" }
  foreach ($appName in @('frappe', 'erpnext', 'hrms', 'kamra', 'ury')) {
    $appDestination = Join-Path $businessDestination "bench\apps\$appName"
    if (Test-Path -LiteralPath $appDestination) { Remove-Item -LiteralPath $appDestination -Recurse -Force }
  }
  foreach ($appName in @('frappe', 'erpnext', 'hrms', 'kamra', 'ury')) {
    Copy-Item -LiteralPath (Join-Path $root "imported\$appName") -Destination (Join-Path $businessDestination "bench\apps\$appName") -Recurse
  }
  Get-ChildItem -LiteralPath (Join-Path $businessDestination 'bench\apps') -Filter '.git' -Recurse -Force | Remove-Item -Force
  Copy-Item -LiteralPath (Join-Path $root 'scripts\business-runtime\tuyu_frappe_runtime.py') -Destination $businessDestination
  Copy-Item -LiteralPath (Join-Path $root 'scripts\business-runtime\tuyu_runtime_common.py') -Destination $businessDestination
  Copy-Item -LiteralPath (Join-Path $root 'scripts\business-runtime\tuyu_voyant_runtime.py') -Destination $businessDestination
  Copy-Item -LiteralPath (Join-Path $root 'scripts\business-runtime\tuyu_hi_events_runtime.py') -Destination $businessDestination
  Copy-Item -LiteralPath (Join-Path $root 'scripts\business-runtime\tuyu_https_proxy.py') -Destination $businessDestination
  Copy-Item -LiteralPath (Join-Path $root 'scripts\business-runtime\runtime.lock.json') -Destination $businessDestination

  if ($CertificateThumbprint) {
    Get-ChildItem -LiteralPath $release -File -Recurse |
      Where-Object { $_.Extension -in @('.exe', '.dll') } |
      ForEach-Object {
        & signtool.exe sign /sha1 $CertificateThumbprint /fd SHA256 /tr https://timestamp.digicert.com /td SHA256 $_.FullName
        if ($LASTEXITCODE -ne 0) { throw "signtool failed: $($_.FullName)" }
      }
  }

  # Signing changes PE files, so hash the final release runtime in place.
  $runtimeDestination = Join-Path $release 'postgresql'
  $runtimeManifest = Join-Path $runtimeDestination 'MANIFEST.sha256'
  Get-ChildItem -LiteralPath $runtimeDestination -Recurse -File |
    Where-Object { $_.FullName -ne $runtimeManifest } |
    Sort-Object FullName |
    ForEach-Object {
      $relativePath = $_.FullName.Substring($runtimeDestination.Length).TrimStart([char[]]"\/").Replace('\', '/')
      $fileHash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
      "$fileHash  $relativePath"
    } |
    Set-Content -LiteralPath $runtimeManifest -Encoding Ascii
  & (Join-Path $PSScriptRoot 'verify_bundle.ps1') -Bundle $release -RequireAuthenticode:$([bool]$CertificateThumbprint)

  Compress-Archive -LiteralPath $release -DestinationPath $archive -CompressionLevel Optimal
  $hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
  Set-Content -LiteralPath "$archive.sha256" -Value "$hash *$(Split-Path $archive -Leaf)" -Encoding Ascii
  Write-Host "Built TuyuBooking Windows x86-64 archive: $archive"
} finally {
  if (Test-Path -LiteralPath $stage) {
    Remove-Item -LiteralPath $stage -Recurse -Force
  }
}
