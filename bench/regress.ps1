# regression: build & run all examples (stdin from <name>.in if present)
$examples = Get-ChildItem d:\zfy\examples\*.zfy
$fail = 0
foreach ($e in $examples) {
  $name = $e.BaseName
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
    if ($name -eq "input_fail_test") {
      # fail-fast 测试：预期 exit 1 且 stderr 有 runtime error
      $err = Get-Content "d:\zfy\examples\$name.err" -Raw
      if ($code -eq 1 -and $err -match "runtime error") { Write-Host "PASS $name (expected fail-fast)" }
      else { Write-Host "FAIL(exit=$code) $name"; $fail++ }
    } elseif ($null -eq $code -or $code -ne 0) {
      Write-Host "FAIL(exit=$code) $name"
      $fail++
    } else {
      Write-Host "PASS $name"
    }
  }
}
Write-Host "failures: $fail"
