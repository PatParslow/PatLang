#!/usr/bin/env ruby
# Debug the specific failing test to see what's happening

require 'minitest/autorun'

# Force reload of all modules to ensure we get the latest code
Object.send(:remove_const, :ReasoningCoordinator) rescue nil
Object.send(:remove_const, :TypeConstraint) rescue nil
Object.send(:remove_const, :NullTypeConstraint) rescue nil
Object.send(:remove_const, :TypeConstraintSystem) rescue nil

require_relative 'test/helpers/test_helper'
require_relative 'src/evaluator'
require_relative 'src/parser'
require_relative 'src/lexer'

puts "=== Debugging test_logic_enhanced_type_checking ==="

class DebugTestReasoningIntegration < Minitest::Test
  def setup
    @evaluator = Evaluator.new
    @evaluator.enable_object_mode
    @reasoning_coordinator = ReasoningCoordinator.new(@evaluator)
    @evaluator.set_reasoning_coordinator(@reasoning_coordinator)
    @event_log = []
    
    # Subscribe to reasoning events
    @reasoning_coordinator.on_event(:reasoning_mode_enabled) { |e| @event_log << e }
    @reasoning_coordinator.on_event(:constraint_declared) { |e| @event_log << e }
    @reasoning_coordinator.on_event(:goal_created) { |e| @event_log << e }
    @reasoning_coordinator.on_event(:inference_completed) { |e| @event_log << e }
  end

  def evaluate_patlang_code(code)
    puts "Evaluating code: #{code.inspect}"
    begin
      parser = Parser.new(code)
      ast = parser.parse
      result = @evaluator.evaluate(ast)
      puts "Evaluation result: #{result.inspect}"
      result
    rescue => e
      puts "Error evaluating: #{e.message}"
      raise RuntimeError, "Error evaluating: #{code.inspect}\nOriginal: #{e.message}"
    end
  end

  def enable_reasoning_mode
    puts "Enabling reasoning mode..."
    @reasoning_coordinator.enable_reasoning_mode
  end

  def test_logic_enhanced_type_checking_debug
    enable_reasoning_mode
    code = <<~PATLANG
      assert fact(typeof(x, number))
      assert fact(range(number, 1, 100))
      assert fact(property(x, positive))
      
      constrain x :: infer_from_facts
    PATLANG
    
    puts "About to evaluate code..."
    result = evaluate_patlang_code(code)
    
    puts "Checking result type..."
    puts "Result: #{result.inspect}"
    puts "Result class: #{result.class}"
    
    puts "About to call get_constraint..."
    constraint = @reasoning_coordinator.get_constraint(:x)
    puts "get_constraint returned: #{constraint.inspect}"
    puts "Constraint class: #{constraint.class}"
    puts "Constraint nil?: #{constraint.nil?}"
    
    if constraint.nil?
      puts "ERROR: Constraint is still nil!"
      puts "Methods available on @reasoning_coordinator: #{@reasoning_coordinator.methods.grep(/constraint/)}"
      puts "Checking constraint_system: #{@reasoning_coordinator.constraint_system.inspect}"
    else
      puts "About to call satisfies? methods..."
      result1 = constraint.satisfies?(50)
      result2 = constraint.satisfies?(-5)
      result3 = constraint.satisfies?("string")
      
      puts "constraint.satisfies?(50): #{result1}"
      puts "constraint.satisfies?(-5): #{result2}"
      puts "constraint.satisfies?('string'): #{result3}"
    end
  end
end

# Run the test
debug_test = DebugTestReasoningIntegration.new(:test_logic_enhanced_type_checking_debug)
debug_test.setup
debug_test.test_logic_enhanced_type_checking_debug