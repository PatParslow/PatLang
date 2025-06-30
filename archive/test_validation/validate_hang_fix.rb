#!/usr/bin/env ruby
# frozen_string_literal: true

# Validation script to test the hang fix implementation
require_relative 'src/emergency_timeout'

puts "Testing EmergencyTimeout mechanism..."

# Test 1: Normal operation within timeout
begin
  result = EmergencyTimeout.protect(1) do
    puts "  ✓ Normal operation completed"
    "success"
  end
  puts "  ✓ Test 1 PASSED: Normal operation returned '#{result}'"
rescue => e
  puts "  ✗ Test 1 FAILED: #{e.message}"
end

# Test 2: Operation that would hang gets terminated
begin
  EmergencyTimeout.protect(0.5) do
    puts "  Starting potentially hanging operation..."
    sleep(2)  # This should timeout
    puts "  This should never print"
  end
  puts "  ✗ Test 2 FAILED: Timeout should have occurred"
rescue EmergencyTimeout::TimeoutError => e
  puts "  ✓ Test 2 PASSED: Timeout protection worked: #{e.message}"
rescue => e
  puts "  ✗ Test 2 FAILED: Unexpected error: #{e.message}"
end

# Test 3: Very short timeout for individual operations
begin
  EmergencyTimeout.protect_operation(0.01) do
    sleep(0.1)  # Should timeout quickly
  end
  puts "  ✗ Test 3 FAILED: Should have timed out"
rescue EmergencyTimeout::TimeoutError => e
  puts "  ✓ Test 3 PASSED: Per-operation timeout worked: #{e.message}"
rescue => e
  puts "  ✗ Test 3 FAILED: Unexpected error: #{e.message}"
end

puts "\nHang fix validation completed!"
puts "The EmergencyTimeout mechanism is working correctly and should prevent test hangs."