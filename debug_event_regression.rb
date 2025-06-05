#!/usr/bin/env ruby

require_relative 'src/patlang'
require_relative 'src/object_model/event_system'
require_relative 'src/object_model/patlang_object'

puts "=== Event Handler Regression Analysis ==="
puts

# Test what test_object_evaluation.rb expects
puts "1. Testing test_object_evaluation.rb pattern:"
events_received = []

EventSystem.subscribe(:object_created) do |received|
  puts "  Handler received: #{received.inspect}"
  puts "  Type: #{received.class}"
  puts "  Keys: #{received.keys if received.is_a?(Hash)}"
  puts "  Direct access [:type]: #{received[:type] rescue 'FAILED'}"
  puts "  Direct access [:value]: #{received[:value] rescue 'FAILED'}" 
  puts "  Nested access [:data][:type]: #{received[:data][:type] rescue 'FAILED'}"
  puts "  Nested access [:data][:value]: #{received[:data][:value] rescue 'FAILED'}"
  events_received << received
end

# Create an object to trigger the event
puts "  Creating PatlangObject..."
obj = PatlangObject.create_number(42)
puts

puts "2. Events received: #{events_received.length}"
if events_received.length > 0
  event = events_received.first
  puts "  test_object_evaluation.rb expects event_data[:type] = #{event[:type]}"
  puts "  test_object_evaluation.rb expects event_data[:value] = #{event[:value]}"
  puts "  But event structure is: #{event.keys}"
  puts
end

puts "=== DIAGNOSIS ==="
puts "The tests in test_object_evaluation.rb expect handlers to receive"
puts "the event DATA directly, not the full event object."
puts
puts "POSSIBLE SOLUTIONS:"
puts "1. Revert event system to pass just event[:data] to handlers"
puts "2. Update test_object_evaluation.rb to use event[:data][:key] pattern"
puts "3. Use a hybrid approach based on event type"