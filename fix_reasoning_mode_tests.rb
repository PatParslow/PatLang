#!/usr/bin/env ruby

# Phase 1C Priority 1: Fix Reasoning Mode Requirement Failures
# Target: TestEvaluatorReasoning#test_patlang_evaluate_with_goal_system and test_patlang_evaluate_with_facts_database

puts "🎯 PHASE 1C: FIXING REASONING MODE REQUIREMENT FAILURES"
puts "=" * 70

require_relative 'src/patlang'

# Test the current behavior
puts "\n1. TESTING CURRENT FAILURE SCENARIO:"
puts "-" * 40

begin
  result = Patlang.evaluate("goal system test")
  puts "✅ No error - this might be the issue!"
  puts "Result: #{result.inspect}"
rescue => e
  puts "❌ Error: #{e.message}"
  puts "   This confirms the reasoning mode requirement error"
end

begin
  result = Patlang.evaluate("fact database test")
  puts "✅ No error - this might be the issue!"  
  puts "Result: #{result.inspect}"
rescue => e
  puts "❌ Error: #{e.message}"
  puts "   This confirms the reasoning mode requirement error"
end

# Test what should work
puts "\n2. TESTING WHAT SHOULD WORK:"
puts "-" * 40

# Test simple expressions that don't require reasoning mode
begin
  result = Patlang.evaluate("1 + 2")
  puts "✅ Simple math works: #{result}"
rescue => e
  puts "❌ Even simple math fails: #{e.message}"
end

# Test reasoning mode enabled version
puts "\n3. TESTING WITH REASONING MODE:"
puts "-" * 40

begin
  result = Patlang.evaluate_with_reasoning("goal system test")
  puts "✅ With reasoning mode works: #{result.inspect}"
rescue => e
  puts "❌ Even with reasoning mode fails: #{e.message}"
end

puts "\n4. ANALYZING THE PROBLEM:"
puts "-" * 40
puts "The test expressions 'goal system test' and 'fact database test'"
puts "are likely being parsed as goal/fact declarations when they shouldn't be."
puts "OR the tests should use evaluate_with_reasoning() instead of evaluate()."