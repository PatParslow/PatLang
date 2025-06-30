#!/usr/bin/env ruby

require 'pathname'

# Add src to load path
src_path = File.expand_path('../src', __FILE__)
$LOAD_PATH.unshift(src_path) unless $LOAD_PATH.include?(src_path)

puts "=== PRIORITY 1 COMPLETION VALIDATION ==="
puts "Baseline: 103 total errors"
puts "Expected after Priority 1 fixes: ~74 errors (29 error reduction)"
puts "=" * 60

# Load minitest properly
require 'minitest/autorun'
require 'minitest'

# Test infrastructure
require_relative 'test/helpers/test_helper'

# Run comprehensive test analysis using simpler approach
total_tests = 0
total_failures = 0
total_errors = 0
error_categories = Hash.new(0)
specific_errors = []

# Use the existing comprehensive test runner approach
puts "Running comprehensive test analysis using existing Ruby test framework..."

begin
  # Use the existing run_all_tests approach but capture output
  test_result = `cd "#{Dir.pwd}" && ruby -I src -r test/helpers/test_helper test/run_all_tests.rb 2>&1`
  exit_code = $?.exitstatus
  
  puts "Test execution completed with exit code: #{exit_code}"
  puts "\nTest Output Analysis:"
  puts "-" * 40
  
  # Parse the output to extract error information
  lines = test_result.split("\n")
  
  # Look for patterns that indicate errors and failures
  error_lines = lines.select { |line| 
    line.include?('Error') || 
    line.include?('ERROR') || 
    line.include?('Failure') || 
    line.include?('FAIL') ||
    line.include?('NameError') ||
    line.include?('NoMethodError') ||
    line.include?('LoadError') ||
    line.include?('SyntaxError')
  }
  
  # Count different types of issues
  name_errors = error_lines.count { |line| line.include?('NameError') }
  no_method_errors = error_lines.count { |line| line.include?('NoMethodError') }
  load_errors = error_lines.count { |line| line.include?('LoadError') }
  syntax_errors = error_lines.count { |line| line.include?('SyntaxError') }
  
  total_errors = error_lines.length
  
  puts "ERROR ANALYSIS FROM TEST OUTPUT:"
  puts "  NameError: #{name_errors}"
  puts "  NoMethodError: #{no_method_errors}" 
  puts "  LoadError: #{load_errors}"
  puts "  SyntaxError: #{syntax_errors}"
  puts "  Total detected issues: #{total_errors}"
  
  # Look for specific patterns related to Priority 1 fixes
  reasoning_errors = error_lines.count { |line| line.include?('reasoning') || line.include?('Reasoning') }
  parser_errors = error_lines.count { |line| line.include?('parser') || line.include?('Parser') }
  satisfies_errors = error_lines.count { |line| line.include?('satisfies') }
  
  puts "\nPRIORITY 1 TARGET ANALYSIS:"
  puts "  Reasoning-related errors: #{reasoning_errors}"
  puts "  Parser-related errors: #{parser_errors}"
  puts "  Satisfies method errors: #{satisfies_errors}"
  
rescue StandardError => e
  puts "Error running comprehensive test: #{e.message}"
  puts "Falling back to direct error analysis..."
  
  # Fallback: try to load individual test files and capture errors
  test_dir = File.dirname(__FILE__) + '/test'
  test_files = Dir.glob(File.join(test_dir, '**', 'test_*.rb')).sort
  
  test_files.each do |test_file|
    relative_path = Pathname.new(test_file).relative_path_from(Pathname.new(test_dir)).to_s
    
    begin
      load test_file
      puts "✓ #{relative_path}"
    rescue StandardError => load_error
      total_errors += 1
      error_type = load_error.class.name
      error_categories[error_type] += 1
      
      puts "✗ #{relative_path}: #{error_type}"
      
      specific_errors << {
        file: relative_path,
        type: error_type,
        message: load_error.message.split("\n").first
      }
    end
  end
end

puts "\n" + "=" * 60
puts "PRIORITY 1 VALIDATION RESULTS"
puts "=" * 60

baseline_errors = 103
current_errors = total_errors
improvement = baseline_errors - current_errors

puts "PROGRESS ANALYSIS:"
puts "  Baseline (before Priority 1): #{baseline_errors} errors"
puts "  Current (after Priority 1): #{current_errors} errors"
puts "  Improvement: #{improvement} errors resolved"

if improvement > 0
  puts "  Progress: #{(improvement.to_f / baseline_errors * 100).round(1)}%"
else
  puts "  Progress: Issues may have increased or remained stable"
end

puts

if improvement >= 25
  puts "✅ PRIORITY 1 SUCCESS: Significant error reduction achieved!"
elsif improvement >= 10
  puts "⚠️  PRIORITY 1 PARTIAL: Some progress made, expected ~29 error reduction"
else
  puts "❌ PRIORITY 1 INCOMPLETE: Expected ~29 error reduction, got #{improvement}"
end

if error_categories.any?
  puts "\nERROR CATEGORIES:"
  error_categories.sort_by { |_, count| -count }.each do |error_type, count|
    puts "  #{error_type}: #{count} occurrences"
  end
end

# Analyze specific Priority 2 targets
puts "\nPRIORITY 2 TARGET ANALYSIS:"

# Look for type constraint issues in the captured errors
type_constraint_errors = specific_errors.select do |error|
  error[:message]&.include?('expected') && 
  (error[:message]&.include?(':') || error[:message]&.include?('"'))
end

puts "  Type Constraint Format Errors: #{type_constraint_errors.count}"

if type_constraint_errors.count > 0
  puts "\nSAMPLE TYPE CONSTRAINT ERRORS:"
  type_constraint_errors.first(3).each_with_index do |error, i|
    puts "  #{i+1}. #{error[:type]}: #{error[:message]}"
    puts "     Location: #{error[:file]}"
  end
end

# Identify next highest-impact targets
if error_categories.any?
  puts "\nNEXT TARGETS FOR PRIORITY 2:"
  top_errors = error_categories.sort_by { |_, count| -count }.first(3)
  top_errors.each_with_index do |(error_type, count), i|
    percentage = current_errors > 0 ? (count.to_f / current_errors * 100).round(1) : 0
    puts "  #{i+1}. #{error_type}: #{count} errors (#{percentage}% of remaining)"
  end
end

puts "\n" + "=" * 60
puts "VALIDATION COMPLETE"
puts "=" * 60