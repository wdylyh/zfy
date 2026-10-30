# regression: build & run all examples (stdin from <name>.in if present)
Write-Output "REGRESS v2"
$examples = Get-ChildItem d:\zfy\examples\*.zfy
$fail = 0
foreach ($e in $examples) {
  $name = $e.BaseName
  $expectFile = "d:\zfy\examples\$name.expect"
  # freestanding 裸机用例（frs_* 报错用例 / freestanding_* 冒烟）：
  # 走 --freestanding --no-link（宿主 Windows 无法链接裸机 ELF，
  # 只验证编译成功与 IR 产物；带 .expect 的仍按编译失败断言）
  $fs = ($name -like "frs_*") -or ($name -like "freestanding_*")
  $zargs = @("build")
  if ($fs) { $zargs += @("--freestanding", "--no-link") }
  $zargs += $e.FullName
  Write-Output "LOOP[$name] fs=$fs args=$($zargs -join '|')"
  if (Test-Path $expectFile) {
    # 预期编译失败用例：错误输出须包含基线子串
    $log = & d:\zfy\compiler\_build\zfyc.exe @zargs 2>&1 | ForEach-Object { $_.ToString() }
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
  if ($fs) {
    # freestanding 冒烟：编译须成功，且 IR 含裸机入口与 panic 适配器
    $log = & d:\zfy\compiler\_build\zfyc.exe @zargs 2>&1 | ForEach-Object { $_.ToString() }
    if ($LASTEXITCODE -ne 0) {
      Write-Host "FAIL(build) $name"
      $log | ForEach-Object { Write-Host $_ }
      $fail++
      continue
    }
    $llFile = "d:\zfy\examples\$name.ll"
    $txt = Get-Content $llFile -Raw
    if (-not $txt.Contains("define void @_start()")) {
      Write-Host "FAIL(no-entry) $name"
      $fail++
    } elseif (-not $txt.Contains("zfy.fs.panic_adapter")) {
      Write-Host "FAIL(no-panic-hook) $name"
      $fail++
    } else {
      Write-Host "PASS $name"
    }
    continue
  }
  $null = & d:\zfy\compiler\_build\zfyc.exe @zargs 2>&1
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
