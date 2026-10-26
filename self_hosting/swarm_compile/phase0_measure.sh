#!/bin/bash
# Swarm compiler Phase 0: per-stage timing via an external sampler of
# genb_tempdebug.txt (no compiler changes), plus a determinism check.
cd /d/PatLang
OUT=self_hosting/build/phase0
DBG=self_hosting/build/genb_tempdebug.txt
run_one() {  # label input output
  rm -rf self_hosting/build/x64_obj_cache; mkdir -p self_hosting/build/x64_obj_cache
  rm -f $DBG
  local log=$OUT/$1.samples
  : > $log
  ./patc1.exe $2 $3 --x64 > $OUT/$1.out 2>&1 &
  local pid=$!
  local last=""
  echo "START $(date +%s%3N)" >> $log
  while kill -0 $pid 2>/dev/null; do
    if [ -f $DBG ]; then
      cur=$(cat $DBG 2>/dev/null)
      if [ "$cur" != "$last" ]; then echo "$(date +%s%3N) $cur" >> $log; last="$cur"; fi
    fi
    sleep 1
  done
  wait $pid
  echo "END $(date +%s%3N) exit=$?" >> $log
}
run_one mini1 self_hosting/build/patc1_mini_all.patlang $OUT/mini1.exe
run_one mini2 self_hosting/build/patc1_mini_all.patlang $OUT/mini2.exe
if cmp -s $OUT/mini1.exe $OUT/mini2.exe; then echo "DETERMINISM identical" > $OUT/determinism.txt; else cmp $OUT/mini1.exe $OUT/mini2.exe > $OUT/determinism.txt 2>&1; echo "differing bytes: $(cmp -l $OUT/mini1.exe $OUT/mini2.exe | wc -l)" >> $OUT/determinism.txt; fi
run_one full self_hosting/build/patc1_all.patlang $OUT/full.exe
echo DONE > $OUT/done.txt
