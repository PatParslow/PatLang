#!/usr/bin/env ruby

require_relative 'src/evaluator'
require_relative 'src/reasoning/facts_database'
require_relative 'src/reasoning/reasoning_coordinator'

# Set up like the test
evaluator = Evaluator.new
evaluator.enable_object_mode
facts_db = FactsDatabase.new(evaluator)
reasoning_coordinator = ReasoningCoordinator.new(evaluator)
facts_db.set_reasoning_coordinator(reasoning_coordinator)

# Add facts from the test
facts = [
  "student(alice, computer_science)",
  "student(bob, mathematics)",
  "grade(alice, algorithms, 95)",
  "grade(alice, databases, 88)",
  "grade(bob, calculus, 92)"
]

puts "Adding facts:"
facts.each { |fact| facts_db.assert_fact(fact) }

puts "\nQuery: student(Student, Major), grade(Student, Course, Grade)"
results = facts_db.query("student(Student, Major), grade(Student, Course, Grade)")

puts "\nResults (#{results.length}):"
results.each_with_index do |result, i|
  puts "#{i+1}: #{result.inspect}"
end

puts "\nExpected: 3 results"
puts "Actual: #{results.length} results"