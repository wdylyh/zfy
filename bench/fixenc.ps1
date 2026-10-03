$path = 'd:\zfy\compiler\lib\mir.ml'
$bytes = [IO.File]::ReadAllBytes($path)
$utf8 = New-Object Text.UTF8Encoding($false)
$text = $utf8.GetString($bytes)
# reverse the mojibake: encode the (garbled) chars back to GBK bytes, then decode as UTF-8
$gbk = [Text.Encoding]::GetEncoding(936)
$origBytes = $gbk.GetBytes($text)
$orig = $utf8.GetString($origBytes)
# sanity: original must decode cleanly (strict)
$strict = New-Object Text.UTF8Encoding($false, $true)
$null = $strict.GetString($origBytes)
[IO.File]::WriteAllText($path, $orig, (New-Object Text.UTF8Encoding($false)))
Write-Host "repaired"
