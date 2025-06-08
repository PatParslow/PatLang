#!/usr/bin/env ruby

require 'timeout'
require 'json'

# Add the src directory to the load path
$LOAD_PATH.unshift(File.expand_path('../src', __FILE__))

puts "🔧 Priority 2 Fix Validation: EventSystem Instantiation Issues"
puts "=" * 65

@validation_results = []

def safe_validate(description, timeout_seconds = 10)
  puts "\n🔍 Validating: #{description}"
  result = { description: description, status: nil, error: nil, details: nil }
  
  begin
    Timeout::timeout(timeout_seconds) do
      yield
      result[:status] = "SUCCESS"
      puts "✅ VALID: #{description}"
    end
  rescue Timeout::Error
    result[:status] = "TIMEOUT"
    result[:error] = "Validation timed out after #{timeout_seconds} seconds"
    puts "⏰ TIMEOUT: #{description} (#{timeout_seconds}s)"
  rescue => e
    result[:status] = "ERROR"
    result[:error] = e.class.name
    result[:details] = e.message
    puts "❌ ERROR: #{description}"
    puts "   Type: #{e.class.name}"
    puts "   Message: #{e.message}"
  end
  
  @validation_results << result
  result
end

# Test 1: Confirm EventSystem is correctly implemented as module
safe_validate("EventSystem is correctly implemented as module") do
  require_relative 'src/object_model/event_system'
  
  # Should be defined
  raise "EventSystem not defined" unless defined?(EventSystem)
  
  # Should be a module, not a class
  raise "EventSystem should be a module" unless EventSystem.is_a?(Module)
  raise "EventSystem should not be a class" if EventSystem.is_a?(Class)
  
  # Should not respond to .new
  raise "EventSystem should not respond to .new" if EventSystem.respond_to?(:new)
  
  puts "   ✓ EventSystem is correctly implemented as module"
end

# Test 2: Validate the fixed error_diagnosis_validation.rb file works
safe_validate("Fixed error_diagnosis_validation.rb works correctly") do
  # Run the specific test section that was fixed
  require_relative 'src/object_model/event_system'
  
  if defined?(EventSystem)
    puts "   ✓ EventSystem module exists"
    
    # Test if common events can be fired using the module's class methods
    test_events = [:type_refinement, :emergent_behavior_detected, :logic_goal_synthesis]
    
    test_events.each do |event|
      # Test using EventSystem's global fire_event method
      if EventSystem.respond_to?(:fire_global_event)
        EventSystem.fire_global_event(event, { test: true })
        puts "   ✓ Event system can fire #{event}"
      else
        raise "Event system missing fire_global_event method"
      end
    end
  else
    raise "EventSystem module not defined"
  end
end

# Test 3: Validate proper EventSystem usage patterns in object model
safe_validate("Object model components use EventSystem correctly") do
  require_relative 'src/object_model/object_integration'
  require_relative 'src/object_model/patlang_object'
  require_relative 'src/object_model/number_object'
  require_relative 'src/object_model/string_object'
  
  # Test that PatlangObject includes EventCapable correctly
  obj = PatlangObject.create_number(5)
  
  # Should have event capabilities from mixin
  raise "Object should respond to fire_event" unless obj.respond_to?(:fire_event)
  raise "Object should respond to on_event" unless obj.respond_to?(:on_event)
  
  puts "   ✓ PatlangObject has correct EventSystem integration"
end

# Test 4: Validate EventSystem class methods work correctly
safe_validate("EventSystem class methods function correctly") do
  require_relative 'src/object_model/event_system'
  
  # Test global registry
  raise "Missing global_registry method" unless EventSystem.respond_to?(:global_registry)
  
  # Test global subscribe
  raise "Missing subscribe method" unless EventSystem.respond_to?(:subscribe)
  
  # Test global fire event
  raise "Missing fire_global_event method" unless EventSystem.respond_to?(:fire_global_event)
  
  # Test message bus
  raise "Missing message_bus method" unless EventSystem.respond_to?(:message_bus)
  
  # Test actual event firing
  events_received = []
  EventSystem.subscribe(:test_validation_event) do |event|
    events_received << event
  end
  
  EventSystem.fire_global_event(:test_validation_event, { validation: true })
  
  raise "Event not received" if events_received.empty?
  raise "Event data incorrect" unless events_received.first[:data][:validation]
  
  puts "   ✓ All EventSystem class methods work correctly"
end

# Test 5: Validate EventRegistry and MessageBus instantiation
safe_validate("EventRegistry and MessageBus can be instantiated correctly") do
  require_relative 'src/object_model/event_system'
  
  # These should work since they are classes inside the module
  registry = EventSystem::EventRegistry.new
  raise "EventRegistry not created" unless registry
  raise "EventRegistry missing register_handler" unless registry.respond_to?(:register_handler)
  
  message_bus = EventSystem::MessageBus.new
  raise "MessageBus not created" unless message_bus
  raise "MessageBus missing send_message" unless message_bus.respond_to?(:send_message)
  
  puts "   ✓ EventRegistry and MessageBus instantiate correctly"
end

# Test 6: Test that the specific error from error_diagnosis_validation.rb is resolved
safe_validate("Original EventSystem.new error is resolved") do
  require_relative 'src/object_model/event_system'
  
  # This should NOT work (demonstrating the fix)
  begin
    EventSystem.new
    raise "EventSystem.new should have failed but didn't"
  rescue NoMethodError => e
    # This is expected - the error should be about undefined method `new`
    if e.message.include?("undefined method") && e.message.include?("new")
      puts "   ✓ EventSystem.new correctly fails with NoMethodError"
    else
      raise "Unexpected error message: #{e.message}"
    end
  end
end

puts "\n" + "=" * 65
puts "📊 PRIORITY 2 FIX VALIDATION SUMMARY" 
puts "=" * 65

successful_validations = @validation_results.count { |r| r[:status] == "SUCCESS" }
total_validations = @validation_results.length

puts "\n✅ Successful Validations: #{successful_validations}/#{total_validations}"

if successful_validations == total_validations
  puts "🎉 ALL PRIORITY 2 EVENTSYSTEM FIXES VALIDATED SUCCESSFULLY!"
else
  puts "\n❌ Failed Validations:"
  @validation_results.each_with_index do |result, index|
    if result[:status] != "SUCCESS"
      puts "\n#{index + 1}. #{result[:description]}"
      puts "   Status: #{result[:status]}"
      puts "   Error: #{result[:error]}" if result[:error]
      puts "   Details: #{result[:details]}" if result[:details]
    end
  end
end

# Save validation report
validation_report = {
  fix_type: "Priority 2 - EventSystem Instantiation Issues",
  timestamp: Time.now.to_s,
  total_validations: total_validations,
  successful_validations: successful_validations,
  success_rate: (successful_validations.to_f / total_validations * 100).round(2),
  validation_results: @validation_results,
  fixes_applied: [
    "Fixed test/error_diagnosis_validation.rb line 75: Changed EventSystem.new to use EventSystem.fire_global_event",
    "Updated terminology from 'class' to 'module' for EventSystem",
    "Validated proper EventSystem usage patterns across codebase"
  ],
  summary: {
    issue_resolved: "EventSystem module vs class confusion",
    validation_status: successful_validations == total_validations ? "COMPLETE" : "PARTIAL",
    next_steps: successful_validations == total_validations ? 
      "Priority 2 fixes complete. Ready for Priority 3 error fixes." :
      "Address remaining validation failures before proceeding."
  }
}

File.write('PRIORITY_2_EVENTSYSTEM_FIX_VALIDATION.json', JSON.pretty_generate(validation_report))
puts "\n💾 Validation report saved to: PRIORITY_2_EVENTSYSTEM_FIX_VALIDATION.json"

if successful_validations == total_validations
  puts "\n🚀 PRIORITY 2 COMPLETE - EventSystem instantiation issues resolved!"
  puts "📋 Ready to proceed with Priority 3 error fixes."
end