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

# Add some facts like the test
facts = [
  "likes(alice, bob)",
  "likes(bob, charlie)",
  "likes(charlie, alice)"
]

puts "Adding facts:"
facts.each do |fact|
  result = facts_db.assert_fact(fact)
  puts "  #{fact}: #{result}"
end

puts "\nAll facts:"
facts_db.all_facts.each { |fact| puts "  #{fact}" }

puts "\nTesting query: likes(alice, X)"
results = facts_db.query("likes(alice, X)")
puts "Query results: #{results.inspect}"

if results && results.any?
  puts "First result: #{results.first.inspect}"
  if results.first.respond_to?(:[])
    puts "X value: #{results.first[:X].inspect}"
  end
end