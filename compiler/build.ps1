# zfy 编译器构建脚本（不依赖 dune，直接 ocamlopt）
$ErrorActionPreference = "Stop"
$env:Path = "D:\opam\bin;D:\opam\ocaml-variants.4.14.2+mingw64c\bin;D:\mingw64\bin;$env:Path"

$root = $PSScriptRoot
$build = Join-Path $root "_build"
New-Item -ItemType Directory -Force -Path $build | Out-Null

# 按依赖顺序编译 lib 模块，再链接 bin/zfyc.ml
$libSources = @(
  "lib/tokens.ml",
  "lib/lexer.ml",
  "lib/ast.ml",
  "lib/parser.ml",
  "lib/hir.ml",
  "lib/typeck.ml",
  "lib/mir.ml",
  "lib/llvmgen.ml",
  "lib/driver.ml"
)

$cmx = @()
foreach ($src in $libSources) {
  $full = Join-Path $root $src
  if (Test-Path $full) {
    & ocamlopt -I $build -c -o (Join-Path $build ([IO.Path]::GetFileNameWithoutExtension($src) + ".cmx")) $full
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $cmx += (Join-Path $build ([IO.Path]::GetFileNameWithoutExtension($src) + ".cmx"))
  }
}

# flexlink 不读取 FLEXLINKFLAGS，用 -cclib 显式传库搜索路径
$cclibs = @(
  "-cclib", "-LD:/mingw64/x86_64-w64-mingw32/lib",
  "-cclib", "-LD:/mingw64/lib",
  "-cclib", "-LD:/mingw64/lib/gcc/x86_64-w64-mingw32/16.2.0"
)

& ocamlopt -I $build -o (Join-Path $build "zfyc.exe") @cclibs @cmx (Join-Path $root "bin/zfyc.ml")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "OK: $build\zfyc.exe"
