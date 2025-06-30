#!/usr/bin/env ruby

# Memory Leak Diagnosis Script for Type Constraint Parser Tests
# Analyzing the critical 44GB memory consumption issue

require_relative 'test/helpers/test_helper'
require_relative 'src/reasoning/type_constraint_system'
require_relative 'src/parser'
require_relative 'src/lexer'
require_relative 'src/ast_nodes'

puts "=== MEMORY LEAK DIAGNOSIS FOR TYPE CONSTRAINT PARSER ==="
puts "Starting memory analysis..."

# Track memory usage
def memory_usage
  `tasklist /FI "PID eq #{Process.pid}" /FO CSV | findstr "#{Process.pid}"`.split(',')[4].tr('"', '').tr(',', '').to_i rescue 0
end

def gc_stats
  GC.stat.select { |k, v| [:count, :heap_allocated_pages, :heap_live_slots, :heap_free_slots].include?(k) }
end

initial_memory = memory_usage
initial_gc = gc_stats
puts "Initial memory: #{initial_memory}KB"
puts "Initial GC stats: #{initial_gc}"

# Reproduce the test patterns that cause memory leaks
puts "\n=== TESTING MEMORY LEAK SOURCES ==="

# 1. Test Event System Memory Accumulation
puts "\n1. Testing Event System Memory Accumulation..."
event_test_start = memory_usage

parsers_with_events = []
100.times do |i|
  lexer = Lexer.new("x#{i} :: Number")
  tokens = lexer.tokenize
  parser = Parser.new(tokens)
  
  # Subscribe to events (this creates memory references)
  event_log = []
  if parser.respond_to?(:on_event)
    parser.on_event(:constraint_parsed) { |event| event_log << event[:data].merge(event_type: :constraint_parsed) }
    parser.on_event(:type_annotation_parsed) { |event| event_log << event[:data].merge(event_type: :type_annotation_parsed) }
    parser.on_event(:parsing_error) { |event| event_log << event[:data].merge(event_type: :parsing_error) }
  end
  
  parsers_with_events << { parser: parser, event_log: event_log }
end

event_test_end = memory_usage
puts "Event system test: #{event_test_end - event_test_start}KB increase"

# 2. Test Parser Instance Accumulation
puts "\n2. Testing Parser Instance Accumulation..."
parser_test_start = memory_usage

parsers = []
100.times do |i|
  lexer = Lexer.new("var#{i} :: Number(#{i}..#{i+100})")
  tokens = lexer.tokenize
  parser = Parser.new(tokens)
  result = parser.parse
  parsers << { parser: parser, result: result }
end

parser_test_end = memory_usage
puts "Parser accumulation test: #{parser_test_end - parser_test_start}KB increase"

# 3. Test Recursive Parsing Memory
puts "\n3. Testing Recursive Parsing Memory..."
recursive_test_start = memory_usage

50.times do |i|
  # Complex nested structural constraints
  code = <<~CODE
    data#{i} :: {
      users: Array[{
        profile: {
          personal: {
            name: String(/^[A-Za-z\\s]+$/),
            age: Number(0..150),
            email: String(/\\w+@\\w+\\.\\w+/)
          },
          preferences: {
            theme: String,
            notifications: Boolean,
            privacy: {
              public: Boolean,
              searchable: Boolean
            }
          }
        },
        activity: {
          lastLogin: String,
          loginCount: Number(0..),
          permissions: Array[String]
        }
      }],
      metadata: {
        version: String,
        created: String,
        modified: String
      }
    }
  CODE
  
  lexer = Lexer.new(code)
  tokens = lexer.tokenize
  parser = Parser.new(tokens)
  result = parser.parse
end

recursive_test_end = memory_usage
puts "Recursive parsing test: #{recursive_test_end - recursive_test_start}KB increase"

# 4. Test Event History Accumulation
puts "\n4. Testing Event History Accumulation..."
history_test_start = memory_usage

# Simulate the event history building up over time
if defined?(EventSystem)
  100.times do |i|
    EventSystem.fire_global_event(:test_event, { data: "test_#{i}" * 100 })
  end
end

history_test_end = memory_usage
puts "Event history test: #{history_test_end - history_test_start}KB increase"

# 5. Test Object Reference Cycles
puts "\n5. Testing Object Reference Cycles..."
cycle_test_start = memory_usage

constraint_systems = []
100.times do |i|
  constraint_system = TypeConstraintSystem.new
  
  # Create potential reference cycles
  10.times do |j|
    constraint_system.create_constraint("var#{j}", :range, { min: 0, max: 100 })
  end
  
  constraint_systems << constraint_system
end

cycle_test_end = memory_usage
puts "Reference cycles test: #{cycle_test_end - cycle_test_start}KB increase"

# Final memory assessment
final_memory = memory_usage
final_gc = gc_stats
total_increase = final_memory - initial_memory

puts "\n=== FINAL MEMORY ANALYSIS ==="
puts "Initial memory: #{initial_memory}KB"
puts "Final memory: #{final_memory}KB"
puts "Total increase: #{total_increase}KB"
puts "Initial GC stats: #{initial_gc}"
puts "Final GC stats: #{final_gc}"

# Force garbage collection and check again
GC.start
post_gc_memory = memory_usage
post_gc_stats = gc_stats

puts "\n=== POST-GC ANALYSIS ==="
puts "Memory after GC: #{post_gc_memory}KB"
puts "Memory freed by GC: #{final_memory - post_gc_memory}KB"
puts "Post-GC stats: #{post_gc_stats}"

# Identify the worst offenders
puts "\n=== LEAK SOURCE ANALYSIS ==="
event_leak = event_test_end - event_test_start
parser_leak = parser_test_end - parser_test_start
recursive_leak = recursive_test_end - recursive_test_start
history_leak = history_test_end - history_test_start
cycle_leak = cycle_test_end - cycle_test_start

leaks = [
  ["Event System", event_leak],
  ["Parser Accumulation", parser_leak],
  ["Recursive Parsing", recursive_leak],
  ["Event History", history_leak],
  ["Reference Cycles", cycle_leak]
]

leaks.sort_by! { |name, leak| -leak }

puts "Memory leak sources (highest to lowest):"
leaks.each_with_index do |(name, leak), index|
  puts "#{index + 1}. #{name}: #{leak}KB"
end

# Specific diagnostics for the most likely sources
puts "\n=== DETAILED DIAGNOSIS ==="

if event_leak > 1000
  puts "🚨 CRITICAL: Event system memory leak detected!"
  puts "   - Event handlers are accumulating without cleanup"
  puts "   - @event_log array growing unbounded in tests"
  puts "   - Event registries not being cleared between tests"
end

if parser_leak > 1000
  puts "🚨 CRITICAL: Parser instance memory leak detected!"
  puts "   - Parser instances holding references to large token arrays"
  puts "   - Specialized parser modules (TypeConstraintParser) not being cleaned up"
  puts "   - AST nodes forming reference cycles"
end

if recursive_leak > 1000
  puts "🚨 CRITICAL: Recursive parsing memory leak detected!"
  puts "   - Deep nested structures creating excessive object graphs"
  puts "   - Type constraint objects not being garbage collected"
  puts "   - Possible infinite recursion in constraint parsing"
end

puts "\n=== RECOMMENDATIONS ==="
puts "Based on analysis, implement these fixes:"
puts "1. Add proper cleanup in test teardown methods"
puts "2. Clear event registries between tests"
puts "3. Implement parser instance pooling or explicit cleanup"
puts "4. Add bounds checking for recursive parsing depth"
puts "5. Use weak references where appropriate in event system"

puts "\nDiagnosis complete. Check the most critical leak sources identified above."