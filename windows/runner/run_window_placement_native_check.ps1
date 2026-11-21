$ErrorActionPreference = 'Stop'
$compiler = Get-Command cl.exe -ErrorAction SilentlyContinue
if ($null -eq $compiler) {
  throw 'Run this check from a Visual Studio Native Tools PowerShell prompt.'
}

$tempDirectory = Join-Path ([IO.Path]::GetTempPath()) "iris-window-check-$([guid]::NewGuid())"
$testSource = Join-Path $PSScriptRoot 'window_placement_store_test.cpp'
$storeSource = Join-Path $PSScriptRoot 'window_placement_store.cpp'
New-Item -ItemType Directory -Path $tempDirectory | Out-Null
Push-Location -LiteralPath $tempDirectory
try {
  & $compiler.Source /nologo /std:c++17 /EHsc /W4 /WX /DUNICODE /D_UNICODE /DNOMINMAX `
    /Fe:window_placement_store_test.exe $testSource $storeSource user32.lib shell32.lib ole32.lib
  if ($LASTEXITCODE -ne 0) { throw "Native check compilation failed: $LASTEXITCODE" }

  & .\window_placement_store_test.exe
  if ($LASTEXITCODE -ne 0) { throw "Native check failed: $LASTEXITCODE" }
} finally {
  Remove-Item -LiteralPath window_placement_store_test.exe, window_placement_store_test.obj, `
    window_placement_store.obj -Force -ErrorAction SilentlyContinue
  Pop-Location
  [IO.Directory]::Delete($tempDirectory)
}
