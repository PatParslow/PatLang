#!/bin/bash
MODELS="nextcoder:latest qwen2.5-coder:14b qwen3.5:latest gemma4:latest gemma3n:latest"
TASK="Write a function that checks whether a number is prime."
for m in $MODELS; do
  safe=$(echo "$m" | tr ':/' '__')
  echo "=== BENCH START: $m at $(date) ==="
  rm -f agent_work/attempt_*.patlang
  printf "%s\n" "$TASK" | ./rust-runtime/target/release/pat.exe --ir-run self_hosting/tools/agent_team.patlang "$m" > "agent_work/bench2_${safe}.log" 2>&1
  mkdir -p "agent_work/bench2_${safe}_attempts"
  cp agent_work/attempt_*.patlang "agent_work/bench2_${safe}_attempts/" 2>/dev/null
  echo "=== BENCH DONE: $m at $(date) ==="
  tail -3 "agent_work/bench2_${safe}.log"
done
echo "=== ALL BENCHMARKS COMPLETE ==="
