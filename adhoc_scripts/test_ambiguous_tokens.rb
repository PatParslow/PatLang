#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/token'
require_relative 'src/ambiguous_token'

puts "=== TESTING AMBIGUOUS TOKEN CREATION ==="
puts

test_cases = [
  {
    name: "Test 'a' returns AmbiguousToken",
    code: "a = 5",
    expected_word: "a"
  },
  {
    name: "Test 'function' returns AmbiguousToken", 
    code: "function test",
    expected_word: "function"
  },
  {
    name: "Test 'called' returns AmbiguousToken",
    code: "called test",
    expected_word: "called"
  },
  {
    name: "Test 'make' in complete phrase",
    code: "make a function called test",
    expected_word: "make"
  }
]

test_cases.each do |test_case|
  puts "--- #{test_case[:name]} ---"
  puts "Code: #{test_case[:code]}"
  
  begin
    lexer = Lexer.new(test_case[:code])
    tokens = lexer.tokenize
    
    puts "Tokens:"
    tokens.each_with_index do |token, i|
      next if token.type == Token::TOKEN_TYPES[:EOF]
      
      if token.is_a?(AmbiguousToken)
        puts "  #{i}: AmbiguousToken(#{token.value}) with possibilities:"
        token.possibilities.each do |poss|
          puts "    - #{poss[:type]} (#{poss[:value]})"
        end
      else
        puts "  #{i}: #{token.type} (#{token.value})"
      end
    end
    
    # Find the target word token
    target_token = tokens.find { |t| t.value == test_case[:expected_word] }
    if target_token
      if target_token.is_a?(AmbiguousToken)
        puts "✅ SUCCESS: '#{test_case[:expected_word]}' is an AmbiguousToken"
      else
        puts "ℹ️  INFO: '#{test_case[:expected_word]}' is concrete token: #{target_token.type}"
      end
    else
      puts "❌ ERROR: '#{test_case[:expected_word]}' token not found"
    end
    
  rescue => e
    puts "❌ ERROR: #{e.message}"
    puts "Backtrace: #{e.backtrace.first}"
  end
  
  puts
end