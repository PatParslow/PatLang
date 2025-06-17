#!/usr/bin/env ruby

# Simple coverage test runner to identify gaps
require 'simplecov'

SimpleCov.start do
  add_filter '/test/'
  add_group 'Core Infrastructure', ['src/lexer.rb', 'src/parser.rb', 'src/ast_nodes.rb', 'src/token.rb']
  add_group 'Evaluator', ['src/evaluator.rb']
  add_group 'REPL', ['src/patlang.rb']
  
  enable_coverage :branch
end

puts "🔍 PATLANG WORKING FEATURES COVERAGE ANALYSIS"
puts "=" * 60

# Test the core working functionality
puts "\n📊 TESTING CORE ARITHMETIC (KNOWN WORKING):"

require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/evaluator'
require_relative 'src/patlang'

# Test basic arithmetic that we know works
working_arithmetic = [
  "42",
  "2 + 3", 
  "10 - 5",
  "3 * 4",
  "15 / 3",
  "2 + 3 * 4",
  "(2 + 3) * 4"
]

successful_tests = 0
total_tests = working_arithmetic.length

working_arithmetic.each do |expr|
  begin
    result = Patlang.process_expression(expr)
    puts "  ✅ #{expr} = #{result}"
    successful_tests += 1
  rescue => e
    puts "  ❌ #{expr} failed: #{e.message}"
  end
end

puts "\n📈 BASIC FUNCTIONALITY SUCCESS RATE: #{successful_tests}/#{total_tests} (#{(successful_tests.to_f/total_tests*100).round(1)}%)"

# Test lexer directly
puts "\n🔤 TESTING LEXER DIRECTLY:"
test_lexer_expressions = [
  "hello world",
  "42 + 3.14", 
  "if x > 5 then print \"big\" end",
  "make a function called test"
]

test_lexer_expressions.each do |expr|
  begin
    lexer = Lexer.new(expr)
    tokens = lexer.tokenize
    puts "  ✅ '#{expr}' → #{tokens.length} tokens"
  rescue => e
    puts "  ❌ '#{expr}' failed: #{e.message}"
  end
end

# Test parser on simple expressions (avoid control flow for now)
puts "\n🌳 TESTING PARSER (SIMPLE EXPRESSIONS):"
simple_expressions = [
  "42",
  "x + y",
  "2 * (3 + 4)",
  "true == false"
]

simple_expressions.each do |expr|
  begin
    lexer = Lexer.new(expr)
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    puts "  ✅ '#{expr}' → #{ast.class}"
  rescue => e
    puts "  ❌ '#{expr}' failed: #{e.message}"
  end
end

puts "\n📊 COVERAGE RESULTS:"
puts "Coverage report will be generated in coverage/index.html"
puts "\nRun this script to identify specific lines needing test coverage."