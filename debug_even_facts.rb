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

# Insert first 100 facts and check
100.times do |i|
  facts_db.assert_fact("number(#{i})")
  if i.even?
    facts_db.assert_fact("even(#{i})")
  end
end

puts "Total facts after 100 numbers: #{facts_db.fact_count}"
puts "Expected: #{100 + 50} = 150"

# Count even facts explicitly
even_facts = facts_db.all_facts.select { |fact| fact.start_with?('even(') }
puts "Even facts found: #{even_facts.length}"
puts "Expected even facts: 50"

puts "\nFirst 10 even facts:"
even_facts.first(10).each { |fact| puts "  #{fact}" }

puts "\nLast 10 even facts:"
even_facts.last(10).each { |fact| puts "  #{fact}" }

# Check specific even numbers
puts "\nSpecific even fact checks:"
[0, 2, 4, 6, 8, 10, 98].each do |n|
  puts "even(#{n}): #{facts_db.has_fact?("even(#{n})")}"
end