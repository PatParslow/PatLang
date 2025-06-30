#!/usr/bin/env ruby

require 'pathname'

# Add src to load path
src_path = File.expand_path('../src', __FILE__)
$LOAD_PATH.unshift(src_path) unless $LOAD_PATH.include?(src_path)

puts "=== PRIORITY 1 COMPLETION VALIDATION ==="
puts "Baseline: 103 total errors"
puts "Expected after Priority 1 fixes: ~74 errors (29 error reduction)"
puts "=" * 60

# Test infrastructure
require_relative 'test/helpers/test_helper'

# Run comprehensive test analysis
total_tests = 0
total_failures = 0
total_errors = 0
error_categories = Hash.new(0)
specific_errors = []

# Discover all test files
test_dir = File.dirname(__FILE__) + '/test'
test_files = Dir.glob(File.join(test_dir, '**', 'test_*.rb')).sort

excluded_files = ['test_helper.rb', 'run_all_tests.rb']
test_files_to_run = test_files.select do |file|
  basename = File.basename(file)
  !excluded_files.include?(basename) && basename.start_with?('test_')
end

puts "Running #{test_files_to_run.length} test files for comprehensive analysis..."
puts

# Capture test results
test_results = {}

test_files_to_run.each do |test_file|
  relative_path = Pathname.new(test_file).relative_path_from(Pathname.new(test_dir)).to_s
  
  begin
    # Clear previous test classes to avoid conflicts
    ObjectSpace.each_object(Class) do |klass|
      if klass < MiniTest::Test && klass.name&.start_with?('Test')
        klass.reset if klass.respond_to?(:reset)
      end
    end
    
    puts "Loading: #{relative_path}"
    require test_file
    
  rescue StandardError => e
    puts "  ERROR loading #{relative_path}: #{e.class.name}: #{e.message}"
    total_errors += 1
    error_categories[e.class.name] += 1
    specific_errors << {
      file: relative_path,
      type: e.class.name,
      message: e.message,
      location: e.backtrace&.first
    }
  end
end

puts "\n" + "=" * 60
puts "RUNNING TESTS..."
puts "=" * 60

# Run all loaded test classes
test_classes = ObjectSpace.each_object(Class).select { |klass| klass < MiniTest::Test }

test_classes.each do |test_class|
  next unless test_class.name # Skip anonymous classes
  
  puts "\nRunning #{test_class.name}..."
  
  test_methods = test_class.instance_methods.grep(/^test_/)
  
  test_methods.each do |method_name|
    total_tests += 1
    
    begin
      test_instance = test_class.new(method_name)
      test_instance.setup if test_instance.respond_to?(:setup)
      test_instance.send(method_name)
      test_instance.teardown if test_instance.respond_to?(:teardown)
      print "."
      
    rescue MiniTest::Assertion => e
      total_failures += 1
      print "F"
      specific_errors << {
        file: test_class.name,
        method: method_name,
        type: "Assertion Failure",
        message: e.message
      }
      
    rescue StandardError => e
      total_errors += 1
      error_categories[e.class.name] += 1
      print "E"
      specific_errors << {
        file: test_class.name,
        method: method_name,
        type: e.class.name,
        message: e.message,
        location: e.backtrace&.first
      }
    end
  end
end

puts "\n\n" + "=" * 60
puts "PRIORITY 1 VALIDATION RESULTS"
puts "=" * 60

puts "SUMMARY:"
puts "  Total Tests: #{total_tests}"
puts "  Failures: #{total_failures}"
puts "  Errors: #{total_errors}"
puts "  Total Issues: #{total_failures + total_errors}"
puts

puts "PROGRESS ANALYSIS:"
baseline_errors = 103
current_errors = total_failures + total_errors
improvement = baseline_errors - current_errors
puts "  Baseline (before Priority 1): #{baseline_errors} errors"
puts "  Current (after Priority 1): #{current_errors} errors"
puts "  Improvement: #{improvement} errors resolved"
puts "  Progress: #{(improvement.to_f / baseline_errors * 100).round(1)}%"
puts

if improvement >= 25
  puts "✅ PRIORITY 1 SUCCESS: Significant error reduction achieved!"
else
  puts "⚠️  PRIORITY 1 PARTIAL: Expected ~29 error reduction, got #{improvement}"
end

puts "\nERROR CATEGORIES:"
error_categories.sort_by { |_, count| -count }.each do |error_type, count|
  puts "  #{error_type}: #{count} occurrences"
end

puts "\nPRIORITY 2 TARGET ANALYSIS:"
# Focus on type constraint issues
type_constraint_errors = specific_errors.select do |error|
  error[:message]&.include?('expected') && 
  (error[:message]&.include?(':') || error[:message]&.include?('"'))
end

puts "  Type Constraint Format Errors: #{type_constraint_errors.count}"

if type_constraint_errors.count > 0
  puts "\nSAMPLE TYPE CONSTRAINT ERRORS:"
  type_constraint_errors.first(5).each_with_index do |error, i|
    puts "  #{i+1}. #{error[:type]}: #{error[:message]}"
    puts "     Location: #{error[:file]}::#{error[:method] || 'load'}"
  end
end

puts "\nNEXT TARGETS FOR PRIORITY 2:"
# Identify highest frequency error types for Priority 2
top_errors = error_categories.sort_by { |_, count| -count }.first(3)
top_errors.each_with_index do |(error_type, count), i|
  puts "  #{i+1}. #{error_type}: #{count} errors (#{(count.to_f / current_errors * 100).round(1)}% of remaining)"
end

puts "\n" + "=" * 60
puts "VALIDATION COMPLETE"
puts "=" * 60