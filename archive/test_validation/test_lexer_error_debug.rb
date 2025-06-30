#!/usr/bin/env ruby

require_relative 'src/lexer'

def test_lexer_error_cases
  puts "=== Testing Lexer Error Cases ==="
  
  invalid_inputs = ['@', '$', '^', '&', '~', '`']
  
  invalid_inputs.each do |invalid_char|
    puts "\n--- Testing: #{invalid_char.inspect} ---"
    begin
      lexer = Lexer.new(invalid_char)
      result = lexer.tokenize
      puts "❌ Expected RuntimeError but got result: #{result.inspect}"
    rescue RuntimeError => e
      puts "✅ Correctly raised RuntimeError: #{e.message}"
    rescue => e
      puts "⚠️  Got unexpected error type: #{e.class}: #{e.message}"
    end
  end
end

test_lexer_error_cases