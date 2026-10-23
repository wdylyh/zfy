#!/bin/bash
fail=0
for e in /d/zfy/examples/*.zfy; do
  name=$(basename "$e" .zfy)
  /d/zfy/compiler/_build/zfyc.exe build "$e" >/dev/null 2>&1
  if [ $? -ne 0 ]; then echo "FAIL(build) $name"; fail=$((fail+1)); continue; fi
  if [ -f "/d/zfy/examples/$name.in" ]; then
    timeout 15 "/d/zfy/examples/$name.exe" < "/d/zfy/examples/$name.in" > "/d/zfy/examples/$name.out" 2> "/d/zfy/examples/$name.err"
  else
    timeout 15 "/d/zfy/examples/$name.exe" < /dev/null > "/d/zfy/examples/$name.out" 2> "/d/zfy/examples/$name.err"
  fi
  rc=$?
  if [ $rc -ne 0 ]; then echo "FAIL(exit=$rc) $name"; fail=$((fail+1)); else echo "PASS $name"; fi
done
echo "failures: $fail"
