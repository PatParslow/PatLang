#!/bin/sh
# Re-runs bm_parity_one.sh across every self_hosting/*_selftest.patlang file,
# writing one result line per program to stdout, into a fresh, dedicated OUT
# dir.
#
# Concurrency history: the 2026-09-25 cutover report flagged that higher
# concurrency against the shared x64_obj_cache produced visibly different
# pass counts (23, 30, 29) across attempts, so this originally ran at a
# deliberately low parallelism (2) to trade speed for a trustworthy number.
# Root-caused 2026-10-18: ObjCache.store() copied straight onto the final
# hash-named path (std::fs::copy, not atomic), so a concurrent has()/store()
# for the same content hash could observe a partially-written .obj. Fixed in
# self_hosting/lib/x64_obj_cache.patlang (copy to a per-writer temp path,
# then rename_file -- atomic on one filesystem) -- concurrency is no longer
# the correctness hazard it was, so this runs at a higher parallelism now.
# Don't trust this comment either: if the cache mechanism changes again,
# re-verify before assuming either number is still right.
CONCURRENCY=6
set -u
cd "$(dirname "$0")/../.." || exit 1
OUT="self_hosting/build/parity_check_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT"
echo "Output dir: $OUT" >&2
find self_hosting -maxdepth 1 -iname "*_selftest.patlang" | sort > "$OUT/_files.txt"
TOTAL=$(wc -l < "$OUT/_files.txt")
echo "Checking $TOTAL files, $CONCURRENCY at a time..." >&2
: > "$OUT/_results.txt"
i=0
while read -r f; do
  i=$((i + 1))
  self_hosting/tools/bm_parity_one.sh "$f" "$OUT" --x64 >> "$OUT/_results.txt" &
  if [ $((i % CONCURRENCY)) -eq 0 ]; then
    wait
  fi
  echo "($i/$TOTAL queued: $f)" >&2
done < "$OUT/_files.txt"
wait
echo "=== Summary ===" >&2
sort "$OUT/_results.txt" | awk '{print $2}' | sort | uniq -c
cat "$OUT/_results.txt"
