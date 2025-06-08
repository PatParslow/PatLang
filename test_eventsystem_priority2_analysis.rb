#!/usr/bin/env ruby

require 'timeout'
require 'json'

# Add the src directory to the load path
$LOAD_PATH.unshift(File.expand_path('../src', __FILE__))

puts "🔍 Priority 2 Analysis: EventSystem Instantiation Issues"
puts "=" * 60

errors_found = []
eventsystem_errors = []

def safe_execute(description, timeout_seconds = 10)
  puts "\n📋 Testing: #{description}"
  result = { description: description, status: nil, error: nil, details: nil }
  
  begin
    Timeout::timeout(timeout_seconds) do
      yield
      result[:status] = "SUCCESS"
      puts "✅ SUCCESS: #{description}"
    end
  rescue Timeout::Error
    result[:status] = "TIMEOUT"
    result[:error] = "Operation timed out after #{timeout_seconds} seconds"
    puts "⏰ TIMEOUT: #{description} (#{timeout_seconds}s)"
  rescue => e
    result[:status] = "ERROR"
    result[:error] = e.class.name
    result[:details] = e.message
    puts "❌ ERROR: #{description}"
    puts "   Type: #{e.class.name}"
    puts "   Message: #{e.message}"
    
    # Check if this is EventSystem related
    if e.message.downcase.include?('eventsystem') || 
       e.class.name.include?('EventSystem') ||
       e.message.include?('event_system') ||
       e.backtrace&.any? { |line| line.include?('event_system') }
      eventsystem_errors << result.dup
      puts "🎯 EVENTSYSTEM ERROR DETECTED!"
    end
  end
  
  errors_found << result if result[:status] != "SUCCESS"
  result
end

# Test 1: Direct EventSystem file loading
safe_execute("Loading EventSystem file directly") do
  require_relative 'src/object_model/event_system'
end

# Test 2: Try to reference EventSystem class/module
safe_execute("Accessing EventSystem constant") do
  require_relative 'src/object_model/event_system'
  EventSystem # Try to access the constant
end

# Test 3: Try EventSystem instantiation
safe_execute("EventSystem instantiation attempt") do
  require_relative 'src/object_model/event_system'
  if defined?(EventSystem)
    if EventSystem.respond_to?(:new)
      EventSystem.new
    else
      puts "EventSystem doesn't respond to :new (likely a module)"
    end
  else
    puts "EventSystem not defined"
  end
end

# Test 4: Check ObjectModel integration
safe_execute("Object model integration with EventSystem") do
  require_relative 'src/object_model/object_integration'
end

# Test 5: Check if EventSystem is used in other components
safe_execute("Load main patlang system") do
  require_relative 'src/patlang'
end

# Test 6: Check evaluator integration
safe_execute("Check evaluator EventSystem usage") do
  require_relative 'src/evaluator'
  evaluator = Evaluator.new
  # Try to access event system if it exists
  if evaluator.respond_to?(:event_system)
    evaluator.event_system
  end
end

puts "\n" + "=" * 60
puts "📊 PRIORITY 2 ANALYSIS SUMMARY"
puts "=" * 60

puts "\n🎯 EventSystem-Specific Errors Found: #{eventsystem_errors.length}"
eventsystem_errors.each_with_index do |error, index|
  puts "\n#{index + 1}. #{error[:description]}"
  puts "   Status: #{error[:status]}"
  puts "   Error: #{error[:error]}" if error[:error]
  puts "   Details: #{error[:details]}" if error[:details]
end

puts "\n📈 Total Errors Found: #{errors_found.length}"
puts "🔍 EventSystem Errors: #{eventsystem_errors.length}"

# Save detailed analysis
analysis_report = {
  analysis_type: "Priority 2 - EventSystem Instantiation Issues",
  timestamp: Time.now.to_s,
  total_errors: errors_found.length,
  eventsystem_specific_errors: eventsystem_errors.length,
  all_errors: errors_found,
  eventsystem_errors: eventsystem_errors,
  summary: {
    focus: "EventSystem module vs class confusion and instantiation issues",
    priority: 2,
    next_steps: "Examine EventSystem implementation and fix instantiation patterns"
  }
}

File.write('PRIORITY_2_EVENTSYSTEM_ANALYSIS.json', JSON.pretty_generate(analysis_report))
puts "\n💾 Detailed analysis saved to: PRIORITY_2_EVENTSYSTEM_ANALYSIS.json"

puts "\n🎯 NEXT STEPS:"
puts "1. Examine EventSystem implementation in src/object_model/event_system.rb"
puts "2. Identify module vs class confusion patterns"  
puts "3. Fix instantiation issues in dependent components"
puts "4. Validate fixes with targeted testing"