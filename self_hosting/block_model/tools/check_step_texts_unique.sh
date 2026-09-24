#!/bin/sh
# The Gherkin runner's exact-step registry is keyed by step TEXT, and
# re-registering a text silently REPLACES the earlier registration -- so two
# features that reuse a step phrase for different checks quietly run the
# wrong one, with no error. This lists every step text registered against
# more than one non-noop function in spec_steps_block_model.patlang.
# Exit 1 (and print the offenders) if any exist; exit 0 if none.
#
# Usage (from anywhere): sh self_hosting/block_model/tools/check_step_texts_unique.sh
cd "$(dirname "$0")/../../.." || exit 1
DUPS=$(grep -oE 'step\("[^"]*(\\"[^"]*)*", "st_[a-z_0-9]+"\)' self_hosting/block_model/spec_steps_block_model.patlang \
  | grep -v '"st_noop"' \
  | sed -E 's/, "st_[a-z_0-9]+"\)$//' \
  | sort | uniq -d)
if [ -n "$DUPS" ]; then
  echo "DUPLICATE step texts (a later registration silently replaces an earlier one):"
  echo "$DUPS"
  exit 1
fi
echo "ok: every non-noop step text in spec_steps_block_model.patlang is registered exactly once"
