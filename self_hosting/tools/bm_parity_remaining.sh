#!/bin/sh
# Continues the parity check in the SAME output dir, skipping names already
# in _results.txt, at higher parallelism (4, up from 2). Note (2026-09-25
# report): higher concurrency against the shared x64_obj_cache has been
# observed to produce visibly different pass counts across attempts --
# trading some reproducibility for speed here, by explicit request.
set -u
cd "$(dirname "$0")/../.." || exit 1
OUT="$1"
PAR="${2:-4}"
cut -d' ' -f1 "$OUT/_results.txt" | sort > "$OUT/_done.txt"
sed 's/\.patlang$//' "$OUT/_files.txt" | xargs -n1 basename | sort > "$OUT/_all_basenames.txt"
comm -23 "$OUT/_all_basenames.txt" "$OUT/_done.txt" > "$OUT/_remaining.txt"
TOTAL=$(wc -l < "$OUT/_remaining.txt")
echo "Remaining: $TOTAL files, $PAR at a time" >&2
i=0
while read -r name; do
  i=$((i + 1))
  f="self_hosting/${name}.patlang"
  self_hosting/tools/bm_parity_one.sh "$f" "$OUT" --x64 >> "$OUT/_results.txt" &
  if [ $((i % PAR)) -eq 0 ]; then
    wait
  fi
  echo "($i/$TOTAL queued: $name)" >&2
done < "$OUT/_remaining.txt"
wait
echo "=== Summary (all results so far) ===" >&2
awk '{print $2}' "$OUT/_results.txt" | sort | uniq -c
