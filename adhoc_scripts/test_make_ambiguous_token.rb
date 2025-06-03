#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/ambiguous_token'

# Test the "make" AmbiguousToken extension
def test_make_ambiguous_token
  puts "🧪 Testing 'make' AmbiguousToken Extension"
  puts "=" * 50
  
  lexer = Lexer.new("make")
  token = lexer.get_next_token
  
  puts "Input: 'make'"
  puts "Token class: #{token.class}"
  
  if token.is_a?(AmbiguousToken)
    puts "✅ SUCCESS: 'make' returns AmbiguousToken"
    puts "Possibilities:"
    token.possibilities.each_with_index do |poss, i|
      puts "  #{i + 1}. #{poss[:type]} -> '#{poss[:value]}'"
    end
    
    # Verify the expected possibilities
    types = token.possibilities.map { |p| p[:type] }
    if types.include?(:MAKE) && types.include?(:IDENTIFIER)
      puts "✅ SUCCESS: Contains both MAKE and IDENTIFIER possibilities"
      return true
    else
      puts "❌ FAILURE: Missing expected token types"
      puts "Expected: [:MAKE, :IDENTIFIER]"
      puts "Got: #{types}"
      return false
    end
  else
    puts "❌ FAILURE: 'make' should return AmbiguousToken, got #{token.class}"
    puts "Token type: #{token.type}"
    puts "Token value: #{token.value}"
    return false
  end
end

# Run the test
success = test_make_ambiguous_token
puts "\n🎯 TEST RESULT: #{success ? 'PASSED' : 'FAILED'}"
exit(success ? 0 : 1)