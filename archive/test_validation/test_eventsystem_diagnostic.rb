#!/usr/bin/env ruby

# Event System Integration Diagnostic Test
# Purpose: Identify specific issues with event system integration causing nil returns in tests

puts "=== Event System Integration Diagnostic ==="
puts "Time: #{Time.now}"
puts

# Load required dependencies
require_relative 'src/object_model/patlang_object'
require_relative 'src/object_model/event_system'
require_relative 'src/reasoning/type_constraint_system'

def test_basic_event_system
  puts "1. Testing Basic Event System Functionality"
  puts "-" * 50
  
  registry = EventSystem::EventRegistry.new
  events_received = []
  
  # Register handler
  handler_id = registry.register_handler(:test_event) do |event|
    events_received << event
    puts "   ✓ Event received: #{event[:type]} with data: #{event[:data]}"
  end
  
  # Fire event
  event = registry.fire_event(:test_event, { message: "test" })
  
  puts "   Event fired: #{event ? 'SUCCESS' : 'FAILED (nil returned)'}"
  puts "   Events received count: #{events_received.length}"
  puts "   Handler ID: #{handler_id}"
  
  return events_received.length > 0
end

def test_patlang_object_events
  puts "\n2. Testing PatlangObject Event Integration"
  puts "-" * 50
  
  events_received = []
  
  # Subscribe to global object creation events
  EventSystem.subscribe(:object_created) do |event|
    events_received << event
    puts "   ✓ Global object_created event: #{event[:data][:value]} (#{event[:data][:type]})"
  end
  
  # Create a PatlangObject (should fire creation event)
  obj = PatlangObject.new(42, :number)
  
  puts "   Object created: #{obj.object_id} with value #{obj.value}"
  puts "   Events received count: #{events_received.length}"
  puts "   Object fires events: #{obj.respond_to?(:fire_event) ? 'YES' : 'NO'}"
  
  # Test manual event firing
  obj.fire_event(:test_manual, { test: true })
  puts "   Manual event fired on object"
  
  return events_received.length > 0
end

def test_type_constraint_system_events
  puts "\n3. Testing TypeConstraintSystem Event Integration"
  puts "-" * 50
  
  constraint_system = TypeConstraintSystem.new
  events_received = []
  
  # Subscribe to constraint events
  constraint_system.on_event(:constraint_created) { |e| 
    events_received << e
    puts "   ✓ constraint_created event: variable=#{e[:data][:variable]}, type=#{e[:data][:constraint_type]}"
  }
  
  constraint_system.on_event(:constraint_validated) { |e| 
    events_received << e
    puts "   ✓ constraint_validated event: variable=#{e[:data][:variable]}, success=#{e[:data][:success]}"
  }
  
  puts "   TypeConstraintSystem created: #{constraint_system.class}"
  puts "   Inherits from PatlangObject: #{constraint_system.is_a?(PatlangObject) ? 'YES' : 'NO'}"
  puts "   Has fire_event method: #{constraint_system.respond_to?(:fire_event) ? 'YES' : 'NO'}"
  puts "   Has event system initialized: #{constraint_system.instance_variable_get(:@instance_event_registry) ? 'YES' : 'NO'}"
  
  # Create a constraint (should fire creation event)
  puts "   Creating constraint..."
  constraint = constraint_system.create_constraint(:x, :type, :Number)
  
  puts "   Constraint created: #{constraint ? 'SUCCESS' : 'FAILED (nil returned)'}"
  puts "   Events received count: #{events_received.length}"
  
  # Test constraint validation (should fire validation event)
  puts "   Testing constraint validation..."
  result = constraint_system.satisfies_all_constraints?(:x, 42)
  
  puts "   Validation result: #{result}"
  puts "   Total events received: #{events_received.length}"
  
  return events_received.length > 0
end

def test_event_system_initialization
  puts "\n4. Testing Event System Initialization Flow"
  puts "-" * 50
  
  # Test TypeConstraintSystem initialization step by step
  puts "   Creating TypeConstraintSystem..."
  system = TypeConstraintSystem.new
  
  puts "   Checking instance variables:"
  instance_vars = system.instance_variables
  instance_vars.each do |var|
    value = system.instance_variable_get(var)
    puts "     #{var}: #{value ? value.class : 'nil'}"
  end
  
  puts "   Event registry initialized: #{system.instance_variable_get(:@instance_event_registry) ? 'YES' : 'NO'}"
  
  # Test manual event firing
  events_fired = []
  system.on_event(:debug_test) { |e| events_fired << e }
  
  puts "   Firing manual debug event..."
  system.fire_event(:debug_test, { debug: true })
  
  puts "   Manual events fired: #{events_fired.length}"
  
  return events_fired.length > 0
end

def test_common_failing_scenarios
  puts "\n5. Testing Common Failing Scenarios"
  puts "-" * 50
  
  # Scenario 1: TypeConstraint test expectations
  puts "   Scenario 1: TypeConstraint creation with event expectations"
  
  constraint_system = TypeConstraintSystem.new
  event_log = []
  
  # Subscribe exactly like the failing tests do
  constraint_system.on_event(:constraint_created) { |e| event_log << e }
  constraint_system.on_event(:constraint_validated) { |e| event_log << e }
  constraint_system.on_event(:constraint_failed) { |e| event_log << e }
  constraint_system.on_event(:type_refined) { |e| event_log << e }
  
  # Create constraint like failing test
  constraint = constraint_system.create_constraint(:x, :type, :Number)
  
  puts "     Constraint created: #{constraint ? 'SUCCESS' : 'FAILED'}"
  puts "     Event log size: #{event_log.length}"
  puts "     Expected event types: [:constraint_created]"
  
  if event_log.length > 0
    actual_event_types = event_log.map { |e| e[:event_type] || e[:type] }
    puts "     Actual event types: #{actual_event_types}"
  else
    puts "     ❌ NO EVENTS FIRED - This is the problem!"
  end
  
  return event_log.length > 0
end

# Run all diagnostic tests
puts "Starting Event System Integration Diagnostics..."
puts "=" * 70

results = {
  basic_event_system: test_basic_event_system,
  patlang_object_events: test_patlang_object_events,
  type_constraint_system_events: test_type_constraint_system_events,
  event_system_initialization: test_event_system_initialization,
  common_failing_scenarios: test_common_failing_scenarios
}

puts "\n" + "=" * 70
puts "DIAGNOSTIC RESULTS SUMMARY"
puts "=" * 70

results.each do |test_name, passed|
  status = passed ? "✅ PASS" : "❌ FAIL"
  puts "#{test_name.to_s.ljust(30)}: #{status}"
end

failed_tests = results.select { |k, v| !v }
if failed_tests.any?
  puts "\n🚨 ISSUES DETECTED:"
  puts "Failed tests indicate event system integration problems."
  puts "Focus investigation on: #{failed_tests.keys.join(', ')}"
else
  puts "\n✅ All event system tests passed - investigate test-specific issues"
end

puts "\nDiagnostic completed at #{Time.now}"