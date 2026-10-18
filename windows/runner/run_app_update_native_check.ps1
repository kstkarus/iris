$ErrorActionPreference = 'Stop'
$compiler = Get-Command cl.exe -ErrorAction SilentlyContinue
if ($null -eq $compiler) {
  throw 'Run this check from a Visual Studio Native Tools PowerShell prompt.'
}

$testSource = Join-Path $PSScriptRoot 'app_update_utils_test.cpp'
$outputPath = Join-Path ([IO.Path]::GetTempPath()) "iris-update-native-check-$PID.exe"
$objectPath = Join-Path ([IO.Path]::GetTempPath()) "iris-update-native-check-$PID.obj"

try {
  & $compiler.Source /nologo /std:c++17 /EHsc /W4 /WX /DUNICODE /D_UNICODE /DNOMINMAX `
    "/Fo:$objectPath" "/Fe:$outputPath" $testSource
  if ($LASTEXITCODE -ne 0) { throw "Native check compilation failed: $LASTEXITCODE" }

  & $outputPath
  if ($LASTEXITCODE -ne 0) { throw "Native check failed: $LASTEXITCODE" }
} finally {
  Remove-Item -LiteralPath $outputPath, $objectPath -Force -ErrorAction SilentlyContinue
}
