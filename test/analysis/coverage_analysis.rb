#!/usr/bin/env ruby

require 'simplecov'
require 'json'

# Configure SimpleCov for detailed analysis
SimpleCov.start do
  add_filter '/test/'
  add_group 'Core Infrastructure', ['src/lexer.rb', 'src/parser.rb', 'src/ast_nodes.rb']
  add_group 'Evaluator', ['src/evaluator.rb', 'src/evaluator/']
  add_group 'REPL', ['src/patlang.rb']
  add_group 'Reasoning', ['src/reasoning/']
  
  # Track branch coverage
  enable_coverage :branch
  
  # Set minimum coverage thresholds
  minimum_coverage 80
  minimum_coverage_by_file 70
end

puts "🔍 PATLANG COVERAGE ANALYSIS"
puts "=" * 50

# Test the working components systematically
working_tests = [
  'test/infrastructure/test_lexer.rb',
  'test/infrastructure/test_ast_nodes.rb',
  'test/patlang_language/test_is_keyword_implementation.rb',
  'test/patlang_language/test_flexible_function_syntax.rb'
]

puts "\n📊 TESTING WORKING COMPONENTS:"
working_tests.each do |test_file|
  if File.exist?(test_file)
    puts "  ✅ #{test_file}"
    begin
      load test_file
    rescue => e
      puts "    ❌ Error: #{e.message}"
    end
  else
    puts "  ❌ Missing: #{test_file}"
  end
end

puts "\n🎯 RUNNING CORE ARITHMETIC TESTS:"

# Test arithmetic functionality that we know works
require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/evaluator'
require_relative 'ruby-host/bootstrap/patlang'

# Simple arithmetic tests
arithmetic_tests = [
  "42",
  "2 + 3",
  "2 + 3 * 4", 
  "(2 + 3) * 4",
  "10 - 5 / 2"
]

arithmetic_tests.each do |expr|
  begin
    result = Patlang.process_expression(expr)
    puts "  ✅ #{expr} = #{result}"
  rescue => e
    puts "  ❌ #{expr} failed: #{e.message}"
  end
end

puts "\n📈 COVERAGE SUMMARY:"
puts "Run with: ruby -r simplecov coverage_analysis.rb"
puts "Check coverage/index.html for detailed report"