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

# Test with incremental sizes
[100, 500, 1000, 5000, 10000].each do |size|
  facts_db = FactsDatabase.new(evaluator)
  facts_db.set_reasoning_coordinator(reasoning_coordinator)
  
  size.times do |i|
    facts_db.assert_fact("number(#{i})")
    facts_db.assert_fact("even(#{i})") if i.even?
    facts_db.assert_fact("prime(#{i})") if prime?(i)
  end
  
  expected = size * 2 + count_primes_up_to(size)
  actual = facts_db.fact_count
  
  puts "Size #{size}: Expected #{expected}, Actual #{actual}, Diff #{expected - actual}"
end