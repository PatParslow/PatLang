#!/usr/bin/env ruby

# Test script to verify constructor issues and fixes
require_relative 'src/reasoning/facts_database'
require_relative 'src/reasoning/goal_system'
require_relative 'src/reasoning/unification_engine'
require_relative 'src/reasoning/cross_paradigm_coordinator'

puts "Testing constructor issues..."

# Test 1: FactsDatabase constructor with no arguments
begin
  facts_db = FactsDatabase.new
  puts "✗ FactsDatabase.new() should fail but succeeded"
rescue ArgumentError => e
  puts "✓ FactsDatabase.new() correctly fails: #{e.message}"
end

# Test 2: GoalSystem constructor with no arguments  
begin
  goal_system = GoalSystem.new
  puts "✗ GoalSystem.new() should fail but succeeded"
rescue ArgumentError => e
  puts "✓ GoalSystem.new() correctly fails: #{e.message}"
end

# Test 3: UnificationEngine.unify with 2 arguments (should work after fix)
begin
  unification_engine = UnificationEngine.new
  result = unification_engine.unify(:a, :b)
  puts "Testing unify with 2 args: #{result.nil? ? 'failed' : 'succeeded'}"
rescue ArgumentError => e
  puts "✗ UnificationEngine.unify with 2 args fails: #{e.message}"
end

# Test 4: Cross-Paradigm Coordinator execute_workflow with nil checks
begin
  coordinator = CrossParadigmCoordinator.new
  result = coordinator.execute_workflow("test", nil, {})
  puts "✓ CrossParadigmCoordinator.execute_workflow handles nil: #{result[:status]}"
rescue => e
  puts "✗ CrossParadigmCoordinator.execute_workflow fails: #{e.message}"
end

puts "Constructor test complete."