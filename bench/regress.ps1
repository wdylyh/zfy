# regression: build & run all examples (stdin from <name>.in if present)
$examples = Get-ChildItem d:\zfy\examples\*.zfy
$fail = 0
foreach ($e in $examples) {
  $name = $e.BaseName
  $expectFile = "d:\zfy\examples\$name.expect"
  if (Test-Path $expectFile) {
    # 预期编译失败用例：错误输出须包含基线子串
    $log = d:\zfy\compiler\_build\zfyc.exe build $e.FullName 2>&1 | ForEach-Object { $_.ToString() }
    # 控制台宽度会把长文案从单词中间折断——双方去空白后再匹配
    $flat = ($log -join "") -replace "\s", ""
    $needle = ((Get-Content $expectFile -Raw) -replace "\s", "")
    if ($LASTEXITCODE -eq 0) {
      Write-Host "FAIL(no-error) $name"
      $fail++
    } elseif (-not $flat.Contains($needle)) {
      Write-Host "FAIL(wrong-error) $name (expected '$needle')"
      $fail++
    } else {
      Write-Host "PASS $name"
    }
    continue
  }
  $null = d:\zfy\compiler\_build\zfyc.exe build $e.FullName 2>&1
  if ($LASTEXITCODE -ne 0) {
    Write-Host "FAIL(build) $name"
    $fail++
    continue
  }
  $inFile = "d:\zfy\examples\$name.in"
  $args = @()
  if (Test-Path $inFile) {
    $p = Start-Process "d:\zfy\examples\$name.exe" -PassThru -RedirectStandardInput $inFile -RedirectStandardOutput "d:\zfy\examples\$name.out" -RedirectStandardError "d:\zfy\examples\$name.err" -WindowStyle Hidden
  } else {
    $p = Start-Process "d:\zfy\examples\$name.exe" -PassThru -RedirectStandardOutput "d:\zfy\examples\$name.out" -RedirectStandardError "d:\zfy\examples\$name.err" -WindowStyle Hidden
  }
  $null = $p.Handle
  $h = $p.WaitForExit(15000)
  if (-not $h) {
    Stop-Process -Id $p.Id -Force
    Write-Host "FAIL(hang) $name"
    $fail++
  } else {
    $code = $p.ExitCode
    if ($null -eq $code -or $code -ne 0) {
      Write-Host "FAIL(exit=$code) $name"
      $fail++
    } else {
      Write-Host "PASS $name"
    }
  }
}
Write-Host "failures: $fail"
