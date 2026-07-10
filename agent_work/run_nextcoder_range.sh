#!/bin/bash
MODEL="nextcoder:latest"

declare -a TASKS=(
  "bank|Keep track of a bank account balance that supports deposits and withdrawals, and show it working correctly for two separate accounts (alice and bob) that end up with different balances."
  "thermostat|Build a simple thermostat: when a temperature reading comes in, print a heating message if it is below 65, a cooling message if it is above 78, and an OK message otherwise. Demonstrate it with a few sample readings."
  "family|Given a list of parent-child relationships in a family, write a program that can answer how many children a given person has. Demonstrate it with a small family of at least 4 people where one person has multiple children."
  "evens_squared|Given a list of numbers, produce a new list containing only the even numbers, each squared."
  "fibonacci|Write a function that returns a list of the first N Fibonacci numbers (starting 0, 1, 1, 2, 3, 5, ...). Demonstrate it for N=10."
  "palindrome|Write a function that checks whether a string is a palindrome, ignoring case and spaces (so \"Race car\" counts as a palindrome). Demonstrate it with a few example strings, including at least one palindrome and one non-palindrome."
)

for entry in "${TASKS[@]}"; do
  name="${entry%%|*}"
  task="${entry#*|}"
  echo "=== TASK START: $name at $(date) ==="
  rm -f agent_work/attempt_*.patlang
  printf "%s\n" "$task" | ./rust-runtime/target/release/pat.exe --ir-run self_hosting/tools/agent_team.patlang "$MODEL" > "agent_work/nextcoder_${name}.log" 2>&1
  mkdir -p "agent_work/nextcoder_${name}_attempts"
  cp agent_work/attempt_*.patlang "agent_work/nextcoder_${name}_attempts/" 2>/dev/null
  echo "=== TASK DONE: $name at $(date) ==="
  tail -3 "agent_work/nextcoder_${name}.log"
done
echo "=== NEXTCODER RANGE COMPLETE ==="
