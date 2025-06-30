#!/usr/bin/env ruby

# Validate Phase 2 reasoning system errors
require 'minitest/autorun'
require_relative 'test/test_helper'

puts "=== Phase 2 Reasoning System Error Validation ==="
puts "Checking for specific errors mentioned in task..."

# Test 1: Unification Engine errors around line 95
puts "\n1. Checking Unification Engine (src/reasoning/unification_engine.rb)..."
begin
  require_relative 'src/reasoning/unification_engine'
  puts "   ✓ Unification Engine loads successfully"
rescue => e
  puts "   ✗ Unification Engine error: #{e.message}"
  puts "   Error location: #{e.backtrace.first}"
end

# Test 2: Type Constraint Parser (check which file actually exists)
puts "\n2. Checking Type Constraint files..."
type_constraint_files = [
  'src/reasoning/type_constraint_parser.rb',
  'src/reasoning/type_constraint_system.rb',
  'src/reasoning/type_constraint.rb'
]

type_constraint_files.each do |file|
  if File.exist?(file)
    puts "   Found: #{file}"
    begin
      require_relative file
      puts "   ✓ #{file} loads successfully"
    rescue => e
      puts "   ✗ #{file} error: #{e.message}"
      puts "   Error location: #{e.backtrace.first}"
    end
  else
    puts "   ✗ Not found: #{file}"
  end
end

# Test 3: Reasoning Coordinator
puts "\n3. Checking Reasoning Coordinator (src/reasoning/reasoning_coordinator.rb)..."
begin
  require_relative 'src/reasoning/reasoning_coordinator'
  puts "   ✓ Reasoning Coordinator loads successfully"
rescue => e
  puts "   ✗ Reasoning Coordinator error: #{e.message}"
  puts "   Error location: #{e.backtrace.first}"
end

puts "\n=== Running targeted tests to find actual errors ==="

# Try to run tests that would trigger these components
begin
  # Simple test to trigger reasoning components
  puts "\n4. Testing basic unification..."
  require_relative 'src/reasoning/unification_engine'
  ue = UnificationEngine.new
  result = ue.unify("X", "test", {})
  puts "   ✓ Basic unification works: #{result}"
rescue => e
  puts "   ✗ Unification test error: #{e.message}"
  puts "   Error location: #{e.backtrace.first}"
end

puts "\n=== Phase 2 Error Validation Complete ==="