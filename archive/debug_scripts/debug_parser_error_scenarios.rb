#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/exceptions'

# Chain of Drafts Analysis:
# Draft 1: Current fix advances ALL tokens - too aggressive
# Draft 2: Need selective advancement - only for specific tokens
# Draft 3: UNKNOWN/UNTERMINATED cause loops, syntax errors need ParseError
# Draft 4: Unbalanced parens should raise ParseError, not advance
# Draft 5: Key insight - differentiate recovery vs legitimate errors
# Summary: Selective token advancement based on error type needed

puts "=== PARSER ERROR SCENARIO ANALYSIS ==="
puts

# Test scenarios to understand the problem
test_cases = [
  {
    name: "UNKNOWN Token (should advance to prevent infinite loop)",
    code: "@#$%",
    should_advance: true,
    expected_behavior: "Creates ErrorNode, advances past UNKNOWN token"
  },
  {
    name: "Unclosed Parenthesis (should raise ParseError)",
    code: "(2 + 3",
    should_advance: false,
    expected_behavior: "Should raise ParseError for malformed syntax"
  },
  {
    name: "Extra Closing Parenthesis (should raise ParseError)",
    code: "2 + 3)",
    should_advance: false,
    expected_behavior: "Should raise ParseError for malformed syntax"
  },
  {
    name: "Unterminated String (should advance to prevent infinite loop)",
    code: '"hello world',
    should_advance: true,
    expected_behavior: "Creates ErrorNode, advances past unterminated string"
  },
  {
    name: "Invalid Expression Start (context-dependent)",
    code: "+ 5",
    should_advance: false,
    expected_behavior: "Should raise ParseError for invalid expression start"
  }
]

def analyze_token_behavior(code, description)
  puts "--- #{description} ---"
  puts "Code: #{code.inspect}"
  
  begin
    lexer = Lexer.new(code)
    tokens = lexer.tokenize
    puts "Tokens generated: #{tokens.map(&:type).inspect}"
    
    # Check if we have UNKNOWN or problematic tokens
    unknown_tokens = tokens.select { |t| t.type == :UNKNOWN }
    puts "UNKNOWN tokens: #{unknown_tokens.length}"
    
    parser = Parser.new(tokens)
    result = parser.parse
    puts "Parse result: #{result.class}"
    puts "✓ Parsing succeeded (created ErrorNode or valid AST)"
    
  rescue ParseError => e
    puts "ParseError raised: #{e.message}"
    puts "✓ This is expected for malformed syntax"
    
  rescue => e
    puts "Other error: #{e.class} - #{e.message}"
    puts "⚠ Unexpected error type"
  end
  
  puts
end

# Analyze each test case
test_cases.each do |test_case|
  analyze_token_behavior(test_case[:code], test_case[:name])
end

puts "=== PROBLEM ANALYSIS SUMMARY ==="
puts
puts "CHAIN OF DRAFTS FINDINGS:"
puts "1. Lexer creates UNKNOWN tokens for unrecognized characters"
puts "2. Current fix advances ALL error tokens - breaks ParseError tests"
puts "3. Need selective advancement based on token type:"
puts "   - UNKNOWN tokens: ADVANCE (prevents infinite loops)"
puts "   - UNTERMINATED_STRING tokens: ADVANCE (prevents infinite loops)"
puts "   - Syntax errors (unbalanced parens): DON'T ADVANCE (preserve ParseError)"
puts
puts "KEY INSIGHT: Error recovery vs legitimate syntax errors"
puts "- Recovery: Advance past tokens that cause infinite loops"
puts "- Syntax errors: Preserve ParseError raising for malformed constructs"

# Proposed solution logic
puts
puts "=== PROPOSED SOLUTION LOGIC ==="
puts
puts "def create_error_placeholder(message)"
puts "  # Only advance for tokens that cause infinite loops"
puts "  if @parser.current_token && @parser.current_token.type != :EOF"
puts "    case @parser.current_token.type"
puts "    when :UNKNOWN, :UNTERMINATED_STRING"
puts "      # These tokens cause infinite loops - advance past them"
puts "      @parser.advance"
puts "    else"
puts "      # For other tokens, let normal ParseError handling work"
puts "      # Don't advance - this preserves ParseError raising"
puts "    end"
puts "  end"
puts "  ErrorNode.new(message)"
puts "end"
puts
puts "This approach:"
puts "✓ Prevents infinite loops for UNKNOWN/UNTERMINATED_STRING tokens"
puts "✓ Preserves ParseError raising for malformed syntax (parentheses, etc.)"
puts "✓ Maintains compatibility with existing error handling tests"