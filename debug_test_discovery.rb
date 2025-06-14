#!/usr/bin/env ruby
# Quick diagnostic to identify hanging and test discovery issues

puts "🔍 DIAGNOSTIC: Test Discovery and Hang Analysis"
puts "=" * 60

# Test 1: Check test file discovery pattern
puts "\n1. Testing file discovery pattern:"
test_dir = File.join(__dir__, 'test')
puts "   Test directory: #{test_dir}"

test_files = Dir.glob(File.join(test_dir, '**', 'test_*.rb')).sort
puts "   Total test_*.rb files found: #{test_files.length}"

# Filter like real_time_test_runner does
excluded_files = [
  'test_helper.rb',
  'run_all_tests.rb', 
  'enhanced_test_runner.rb',
  'enhanced_test_runner_simple.rb',
  'progress_test_runner.rb',
  'real_time_test_runner.rb'
]

test_files_to_load = test_files.select do |file|
  basename = File.basename(file)
  !excluded_files.include?(basename) && basename.start_with?('test_')
end

puts "   After filtering: #{test_files_to_load.length} files"
puts "   First 5 files:"
test_files_to_load.first(5).each_with_index do |file, index|
  puts "     #{index + 1}. #{File.basename(file)}"
end

# Test 2: Try loading test_helper
puts "\n2. Testing test_helper loading:"
begin
  require_relative 'test/helpers/test_helper'
  puts "   ✅ test_helper loaded successfully"
rescue => e
  puts "   ❌ test_helper failed: #{e.message}"
  puts "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
end

# Test 3: Try loading a simple test file
puts "\n3. Testing individual test file loading:"
if test_files_to_load.any?
  test_file = test_files_to_load.first
  puts "   Trying to load: #{File.basename(test_file)}"
  
  begin
    # Set a timeout to detect hangs
    require 'timeout'
    Timeout::timeout(10) do
      require test_file
      puts "   ✅ Test file loaded successfully"
    end
  rescue Timeout::Error
    puts "   🚨 HANG DETECTED: Test file loading timed out after 10s"
  rescue => e
    puts "   ❌ Test file failed: #{e.message}"
    puts "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
  end
end

# Test 4: Check if any source files might cause hangs
puts "\n4. Checking potential problematic source files:"
src_files = Dir.glob(File.join(__dir__, 'src', '**', '*.rb')).sort
puts "   Source files found: #{src_files.length}"

problematic_patterns = [
  'unification',
  'reasoning',
  'type_constraint',
  'evaluator'
]

problematic_files = src_files.select do |file|
  basename = File.basename(file, '.rb')
  problematic_patterns.any? { |pattern| basename.include?(pattern) }
end

puts "   Potentially problematic files:"
problematic_files.each { |file| puts "     - #{File.basename(file)}" }

puts "\n" + "=" * 60
puts "🎯 DIAGNOSIS COMPLETE"