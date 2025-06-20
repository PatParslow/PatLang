#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'patlang-core/evaluator/evaluator'

# Detailed integration debug script
puts "🔍 Goal Integration Debug Trace"
puts "=" * 50

evaluator = Evaluator.new
evaluator.enable_reasoning_mode

# Check goal integration object
goal_integration = evaluator.instance_variable_get(:@goal_integration)
puts "1. Goal Integration Object: #{goal_integration.class}"

# Trigger initialization by calling assert_fact
puts "\n2. Asserting facts and triggering initialization..."
evaluator.assert_fact("user(alice)")

# Check if integration is enabled after first fact assertion
puts "   Integration enabled: #{evaluator.goal_integration_enabled?}"

# Get the facts database from goal integration
goal_integration = evaluator.instance_variable_get(:@goal_integration)
facts_db_from_integration = goal_integration.facts_database
puts "   Facts DB from integration: #{facts_db_from_integration.object_id}"

# Check what the main evaluator has
main_evaluator_facts_db = evaluator.instance_variable_get(:@facts_database)
puts "   Facts DB from main evaluator: #{main_evaluator_facts_db&.object_id || 'nil'}"

# Check facts in integration's facts database
if facts_db_from_integration
  integration_facts = facts_db_from_integration.instance_variable_get(:@facts)
  puts "   Facts in integration DB: #{integration_facts.inspect}"
end

# Check facts in main evaluator's facts database (if it exists)
if main_evaluator_facts_db
  main_facts = main_evaluator_facts_db.instance_variable_get(:@facts)
  puts "   Facts in main evaluator DB: #{main_facts.inspect}"
end

puts "\n3. Testing queries through different paths..."

# Test direct query on integration facts database
if facts_db_from_integration
  direct_results = facts_db_from_integration.query("user(X)")
  puts "   Direct query on integration DB: #{direct_results.inspect}"
end

# Test query through goal integration
if goal_integration
  integration_results = goal_integration.query_facts("user(X)")
  puts "   Query through integration layer: #{integration_results.inspect}"
end

# Test query through evaluator
evaluator_results = evaluator.query_facts("user(X)")
puts "   Query through evaluator: #{evaluator_results.inspect}"

puts "\n4. Checking method dispatch..."
puts "   evaluator.query_facts delegates to: #{evaluator.method(:query_facts).source_location}"

puts "\n" + "=" * 50
puts "Integration debug complete"