#!/bin/bash
export ZFY_FORCE=1
fail=0
for e in examples/*.zfy; do
  n=$(basename "$e" .zfy)
  timeout 25 ./compiler/_build/zfyc.exe build "$e" >/dev/null 2>&1
  if [ $? -ne 0 ]; then echo "FAIL(build) $n"; fail=$((fail+1)); continue; fi
  if [ -f "examples/$n.in" ]; then
    timeout 25 ./examples/$n.exe < "examples/$n.in" > /dev/null 2>&1
  else
    timeout 25 ./examples/$n.exe < /dev/null > /dev/null 2>&1
  fi
  c=$?
  if [ $c -ne 0 ]; then echo "FAIL(exit=$c) $n"; fail=$((fail+1)); else echo "PASS $n"; fi
done
echo "failures: $fail"
