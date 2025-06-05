#!/usr/bin/env ruby

require_relative 'test_helper'
require_relative '../src/object_model/patlang_object'

puts "=== VALIDATING TYPE DIAGNOSIS ==="

# Clear registry
PatlangObject.clear_registry

puts "\n1. Testing create_number conversion behavior:"
puts "Input: 42 (Integer)"
obj1 = PatlangObject.create_number(42)
puts "Result value: #{obj1.value} (#{obj1.value.class})"
puts "Result type: #{obj1.object_type}"

puts "\nInput: 42.0 (Float)"
obj2 = PatlangObject.create_number(42.0)
puts "Result value: #{obj2.value} (#{obj2.value.class})"
puts "Result type: #{obj2.object_type}"

puts "\n2. Testing event data during object creation:"
event_data_captured = []
EventSystem.subscribe(:object_created) do |event_data|
  event_data_captured << {
    input_type: event_data[:value].class,
    input_value: event_data[:value],
    event_type: event_data[:type]
  }
  puts "EVENT: value=#{event_data[:value]} (#{event_data[:value].class}), type=#{event_data[:type]}"
end

puts "\nCreating object with integer 123:"
obj3 = PatlangObject.create_number(123)
puts "Object value: #{obj3.value} (#{obj3.value.class})"

puts "\n3. Testing wrap method behavior:"
puts "Wrapping integer 456:"
obj4 = PatlangObject.wrap(456)
puts "Wrapped value: #{obj4.value} (#{obj4.value.class})"
puts "Wrapped type: #{obj4.object_type}"

puts "\n4. Event data summary:"
event_data_captured.each_with_index do |data, i|
  puts "Event #{i+1}: #{data[:input_value]} (#{data[:input_type]}) -> type #{data[:event_type]}"
end

puts "\n5. Testing infer_type directly (private method via send):"
test_obj = PatlangObject.new(1, :number)
puts "infer_type(42): #{test_obj.send(:infer_type, 42)}"
puts "infer_type(42.0): #{test_obj.send(:infer_type, 42.0)}"
puts "infer_type('hello'): #{test_obj.send(:infer_type, 'hello')}"

puts "\n=== DIAGNOSIS COMPLETE ==="