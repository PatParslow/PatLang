#!/usr/bin/env ruby
require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/token'

puts "=== PHASE 1 INFRASTRUCTURE ERROR DIAGNOSIS ==="

# Test 1: Lexer Position Tracking Issue
puts "\n1. Testing Lexer Position Tracking..."
begin
  lexer = Lexer.new("hello world\n test")
  tokens = lexer.tokenize
  puts "✓ Lexer tokenization successful"
  puts "  First token: #{tokens[0].inspect}"
  puts "  Position: #{tokens[0].position}, Line: #{tokens[0].line}, Column: #{tokens[0].column}"
rescue => e
  puts "✗ Lexer error: #{e.class} - #{e.message}"
  puts "  Backtrace: #{e.backtrace.first(3).join("\n  ")}"
end

# Test 2: Parser Constructor Issue  
puts "\n2. Testing Parser Constructor..."
begin
  lexer = Lexer.new("2 + 3")
  tokens = lexer.tokenize
  parser = Parser.new(tokens)
  puts "✓ Parser constructor successful"
rescue => e
  puts "✗ Parser constructor error: #{e.class} - #{e.message}"
  puts "  Backtrace: #{e.backtrace.first(3).join("\n  ")}"
end

# Test 3: Try the specific failing test patterns
puts "\n3. Testing specific failing patterns..."

# Test lexer position tracking with complex tokens
begin
  lexer = Lexer.new("!= >= <= == test")
  token = lexer.get_next_token # This should be the != token
  puts "✓ Complex token parsing: #{token.type} '#{token.value}' at line #{token.line}, column #{token.column}"
rescue => e
  puts "✗ Complex token error: #{e.class} - #{e.message}"
  puts "  Backtrace: #{e.backtrace.first(3).join("\n  ")}"
end

# Test parser with incomplete expressions
begin
  lexer = Lexer.new("2 +")
  tokens = lexer.tokenize
  parser = Parser.new(tokens)
  ast = parser.parse
  puts "✓ Incomplete expression parsing successful"
rescue => e
  puts "✗ Incomplete expression error: #{e.class} - #{e.message}"
  puts "  Backtrace: #{e.backtrace.first(3).join("\n  ")}"
end

puts "\n=== DIAGNOSIS COMPLETE ==="