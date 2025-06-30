#!/usr/bin/env ruby

require_relative 'src/patlang'
require_relative 'src/lexer'
require_relative 'src/parser'

def test_specific_parser_errors
  puts "=== Testing Specific Parser Error Recovery Cases ==="
  
  # Test cases from the failing tests
  test_cases = [
    {
      name: "if missing end",
      code: "if x == 5 then y = 10",
      should_raise: "RuntimeError"
    },
    {
      name: "while missing do", 
      code: "while x > 0 x = x - 1 end",
      should_raise: "RuntimeError"
    },
    {
      name: "while missing end",
      code: "while x > 0 do x = x - 1", 
      should_raise: "RuntimeError"
    },
    {
      name: "if missing then",
      code: "if x == 5 y = 10 end",
      should_raise: "RuntimeError"  
    },
    {
      name: "assignment missing expression",
      code: "x = ",
      should_raise: "RuntimeError"
    }
  ]
  
  test_cases.each do |test_case|
    puts "\n--- Testing: #{test_case[:name]} ---"
    puts "Code: #{test_case[:code].inspect}"
    
    begin
      lexer = Lexer.new(test_case[:code])
      tokens = lexer.tokenize
      parser = Parser.new(tokens)
      result = parser.parse
      
      puts "❌ Expected #{test_case[:should_raise]} but got result: #{result.inspect}"
    rescue RuntimeError => e
      puts "✅ Correctly raised RuntimeError: #{e.message}"
    rescue => e
      puts "⚠️  Got unexpected error type: #{e.class}: #{e.message}"
    end
  end
end

test_specific_parser_errors