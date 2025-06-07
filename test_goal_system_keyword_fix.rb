#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'src/evaluator'
require_relative 'src/reasoning/goal_system'
require_relative 'src/reasoning/reasoning_coordinator'

# Test script to verify GoalSystem constructor keyword fix
puts "Testing GoalSystem constructor keyword fix..."

begin
  evaluator = Evaluator.new
  evaluator.enable_object_mode
  goal_system = GoalSystem.new(evaluator)
  reasoning_coordinator = ReasoningCoordinator.new(evaluator)
  goal_system.set_reasoning_coordinator(reasoning_coordinator)
  
  # Test goal declaration with keywords that were causing ArgumentError
  goal_definition = <<~PATLANG
    goal find_optimal_value {
      description: "Find a value that satisfies multiple criteria",
      postcondition: result > 10 and result < 100 and result.even?
    }
  PATLANG
  
  goal = goal_system.declare_goal(:find_optimal_value, goal_definition)
  
  puts "✓ SUCCESS: Goal created successfully"
  puts "  - Goal name: #{goal.name}"
  puts "  - Goal description: #{goal.description}"
  puts "  - Has description: #{!goal.description.nil? && !goal.description.empty?}"
  puts "  - Has context: #{goal.respond_to?(:context)}"
  puts "  - Context value: #{goal.context if goal.respond_to?(:context)}"
  
  # Test goal with strategies
  goal_definition_with_strategies = <<~PATLANG
    goal find_prime_number(min, max) {
      postcondition: result.prime? and result >= min and result <= max,
      strategies: [
        trial_division,
        sieve_of_eratosthenes,
        miller_rabin_test
      ],
      preference: performance_optimized
    }
  PATLANG
  
  goal2 = goal_system.declare_goal(:find_prime_number, goal_definition_with_strategies)
  puts "✓ SUCCESS: Goal with strategies created successfully"
  puts "  - Strategies count: #{goal2.strategies&.length || 0}"
  puts "  - Strategies: #{goal2.strategies || []}"
  
  # Test goal with subgoals
  goal_definition_with_subgoals = <<~PATLANG
    goal plan_vacation(destination, budget, duration) {
      postcondition: 
        plan.total_cost <= budget and
        plan.duration == duration and
        plan.satisfaction_score >= 8.0,
      subgoals: [
        find_flights,
        book_accommodation,
        plan_activities,
        arrange_transportation
      ]
    }
  PATLANG
  
  goal3 = goal_system.declare_goal(:plan_vacation, goal_definition_with_subgoals)
  puts "✓ SUCCESS: Goal with subgoals created successfully"
  puts "  - Subgoals count: #{goal3.subgoals&.length || 0}"
  puts "  - Subgoals: #{goal3.subgoals || []}"
  
  # Test goal with context
  goal_definition_with_context = <<~PATLANG
    goal optimize_portfolio(stocks, target_return) {
      precondition: stocks.length > 0 and target_return > 0,
      postcondition: 
        result.expected_return >= target_return and
        result.risk_level <= acceptable_risk and
        result.diversification_score >= 0.7,
      context: {
        market_data: current_market_state,
        risk_tolerance: user_preferences.risk_level,
        time_horizon: investment_timeline
      }
    }
  PATLANG
  
  goal4 = goal_system.declare_goal(:optimize_portfolio, goal_definition_with_context)
  puts "✓ SUCCESS: Goal with context created successfully"
  puts "  - Context: #{goal4.context}"
  puts "  - Context keys: #{goal4.context.keys if goal4.context.is_a?(Hash)}"
  
  puts "\n🎉 ALL TESTS PASSED - ArgumentError for unknown keywords fixed!"
  puts "The GoalSystem constructor now properly accepts:"
  puts "  - :description keyword"
  puts "  - :strategies keyword" 
  puts "  - :subgoals keyword"
  puts "  - :context keyword"

rescue ArgumentError => e
  if e.message.include?("unknown keywords")
    puts "❌ FAILED: ArgumentError still occurring"
    puts "Error: #{e.message}"
    puts "This indicates the constructor keyword mismatch is not yet fixed"
    exit 1
  else
    puts "❌ Different ArgumentError: #{e.message}"
    exit 1
  end
rescue => e
  puts "❌ Unexpected error: #{e.class}: #{e.message}"
  puts "Backtrace:"
  puts e.backtrace[0..5].join("\n")
  exit 1
end