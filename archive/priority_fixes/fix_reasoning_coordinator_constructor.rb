#!/usr/bin/env ruby

# Fix 2: ReasoningCoordinator Constructor ArgumentError
# Issue: Constructor requires evaluator parameter but tests call it without arguments

puts "🔧 FIX 2: ReasoningCoordinator Constructor"
puts "=========================================="

# Read the current file
reasoning_content = File.read('src/reasoning/reasoning_coordinator.rb')

# The issue is on line 11: def initialize(evaluator)
# Should be: def initialize(evaluator = nil)

fixed_content = reasoning_content.gsub(
  /def initialize\(evaluator\)/,
  'def initialize(evaluator = nil)'
)

# Also need to update the enable_reasoning_mode method to handle nil evaluator
fixed_content = fixed_content.gsub(
  /evaluator: @evaluator\.class\.name/,
  'evaluator: @evaluator&.class&.name || "No evaluator"'
)

# Write the fixed content
File.write('src/reasoning/reasoning_coordinator.rb', fixed_content)

puts "✅ Fixed ReasoningCoordinator constructor ArgumentError"
puts "   - Constructor now accepts optional evaluator parameter"
puts "   - Added safe navigation for nil evaluator in events"
puts "   - Maintains backwards compatibility"
puts