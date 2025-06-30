#!/usr/bin/env ruby
# Validate the two primary suspected issues

puts "🔬 VALIDATING HANG DIAGNOSIS"
puts "=" * 50

# Test 1: Check if load_test_files is called when real_time_test_runner is required
puts "\n1. Testing real_time_test_runner execution flow:"
puts "   Current behavior: require_relative should trigger load_test_files"

# Simulate what run_all_tests.rb does
puts "   Requiring real_time_test_runner..."
begin
  # Add debug to see if load_test_files gets called
  original_load_test_files = nil
  
  # Capture if load_test_files is called
  load_called = false
  
  # Override puts to capture output
  original_puts = method(:puts)
  captured_output = []
  
  define_method(:puts) do |*args|
    captured_output.concat(args)
    original_puts.call(*args)
  end
  
  require_relative 'test/real_time_test_runner'
  
  # Check if we see test discovery output
  discovery_output = captured_output.any? { |line| line.to_s.include?("Discovering test files") }
  puts "   🔍 Test discovery triggered: #{discovery_output}"
  
rescue => e
  puts "   ❌ Error: #{e.message}"
end

# Test 2: Check assert_not_nil availability
puts "\n2. Testing minitest assertion availability:"
begin
  require 'minitest/autorun'
  
  # Create a test class to check available methods
  class TestAssertions < Minitest::Test
    def test_dummy; end
  end
  
  test_instance = TestAssertions.new(:test_dummy)
  
  has_assert_not_nil = test_instance.respond_to?(:assert_not_nil)
  puts "   assert_not_nil available: #{has_assert_not_nil}"
  
  if has_assert_not_nil
    puts "   ✅ Minitest assertions properly loaded"
  else
    puts "   ❌ Missing assert_not_nil - this explains test failures!"
    puts "   Available assertion methods:"
    assertion_methods = test_instance.methods.select { |m| m.to_s.start_with?('assert') }.sort
    assertion_methods.first(10).each { |m| puts "     - #{m}" }
  end
  
rescue => e
  puts "   ❌ Error: #{e.message}"
end

# Test 3: Check execution of real_time_test_runner as main
puts "\n3. Testing direct execution of real_time_test_runner:"
puts "   Checking if __FILE__ == $0 condition works correctly..."

# Get the actual content to see the execution trigger
File.open('test/real_time_test_runner.rb', 'r') do |file|
  content = file.read
  has_main_execution = content.include?('if __FILE__ == $0')
  has_load_call = content.include?('load_test_files')
  
  puts "   Has main execution guard: #{has_main_execution}"
  puts "   Has load_test_files call: #{has_load_call}"
  
  if has_main_execution && has_load_call
    puts "   🔍 The issue is likely that real_time_test_runner is required, not executed!"
  end
end

puts "\n" + "=" * 50
puts "🎯 DIAGNOSIS VALIDATION COMPLETE"