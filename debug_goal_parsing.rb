#!/usr/bin/env ruby
# Debug Goal Parsing Issue

require_relative 'src/reasoning/goal_system'
require_relative 'src/evaluator'

puts "=== Debugging Goal Parsing Issue ==="

# Set up like the test
evaluator = Evaluator.new
evaluator.enable_object_mode
goal_system = GoalSystem.new(evaluator)

# Test the exact goal definition from the failing test
goal_definition = <<~PATLANG
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

puts "Goal definition:"
puts goal_definition
puts
puts "Parsed lines:"
lines = goal_definition.split("\n").map(&:strip).reject(&:empty?)
lines.each_with_index { |line, i| puts "#{i}: #{line.inspect}" }
puts

# Test the parsing
puts "=== Testing Goal Declaration ==="
begin
  puts "Before goal creation..."
  goal = goal_system.declare_goal(:find_prime_number, goal_definition)
  
  puts "Goal created successfully!"
  puts "Goal name: #{goal.name}"
  puts "Goal class: #{goal.class}"
  puts "Goal strategies: #{goal.strategies.inspect}"
  puts "Goal strategies class: #{goal.strategies.class}"
  puts "Goal strategies length: #{goal.strategies&.length || 'nil'}"
  puts "Goal preference: #{goal.preference}"
  puts "Goal description: #{goal.description.inspect}"
  
  # Check instance variables directly
  puts "\n=== Direct Instance Variable Check ==="
  puts "Goal @strategies: #{goal.instance_variable_get(:@strategies).inspect}"
  puts "Goal @preference: #{goal.instance_variable_get(:@preference).inspect}"
  
rescue => e
  puts "ERROR: #{e.class}: #{e.message}"
  puts e.backtrace.first(5)
end

puts "\n=== Testing Direct Parsing Method ==="
# Test parse_goal_definition directly
begin
  parsed = goal_system.send(:parse_goal_definition, goal_definition)
  puts "Parsed result: #{parsed.inspect}"
rescue => e
  puts "ERROR in parsing: #{e.class}: #{e.message}"
  puts e.backtrace.first(5)
end