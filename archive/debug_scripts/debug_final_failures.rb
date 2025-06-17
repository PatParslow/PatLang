#!/usr/bin/env ruby
require 'date'
require_relative 'src/evaluator'
require_relative 'src/reasoning/advanced_goal_strategies'

puts "=== DEBUGGING FINAL 2 FAILURES ==="

evaluator = Evaluator.new
evaluator.enable_object_mode
goal_strategies = AdvancedGoalStrategies.new(evaluator)

puts "\n1. VOTING TEST DEBUG:"
market_scenario = {
  historical_data: (1..100).map { |d| { date: Date.today - d, price: 100 + rand(-10.0..10.0) } },
  current_indicators: { volatility: 0.15, trend: "bullish" },
  constraints: { max_risk: 0.12, min_return: 0.08 }
}

result = goal_strategies.execute_parallel_strategies(
  :find_optimal_investment_portfolio,
  "goal definition...",
  market_scenario
)

puts "Strategies executed: #{result[:parallel_execution][:strategies_executed]} (expected: 4)"
puts "Consensus reached: #{result[:voting_results][:consensus_reached]} (expected: true)"
puts "Confidence score: #{result[:final_portfolio][:confidence_score]} (expected: >= 0.8)"
puts "Strategy contributions count: #{result[:strategy_contributions].length}"
puts "All weights > 0: #{result[:strategy_contributions].all? { |c| c[:weight] > 0 }}"
puts "Strategy contributions: #{result[:strategy_contributions].inspect}"

puts "\n2. REAL-TIME ADAPTATION DEBUG:"
initial_state = { intersections: 20, average_speed: 35, density: 0.6, incidents: 0 }
changing_events = [
  { time: 1000, type: :accident, location: "intersection_5" },
  { time: 2000, type: :emergency_vehicle, route: "main_avenue" },
  { time: 3000, type: :weather_change, condition: "heavy_rain" },
  { time: 4000, type: :rush_hour_peak, density_multiplier: 2.5 }
]

result = goal_strategies.execute_adaptive_goal(
  :manage_smart_city_traffic,
  "goal definition...",
  { traffic_state: initial_state, events: changing_events }
)

puts "Events length: #{changing_events.length}"
puts "Adaptations length: #{result[:adaptations].length} (expected: >= #{changing_events.length})"
puts "Average response time: #{result[:real_time_performance][:average_response_time]} (expected: < 0.1)"
puts "Objectives balanced: #{result[:optimization_results][:objectives_balanced]} (expected: true)"
puts "Adaptations: #{result[:adaptations].inspect}"