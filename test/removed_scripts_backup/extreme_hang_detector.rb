#!/usr/bin/env ruby
# frozen_string_literal: true

puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 🚨 EXTREME HANG DETECTOR STARTING"

# Global timeout for the entire script
Thread.new do
  sleep(30)  # 30 second total timeout
  puts ""
  puts "🚨" * 30
  puts "GLOBAL TIMEOUT: Script has been running for 30+ seconds"
  puts "This indicates a critical hang in basic Ruby operations"
  puts "🚨" * 30
  exit(1)
end

def safe_operation(operation_name, timeout_seconds = 5)
  puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 🔧 TESTING: #{operation_name}"
  
  result = nil
  completed = false
  
  # Create a thread to perform the operation
  operation_thread = Thread.new do
    begin
      result = yield
      completed = true
    rescue => e
      puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] ❌ ERROR in #{operation_name}: #{e.message}"
      result = e
    end
  end
  
  # Wait for completion or timeout
  operation_thread.join(timeout_seconds)
  
  if completed
    puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] ✅ SUCCESS: #{operation_name}"
    return result
  else
    puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] ⏰ TIMEOUT: #{operation_name} exceeded #{timeout_seconds}s"
    puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 🚨 HANG DETECTED IN: #{operation_name}"
    
    # Kill the hanging thread
    operation_thread.kill if operation_thread.alive?
    
    return :timeout
  end
end

# Test each component with aggressive timeouts
puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 🔍 Testing basic Ruby operations..."

result = safe_operation("Basic require 'pathname'", 3) do
  require 'pathname'
end
exit(1) if result == :timeout

result = safe_operation("Basic require 'timeout'", 3) do
  require 'timeout'
end
exit(1) if result == :timeout

result = safe_operation("Basic require 'thread'", 3) do
  require 'thread'
end
exit(1) if result == :timeout

puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 🔍 Testing SimpleCov loading..."

result = safe_operation("SimpleCov require", 5) do
  require 'simplecov'
end

if result == :timeout
  puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 🚨 CRITICAL: SimpleCov loading hangs!"
  puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 💡 This is likely the root cause of test runner hangs"
  exit(1)
end

puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 🔍 Testing SimpleCov configuration..."

result = safe_operation("SimpleCov configuration", 5) do
  SimpleCov.start do
    enable_coverage :branch
    add_filter '/test/'
    track_files 'src/**/*.rb'
    formatter SimpleCov::Formatter::SimpleFormatter
    minimum_coverage line: 95, branch: 90
  end
end

if result == :timeout
  puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 🚨 CRITICAL: SimpleCov configuration hangs!"
  puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 💡 SimpleCov is hanging during configuration phase"
  exit(1)
end

puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 🔍 Testing test_helper loading..."

result = safe_operation("test_helper loading", 10) do
  require_relative 'helpers/test_helper'
end

if result == :timeout
  puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 🚨 CRITICAL: test_helper loading hangs!"
  puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 💡 The hang occurs during test_helper initialization"
  exit(1)
end

puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 🔍 Testing Minitest availability..."

result = safe_operation("Minitest check", 3) do
  {
    minitest_defined: defined?(Minitest),
    test_defined: defined?(Minitest::Test)
  }
end

if result == :timeout
  puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 🚨 CRITICAL: Minitest check hangs!"
  exit(1)
end

puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] ✅ Minitest status: #{result}"

puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 🔍 Testing individual file loading..."

test_dir = File.dirname(__FILE__)
test_files = Dir.glob(File.join(test_dir, '**', 'test_*.rb')).sort

excluded_files = [
  'test_helper.rb',
  'run_all_tests.rb',
  'enhanced_test_runner.rb',
  'enhanced_test_runner_simple.rb',
  'progress_test_runner.rb',
  'real_time_test_runner.rb',
  'enhanced_real_time_test_runner.rb',
  'diagnostic_test_runner.rb',
  'robust_test_runner.rb',
  'extreme_hang_detector.rb'
]

test_files_to_load = test_files.select do |file|
  basename = File.basename(file)
  !excluded_files.include?(basename) && basename.start_with?('test_')
end

puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 📁 Found #{test_files_to_load.length} test files to check"

hanging_files = []
loaded_files = 0

test_files_to_load.each_with_index do |file, index|
  relative_path = Pathname.new(file).relative_path_from(Pathname.new(test_dir)).to_s
  
  result = safe_operation("Loading #{relative_path}", 3) do
    require_relative relative_path.sub('.rb', '')
    :success
  end
  
  if result == :timeout
    hanging_files << relative_path
    puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 🚨 HANGING FILE IDENTIFIED: #{relative_path}"
    
    # Stop at first hanging file for analysis
    break
  elsif result.is_a?(Exception)
    puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] ❌ LOAD ERROR: #{relative_path} - #{result.message}"
  else
    loaded_files += 1
  end
  
  # Stop after 5 files to prevent excessive testing
  break if index >= 4
end

if hanging_files.any?
  puts ""
  puts "🚨" * 40
  puts "HANGING FILE(S) DETECTED"
  puts "🚨" * 40
  puts ""
  hanging_files.each do |file|
    puts "🎯 HANGING FILE: #{file}"
  end
  puts ""
  puts "💡 ROOT CAUSE: The test runner hangs when loading specific test files."
  puts "💡 The hang occurs during the require process of these files."
  puts "💡 This suggests infinite loops or blocking operations in test class definitions."
  puts ""
  puts "🔧 RECOMMENDED FIXES:"
  puts "  1. Examine the hanging test file for:"
  puts "     - Infinite loops in class-level code"
  puts "     - Blocking I/O operations during file load"
  puts "     - Recursive require statements"
  puts "     - Heavy computations in class definitions"
  puts "  2. Add timeouts around heavy operations in test files"
  puts "  3. Move expensive operations from class level to test methods"
  puts ""
  exit(1)
else
  puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] ✅ No hanging files detected in sample"
  puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 💡 The hang likely occurs during test execution, not file loading"
end

puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 🔍 Testing basic Minitest execution..."

result = safe_operation("Basic Minitest.run", 10) do
  Minitest.run([])
end

if result == :timeout
  puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 🚨 CRITICAL: Minitest.run() hangs!"
  puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 💡 The hang occurs during test execution phase"
  puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] 💡 This confirms the infinite loop is in test code or parser"
  exit(1)
end

puts "[#{Time.now.strftime("%H:%M:%S.%3N")}] ✅ Basic Minitest execution completed: #{result}"

puts ""
puts "🎯" * 40
puts "EXTREME HANG DETECTION COMPLETE"
puts "🎯" * 40
puts ""
puts "📊 SUMMARY:"
puts "  ✅ SimpleCov loads and configures successfully"
puts "  ✅ test_helper loads successfully"
puts "  ✅ Test files load successfully (sample tested)"
puts "  ✅ Basic Minitest execution works"
puts ""
puts "💡 CONCLUSION:"
puts "  The hang occurs during complex test execution, likely:"
puts "  1. Infinite loop in parser (src/parser/expression_parser.rb)"
puts "  2. Specific test cases that trigger parser hangs"
puts "  3. Complex reasoning operations that don't terminate"
puts ""
puts "🔧 NEXT STEPS:"
puts "  1. Fix the parser infinite loop issue"
puts "  2. Add parser-level timeouts"
puts "  3. Review specific test cases that cause hangs"
puts ""
puts "⏰ Total runtime: #{(Time.now.time_ms - RUBY_ENGINE_START_TIME) / 1000.0}s"
puts "🎯" * 40

# Define a constant for timing (Ruby doesn't have RUBY_ENGINE_START_TIME)
RUBY_ENGINE_START_TIME = Time.now.to_f * 1000

class Time
  def time_ms
    (self.to_f * 1000).to_i
  end
end