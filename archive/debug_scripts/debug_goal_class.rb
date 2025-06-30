#!/usr/bin/env ruby
# Debug which Goal class is being used

require_relative 'src/reasoning/goal_system'
require_relative 'src/evaluator'

puts "=== Debugging Goal Class Issue ==="

# Check which Goal classes are loaded
puts "Goal class: #{Goal}"
puts "Goal class location: #{Goal.method(:new).source_location}"
puts "Goal instance methods: #{Goal.instance_methods(false).sort}"
puts

# Check if there are multiple Goal classes
goal_classes = ObjectSpace.each_object(Class).select { |c| c.name == 'Goal' }
puts "Number of Goal classes found: #{goal_classes.length}"
goal_classes.each_with_index do |klass, i|
  puts "Goal class #{i+1}: #{klass.object_id} - #{klass}"
  begin
    puts "  Source location: #{klass.method(:new).source_location}"
  rescue => e
    puts "  Source location: #{e.message}"
  end
end
puts

# Test Goal creation directly with known parameters
puts "=== Testing Direct Goal Creation ==="
test_options = {
  strategies: [:test1, :test2, :test3],
  preference: :test_preference,
  description: "test description"
}

goal = Goal.new(:test_goal, **test_options)
puts "Created goal: #{goal.inspect}"
puts "Goal strategies: #{goal.strategies.inspect}"
puts "Goal preference: #{goal.preference.inspect}"
puts "Goal description: #{goal.description.inspect}"