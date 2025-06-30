#!/usr/bin/env ruby
require 'timeout'

puts "=== CURRENT ERROR STATE VALIDATION ==="

test_files = [
  'test/infrastructure/test_lexer.rb',
  'test/infrastructure/test_parser.rb', 
  'test/infrastructure/test_unification_engine.rb',
  'test/infrastructure/test_type_constraint_parser.rb',
  'test/infrastructure/test_reasoning_coordinator.rb',
  'test/patlang_language/test_reasoning_integration.rb'
]

total_errors = 0
error_summary = {}

test_files.each do |test_file|
  puts "\n--- Testing #{test_file} ---"
  
  begin
    Timeout::timeout(30) do
      output = `ruby -I. -Isrc -Itest #{test_file} 2>&1`
      exit_code = $?.exitstatus
      
      if exit_code != 0
        # Count errors from output
        error_lines = output.lines.select { |line| line.match(/Error:|ERROR|Exception:|RuntimeError|NoMethodError|ArgumentError/) }
        error_count = error_lines.size
        total_errors += error_count
        
        if error_count > 0
          error_summary[test_file] = {
            count: error_count,
            sample_errors: error_lines.first(3)
          }
          puts "✗ #{error_count} errors found"
          error_lines.first(3).each { |line| puts "  #{line.strip}" }
        else
          puts "✓ No errors detected"
        end
      else
        # Check if there are failures/errors in successful runs
        if output.include?('failures') || output.include?('errors')
          failure_line = output.lines.find { |line| line.match(/\d+ runs, \d+ assertions, \d+ failures, \d+ errors/) }
          puts "  #{failure_line.strip}" if failure_line
        else
          puts "✓ All tests passed"
        end
      end
    end
  rescue Timeout::Error
    puts "✗ Test timed out (30s limit)"
    total_errors += 1
    error_summary[test_file] = { count: 1, sample_errors: ["Test timeout"] }
  rescue => e
    puts "✗ Test execution failed: #{e.message}"
    total_errors += 1
    error_summary[test_file] = { count: 1, sample_errors: [e.message] }
  end
end

puts "\n=== SUMMARY ==="
puts "Total errors found: #{total_errors}"

if error_summary.any?
  puts "\nError breakdown:"
  error_summary.each do |file, details|
    puts "  #{file}: #{details[:count]} errors"
    details[:sample_errors].each { |err| puts "    - #{err.strip}" }
  end
else
  puts "No errors found - Phase 1 infrastructure appears to be working correctly!"
end