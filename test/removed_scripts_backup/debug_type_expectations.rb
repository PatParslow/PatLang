#!/usr/bin/env ruby

require_relative 'test_helper'
require_relative '../patlang-core/lexer/lexer'
require_relative '../patlang-core/parser/parser'
require_relative '../patlang-core/evaluator/evaluator'
require_relative '../src/object_model/patlang_object'
require_relative '../src/object_model/number_object'
require_relative '../src/object_model/string_object'
require_relative '../src/object_model/event_system'

puts "=== DEBUGGING TYPE EXPECTATION MISMATCHES ==="

def parse_and_evaluate(code, evaluator)
  lexer = Lexer.new(code)
  tokens = lexer.tokenize
  parser = Parser.new(tokens)
  ast = parser.parse
  evaluator.evaluate(ast)
end

# Clear registry
PatlangObject.clear_registry

evaluator = Evaluator.new
evaluator.enable_object_mode

puts "\n1. Testing basic number creation:"
puts "Code: 42"
result = parse_and_evaluate("42", evaluator)
puts "Result class: #{result.class}"
puts "Result value: #{result.value}"
puts "Result object_type: #{result.object_type}" if result.respond_to?(:object_type)

puts "\n2. Testing string creation:"
puts 'Code: "hello"'
result = parse_and_evaluate('"hello"', evaluator)
puts "Result class: #{result.class}"
puts "Result value: #{result.value}"
puts "Result object_type: #{result.object_type}" if result.respond_to?(:object_type)

puts "\n3. Testing event data from object creation:"
event_data_captured = []
EventSystem.subscribe(:object_created) do |event_data|
  event_data_captured << event_data.dup
  puts "EVENT CAPTURED: #{event_data.inspect}"
end

puts "Code: 123"
result = parse_and_evaluate("123", evaluator)
puts "Result after event setup: #{result.class} - #{result.value}"

puts "\n4. Captured event data:"
event_data_captured.each_with_index do |data, i|
  puts "Event #{i+1}: type=#{data[:type]}, value=#{data[:value]}"
end

puts "\n5. Testing arithmetic with events:"
arith_events = []
EventSystem.subscribe(:arithmetic_operation) do |event_data|
  arith_events << event_data.dup
  puts "ARITHMETIC EVENT: #{event_data.inspect}"
end

puts "Code: 10 + 5"
result = parse_and_evaluate("10 + 5", evaluator)
puts "Arithmetic result: #{result.class} - #{result.value}"
puts "Arithmetic events captured: #{arith_events.length}"

puts "\n6. Testing PatlangObject.infer_type method:"
puts "infer_type(42): #{PatlangObject.infer_type(42)}"
puts "infer_type('hello'): #{PatlangObject.infer_type('hello')}"
puts "infer_type(true): #{PatlangObject.infer_type(true)}"
puts "infer_type(false): #{PatlangObject.infer_type(false)}"

puts "\n7. Testing object mode status:"
puts "Object mode enabled: #{evaluator.object_mode_enabled?}"

puts "\n=== END DEBUG ==="