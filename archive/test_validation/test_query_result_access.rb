#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'src/evaluator'
require_relative 'src/reasoning/facts_database'
require_relative 'src/reasoning/reasoning_coordinator'

puts "🧪 TESTING QUERY RESULT ACCESS WITH SYMBOL KEYS"
puts "=" * 50

# Initialize the facts database system
evaluator = Evaluator.new
evaluator.enable_object_mode
facts_db = FactsDatabase.new(evaluator)
reasoning_coordinator = ReasoningCoordinator.new(evaluator)
facts_db.set_reasoning_coordinator(reasoning_coordinator)

# Add test facts
facts_db.assert_fact("likes(alice, bob)")

# Query and test symbol access
results = facts_db.query("likes(alice, X)")
first_result = results.first

puts "Result class: #{first_result.class}"
puts "Bindings: #{first_result.bindings.inspect}"

# Test different access methods
puts "\nTesting access methods:"
puts "result[:X] = #{first_result[:X].inspect}"
puts "result['X'] = #{first_result['X'].inspect}"  
puts "result.bindings[:X] = #{first_result.bindings[:X].inspect}"
puts "result.bindings['X'] = #{first_result.bindings['X'].inspect}"

# Test if symbol access works
symbol_access_works = first_result[:X] == "bob"
string_access_works = first_result["X"] == "bob"

puts "\n✅ VALIDATION RESULTS:"
puts "Symbol access (:X) works: #{symbol_access_works}"
puts "String access ('X') works: #{string_access_works}"
puts "Both should be true for test compatibility"

if symbol_access_works && string_access_works
  puts "\n🎉 SUCCESS: QueryResult now supports both symbol and string key access!"
else
  puts "\n❌ ISSUE: Key access not working as expected"
end