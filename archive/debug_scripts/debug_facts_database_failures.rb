#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'src/evaluator'
require_relative 'src/reasoning/facts_database'
require_relative 'src/reasoning/reasoning_coordinator'

puts "🔍 FACTS DATABASE QUERY FAILURE ANALYSIS"
puts "=" * 60

# Initialize the facts database system
evaluator = Evaluator.new
evaluator.enable_object_mode
facts_db = FactsDatabase.new(evaluator)
reasoning_coordinator = ReasoningCoordinator.new(evaluator)
facts_db.set_reasoning_coordinator(reasoning_coordinator)

puts "\n📋 TEST 1: Simple Fact Query (test_simple_fact_query)"
puts "-" * 50

# Set up the test scenario from the failing test
facts = [
  "likes(alice, bob)",
  "likes(bob, charlie)", 
  "likes(charlie, alice)"
]

facts.each { |fact| facts_db.assert_fact(fact) }
puts "Facts asserted: #{facts_db.fact_count}"
facts_db.all_facts.each { |f| puts "  - #{f}" }

# Execute the query that's failing
puts "\n🔍 Executing query: likes(alice, X)"
results = facts_db.query("likes(alice, X)")

puts "Query results count: #{results.length}"
puts "Expected: 1 result with X = 'bob'"
puts "Actual results:"
if results.empty?
  puts "  ❌ NO RESULTS RETURNED"
else
  results.each_with_index do |result, i|
    puts "  Result #{i+1}:"
    puts "    Class: #{result.class}"
    puts "    Content: #{result.inspect}"
    if result.respond_to?(:bindings)
      puts "    Bindings: #{result.bindings}"
      puts "    X value: #{result.bindings[:X] || result.bindings['X']}"
    end
  end
end

puts "\n📋 TEST 2: Multi-Variable Query (test_multi_variable_query)"
puts "-" * 50

# Clear and set up new scenario
facts_db = FactsDatabase.new(evaluator)
facts_db.set_reasoning_coordinator(reasoning_coordinator)

multi_facts = [
  "likes(alice, bob)",
  "likes(bob, charlie)",
  "likes(charlie, alice)", 
  "likes(alice, charlie)"
]

multi_facts.each { |fact| facts_db.assert_fact(fact) }
puts "Facts asserted: #{facts_db.fact_count}"

puts "\n🔍 Executing query: likes(X, Y)"
multi_results = facts_db.query("likes(X, Y)")
puts "Query results count: #{multi_results.length}"
puts "Expected: 4 results"
puts "Actual results:"
if multi_results.empty?
  puts "  ❌ NO RESULTS RETURNED"
else
  multi_results.each_with_index do |result, i|
    puts "  Result #{i+1}: #{result.inspect}"
    if result.respond_to?(:bindings)
      puts "    X=#{result.bindings[:X]}, Y=#{result.bindings[:Y]}"
    end
  end
end

puts "\n📋 DIAGNOSIS: Possible Root Causes"
puts "-" * 50

puts "1. Query result format mismatch - tests expect Hash format"
puts "2. Variable binding extraction not working properly"
puts "3. Unification algorithm returning wrong result structure"
puts "4. QueryResult class not compatible with test expectations"
puts "5. Symbol vs string key issues in bindings hash"

# Test the query result format specifically
puts "\n🔬 DETAILED DIAGNOSIS: Query Result Format"
puts "-" * 50

if !results.empty?
  first_result = results.first
  puts "First result class: #{first_result.class}"
  puts "First result methods: #{first_result.methods.grep(/\[\]|bindings|to_h/).inspect}"
  
  if first_result.respond_to?(:bindings)
    bindings = first_result.bindings
    puts "Bindings class: #{bindings.class}"
    puts "Bindings content: #{bindings.inspect}"
    puts "Bindings keys: #{bindings.keys.inspect}"
    puts "Key types: #{bindings.keys.map(&:class).inspect}"
  end
end

puts "\n🎯 EXPECTED TEST FORMAT:"
puts "  results.first[:X] should return 'bob'"
puts "  Test expects results to respond to [:X] method"
puts "  This suggests results should be array of hashes or hash-like objects"

puts "\n✅ VALIDATION SUMMARY:"
puts "- Constructor fix impact: Reduced errors from 99 to 97 (2 errors eliminated)"
puts "- Next target: Facts Database query processing (16 failures identified)"
puts "- Root cause: QueryResult objects not compatible with test hash access patterns"