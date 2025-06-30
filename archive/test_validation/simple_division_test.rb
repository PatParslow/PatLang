#!/usr/bin/env ruby

# Simple test to validate division by zero error handling
puts "Testing division by zero error handling..."

begin
  require_relative 'test/helpers/test_helper'
  require_relative 'src/lexer'
  require_relative 'src/parser'
  require_relative 'src/evaluator'
  require_relative 'src/exceptions'

  evaluator = Evaluator.new
  input = <<~PATLANG
make a function called divide takes: x, y {
  return x / y
}
call divide(10, 0)
PATLANG

  lexer = Lexer.new(input)
  tokens = lexer.tokenize
  parser = Parser.new(tokens)
  ast = parser.parse
  result = evaluator.evaluate(ast)
  
  puts "ERROR: Should have thrown PatlangDivisionByZeroError, but got result: #{result}"
  
rescue PatlangDivisionByZeroError => e
  puts "SUCCESS: PatlangDivisionByZeroError caught!"
  puts "Message: #{e.message}"
  
  if e.message.match?(/Division by zero/i)
    puts "Message validation: PASS"
    puts "OVERALL: VALIDATION SUCCESSFUL - FIX IS WORKING"
  else
    puts "Message validation: FAIL - missing 'Division by zero'"
    puts "OVERALL: VALIDATION FAILED"
  end
  
rescue ZeroDivisionError => e
  puts "FAIL: Ruby ZeroDivisionError still being thrown"
  puts "Message: #{e.message}"
  puts "OVERALL: VALIDATION FAILED - FIX NOT WORKING"
  
rescue => e
  puts "ERROR: #{e.class} - #{e.message}"
  puts "OVERALL: VALIDATION FAILED - UNEXPECTED ERROR"
end