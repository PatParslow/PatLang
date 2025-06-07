#!/usr/bin/env ruby

# Quick error count verification and Goal constructor status check
puts "🔍 VERIFYING CURRENT ERROR STATE"
puts "=" * 50

# Run a simplified test to get exact numbers
require 'open3'

puts "Running simplified test count..."
output, error, status = Open3.capture3("ruby -Ilib -Isrc -e \"
require_relative 'test/run_all_tests.rb'
\" 2>&1")

# Parse the actual output for real numbers
lines = output.split("\n")
summary_line = lines.find { |line| line.match(/\d+ runs, \d+ assertions, \d+ failures, \d+ errors/) }

if summary_line
  puts "Found summary: #{summary_line}"
  
  # Extract numbers
  if match = summary_line.match(/(\d+) runs, (\d+) assertions, (\d+) failures, (\d+) errors/)
    runs, assertions, failures, errors = match.captures.map(&:to_i)
    
    total_issues = failures + errors
    puts
    puts "📊 ACTUAL CURRENT STATE:"
    puts "  Total Test Runs: #{runs}"
    puts "  Assertions: #{assertions}"
    puts "  Failures: #{failures}"
    puts "  Errors: #{errors}"
    puts "  TOTAL ISSUES: #{total_issues}"
    puts
    
    # Check if our prediction was accurate
    original_count = 104
    predicted_after_fixes = 56
    
    if total_issues <= predicted_after_fixes + 5 # Allow small margin
      puts "✅ SUCCESS: Error count matches prediction (~#{predicted_after_fixes})"
      puts "   Our Goal constructor fix was effective!"
    elsif total_issues > 90
      puts "❌ ISSUE: Error count still very high (#{total_issues})"
      puts "   Goal constructor fix may not have been applied correctly"
    else
      puts "⚡ PARTIAL: Error count (#{total_issues}) between original and predicted"
      puts "   Some fixes worked, others may need verification"
    end
    
    puts
    puts "🎯 NEXT PRIORITY ASSESSMENT:"
    if total_issues > 80
      puts "  PRIORITY: Verify our fixes were properly applied"
      puts "  ACTION: Check Goal constructor and ReasoningCoordinator changes"
    elsif total_issues > 60
      puts "  PRIORITY: Focus on remaining high-impact errors"
      puts "  ACTION: Variable resolution and parser syntax fixes"
    else
      puts "  PRIORITY: Fine-tuning and assertion alignment"
      puts "  ACTION: Address test behavior mismatches"
    end
  end
else
  puts "Could not parse test summary. Raw output:"
  puts output
end