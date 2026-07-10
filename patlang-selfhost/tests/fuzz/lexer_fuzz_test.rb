# patlang lexer fuzz test entry point (scaffolding)
# Usage: ruby lexer_fuzz_test.rb

def fuzz_lexer(input)
  # TODO: Integrate with actual lexer
  puts "Fuzzing lexer with: \#{input.inspect}"
end

# Minimal smoke test
inputs = [
  "let x = 42",
  "",
  "invalid_token @@@"
]

inputs.each { |input| fuzz_lexer(input) }