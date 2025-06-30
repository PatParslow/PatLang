require_relative 'src/lexer'
require_relative 'src/parser'

# Test to confirm the timing issue between token resolution and parser peeking
def test_timing_issue
  puts "=== Token Resolution Timing Issue Analysis ==="
  
  code = 'make a function called test { return "works" }'
  puts "Testing: #{code}"
  
  # Step 1: Create parser
  lexer = Lexer.new(code)
  tokens = lexer.tokenize
  parser = Parser.new(tokens)
  
  puts "\n--- Initial State ---"
  puts "Parser @tokens before parse():"
  parser.instance_variable_get(:@tokens).each_with_index do |token, i|
    puts "  #{i}: #{token} (class: #{token.class})"
  end
  
  puts "Parser current_token: #{parser.current_token}"
  puts "Parser peek(1): #{parser.peek(1)}"
  puts "Parser peek(2): #{parser.peek(2)}"
  
  puts "\n--- The Critical Issue ---"
  puts "The parser's parse() method calls @token_resolver.resolve_all_ambiguous_tokens"
  puts "and updates @tokens, but the parser is still peeking at the OLD unresolved tokens!"
  
  puts "\n--- Manual Resolution Test ---"
  token_resolver = parser.instance_variable_get(:@token_resolver)
  resolved_tokens = token_resolver.resolve_all_ambiguous_tokens
  
  puts "Resolved tokens:"
  resolved_tokens.each_with_index do |token, i|
    puts "  #{i}: #{token} (class: #{token.class})"
  end
  
  puts "\n--- After Manual Token Update ---"
  # Manually update the parser's token array to see what should happen
  parser.instance_variable_set(:@tokens, resolved_tokens)
  parser.instance_variable_set(:@current_token_index, 0)
  parser.instance_variable_set(:@current_token, resolved_tokens[0])
  
  puts "Parser current_token: #{parser.current_token}"
  puts "Parser peek(1): #{parser.peek(1)}"
  puts "Parser peek(2): #{parser.peek(2)}"
  
  # Check the function definition conditions now
  peek1 = parser.peek(1)
  peek2 = parser.peek(2)
  
  condition1 = peek1&.type == :IDENTIFIER && peek1&.value == "a" && peek2&.type == :FUNCTION
  condition2 = peek1&.type == :FUNCTION
  
  puts "\nFunction definition detection:"
  puts "  Condition 1 (make a function): #{condition1}"
  puts "  Condition 2 (make function): #{condition2}"
  
  if condition1 || condition2
    puts "  -> Should work now!"
  else
    puts "  -> Still broken - TokenResolver is the core issue"
  end
end

test_timing_issue