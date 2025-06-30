#!/usr/bin/env ruby

puts "=== Type Constraint Format Standardization Validation ==="
puts "Testing that variable names are returned as symbols consistently"

require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/evaluator'

test_cases = [
  {
    description: "Simple type constraint",
    code: "constrain x :: Number",
    expected_variable: :x,
    expected_constraint_type: :type,
    expected_constraint_data: :Number
  },
  {
    description: "Range constraint",
    code: "constrain age :: Number where age >= 0 and age <= 150",
    expected_variable: :age,
    expected_constraint_type: :type,
    expected_constraint_data: :Number
  },
  {
    description: "String constraint",
    code: "constrain name :: String",
    expected_variable: :name,
    expected_constraint_type: :type,
    expected_constraint_data: :String
  }
]

all_passed = true

test_cases.each_with_index do |test_case, i|
  puts "\n#{i + 1}. #{test_case[:description]}"
  puts "   Code: #{test_case[:code]}"
  
  begin
    lexer = Lexer.new(test_case[:code])
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    result = evaluator.evaluate(ast)
    
    # Check variable format
    if result.variable == test_case[:expected_variable] && result.variable.is_a?(Symbol)
      puts "   ✅ Variable: #{result.variable.inspect} (Symbol) - PASS"
    else
      puts "   ❌ Variable: Expected #{test_case[:expected_variable].inspect}, got #{result.variable.inspect} (#{result.variable.class})"
      all_passed = false
    end
    
    # Check constraint type format
    if result.constraint_type == test_case[:expected_constraint_type] && result.constraint_type.is_a?(Symbol)
      puts "   ✅ Constraint Type: #{result.constraint_type.inspect} (Symbol) - PASS"
    else
      puts "   ❌ Constraint Type: Expected #{test_case[:expected_constraint_type].inspect}, got #{result.constraint_type.inspect} (#{result.constraint_type.class})"
      all_passed = false
    end
    
    # Check constraint data format
    if result.constraint_data == test_case[:expected_constraint_data] && result.constraint_data.is_a?(Symbol)
      puts "   ✅ Constraint Data: #{result.constraint_data.inspect} (Symbol) - PASS"
    else
      puts "   ❌ Constraint Data: Expected #{test_case[:expected_constraint_data].inspect}, got #{result.constraint_data.inspect} (#{result.constraint_data.class})"
      all_passed = false
    end
    
  rescue => e
    puts "   ❌ Error: #{e.message}"
    all_passed = false
  end
end

puts "\n" + "="*60
if all_passed
  puts "🎉 ALL TESTS PASSED! Type constraint format standardization is complete."
  puts "✅ Variables are consistently returned as symbols (:x, :age, :name)"
  puts "✅ Constraint types are consistently returned as symbols (:type)"
  puts "✅ Constraint data are consistently returned as symbols (:Number, :String)"
  puts "✅ No more 'Expected :symbol, got string' errors in type constraints"
else
  puts "❌ Some tests failed. Type constraint format issues remain."
end

puts "\nSummary of fixes applied:"
puts "1. Parser: parse_constraint_variable now returns symbols for simple variables"
puts "2. Evaluator: TypeConstraint class constructor converts inputs to symbols"
puts "3. Evaluator: visit_constraint_node ensures consistent symbol usage"