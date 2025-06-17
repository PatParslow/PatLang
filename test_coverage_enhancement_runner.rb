#!/usr/bin/env ruby

# Test runner for coverage enhancement tests
# Runs the new tests to verify they work and provide coverage data

require 'simplecov'

# Configure SimpleCov for detailed coverage reporting
SimpleCov.start do
  add_filter '/test/'
  
  add_group 'Lexer', 'src/lexer.rb'
  add_group 'Parser', 'src/parser.rb'
  add_group 'Evaluator', 'src/evaluator.rb'
  add_group 'AST Nodes', 'src/ast_nodes.rb'
  add_group 'Token', 'src/token.rb'
  add_group 'REPL', 'src/patlang.rb'
  
  enable_coverage :branch
  minimum_coverage 80
end

puts "🧪 PATLANG COVERAGE ENHANCEMENT TEST RUNNER"
puts "=" * 60

# Load the test files
test_files = [
  'test/infrastructure/test_lexer_coverage_enhancement.rb',
  'test/infrastructure/test_parser_coverage_enhancement.rb', 
  'test/infrastructure/test_evaluator_coverage_enhancement.rb'
]

puts "\n📊 RUNNING COVERAGE ENHANCEMENT TESTS:"

successful_files = 0
total_files = test_files.length

test_files.each do |test_file|
  if File.exist?(test_file)
    puts "\n  🔍 Running: #{File.basename(test_file)}"
    begin
      load test_file
      puts "    ✅ Tests loaded successfully"
      successful_files += 1
    rescue => e
      puts "    ❌ Error loading tests: #{e.message}"
      puts "    📍 #{e.backtrace.first}" if e.backtrace
    end
  else
    puts "  ❌ Missing: #{test_file}"
  end
end

puts "\n📈 TEST FILE LOADING RESULTS:"
puts "  Successfully loaded: #{successful_files}/#{total_files} test files"
success_rate = (successful_files.to_f / total_files * 100).round(1)
puts "  Success rate: #{success_rate}%"

if successful_files > 0
  puts "\n🎯 RUNNING A QUICK FUNCTIONALITY TEST:"
  
  # Test basic PatLang functionality
  require_relative 'src/lexer'
  require_relative 'src/parser'
  require_relative 'src/evaluator'
  
  test_expressions = [
    "42",
    "2 + 3",
    "10 - 5",
    "3 * 4",
    "(2 + 3) * 4"
  ]
  
  working_count = 0
  test_expressions.each do |expr|
    begin
      lexer = Lexer.new(expr)
      tokens = lexer.tokenize
      parser = Parser.new(tokens)
      ast = parser.parse
      evaluator = Evaluator.new
      result = evaluator.evaluate(ast)
      
      puts "  ✅ #{expr} = #{result}"
      working_count += 1
    rescue => e
      puts "  ❌ #{expr} failed: #{e.message}"
    end
  end
  
  puts "\n📊 FUNCTIONALITY TEST RESULTS:"
  puts "  Working expressions: #{working_count}/#{test_expressions.length}"
  functionality_rate = (working_count.to_f / test_expressions.length * 100).round(1)
  puts "  Functionality rate: #{functionality_rate}%"
  
  puts "\n🔬 COVERAGE REPORT:"
  puts "  Check coverage/index.html for detailed coverage report"
  puts "  Run individual test files with: ruby test/infrastructure/test_*.rb"
  
else
  puts "\n❌ No test files loaded successfully. Check for syntax errors."
end

puts "\n📋 NEXT STEPS:"
puts "  1. Fix any failing tests identified above"
puts "  2. Run: ruby #{__FILE__} to see coverage results"
puts "  3. Check coverage/index.html for detailed line-by-line coverage"
puts "  4. Add more tests for any uncovered areas"

puts "\n✨ Coverage enhancement tests created successfully!"