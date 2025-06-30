#!/usr/bin/env ruby

# Isolated Test for Event System Failures
# Purpose: Reproduce exact failing scenarios from test suite

require_relative 'src/reasoning/type_constraint_system'

def test_constraint_events_like_failing_test
  puts "=== Testing Constraint Events Like Failing Test ==="
  
  constraint_system = TypeConstraintSystem.new
  event_log = []
  
  # Subscribe exactly like the failing test
  constraint_system.on_event(:constraint_created) { |e| event_log << e }
  constraint_system.on_event(:constraint_validated) { |e| event_log << e }
  constraint_system.on_event(:constraint_failed) { |e| event_log << e }
  constraint_system.on_event(:type_refined) { |e| event_log << e }
  
  puts "1. Creating range constraint..."
  constraint = constraint_system.create_constraint(:age, :range, 0..150)
  
  puts "   Constraint: #{constraint ? 'created' : 'nil'}"
  puts "   Event log size: #{event_log.length}"
  
  if event_log.length > 0
    puts "   Events fired:"
    event_log.each_with_index do |event, i|
      event_type = event[:event_type] || event[:type]
      puts "     #{i+1}. #{event_type}: #{event[:data] || event}"
    end
  else
    puts "   ❌ NO EVENTS FIRED!"
  end
  
  # Test the assert_events_fired equivalent
  expected_events = [:constraint_created]
  actual_event_types = event_log.map { |e| e[:event_type] || e[:type] }
  
  puts "\n2. Event assertion check:"
  puts "   Expected: #{expected_events}"
  puts "   Actual: #{actual_event_types}"
  puts "   Match: #{expected_events == actual_event_types}"
  
  # Check if this is the nil issue
  if actual_event_types.include?(nil)
    puts "   ❌ FOUND NIL EVENT TYPE - This is the problem!"
    puts "   Event structure analysis:"
    event_log.each_with_index do |event, i|
      puts "     Event #{i+1} keys: #{event.keys}"
      puts "     Event #{i+1} structure: #{event.inspect}"
    end
  end
  
  return actual_event_types == expected_events
end

def test_event_data_structure
  puts "\n=== Testing Event Data Structure ==="
  
  constraint_system = TypeConstraintSystem.new
  raw_events = []
  
  # Capture raw events
  constraint_system.on_event(:constraint_created) { |raw_event| 
    raw_events << raw_event 
    puts "   Raw event received: #{raw_event.class}"
    puts "   Raw event keys: #{raw_event.keys if raw_event.respond_to?(:keys)}"
    puts "   Raw event: #{raw_event.inspect}"
  }
  
  puts "Creating constraint to capture event structure..."
  constraint_system.create_constraint(:test, :type, :Number)
  
  if raw_events.any?
    event = raw_events.first
    puts "\nEvent structure analysis:"
    puts "  Type: #{event[:type]}"
    puts "  Event Type: #{event[:event_type]}"  
    puts "  Data: #{event[:data]}"
    puts "  Has :event_type key: #{event.key?(:event_type)}"
    puts "  Has :type key: #{event.key?(:type)}"
  else
    puts "❌ NO RAW EVENTS CAPTURED"
  end
  
  return raw_events.any?
end

def test_manual_fire_event
  puts "\n=== Testing Manual Fire Event ==="
  
  constraint_system = TypeConstraintSystem.new
  manual_events = []
  
  constraint_system.on_event(:manual_test) { |e| 
    manual_events << e 
    puts "   Manual event: #{e.inspect}"
  }
  
  puts "Firing manual event..."
  constraint_system.fire_event(:manual_test, { test: "data" })
  
  puts "Manual events received: #{manual_events.length}"
  return manual_events.any?
end

# Run tests
puts "Starting Event Failure Investigation..."
puts "=" * 60

results = {
  constraint_events: test_constraint_events_like_failing_test,
  event_data_structure: test_event_data_structure,
  manual_fire_event: test_manual_fire_event
}

puts "\n" + "=" * 60
puts "INVESTIGATION RESULTS"
puts "=" * 60

results.each do |test_name, passed|
  status = passed ? "✅ PASS" : "❌ FAIL"
  puts "#{test_name.to_s.ljust(25)}: #{status}"
end

if results.values.all?
  puts "\n✅ All isolated tests passed - issue may be test-specific"
else
  puts "\n🚨 Found event system issues in isolated tests"
end