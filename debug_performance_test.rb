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

def count_primes_up_to(n)
  (0...n).count { |i| prime?(i) }
end

# Set up like the test
evaluator = Evaluator.new
evaluator.enable_object_mode
facts_db = FactsDatabase.new(evaluator)
reasoning_coordinator = ReasoningCoordinator.new(evaluator)
facts_db.set_reasoning_coordinator(reasoning_coordinator)

# Insert large number of facts like the test
fact_count = 10000

puts "Starting fact insertion..."
start_time = Time.now

fact_count.times do |i|
  facts_db.assert_fact("number(#{i})")
  facts_db.assert_fact("even(#{i})") if i.even?
  facts_db.assert_fact("prime(#{i})") if prime?(i)
end

insertion_time = Time.now - start_time

puts "Insertion time: #{insertion_time} seconds"
puts "Expected total facts: #{fact_count * 2 + count_primes_up_to(fact_count)}"
puts "Actual total facts: #{facts_db.fact_count}"
puts "Difference: #{(fact_count * 2 + count_primes_up_to(fact_count)) - facts_db.fact_count}"

# Check a few sample facts
puts "\nSample facts exist?"
puts "number(0): #{facts_db.has_fact?('number(0)')}"
puts "even(0): #{facts_db.has_fact?('even(0)')}"
puts "number(1): #{facts_db.has_fact?('number(1)')}"
puts "even(1): #{facts_db.has_fact?('even(1)')}"
puts "prime(2): #{facts_db.has_fact?('prime(2)')}"