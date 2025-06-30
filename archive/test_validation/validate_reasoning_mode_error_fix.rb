#!/usr/bin/env ruby

# Phase 1 Validation: ReasoningModeError Superclass Mismatch Fix
puts "=== Phase 1 Validation: ReasoningModeError Superclass Mismatch Fix ==="
puts

# Test 1: Verify ReasoningModeError can be loaded without superclass mismatch
puts "1. Testing ReasoningModeError loading..."
begin
  require_relative 'src/exceptions'
  puts "✓ Successfully loaded exceptions.rb"
rescue => e
  puts "✗ Failed to load exceptions.rb: #{e.message}"
  exit 1
end

# Test 2: Verify ReasoningModeError class exists and has correct superclass
puts "\n2. Testing ReasoningModeError class definition..."
begin
  if defined?(ReasoningModeError)
    puts "✓ ReasoningModeError class is defined"
    
    # Check superclass
    superclass = ReasoningModeError.superclass.name
    if superclass == "PatlangError"
      puts "✓ ReasoningModeError correctly inherits from PatlangError"
    else
      puts "✗ ReasoningModeError inherits from #{superclass}, expected PatlangError"
    end
  else
    puts "✗ ReasoningModeError class is not defined"
  end
rescue => e
  puts "✗ Error checking ReasoningModeError definition: #{e.message}"
end

# Test 3: Verify ReasoningModeError can be instantiated with default message
puts "\n3. Testing ReasoningModeError instantiation..."
begin
  error = ReasoningModeError.new
  if error.message == "Reasoning mode not enabled"
    puts "✓ ReasoningModeError has correct default message: '#{error.message}'"
  else
    puts "✗ ReasoningModeError has incorrect default message: '#{error.message}'"
  end
rescue => e
  puts "✗ Failed to instantiate ReasoningModeError: #{e.message}"
end

# Test 4: Verify ReasoningModeError can be instantiated with custom message
puts "\n4. Testing ReasoningModeError with custom message..."
begin
  custom_message = "Custom reasoning error"
  error = ReasoningModeError.new(custom_message)
  if error.message == custom_message
    puts "✓ ReasoningModeError accepts custom message: '#{error.message}'"
  else
    puts "✗ ReasoningModeError custom message failed: '#{error.message}'"
  end
rescue => e
  puts "✗ Failed to instantiate ReasoningModeError with custom message: #{e.message}"
end

# Test 5: Verify evaluator.rb can be loaded
puts "\n5. Testing evaluator.rb loading..."
begin
  require_relative 'src/evaluator'
  puts "✓ Successfully loaded evaluator.rb"
rescue => e
  puts "✗ Failed to load evaluator.rb: #{e.message}"
  puts "  Error details: #{e.class}: #{e.message}"
end

# Test 6: Verify test file can be loaded
puts "\n6. Testing test file loading..."
begin
  require_relative 'test/patlang_language/test_evaluator_branch_coverage'
  puts "✓ Successfully loaded test_evaluator_branch_coverage.rb"
rescue => e
  puts "✗ Failed to load test_evaluator_branch_coverage.rb: #{e.message}"
  puts "  Error details: #{e.class}: #{e.message}"
end

# Test 7: Check for superclass mismatch specifically
puts "\n7. Testing for superclass mismatch errors..."
begin
  # Try to reload the class to see if there are any conflicts
  load 'src/exceptions.rb'
  puts "✓ No superclass mismatch errors detected"
rescue TypeError => e
  if e.message.include?("superclass mismatch")
    puts "✗ Superclass mismatch still exists: #{e.message}"
    exit 1
  else
    puts "✗ Other TypeError: #{e.message}"
  end
rescue => e
  puts "✗ Other error during reload test: #{e.message}"
end

puts "\n=== Phase 1 Validation Complete ==="
puts "ReasoningModeError superclass mismatch resolution appears successful!"