#!/usr/bin/env ruby
# Debug script to test postcondition validation

$LOAD_PATH.unshift(File.expand_path('src', __dir__))
$LOAD_PATH.unshift(File.expand_path('test', __dir__))

require_relative 'src/reasoning/goal_system'

puts "🔍 DEBUGGING POSTCONDITION VALIDATION"
puts "=" * 50

# Create goal system
goal_system = GoalSystem.new

# Define goal with postcondition
goal_definition = <<~GOAL
  goal strict_goal {
    description: "Goal with strict postconditions"
    postcondition: result > 10 and result < 100 and result.even?
  }
GOAL

puts "📋 Declaring goal with postcondition..."
goal = goal_system.declare_goal(:strict_goal, goal_definition)

puts "Goal name: #{goal.name}"
puts "Has postcondition?: #{goal.has_postcondition?}"
puts "Postconditions: #{goal.postconditions.inspect}"

# Mock the goal execution to return 5 (should fail postcondition)
class << goal_system
  def execute_goal_strategy(goal, strategy, context)
    puts "🎯 Executing goal: #{goal.name.inspect} (#{goal.name.class})"
    if goal.name == :strict_goal || goal.name == "strict_goal"
      puts "   ✅ Matched goal name, returning 5"
      return 5
    else
      puts "   ❌ No match, calling super"
      super
    end
  end
end

puts "\n🧪 Testing postcondition validation..."

# Test the postcondition evaluation directly
result = 5
context = { result: result }

puts "Result: #{result}"
puts "Context: #{context.inspect}"

# Test the condition evaluation
expression = "result > 10 and result < 100 and result.even?"
evaluation_result = goal_system.send(:evaluate_condition_expression, expression, context)
puts "Condition '#{expression}' evaluates to: #{evaluation_result}"

# Test check_postconditions
postcondition_check = goal_system.send(:check_postconditions, goal, result, {})
puts "check_postconditions result: #{postcondition_check}"

puts "\n🚀 Testing pursue_goal..."
begin
  result = goal_system.pursue_goal(:strict_goal)
  puts "❌ ERROR: pursue_goal should have raised RuntimeError but returned: #{result}"
rescue RuntimeError => e
  puts "✅ SUCCESS: RuntimeError raised as expected: #{e.message}"
rescue => e
  puts "❌ ERROR: Wrong exception type: #{e.class}: #{e.message}"
end

puts "\n🏁 Debug complete"