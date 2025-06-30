#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/evaluator'

puts "=== Advanced Parser Integration Analysis ==="
puts

# Test 1: Complex constraint with conditions
puts "1. Testing constraint with WHERE clause:"
begin
  code = "constrain age :: Number where age >= 0 and age <= 150"
  lexer = Lexer.new(code)
  tokens = lexer.tokenize
  puts "  Tokens: #{tokens.map(&:type).join(', ')}"
  
  parser = Parser.new(tokens)
  ast = parser.parse
  puts "  AST: #{ast.class} - #{ast}"
  puts "  ✓ Complex constraint parsing works"
rescue => e
  puts "  ✗ Error: #{e.message}"
end
puts

# Test 2: Dotted constraint expressions
puts "2. Testing dotted constraint expressions:"
begin
  code = "constrain user.age :: Number"
  lexer = Lexer.new(code)
  tokens = lexer.tokenize
  puts "  Tokens: #{tokens.map(&:type).join(', ')}"
  
  parser = Parser.new(tokens)
  ast = parser.parse
  puts "  AST: #{ast.class} - #{ast}"
  puts "  ✓ Dotted constraint parsing works"
rescue => e
  puts "  ✗ Error: #{e.message}"
end
puts

# Test 3: Goal with parameters and complex conditions
puts "3. Testing goal with parameters:"
begin
  code = "goal solve_equation(a, b, c) { precondition: a != 0, postcondition: result > 0 }"
  lexer = Lexer.new(code)
  tokens = lexer.tokenize
  puts "  Tokens: #{tokens.map(&:type).join(', ')}"
  
  parser = Parser.new(tokens)
  ast = parser.parse
  puts "  AST: #{ast.class} - #{ast}"
  puts "  ✓ Goal with parameters parsing works"
rescue => e
  puts "  ✗ Error: #{e.message}"
end
puts

# Test 4: Rule with :- syntax
puts "4. Testing rule with :- syntax:"
begin
  code = "rule ancestor(X, Z) :- parent(X, Y), ancestor(Y, Z)"
  lexer = Lexer.new(code)
  tokens = lexer.tokenize
  puts "  Tokens: #{tokens.map(&:type).join(', ')}"
  
  parser = Parser.new(tokens)
  ast = parser.parse
  puts "  AST: #{ast.class} - #{ast}"
  puts "  ✓ Rule with :- syntax parsing works"
rescue => e
  puts "  ✗ Error: #{e.message}"
end
puts

# Test 5: Prolog-style query
puts "5. Testing Prolog-style query:"
begin
  code = "?- parent(john, X)"
  lexer = Lexer.new(code)
  tokens = lexer.tokenize
  puts "  Tokens: #{tokens.map(&:type).join(', ')}"
  
  parser = Parser.new(tokens)
  ast = parser.parse
  puts "  AST: #{ast.class} - #{ast}"
  puts "  ✓ Prolog-style query parsing works"
rescue => e
  puts "  ✗ Error: #{e.message}"
end
puts

# Test 6: Pursue statement
puts "6. Testing pursue statement:"
begin
  code = "pursue find_answer"
  lexer = Lexer.new(code)
  tokens = lexer.tokenize
  puts "  Tokens: #{tokens.map(&:type).join(', ')}"
  
  parser = Parser.new(tokens)
  ast = parser.parse
  puts "  AST: #{ast.class} - #{ast}"
  puts "  ✓ Pursue statement parsing works"
rescue => e
  puts "  ✗ Error: #{e.message}"
end
puts

# Test 7: Type annotation syntax
puts "7. Testing type annotation syntax:"
begin
  code = "x :: Number"
  lexer = Lexer.new(code)
  tokens = lexer.tokenize
  puts "  Tokens: #{tokens.map(&:type).join(', ')}"
  
  parser = Parser.new(tokens)
  ast = parser.parse
  puts "  AST: #{ast.class} - #{ast}"
  puts "  ✓ Type annotation parsing works"
rescue => e
  puts "  ✗ Error: #{e.message}"
end
puts

# Test 8: Typed assignment
puts "8. Testing typed assignment:"
begin
  code = "x: Number = 42"
  lexer = Lexer.new(code)
  tokens = lexer.tokenize
  puts "  Tokens: #{tokens.map(&:type).join(', ')}"
  
  parser = Parser.new(tokens)
  ast = parser.parse
  puts "  AST: #{ast.class} - #{ast}"
  puts "  ✓ Typed assignment parsing works"
rescue => e
  puts "  ✗ Error: #{e.message}"
end
puts

puts "=== Advanced Analysis Complete ==="