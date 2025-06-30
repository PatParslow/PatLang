#!/usr/bin/env ruby

# Quick validation of our evaluator integration fixes
require_relative 'src/patlang'

puts "🧪 TESTING EVALUATOR INTEGRATION FIXES"
puts "=" * 50

def test_basic_functionality
  puts "\n1. Testing basic arithmetic (including exponentiation):"
  
  tests = [
    "2 + 3",
    "10 * 5", 
    "2 ^ 3",  # Test exponentiation
    "x = 42",
    "y = x + 8"
  ]
  
  tests.each do |code|
    begin
      result = Patlang.evaluate(code)
      puts "  ✅ '#{code}' = #{result}"
    rescue => e
      puts "  ❌ '#{code}' failed: #{e.message}"
    end
  end
end

def test_reasoning_constructs
  puts "\n2. Testing reasoning constructs:"
  
  # Enable reasoning mode
  Patlang.evaluate("reasoning on")
  
  reasoning_tests = [
    "goal test_goal { postcondition: x > 0 }",
    "constrain x :: Number",
    "assert fact(likes(alice, bob))"
  ]
  
  reasoning_tests.each do |code|
    begin
      result = Patlang.evaluate(code)
      puts "  ✅ '#{code}' = #{result.class} - #{result.respond_to?(:name) ? result.name : result}"
    rescue => e
      puts "  ❌ '#{code}' failed: #{e.message}"
    end
  end
end

def test_goal_pursuit  
  puts "\n3. Testing goal pursuit:"
  
  begin
    # Set up a goal
    goal_result = Patlang.evaluate("goal find_answer { postcondition: answer > 0 and answer < 100 }")
    puts "  ✅ Goal created: #{goal_result.class}"
    
    # Try to pursue it
    pursue_result = Patlang.evaluate("pursue find_answer")
    puts "  ✅ Pursue result: #{pursue_result}"
    
  rescue => e
    puts "  ❌ Goal pursuit failed: #{e.message}"
  end
end

# Run the tests
test_basic_functionality
test_reasoning_constructs  
test_goal_pursuit

puts "\n🎯 INTEGRATION FIX VALIDATION COMPLETE"