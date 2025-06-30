#!/usr/bin/env ruby
# Debug remaining Advanced Goal Strategy failures

require_relative 'src/evaluator'
require_relative 'src/reasoning/advanced_goal_strategies'

puts "=== DEBUGGING ADVANCED GOAL STRATEGY FAILURES ==="
puts

evaluator = Evaluator.new
evaluator.enable_object_mode
goal_strategies = AdvancedGoalStrategies.new(evaluator)

puts "1. Testing Performance Optimization:"
big_data_scenario = {
  dataset: (1..100).map { |i| { id: i, value: rand(1000), category: rand(10) } },
  analysis_types: ["statistical_analysis", "pattern_mining"],
  performance_targets: { max_execution_time: 30.0, memory_limit: 4_000_000_000, cache_hit_rate: 0.8 }
}

goal_definition = "goal analyze_big_data_patterns..."
results = []
3.times do |iteration|
  result = goal_strategies.execute_performance_optimized(
    :analyze_big_data_patterns,
    goal_definition,
    big_data_scenario
  )
  results << result
  puts "  Iteration #{iteration}: execution_time=#{result[:execution_time]}, performance_improvement=#{result[:performance_improvement]}"
end

puts "  Results comparison:"
puts "    results[0][:execution_time] > results[1][:execution_time]: #{results[0][:execution_time] > results[1][:execution_time]}"
puts "    results[1][:execution_time] > results[2][:execution_time]: #{results[1][:execution_time] > results[2][:execution_time]}"
puts "    results[2][:cache_metrics][:hit_rate] >= 0.8: #{results[2][:cache_metrics][:hit_rate] >= 0.8}"
puts "    results[2][:performance_improvement] >= 2.0: #{results[2][:performance_improvement] >= 2.0}"
puts

puts "2. Testing Multi-Strategy Voting:"
market_scenario = {
  historical_data: (1..100).map { |d| { date: Date.today - d, price: 100 + rand(-10.0..10.0) } },
  current_indicators: { volatility: 0.15, trend: "bullish" },
  constraints: { max_risk: 0.12, min_return: 0.08 }
}

result = goal_strategies.execute_parallel_strategies(
  :find_optimal_investment_portfolio,
  goal_definition,
  market_scenario
)

puts "  Strategies executed: #{result[:parallel_execution][:strategies_executed]} (expected: 4)"
puts "  Consensus reached: #{result[:voting_results][:consensus_reached]} (expected: true)"
puts "  Confidence score: #{result[:final_portfolio][:confidence_score]} (expected: >= 0.8)"
puts "  All weights > 0: #{result[:strategy_contributions].all? { |c| c[:weight] > 0 }}"
puts

puts "3. Testing Real-Time Adaptation:"
initial_state = { intersections: 20, average_speed: 35, density: 0.6, incidents: 0 }
changing_events = [
  { time: 1000, type: :accident, location: "intersection_5" },
  { time: 2000, type: :emergency_vehicle, route: "main_avenue" },
  { time: 3000, type: :weather_change, condition: "heavy_rain" },
  { time: 4000, type: :rush_hour_peak, density_multiplier: 2.5 }
]

result = goal_strategies.execute_adaptive_goal(
  :manage_smart_city_traffic,
  goal_definition,
  { traffic_state: initial_state, events: changing_events }
)

puts "  Adaptations length: #{result[:adaptations].length} (expected: >= #{changing_events.length})"
puts "  Average response time: #{result[:real_time_performance][:average_response_time]} (expected: < 0.1)"
puts "  Objectives balanced: #{result[:optimization_results][:objectives_balanced]} (expected: true)"