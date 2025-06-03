#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/token'

# Test script to isolate lexer regression issues
puts "=== LEXER REGRESSION ANALYSIS ==="
puts

# Test cases that are failing
test_cases = [
  # From failing test: test_function_keywords expects "a" to be IDENTIFIER
  {
    name: "Basic function definition",
    code: "make a function called test_func",
    expected_a_token: :IDENTIFIER,
    description: "Should tokenize 'a' as IDENTIFIER in function phrase"
  },
  
  # Simpler cases to understand the logic
  {
    name: "Just 'a' standalone",
    code: "a = 5",
    expected_a_token: :IDENTIFIER,
    description: "Should tokenize 'a' as IDENTIFIER in assignment"
  },
  
  {
    name: "Make without function phrase",
    code: "make something",
    expected_a_token: nil,
    description: "Make without function phrase"
  },
  
  {
    name: "Arithmetic with 'a'",
    code: "x = a + 3",
    expected_a_token: :IDENTIFIER,
    description: "Should tokenize 'a' as IDENTIFIER in arithmetic"
  }
]

test_cases.each do |test_case|
  puts "--- #{test_case[:name]} ---"
  puts "Code: #{test_case[:code]}"
  puts "Description: #{test_case[:description]}"
  
  begin
    lexer = Lexer.new(test_case[:code])
    tokens = lexer.tokenize
    
    puts "Tokens:"
    tokens.each_with_index do |token, i|
      next if token.type == Token::TOKEN_TYPES[:EOF]
      puts "  #{i}: #{token.type} (#{token.value})"
    end
    
    # Find 'a' token if it exists
    a_token = tokens.find { |t| t.value == "a" }
    if a_token
      puts "Found 'a' token: #{a_token.type}"
      if test_case[:expected_a_token]
        expected_type = Token::TOKEN_TYPES[test_case[:expected_a_token]]
        if a_token.type == expected_type
          puts "✅ PASS: 'a' correctly tokenized as #{test_case[:expected_a_token]}"
        else
          puts "❌ FAIL: Expected #{test_case[:expected_a_token]} (#{expected_type}), got #{a_token.type}"
        end
      end
    elsif test_case[:expected_a_token]
      puts "❌ FAIL: Expected 'a' token but none found"
    else
      puts "✅ PASS: No 'a' token as expected"
    end
    
  rescue => e
    puts "❌ ERROR: #{e.message}"
  end
  
  puts
end

puts "=== CONTEXT DETECTION DEBUGGING ==="
puts

# Debug the context detection methods directly
lexer = Lexer.new("make a function called test")

# Move to position where 'a' would be tokenized
lexer.instance_eval do
  # Skip "make "
  5.times { advance }
  
  puts "Current position: #{@position}"
  puts "Current char: '#{@current_char}'"
  puts "Next few chars: '#{@text[@position, 10]}'"
  
  # Test the context detection methods
  puts "in_function_phrase_context?: #{in_function_phrase_context?}"
  puts "check_function_phrase: #{check_function_phrase}"
  puts "check_partial_function_phrase: #{check_partial_function_phrase}"
end

puts
puts "=== ROOT CAUSE ANALYSIS ==="
puts

# Let's also test some cases that might reveal the issue
edge_cases = [
  "a = 5",  # Simple assignment
  "make a thing",  # Make without function
  "make a function",  # Partial function phrase
  "make function called test",  # Missing 'a'
]

edge_cases.each do |code|
  puts "Testing: '#{code}'"
  begin
    lexer = Lexer.new(code)
    tokens = lexer.tokenize
    a_token = tokens.find { |t| t.value == "a" }
    if a_token
      puts "  'a' token type: #{a_token.type}"
    else
      puts "  No 'a' token found"
    end
  rescue => e
    puts "  ERROR: #{e.message}"
  end
end