#!/usr/bin/env ruby

# PHASE 1: Critical Infrastructure Fix - Constructor Arguments
# Fix all reasoning component constructors to receive required evaluator arguments

require_relative 'src/reasoning/goal_system'
require_relative 'src/reasoning/facts_database'

puts "🔧 CHECKING CONSTRUCTOR REQUIREMENTS"
puts "=" * 40

# Check GoalSystem constructor
begin
  puts "Checking GoalSystem constructor..."
  File.open('src/reasoning/goal_system.rb', 'r') do |file|
    content = file.read
    if content.include?('def initialize(evaluator)')
      puts "✅ GoalSystem already requires evaluator"
    else
      puts "❌ GoalSystem needs evaluator parameter"
    end
  end
rescue => e
  puts "❌ Error checking GoalSystem: #{e.message}"
end

# Check FactsDatabase constructor
begin
  puts "Checking FactsDatabase constructor..."
  File.open('src/reasoning/facts_database.rb', 'r') do |file|
    content = file.read
    if content.include?('def initialize(evaluator)')
      puts "✅ FactsDatabase already requires evaluator"
    elsif content.include?('def initialize')
      puts "❌ FactsDatabase has different constructor signature"
    else
      puts "❌ FactsDatabase needs evaluator parameter"
    end
  end
rescue => e
  puts "❌ Error checking FactsDatabase: #{e.message}"
end

puts "\n🎯 STRATEGY:"
puts "Fix all reasoning component constructors to match expected pattern"