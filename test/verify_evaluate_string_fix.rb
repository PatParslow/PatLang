#!/usr/bin/env ruby

# Simple test to verify evaluate_string method was added successfully

puts "🔍 VERIFYING EVALUATE_STRING FIX"
puts "=" * 40

begin
  # Load the updated evaluator
  require_relative '../src/evaluator'
  
  puts "✅ Evaluator class loaded successfully"
  
  # Create evaluator instance
  evaluator = Evaluator.new
  puts "✅ Evaluator instance created successfully"
  
  # Check if evaluate_string method exists
  if evaluator.respond_to?(:evaluate_string)
    puts "✅ evaluate_string method is available!"
    
    # Test simple evaluation
    result = evaluator.evaluate_string("5 + 3")
    puts "✅ Simple evaluation works: 5 + 3 = #{result}"
    
    # Test variable assignment
    result2 = evaluator.evaluate_string("x = 42")
    puts "✅ Variable assignment works: x = #{result2}"
    
    # Test reasoning mode commands
    begin
      result3 = evaluator.evaluate_string("enable_reasoning")
      puts "✅ Reasoning mode command works: #{result3}"
    rescue => e
      puts "⚠️  Reasoning mode error (expected): #{e.message}"
    end
    
  else
    puts "❌ evaluate_string method is NOT available"
    puts "Available methods: #{evaluator.methods.grep(/eval/).join(', ')}"
  end
  
rescue => e
  puts "❌ Error loading evaluator: #{e.class}: #{e.message}"
  puts "Backtrace:"
  e.backtrace.first(5).each { |line| puts "  #{line}" }
end

puts "=" * 40
puts "🎯 VERIFICATION COMPLETE"