#!/usr/bin/env ruby

# Error Diagnosis Validation Script
# Validates the two primary root causes identified

puts "🔍 VALIDATING ERROR DIAGNOSIS"
puts "=" * 50

# Test 1: Check if Patlang constant exists
puts "\n📋 TEST 1: Patlang Constant Availability"
begin
  require_relative '../src/patlang'
  if defined?(Patlang)
    puts "✅ Patlang constant is defined"
    puts "   Class: #{Patlang.class}"
    puts "   Methods: #{Patlang.methods(false).length} custom methods"
  else
    puts "❌ Patlang constant is NOT defined"
  end
rescue => e
  puts "❌ Error loading Patlang: #{e.class}: #{e.message}"
end

# Test 2: Check reasoning mode functionality
puts "\n📋 TEST 2: Reasoning Mode Implementation"
begin
  require_relative '../patlang-core/evaluator/evaluator'
  evaluator = Evaluator.new
  
  # Test enable reasoning mode
  result = evaluator.evaluate_string("enable_reasoning")
  puts "✅ enable_reasoning executed: #{result.inspect}"
  
  # Test disable reasoning mode  
  result2 = evaluator.evaluate_string("disable_reasoning")
  puts "✅ disable_reasoning executed: #{result2.inspect}"
  
rescue => e
  puts "❌ Reasoning mode error: #{e.class}: #{e.message}"
end

# Test 3: Parser syntax capabilities
puts "\n📋 TEST 3: Parser Advanced Syntax Support"
test_cases = [
  'rule ancestor(X, Y) :- parent(X, Y).',
  'query person(X) where X > 0',
  'constrain age :: Number where age >= 0',
  'email matches /\\w+@\\w+\\.\\w+/'
]

require_relative '../patlang-core/parser/parser'
require_relative '../patlang-core/lexer/lexer'

test_cases.each_with_index do |syntax, index|
  puts "\n   Test #{index + 1}: #{syntax}"
  begin
    lexer = Lexer.new(syntax)
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    puts "   ✅ PARSED: #{ast.class}"
  rescue => e
    puts "   ❌ PARSE ERROR: #{e.message}"
  end
end

# Test 4: Event system availability
puts "\n📋 TEST 4: Event System Implementation"
begin
  require_relative '../src/object_model/event_system'
  if defined?(EventSystem)
    puts "✅ EventSystem module exists"
    
    # Test if common events can be fired using the module's class methods
    test_events = [:type_refinement, :emergent_behavior_detected, :logic_goal_synthesis]
    
    test_events.each do |event|
      begin
        # Test using EventSystem's global fire_event method
        if EventSystem.respond_to?(:fire_global_event)
          EventSystem.fire_global_event(event, { test: true })
          puts "   ✅ Event system can fire #{event}"
        else
          puts "   ❌ Event system missing fire_global_event method"
          break
        end
      rescue => e
        puts "   ❌ Event #{event} error: #{e.message}"
      end
    end
  else
    puts "❌ EventSystem class not defined"
  end
rescue => e
  puts "❌ Event system error: #{e.class}: #{e.message}"
end

# Test 5: Core function availability
puts "\n📋 TEST 5: Core Function Implementations"
core_functions = ['knows', 'likes', 'parent', 'ancestor']

begin
  require_relative '../patlang-core/evaluator/evaluator'
  evaluator = Evaluator.new
  
  core_functions.each do |func|
    begin
      result = evaluator.evaluate_string("#{func}(alice, bob)")
      puts "   ✅ Function #{func} available: #{result.inspect}"
    rescue => e
      puts "   ❌ Function #{func} missing: #{e.message.split(':').first}"
    end
  end
rescue => e
  puts "❌ Function evaluation error: #{e.class}: #{e.message}"
end

puts "\n" + "=" * 50
puts "🎯 DIAGNOSIS VALIDATION COMPLETE"