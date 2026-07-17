require_relative 'src/lexer'
require_relative 'src/parser'

# Test to show exactly why the parser fails with the incorrectly resolved tokens
def test_parser_flow_failure
  puts "=== Parser Flow Failure Analysis ==="
  
  code = 'make a function called test { return "works" }'
  puts "Testing: #{code}"
  
  # Get the incorrectly resolved tokens
  lexer = Lexer.new(code)
  tokens = lexer.tokenize
  resolver = ParserModules::TokenResolver.new(tokens)
  resolved_tokens = resolver.resolve_all_ambiguous_tokens
  
  puts "\n--- Resolved Tokens ---"
  resolved_tokens.each_with_index do |token, i|
    puts "#{i}: #{token}"
  end
  
  # Now trace what the parser sees
  puts "\n--- Parser Analysis ---"
  parser = Parser.new(tokens) # This will re-resolve tokens in parse()
  
  # The parser should recognize this as a function definition
  puts "Current token: #{parser.current_token}"
  puts "Parser sees MAKE token, checking if it's a function definition..."
  
  # Check the peek logic from parser.rb lines 82-84
  peek1 = parser.peek(1)
  peek2 = parser.peek(2)
  
  puts "peek(1): #{peek1} (type: #{peek1&.type}, value: #{peek1&.value})"
  puts "peek(2): #{peek2} (type: #{peek2&.type}, value: #{peek2&.value})"
  
  # The parser expects:
  # peek(1) to be IDENTIFIER with value "a" AND peek(2) to be FUNCTION
  # OR just peek(1) to be FUNCTION
  
  condition1 = peek1&.type == :IDENTIFIER && peek1&.value == "a" && peek2&.type == :FUNCTION
  condition2 = peek1&.type == :FUNCTION
  
  puts "\nParser conditions:"
  puts "  Condition 1 (make a function): #{condition1}"
  puts "    peek(1) == IDENTIFIER && value == 'a': #{peek1&.type == :IDENTIFIER && peek1&.value == "a"}"
  puts "    peek(2) == FUNCTION: #{peek2&.type == :FUNCTION}"
  puts "  Condition 2 (make function): #{condition2}"
  
  if condition1 || condition2
    puts "  -> Parser should call function_parser.parse_function_definition"
  else
    puts "  -> Parser will call expression() instead, which leads to factor error"
  end
  
  puts "\n--- The Root Problem ---"
  puts "The TokenResolver is resolving 'function' to IDENTIFIER instead of FUNCTION"
  puts "This breaks the parser's function definition detection logic"
  puts "When parser calls expression() -> primary(), it encounters LBRACE which is not handled in primary()"
end

test_parser_flow_failure