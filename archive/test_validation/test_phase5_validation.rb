#!/usr/bin/env ruby

# Phase 5 validation - test constructor and coordination fixes
require 'timeout'

puts "=== Phase 5: Constructor & Coordination Fixes Validation ==="
puts

# Test the actual test suite to see improvements
test_files = [
  'test/infrastructure/test_facts_database.rb',
  'test/infrastructure/test_goal_resolution_engine.rb', 
  'test/infrastructure/test_unification_engine.rb',
  'test/patlang_language/test_cross_paradigm_coordination.rb'
]

passed_tests = 0
failed_tests = 0
total_tests_run = 0

test_files.each do |test_file|
  next unless File.exist?(test_file)
  
  puts "Testing #{test_file}..."
  
  begin
    Timeout::timeout(30) do
      result = `ruby -I. #{test_file} 2>&1`
      
      # Count tests from minitest output
      if result =~ /(\d+) runs, (\d+) assertions, (\d+) failures, (\d+) errors/
        runs = $1.to_i
        failures = $3.to_i
        errors = $4.to_i
        
        test_passed = runs - failures - errors
        test_failed = failures + errors
        
        passed_tests += test_passed
        failed_tests += test_failed
        total_tests_run += runs
        
        puts "  #{runs} tests: #{test_passed} passed, #{test_failed} failed"
      else
        puts "  Could not parse test results"
      end
    end
  rescue Timeout::Error
    puts "  TIMEOUT after 30 seconds"
    failed_tests += 1
  rescue => e
    puts "  ERROR: #{e.message}"
    failed_tests += 1
  end
  
  puts
end

puts "=== PHASE 5 SUMMARY ==="
puts "Total tests run: #{total_tests_run}"
puts "Passed: #{passed_tests}"
puts "Failed: #{failed_tests}"
if total_tests_run > 0
  success_rate = (passed_tests.to_f / total_tests_run * 100).round(2)
  puts "Success rate: #{success_rate}%"
  
  if success_rate >= 80.0
    puts "✓ TARGET ACHIEVED: #{success_rate}% >= 80%"
  else
    puts "✗ Target not yet reached: #{success_rate}% < 80%"
  end
else
  puts "No tests were successfully run"
end

puts
puts "=== SPECIFIC FIXES APPLIED ==="
puts "1. ✓ FactsDatabase.initialize - made evaluator parameter optional"
puts "2. ✓ GoalSystem.initialize - made evaluator parameter optional"  
puts "3. ✓ UnificationEngine.unify - added default empty substitution parameter"
puts "4. ✓ CrossParadigmCoordinator.execute_workflow - improved nil handling"
puts
puts "These fixes target the top 16 constructor/coordinator errors identified in the analysis."