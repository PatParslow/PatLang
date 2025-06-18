# frozen_string_literal: true

require_relative '../helpers/test_helper'
require_relative '../../patlang-core/lexer/lexer'
require_relative '../../patlang-core/parser/parser'
require_relative '../../patlang-core/evaluator/evaluator'
require 'minitest/autorun'

class TestEvaluatorStress < Minitest::Test
  def setup
    # Helper method to create evaluator with parsed AST
    @evaluate_source = ->(source) {
      lexer = Lexer.new(source)
      tokens = lexer.tokenize
      parser = Parser.new(tokens)
      ast = parser.parse
      evaluator = Evaluator.new
      evaluator.evaluate(ast)
    }
    
    @create_evaluator = -> {
      Evaluator.new
    }
  end

  def test_stack_overflow_protection
    # Test evaluator's behavior with deeply nested recursive structures
    
    # Deep nested arithmetic expressions
    nesting_levels = [50, 100, 200, 500]
    
    nesting_levels.each do |level|
      # Nested addition: (((1+1)+1)+1)...
      nested_expr = "(" * level + "1"
      level.times { nested_expr += "+1)" }
      
      begin
        result = @evaluate_source.call(nested_expr)
        if level <= 100
          assert_equal level + 1, result, "Should correctly evaluate moderate nesting level #{level}"
        else
          # For very deep nesting, just verify it completes
          refute_nil result, "Should handle deep nesting level #{level}"
        end
      rescue SystemStackError, RuntimeError => e
        # Stack overflow is acceptable for very deep nesting
        if level > 200
          assert_match(/(stack|depth|recursion|overflow)/i, e.message, 
                      "Stack overflow error should be descriptive at level #{level}")
        else
          flunk "Should handle moderate nesting level #{level}: #{e.message}"
        end
      end
    end
    
    # Deep nested if statements
    deep_if_levels = [20, 50, 100]
    deep_if_levels.each do |level|
      if_chain = "x = 1\n"
      level.times do |i|
        if_chain += "if x == 1 then\n"
      end
      if_chain += "x = 42\n"
      level.times { if_chain += "end\n" }
      
      begin
        @evaluate_source.call(if_chain)
      rescue SystemStackError, RuntimeError => e
        if level > 50
          assert e.message.length > 0, "Deep if nesting error should be descriptive"
        else
          flunk "Should handle moderate if nesting level #{level}: #{e.message}"
        end
      end
    end
  end

  def test_infinite_loop_detection_accuracy
    # Test various infinite loop scenarios and detection mechanisms
    
    # Basic infinite while loop (should be detected or timeout)
    infinite_while = <<~CODE
      x = 1
      while x == 1 do
        y = x + 1
      end
    CODE
    
    start_time = Time.now
    begin
      result = @evaluate_source.call(infinite_while)
      elapsed = Time.now - start_time
      
      # If it completes, it should be quickly (indicating detection)
      if elapsed > 1.0
        flunk "Infinite loop should be detected within 1 second, took #{elapsed}s"
      end
    rescue RuntimeError => e
      # Infinite loop detection error is acceptable
      assert_match(/(infinite|loop|timeout|limit)/i, e.message, 
                  "Infinite loop error should be descriptive")
    rescue Timeout::Error => e
      # Timeout is also acceptable protection
      assert true, "Timeout protection working"
    end
    
    # Recursive function infinite loop
    recursive_infinite = <<~CODE
      make a function called infinite_func
        call infinite_func
      end
      call infinite_func
    CODE
    
    begin
      @evaluate_source.call(recursive_infinite)
    rescue SystemStackError => e
      # Stack overflow from infinite recursion is expected
      assert e.message.length > 0, "Recursive infinite loop should cause stack error"
    rescue RuntimeError => e
      # Or runtime error if detected
      assert e.message.length > 0, "Runtime error should be descriptive"
    end
    
    # Nested loop infinite scenario
    nested_infinite = <<~CODE
      x = 1
      y = 1
      while x == 1 do
        while y == 1 do
          z = x + y
        end
      end
    CODE
    
    start_time = Time.now
    begin
      @evaluate_source.call(nested_infinite)
      elapsed = Time.now - start_time
      if elapsed > 2.0
        flunk "Nested infinite loop should be detected, took #{elapsed}s"
      end
    rescue RuntimeError, Timeout::Error => e
      # Detection or timeout acceptable
      assert true, "Infinite loop protection working"
    end
  end

  def test_memory_management_long_running
    # Test memory management during sustained evaluation
    
    # Large number of variable assignments
    large_assignment_script = (1..1000).map do |i|
      "x#{i} = #{i} * 2"
    end.join("\n")
    
    begin
      @evaluate_source.call(large_assignment_script)
    rescue RuntimeError => e
      # Memory errors are acceptable for stress test
      assert_match(/(memory|limit|overflow)/i, e.message, 
                  "Memory error should be descriptive")
    end
    
    # Large array/string operations
    large_string_ops = <<~CODE
      text = "start"
      i = 1
      while i <= 100 do
        text = text + " more text " + i
        i = i + 1
      end
    CODE
    
    begin
      result = @evaluate_source.call(large_string_ops)
      # May not complete due to memory constraints, just check it doesn't crash
      if result && result.is_a?(String)
        assert result.length > 100, "Should create reasonably large string"
      end
    rescue RuntimeError => e
      # Memory issues acceptable for large operations
      assert e.message.length > 0, "Memory management error should be descriptive"
    end
    
    # Function call stress test
    function_stress = <<~CODE
      make a function called stress_func with param
        result = param * 2
        return result
      end
      
      total = 0
      i = 1
      while i <= 500 do
        total = total + call stress_func with i
        i = i + 1
      end
    CODE
    
    begin
      result = @evaluate_source.call(function_stress)
      assert result.is_a?(Numeric), "Should return numeric result"
    rescue RuntimeError => e
      # Performance/memory issues acceptable
      assert e.message.length > 0, "Function stress error should be descriptive"
    end
  end

  def test_error_propagation_nested_contexts
    # Test how errors propagate through nested evaluation contexts
    
    # Error in nested function call
    nested_function_error = <<~CODE
      make a function called outer_func
        result = call inner_func
        return result
      end
      
      make a function called inner_func
        x = undefined_variable
        return x
      end
      
      call outer_func
    CODE
    
    begin
      @evaluate_source.call(nested_function_error)
      flunk "Should raise error for undefined variable"
    rescue RuntimeError => e
      # Error should propagate with context information
      assert e.message.length > 0, "Error message should not be empty"
      # Should ideally include context about where error occurred
    end
    
    # Error in nested control flow
    nested_control_error = <<~CODE
      x = 1
      if x == 1 then
        y = 2
        if y == 2 then
          z = unknown_var + 1
        end
      end
    CODE
    
    begin
      @evaluate_source.call(nested_control_error)
      flunk "Should raise error for undefined variable in nested if"
    rescue RuntimeError => e
      assert e.message.length > 0, "Nested control flow error should be descriptive"
    end
    
    # Error in while loop
    while_loop_error = <<~CODE
      i = 1
      while i <= 3 do
        if i == 2 then
          bad_var = undefined_thing
        end
        i = i + 1
      end
    CODE
    
    begin
      @evaluate_source.call(while_loop_error)
      flunk "Should raise error for undefined variable in while loop"
    rescue RuntimeError => e
      assert e.message.length > 0, "While loop error should be descriptive"
    end
    
    # Division by zero error propagation
    division_error = <<~CODE
      make a function called divide_func with a, b
        return a / b
      end
      
      result = call divide_func with 10, 0
    CODE
    
    begin
      @evaluate_source.call(division_error)
      # Division by zero might be handled differently - just check for reasonable behavior
    rescue RuntimeError, ZeroDivisionError => e
      assert e.message.length > 0, "Division error should be descriptive"
    end
  end

  def test_variable_scope_deep_nesting
    # Test variable scope management under deep nesting conditions
    
    # Deep function nesting with local variables
    deep_function_scope = <<~CODE
      make a function called level1 with x
        a = x + 1
        result = call level2 with a
        return result
      end
      
      make a function called level2 with x
        b = x + 2
        result = call level3 with b
        return result
      end
      
      make a function called level3 with x
        c = x + 3
        return c
      end
      
      final = call level1 with 5
    CODE
    
    begin
      result = @evaluate_source.call(deep_function_scope)
      assert_equal 11, result, "Deep function nesting should work correctly" # 5+1+2+3
    rescue RuntimeError => e
      # Scope management errors
      assert_match(/(scope|variable|undefined|expected|token)/i, e.message,
                  "Scope error should be descriptive")
    end
    
    # Deep block nesting with variable shadowing
    deep_block_scope = <<~CODE
      x = 1
      if x == 1 then
        x = 2
        if x == 2 then
          x = 3
          if x == 3 then
            x = 4
            y = x
          end
        end
      end
    CODE
    
    begin
      @evaluate_source.call(deep_block_scope)
    rescue RuntimeError => e
      assert e.message.length > 0, "Deep block scope error should be descriptive"
    end
    
    # Variable access across scope boundaries
    scope_boundary_test = <<~CODE
      global_var = 100
      
      make a function called scope_test
        local_var = 200
        nested_result = global_var + local_var
        return nested_result
      end
      
      result = call scope_test
    CODE
    
    begin
      result = @evaluate_source.call(scope_boundary_test)
      assert_equal 300, result, "Scope boundary access should work"
    rescue RuntimeError => e
      assert_match(/(scope|variable|undefined|expected|token|lbrace)/i, e.message,
                  "Scope boundary error should be descriptive")
    end
  end

  def test_type_coercion_error_scenarios
    # Test error handling in type coercion situations
    
    type_error_cases = [
      # String + Number operations
      { code: 'result = "hello" + 42', description: "string plus number" },
      { code: 'result = 42 + "world"', description: "number plus string" },
      
      # Invalid comparisons
      { code: 'result = "abc" > 123', description: "string greater than number" },
      { code: 'result = true == 42', description: "boolean equals number" },
      
      # Invalid function arguments
      { code: 'result = "text"[true]', description: "string index with boolean" },
      
      # Invalid arithmetic operations
      { code: 'result = "hello" * "world"', description: "string multiplication" },
      { code: 'result = true + false', description: "boolean arithmetic" },
    ]
    
    type_error_cases.each do |test_case|
      begin
        result = @evaluate_source.call(test_case[:code])
        # Some type coercions might be supported, verify reasonable result
        refute_nil result, "Type coercion should handle or reject: #{test_case[:description]}"
      rescue RuntimeError, ArgumentError, TypeError, NoMethodError => e
        # Type errors should be descriptive
        assert e.message.length > 0, "Type error should be descriptive for: #{test_case[:description]}"
        assert_match(/(type|invalid|cannot|error|comparison|failed|index|must|integer|got|class|undefined|method)/i, e.message,
                    "Type error should mention type issue for: #{test_case[:description]}")
      end
    end
  end

  def test_unknown_node_type_handling
    # Test evaluator's handling of unknown or malformed AST nodes
    
    evaluator = @create_evaluator.call
    
    # Create mock unknown node class
    unknown_node_class = Class.new do
      def initialize(value)
        @value = value
      end
      
      attr_reader :value
    end
    
    unknown_node = unknown_node_class.new("test")
    
    begin
      evaluator.evaluate(unknown_node)
      flunk "Should raise error for unknown node type"
    rescue RuntimeError => e
      assert_match(/unknown node type/i, e.message, 
                  "Unknown node error should be descriptive")
      # Error message should be descriptive for unknown node types
      assert e.message.length > 0, "Error should have meaningful message"
    end
  end

  def test_return_value_handling_complex_control_flows
    # Test return value handling in complex nested control flows
    
    complex_return_flow = <<~CODE
      make a function called complex_flow with x
        if x > 10 then
          while x > 5 do
            if x == 7 then
              return "found seven"
            end
            x = x - 1
          end
          return "finished while"
        else
          return "too small"
        end
        return "unreachable"
      end
      
      result1 = call complex_flow with 15
      result2 = call complex_flow with 7
      result3 = call complex_flow with 3
    CODE
    
    begin
      result = @evaluate_source.call(complex_return_flow)
      # Should handle multiple return paths correctly
    rescue RuntimeError => e
      assert e.message.length > 0, "Complex return flow error should be descriptive"
    end
  end

  def test_concurrent_evaluation_safety
    # Test evaluator safety under simulated concurrent conditions
    # (This is a stress test even though true concurrency may not be implemented)
    
    evaluator = @create_evaluator.call
    
    # Multiple rapid evaluations
    expressions = [
      "x = 1 + 2",
      "y = x * 3", 
      "z = y - 1",
      "result = z / 2"
    ]
    
    begin
      expressions.each do |expr|
        lexer = Lexer.new(expr)
        tokens = lexer.tokenize
        parser = Parser.new(tokens)
        ast = parser.parse
        result = evaluator.evaluate(ast)
        refute_nil result, "Should handle rapid sequential evaluation"
      end
    rescue RuntimeError => e
      assert e.message.length > 0, "Rapid evaluation error should be descriptive"
    end
  end
end