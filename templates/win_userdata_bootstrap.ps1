$ErrorActionPreference = "Stop"

$PayloadBase64Gzip = @"
${userdata_payload_base64gzip}
"@

$TempDir = "C:\Temp"
if (-not (Test-Path "$TempDir")) {
  New-Item -Path "$TempDir" -ItemType Directory -Force | Out-Null
}

$ExpandedScript = "$TempDir\watchmaker-expanded-userdata.ps1"

$PayloadBytes = [System.Convert]::FromBase64String($PayloadBase64Gzip.Trim())
$MemoryStream = New-Object System.IO.MemoryStream(, $PayloadBytes)
$GzipStream = New-Object System.IO.Compression.GzipStream($MemoryStream, [System.IO.Compression.CompressionMode]::Decompress)
$StreamReader = New-Object System.IO.StreamReader($GzipStream, [System.Text.Encoding]::UTF8)

try {
  $ExpandedContent = $StreamReader.ReadToEnd()
}
finally {
  $StreamReader.Dispose()
  $GzipStream.Dispose()
  $MemoryStream.Dispose()
}

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($ExpandedScript, $ExpandedContent, $Utf8NoBom)

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$ExpandedScript"
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
