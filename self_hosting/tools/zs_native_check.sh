#!/bin/sh
# Native (x64) cross-check of the schema library selftests: compile each with
# the self-hosted compiler in parallel (about 5 minutes), run each, and print pass
# counts. Expect zs_expr, zs_schema and zs_feature to match the interpreter; the
# tick section of zs_explore stops with a segmentation fault natively (see zs_expr.patlang).
cd /d/PatLang || exit 1
for t in zs_expr zs_schema zs_explore zs_feature; do
  ( ./patc1.exe self_hosting/${t}_selftest.patlang self_hosting/build/${t}_native.exe --x64 > /tmp/native_${t}_compile.txt 2>&1
    echo "compile_exit=$?" >> /tmp/native_${t}_compile.txt ) &
done
wait
for t in zs_expr zs_schema zs_explore zs_feature; do
  if [ -x self_hosting/build/${t}_native.exe ]; then
    ./self_hosting/build/${t}_native.exe > /tmp/native_${t}_run.txt 2>&1
    printf "%s: " "$t"
    grep -a -E "^tests:" /tmp/native_${t}_run.txt
  else
    echo "$t: no executable"
  fi
done
echo "NATIVE_CHECK_DONE"
