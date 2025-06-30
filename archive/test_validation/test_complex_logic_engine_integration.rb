#!/usr/bin/env ruby
# Test script to verify the ComplexLogicEngine → UnificationEngine integration fix

require_relative 'src/reasoning/complex_logic_engine'

puts "Testing ComplexLogicEngine → UnificationEngine integration fix..."
puts "=" * 60

# Mock evaluator to test with
class MockEvaluator
  def to_s
    "MockEvaluator"
  end
end

# Test: ComplexLogicEngine calling UnificationEngine.new(evaluator)
puts "\nTest: ComplexLogicEngine constructor calling UnificationEngine.new(evaluator)"
begin
  evaluator = MockEvaluator.new
  complex_engine = ComplexLogicEngine.new(evaluator)
  puts "✓ SUCCESS: ComplexLogicEngine.new(evaluator) works without ArgumentError"
  
  # Verify the UnificationEngine was created correctly
  unification_engine = complex_engine.instance_variable_get(:@unification_engine)
  stored_evaluator = unification_engine.instance_variable_get(:@evaluator)
  
  puts "  - UnificationEngine created: #{unification_engine.class}"
  puts "  - Stored evaluator: #{stored_evaluator}"
  puts "  - Evaluator matches: #{stored_evaluator == evaluator}"
  
  if stored_evaluator == evaluator
    puts "✓ SUCCESS: Evaluator correctly passed and stored"
  else
    puts "✗ FAILED: Evaluator not correctly stored"
    exit 1
  end
  
rescue => e
  puts "✗ FAILED: #{e.class}: #{e.message}"
  puts "  This indicates the constructor fix did not work"
  exit 1
end

puts "\n" + "=" * 60
puts "🎉 INTEGRATION TEST PASSED!"
puts "\nThe ArgumentError fix is working correctly:"
puts "- ComplexLogicEngine can now successfully create UnificationEngine with evaluator"
puts "- No more 'wrong number of arguments (given 1, expected 0)' error"
puts "- Evaluator is properly stored in UnificationEngine instance"