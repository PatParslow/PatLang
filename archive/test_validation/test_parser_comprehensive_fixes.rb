#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/parser'

def test_enhanced_constraint_parsing
  puts "=== Testing Enhanced Constraint Parsing ==="
  
  test_cases = [
    # Basic constraints
    "constrain x :: Number where x > 0",
    "constrain name :: String",
    
    # Dotted expressions in constraints
    "constrain user.name :: String where user.name.length > 0",
    "constrain obj.field :: Number",
    "constrain data.items.count :: Integer where data.items.count >= 0",
    
    # Complex constraints with multiple conditions
    "constrain data :: Object where data.valid and data.count > 0",
    "constrain person.age :: Number where person.age >= 18 and person.age <= 120"
  ]
  
  success_count = 0
  test_cases.each_with_index do |code, index|
    puts "\n--- Constraint Test #{index + 1}: #{code} ---"
    begin
      lexer = Lexer.new(code)
      tokens = lexer.tokenize
      
      parser = Parser.new(tokens)
      ast = parser.parse
      puts "✓ SUCCESS: #{ast.class}"
      success_count += 1
    rescue => e
      puts "✗ ERROR: #{e.message}"
      puts "  Error class: #{e.class}"
    end
  end
  
  puts "\nConstraint Parsing Results: #{success_count}/#{test_cases.length} tests passed"
  return success_count, test_cases.length
end

def test_rule_parsing_comprehensive
  puts "\n=== Testing Rule Definition Parsing ==="
  
  rule_cases = [
    # Basic rules
    "rule parent(X, Y) :- father(X, Y)",
    "rule parent(X, Y) :- mother(X, Y)",
    
    # Complex rules with multiple conditions
    "rule grandparent(X, Z) :- parent(X, Y) and parent(Y, Z)",
    "rule ancestor(X, Y) :- parent(X, Y)",
    "rule ancestor(X, Z) :- parent(X, Y) and ancestor(Y, Z)"
  ]
  
  success_count = 0
  rule_cases.each_with_index do |code, index|
    puts "\n--- Rule Test #{index + 1}: #{code} ---"
    begin
      lexer = Lexer.new(code)
      tokens = lexer.tokenize
      
      parser = Parser.new(tokens)
      ast = parser.parse
      puts "✓ SUCCESS: #{ast.class}"
      success_count += 1
    rescue => e
      puts "✗ ERROR: #{e.message}"
      puts "  Error class: #{e.class}"
    end
  end
  
  puts "\nRule Parsing Results: #{success_count}/#{rule_cases.length} tests passed"
  return success_count, rule_cases.length
end

def test_string_escape_sequences
  puts "\n=== Testing String Escape Sequence Parsing ==="
  
  string_cases = [
    '"Hello World"',
    '"Line 1\\nLine 2"',
    '"Tab\\tSeparated"',
    '"Quote: \\"Hello\\""',
    "'Single quote string'",
    '"Mixed \'quotes\'"'
  ]
  
  success_count = 0
  string_cases.each_with_index do |code, index|
    puts "\n--- String Test #{index + 1}: #{code} ---"
    begin
      lexer = Lexer.new(code)
      tokens = lexer.tokenize
      
      parser = Parser.new(tokens)
      ast = parser.parse
      puts "✓ SUCCESS: #{ast.class} - #{ast.inspect if ast.respond_to?(:value)}"
      success_count += 1
    rescue => e
      puts "✗ ERROR: #{e.message}"
      puts "  Error class: #{e.class}"
    end
  end
  
  puts "\nString Parsing Results: #{success_count}/#{string_cases.length} tests passed"
  return success_count, string_cases.length
end

def test_mixed_syntax_scenarios
  puts "\n=== Testing Mixed Syntax Scenarios ==="
  
  mixed_cases = [
    # Constraints with string values
    'constrain user.email :: String where user.email contains "@"',
    
    # Rules with complex expressions
    'rule valid_user(X) :- user.name :: String and user.age :: Number',
    
    # Mixed reasoning constructs
    'goal validate_data { precondition: data :: Object, postcondition: data.valid }',
    
    # Complex dotted expressions
    'constrain system.config.database.connection :: String'
  ]
  
  success_count = 0
  mixed_cases.each_with_index do |code, index|
    puts "\n--- Mixed Test #{index + 1}: #{code} ---"
    begin
      lexer = Lexer.new(code)
      tokens = lexer.tokenize
      
      parser = Parser.new(tokens)
      ast = parser.parse
      puts "✓ SUCCESS: #{ast.class}"
      success_count += 1
    rescue => e
      puts "✗ ERROR: #{e.message}"
      puts "  Error class: #{e.class}"
    end
  end
  
  puts "\nMixed Syntax Results: #{success_count}/#{mixed_cases.length} tests passed"
  return success_count, mixed_cases.length
end

def main
  puts "Parser Syntax Enhancement Validation"
  puts "====================================="
  
  constraint_success, constraint_total = test_enhanced_constraint_parsing
  rule_success, rule_total = test_rule_parsing_comprehensive
  string_success, string_total = test_string_escape_sequences
  mixed_success, mixed_total = test_mixed_syntax_scenarios
  
  total_success = constraint_success + rule_success + string_success + mixed_success
  total_tests = constraint_total + rule_total + string_total + mixed_total
  
  puts "\n" + "="*50
  puts "FINAL RESULTS"
  puts "="*50
  puts "Constraint Parsing: #{constraint_success}/#{constraint_total}"
  puts "Rule Parsing: #{rule_success}/#{rule_total}"
  puts "String Parsing: #{string_success}/#{string_total}"
  puts "Mixed Syntax: #{mixed_success}/#{mixed_total}"
  puts "-" * 30
  puts "TOTAL: #{total_success}/#{total_tests} tests passed"
  
  if total_success == total_tests
    puts "🎉 ALL TESTS PASSED! Parser syntax enhancement complete."
  else
    puts "⚠️  #{total_tests - total_success} tests still failing."
  end
  
  return total_success, total_tests
end

if __FILE__ == $0
  main
end