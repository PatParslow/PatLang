#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'patlang-core/evaluator/evaluator'

# Debug script to trace facts database operations
puts "🔍 Facts Database Debug Trace"
puts "=" * 50

evaluator = Evaluator.new
evaluator.enable_reasoning_mode

# Test fact assertion and storage
puts "1. Testing fact assertion..."
result1 = evaluator.assert_fact("user(alice)")
puts "   assert_fact('user(alice)') returned: #{result1.inspect}"

result2 = evaluator.assert_fact("user(bob)")
puts "   assert_fact('user(bob)') returned: #{result2.inspect}"

result3 = evaluator.assert_fact("admin(alice)")
puts "   assert_fact('admin(alice)') returned: #{result3.inspect}"

# Check if facts database is initialized and accessible
facts_db = evaluator.instance_variable_get(:@goal_integration)&.facts_database
puts "\n2. Facts database status:"
puts "   Facts database object: #{facts_db.class if facts_db}"

if facts_db
  all_facts = facts_db.instance_variable_get(:@facts)
  puts "   Total facts stored: #{all_facts&.length || 0}"
  puts "   Facts content: #{all_facts.inspect}"
else
  puts "   ERROR: Facts database not accessible"
end

# Test direct query on facts database
puts "\n3. Testing direct query..."
if facts_db
  puts "   Querying 'user(X)' directly..."
  
  # Debug the query parsing
  parsed_query = facts_db.send(:parse_query, "user(X)")
  puts "   Parsed query: #{parsed_query.inspect}"
  
  if parsed_query && parsed_query[:goals]
    goal = parsed_query[:goals].first
    puts "   First goal: #{goal.inspect}"
    puts "   Goal predicate: #{goal&.predicate}"
    puts "   Goal arguments: #{goal&.arguments}"
  end
  
  # Test query execution
  direct_results = facts_db.query("user(X)")
  puts "   Direct query results: #{direct_results.inspect}"
  puts "   Result count: #{direct_results.length}"
end

# Test through evaluator interface
puts "\n4. Testing evaluator interface query..."
evaluator_results = evaluator.query_facts("user(X)")
puts "   Evaluator query results: #{evaluator_results.inspect}"
puts "   Result count: #{evaluator_results.length}"

# Test with a simpler fact format
puts "\n5. Testing simple fact assertion..."
simple_result = evaluator.assert_fact("test")
puts "   assert_fact('test') returned: #{simple_result.inspect}"

if facts_db
  simple_query = facts_db.query("test")
  puts "   Query 'test' results: #{simple_query.inspect}"
end

puts "\n" + "=" * 50
puts "Debug trace complete"