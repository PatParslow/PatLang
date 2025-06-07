#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/parser'

def test_constraint_parsing
  puts "=== Testing Constraint Parsing Issues ==="
  
  # Test cases that should expose the DOUBLE_COLON vs DOT parsing issues
  test_cases = [
    # Basic constraint with double colon
    "constrain x :: Number where x > 0",
    
    # Constraint with dot access (should fail currently)
    "constrain user.name :: String where user.name.length > 0",
    
    # Rule definition with :- operator
    "rule parent(X, Y) :- father(X, Y)",
    
    # Mixed constraint and dot notation
    "constrain obj.field :: Number",
    
    # Complex constraint with multiple conditions
    "constrain data :: Object where data.valid and data.count > 0"
  ]
  
  test_cases.each_with_index do |code, index|
    puts "\n--- Test Case #{index + 1}: #{code} ---"
    begin
      lexer = Lexer.new(code)
      tokens = lexer.tokenize
      puts "Tokens: #{tokens.map(&:to_s).join(', ')}"
      
      parser = Parser.new(tokens)
      ast = parser.parse
      puts "Success: #{ast.class}"
    rescue => e
      puts "ERROR: #{e.message}"
      puts "Error class: #{e.class}"
    end
  end
end

def test_rule_parsing
  puts "\n=== Testing Rule Definition Parsing ==="
  
  rule_cases = [
    "rule ancestor(X, Y) :- parent(X, Y)",
    "rule grandparent(X, Z) :- parent(X, Y) and parent(Y, Z)"
  ]
  
  rule_cases.each_with_index do |code, index|
    puts "\n--- Rule Test #{index + 1}: #{code} ---"
    begin
      lexer = Lexer.new(code)
      tokens = lexer.tokenize
      puts "Tokens: #{tokens.map(&:to_s).join(', ')}"
      
      parser = Parser.new(tokens)
      ast = parser.parse
      puts "Success: #{ast.class}"
    rescue => e
      puts "ERROR: #{e.message}"
      puts "Error class: #{e.class}"
    end
  end
end

if __FILE__ == $0
  test_constraint_parsing
  test_rule_parsing
end