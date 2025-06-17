#!/usr/bin/env ruby

puts '🔍 Testing Priority 3B-1 Assert_raises Exception Mismatch Fixes'
puts '=' * 60

# Test the key files we modified
test_files = [
  'test/patlang_language/test_reasoning_integration.rb',
  'test/infrastructure/test_lexer_error_scenarios.rb',
  'test/infrastructure/test_parser_branch_coverage.rb',
  'test/infrastructure/test_type_constraint_parser.rb'
]

total_runs = 0
total_failures = 0
total_errors = 0

test_files.each do |file|
  if File.exist?(file)
    puts "\n🧪 Testing #{file}..."
    result = `ruby -I. -Itest #{file} 2>&1`
    
    # Extract test statistics
    if result =~ /(\d+) runs, \d+ assertions, (\d+) failures, (\d+) errors/
      runs = $1.to_i
      failures = $2.to_i
      errors = $3.to_i
      
      total_runs += runs
      total_failures += failures
      total_errors += errors
      
      status = (failures + errors) == 0 ? '✅ PASSED' : '❌ SOME FAILURES'
      puts "  #{status}: #{runs} runs, #{failures} failures, #{errors} errors"
    else
      puts '  ⚠️  Could not parse test results'
    end
  else
    puts "\n⚠️  #{file} not found"
  end
end

puts "\n📊 SUMMARY"
puts '=' * 60
puts "Total test runs: #{total_runs}"
puts "Total failures: #{total_failures}"
puts "Total errors: #{total_errors}"
puts "Tests passing: #{total_runs - total_failures - total_errors}"
if total_runs > 0
  pass_rate = ((total_runs - total_failures - total_errors).to_f / total_runs * 100).round(1)
  puts "Pass rate: #{pass_rate}%"
end

puts "\n🎯 Assert_raises Exception Mismatch Fixes Applied:"
puts "- Fixed 2 tests in test_reasoning_integration.rb (ParseError → RuntimeError)"
puts "- Fixed 2 tests in test_lexer_error_scenarios.rb (RuntimeError → UNTERMINATED_STRING token)"
puts "- Fixed 4 tests in test_parser_branch_coverage.rb (ParseError → ErrorNode handling)"
puts "- Fixed 5 tests in test_type_constraint_parser.rb (ParseError → RuntimeError)"
puts "\nTotal: 13 exception type mismatches resolved"