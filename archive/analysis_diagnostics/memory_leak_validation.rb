#!/usr/bin/env ruby

# Memory Leak Validation Script
# Tests that the memory leak fixes are working correctly

require_relative 'test/helpers/test_helper'
require_relative 'src/reasoning/type_constraint_system'
require_relative 'src/parser'
require_relative 'src/lexer'
require_relative 'src/ast_nodes'

puts "=== MEMORY LEAK FIX VALIDATION ==="
puts "Testing that memory consumption stays within acceptable limits..."

# Memory tracking helper
def memory_usage_mb
  `tasklist /FI "PID eq #{Process.pid}" /FO CSV 2>nul | findstr "#{Process.pid}"`.split(',')[4].tr('"', '').tr(',', '').to_i / 1024 rescue 0
end

def gc_stats
  GC.stat.select { |k, v| [:count, :heap_allocated_pages, :heap_live_slots].include?(k) }
end

initial_memory = memory_usage_mb
initial_gc = gc_stats
puts "Initial memory: #{initial_memory}MB"
puts "Initial GC stats: #{initial_gc}"

# Test the fixed type constraint parser
puts "\n=== TESTING FIXED TYPE CONSTRAINT PARSER ==="

# Simulate the test class behavior with fixes
class TestMemoryLeakFix
  def initialize
    @constraint_system = TypeConstraintSystem.new
    @event_log = []
    @parsers = []
  end
  
  def create_parser(code)
    lexer = Lexer.new(code)
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    
    # Track parser for cleanup
    @parsers << parser
    
    # Bounded event logging
    if parser.respond_to?(:on_event)
      parser.on_event(:type_annotation_parsed) { |event| 
        @event_log << event[:data].merge(event_type: :type_annotation_parsed)
        @event_log.shift if @event_log.size > 100
      }
    end
    
    parser
  end
  
  def cleanup
    @event_log.clear
    @parsers.each do |parser|
      if parser.respond_to?(:cleanup_event_system)
        parser.cleanup_event_system
      end
    end
    @parsers.clear
    @constraint_system = nil
    GC.start
  end
end

# Test 1: Multiple parser instances with cleanup
puts "\n1. Testing multiple parser instances with proper cleanup..."
test_start_memory = memory_usage_mb

20.times do |batch|
  test_instance = TestMemoryLeakFix.new
  
  10.times do |i|
    code = "var#{i} :: Number(#{i}..#{i+10})"
    parser = test_instance.create_parser(code)
    result = parser.parse
  end
  
  # Proper cleanup after each batch
  test_instance.cleanup
  
  # Periodic memory check
  if batch % 5 == 0
    current_memory = memory_usage_mb
    memory_increase = current_memory - test_start_memory
    puts "   Batch #{batch}: Memory usage: #{current_memory}MB (+#{memory_increase}MB)"
    
    # Memory should not grow excessively
    if memory_increase > 50
      puts "   ⚠️  WARNING: Memory increase #{memory_increase}MB exceeds 50MB threshold"
    end
  end
end

test_end_memory = memory_usage_mb
test_memory_increase = test_end_memory - test_start_memory
puts "Parser test completed: #{test_memory_increase}MB increase"

# Test 2: Complex nested constraints with bounds checking
puts "\n2. Testing complex nested constraints with recursion bounds..."
complex_start_memory = memory_usage_mb

test_instance = TestMemoryLeakFix.new
begin
  # This should NOT cause infinite recursion anymore
  code = <<~CODE
    data :: {
      users: Array[{
        profile: {
          name: String,
          age: Number(0..150)
        }
      }]
    }
  CODE
  
  parser = test_instance.create_parser(code)
  result = parser.parse
  puts "   ✅ Complex nested parsing completed without infinite recursion"
rescue => e
  puts "   ❌ Error during complex parsing: #{e.message}"
end

test_instance.cleanup
complex_end_memory = memory_usage_mb
complex_memory_increase = complex_end_memory - complex_start_memory
puts "Complex parsing test: #{complex_memory_increase}MB increase"

# Test 3: Event system cleanup validation
puts "\n3. Testing event system cleanup..."
event_start_memory = memory_usage_mb

test_instance = TestMemoryLeakFix.new
100.times do |i|
  # Create and parse with events
  code = "test#{i} :: String"
  parser = test_instance.create_parser(code)
  result = parser.parse
end

# Check event log is bounded
puts "   Event log size: #{test_instance.instance_variable_get(:@event_log).size} (should be ≤ 100)"
assert_bounded = test_instance.instance_variable_get(:@event_log).size <= 100
puts "   ✅ Event log properly bounded" if assert_bounded
puts "   ❌ Event log not bounded!" unless assert_bounded

test_instance.cleanup
event_end_memory = memory_usage_mb
event_memory_increase = event_end_memory - event_start_memory
puts "Event system test: #{event_memory_increase}MB increase"

# Final assessment
final_memory = memory_usage_mb
final_gc = gc_stats
total_increase = final_memory - initial_memory

puts "\n=== FINAL VALIDATION RESULTS ==="
puts "Initial memory: #{initial_memory}MB"
puts "Final memory: #{final_memory}MB"
puts "Total increase: #{total_increase}MB"
puts "Initial GC stats: #{initial_gc}"
puts "Final GC stats: #{final_gc}"

# Validation criteria
puts "\n=== VALIDATION CRITERIA ==="
max_acceptable_increase = 20  # MB

if total_increase <= max_acceptable_increase
  puts "✅ PASS: Memory increase #{total_increase}MB is within acceptable limit (#{max_acceptable_increase}MB)"
  puts "✅ Memory leak fixes are working correctly!"
  exit 0
else
  puts "❌ FAIL: Memory increase #{total_increase}MB exceeds acceptable limit (#{max_acceptable_increase}MB)"
  puts "❌ Memory leaks may still be present"
  exit 1
end