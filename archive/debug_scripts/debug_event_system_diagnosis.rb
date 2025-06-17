#!/usr/bin/env ruby

require_relative 'src/object_model/event_system'

puts "=== Event System Diagnosis ==="
puts

# Test 1: Event Registry Basic - what gets passed to handlers?
puts "1. Testing Event Registry Basic - Handler receives what?"
registry = EventSystem::EventRegistry.new
events_received = []

handler_id = registry.register_handler(:test_event) do |received_data|
  puts "  Handler received: #{received_data.inspect}"
  puts "  Type: #{received_data.class}"
  if received_data.is_a?(Hash)
    puts "  Keys: #{received_data.keys}"
    puts "  Has :type? #{received_data.key?(:type)}"
    puts "  Has :data? #{received_data.key?(:data)}"
  end
  events_received << received_data
end

# Fire event
puts "  Firing event with data: { data: 'test' }"
event = registry.fire_event(:test_event, { data: "test" })
puts "  Fire_event returned: #{event.inspect}"
puts

# Test what the test expects vs what it gets
puts "2. What test expects vs what it gets:"
puts "  events_received.length: #{events_received.length}"
if events_received.length > 0
  first_event = events_received.first
  puts "  events_received.first: #{first_event.inspect}"
  puts "  Test expects [:type]: #{first_event[:type] rescue 'ERROR'}"
  puts "  Test expects [:data][:data]: #{first_event[:data][:data] rescue 'ERROR'}"
end
puts

# Test 3: Compare with what event system actually creates
puts "3. What event system creates internally:"
puts "  Event created: #{event.inspect}"
puts "  Event[:type]: #{event[:type]}"
puts "  Event[:data]: #{event[:data]}"
puts

puts "=== DIAGNOSIS ==="
puts "PROBLEM: Event handlers get event[:data] but tests expect full event object"
puts "SOLUTION: Pass full event object to handlers, not just data portion"