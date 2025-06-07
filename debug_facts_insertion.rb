#!/usr/bin/env ruby

require_relative 'src/evaluator'
require_relative 'src/reasoning/facts_database'
require_relative 'src/reasoning/reasoning_coordinator'

def prime?(n)
  return false if n < 2
  return true if n == 2
  return false if n.even?
  
  (3..Math.sqrt(n)).step(2) do |i|
    return false if n % i == 0
  end
  true
end

evaluator = Evaluator.new
evaluator.enable_object_mode
facts_db = FactsDatabase.new(evaluator)
reasoning_coordinator = ReasoningCoordinator.new(evaluator)
facts_db.set_reasoning_coordinator(reasoning_coordinator)

# Test first 10 facts
10.times do |i|
  puts "Adding number(#{i}): #{facts_db.assert_fact("number(#{i})")}"
  if i.even?
    puts "Adding even(#{i}): #{facts_db.assert_fact("even(#{i})")}"
  end
  if prime?(i)
    puts "Adding prime(#{i}): #{facts_db.assert_fact("prime(#{i})")}"
  end
end

puts "\nTotal facts: #{facts_db.fact_count}"
puts "Expected: #{10 + 5 + [2, 3, 5, 7].length}"

puts "\nAll facts:"
facts_db.all_facts.each { |fact| puts "  #{fact}" }