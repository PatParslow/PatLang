#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/evaluator'

puts "=== Parser Integration Analysis ==="
puts

# Test 1: Basic constraint parsing
puts "1. Testing basic constraint parsing:"
begin
  code = "constrain x :: Number"
  lexer = Lexer.new(code)
  tokens = lexer.tokenize
  puts "  Tokens: #{tokens.map(&:type)}"
  
  parser = Parser.new(tokens)
  ast = parser.parse
  puts "  AST: #{ast.class} - #{ast}"
  puts "  ✓ Basic constraint parsing works"
rescue => e
  puts "  ✗ Error: #{e.message}"
end
puts

# Test 2: Goal parsing
puts "2. Testing goal parsing:"
begin
  code = "goal find_answer { postcondition: answer > 0 }"
  lexer = Lexer.new(code)
  tokens = lexer.tokenize
  puts "  Tokens: #{tokens.map(&:type)}"
  
  parser = Parser.new(tokens)
  ast = parser.parse
  puts "  AST: #{ast.class} - #{ast}"
  puts "  ✓ Goal parsing works"
rescue => e
  puts "  ✗ Error: #{e.message}"
end
puts

# Test 3: Fact assertion parsing
puts "3. Testing fact assertion parsing:"
begin
  code = "assert fact(likes(alice, bob))"
  lexer = Lexer.new(code)
  tokens = lexer.tokenize
  puts "  Tokens: #{tokens.map(&:type)}"
  
  parser = Parser.new(tokens)
  ast = parser.parse
  puts "  AST: #{ast.class} - #{ast}"
  puts "  ✓ Fact assertion parsing works"
rescue => e
  puts "  ✗ Error: #{e.message}"
end
puts

# Test 4: Rule parsing
puts "4. Testing rule parsing:"
begin
  code = "rule parent(X, Y) if likes(X, Y)"
  lexer = Lexer.new(code)
  tokens = lexer.tokenize
  puts "  Tokens: #{tokens.map(&:type)}"
  
  parser = Parser.new(tokens)
  ast = parser.parse
  puts "  AST: #{ast.class} - #{ast}"
  puts "  ✓ Rule parsing works"
rescue => e
  puts "  ✗ Error: #{e.message}"
end
puts

# Test 5: Query parsing
puts "5. Testing query parsing:"
begin
  code = "query likes(X, bob)"
  lexer = Lexer.new(code)
  tokens = lexer.tokenize
  puts "  Tokens: #{tokens.map(&:type)}"
  
  parser = Parser.new(tokens)
  ast = parser.parse
  puts "  AST: #{ast.class} - #{ast}"
  puts "  ✓ Query parsing works"
rescue => e
  puts "  ✗ Error: #{e.message}"
end
puts

# Test 6: Reasoning mode parsing
puts "6. Testing reasoning mode parsing:"
begin
  code = "reasoning mode on"
  lexer = Lexer.new(code)
  tokens = lexer.tokenize
  puts "  Tokens: #{tokens.map(&:type)}"
  
  parser = Parser.new(tokens)
  ast = parser.parse
  puts "  AST: #{ast.class} - #{ast}"
  puts "  ✓ Reasoning mode parsing works"
rescue => e
  puts "  ✗ Error: #{e.message}"
end
puts

puts "=== Analysis Complete ==="