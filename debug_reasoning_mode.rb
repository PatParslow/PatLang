#!/usr/bin/env ruby

require_relative 'src/evaluator'

puts "=== Debugging Reasoning Mode ==="

evaluator = Evaluator.new
puts "Evaluator created"

reasoning_evaluator = evaluator.reasoning_evaluator
puts "ReasoningEvaluator: #{reasoning_evaluator.class}"
puts "Initial reasoning mode in ReasoningEvaluator: #{reasoning_evaluator.reasoning_mode_enabled}"

puts "\nCalling enable_reasoning_mode on evaluator..."
evaluator.enable_reasoning_mode

puts "After enable:"
puts "  @reasoning_mode in evaluator: #{evaluator.instance_variable_get(:@reasoning_mode)}"
puts "  reasoning_mode_enabled in ReasoningEvaluator: #{reasoning_evaluator.reasoning_mode_enabled}"
puts "  evaluator.reasoning_mode_enabled?: #{evaluator.reasoning_mode_enabled?}"

puts "\nCalling enable_reasoning_mode directly on ReasoningEvaluator..."
reasoning_evaluator.enable_reasoning_mode
puts "  reasoning_mode_enabled in ReasoningEvaluator: #{reasoning_evaluator.reasoning_mode_enabled}"
puts "  evaluator.reasoning_mode_enabled?: #{evaluator.reasoning_mode_enabled?}"