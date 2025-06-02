#!/usr/bin/env ruby

puts "🧪 COMPREHENSIVE REGRESSION TEST ANALYSIS"
puts "=" * 60

# Test files list
test_files = [
  'test_ast_nodes',
  'test_control_flow_evaluator', 
  'test_evaluator',
  'test_evaluator_edge_cases',
  'test_extended_string_methods',
  'test_function_evaluator',
  'test_function_integration',
  'test_function_lexer',
  'test_function_parser',
  'test_integration',
  'test_lexer',
  'test_lexer_comprehensive',
  'test_parser',
  'test_string_literals',
  'test_string_operations'
]

passed_tests = []
failed_tests = []
error_tests = []

puts "\n📋 INDIVIDUAL TEST FILE RESULTS:"
puts "-" * 40

test_files.each do |test_file|
  print "Testing #{test_file.ljust(30)}... "
  
  begin
    # Run test and capture both stdout and stderr
    output = `ruby -I test test/#{test_file}.rb 2>&1`
    exit_status = $?.exitstatus
    
    if exit_status == 0
      puts "✅ PASSED"
      passed_tests << test_file
    else
      puts "❌ FAILED (exit code: #{exit_status})"
      failed_tests << {name: test_file, exit_code: exit_status, output: output}
    end
  rescue => e
    puts "💥 ERROR: #{e.message}"
    error_tests << {name: test_file, error: e.message}
  end
end

puts "\n📊 SUMMARY STATISTICS:"
puts "-" * 40
puts "✅ PASSED: #{passed_tests.length}/#{test_files.length}"
puts "❌ FAILED: #{failed_tests.length}/#{test_files.length}"
puts "💥 ERRORS: #{error_tests.length}/#{test_files.length}"

if failed_tests.any?
  puts "\n🔍 FAILED TEST DETAILS:"
  puts "-" * 40
  failed_tests.each do |test|
    puts "\n❌ #{test[:name]} (exit code: #{test[:exit_code]})"
    # Show first few lines of output for context
    lines = test[:output].split("\n")
    if lines.length > 10
      puts "   Output (first 10 lines):"
      lines[0..9].each { |line| puts "   #{line}" }
      puts "   ... (#{lines.length - 10} more lines)"
    else
      puts "   Output:"
      lines.each { |line| puts "   #{line}" }
    end
  end
end

if error_tests.any?
  puts "\n💥 ERROR TEST DETAILS:"
  puts "-" * 40
  error_tests.each do |test|
    puts "💥 #{test[:name]}: #{test[:error]}"
  end
end

puts "\n🎯 CORE FUNCTIONALITY VALIDATION:"
puts "-" * 40

# Test basic functionality
puts "Testing basic arithmetic..."
require_relative 'src/patlang'
begin
  result = Patlang.evaluate("5 + 3")
  puts result == 8 ? "✅ Arithmetic: WORKING" : "❌ Arithmetic: FAILED (got #{result})"
rescue => e
  puts "❌ Arithmetic: ERROR - #{e.message}"
end

puts "Testing string operations..."
begin
  result = Patlang.evaluate('"Hello" + " World"')
  puts result == "Hello World" ? "✅ String ops: WORKING" : "❌ String ops: FAILED (got #{result})"
rescue => e
  puts "❌ String ops: ERROR - #{e.message}"
end

puts "Testing control flow..."
begin
  result = Patlang.evaluate('if true then "yes" else "no" end')
  puts result == "yes" ? "✅ Control flow: WORKING" : "❌ Control flow: FAILED (got #{result})"
rescue => e
  puts "❌ Control flow: ERROR - #{e.message}"
end

puts "Testing comments..."
begin
  result = Patlang.evaluate('# This is a comment
  "Hello"')
  puts result == "Hello" ? "✅ Comments: WORKING" : "❌ Comments: FAILED (got #{result})"
rescue => e
  puts "❌ Comments: ERROR - #{e.message}"
end

puts "Testing functions..."
begin
  result = Patlang.evaluate('
    make a function called greet {
      return "Hello, World!"
    }
    call greet
  ')
  puts result == "Hello, World!" ? "✅ Functions: WORKING" : "❌ Functions: FAILED (got #{result})"
rescue => e
  puts "❌ Functions: ERROR - #{e.message}"
end

puts "\n🏁 REGRESSION TEST COMPLETE"
puts "=" * 60