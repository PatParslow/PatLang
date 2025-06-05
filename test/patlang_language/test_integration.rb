require 'minitest/autorun'
require_relative '../../src/lexer'
require_relative '../../src/parser'
require_relative '../../src/evaluator'

class TestIntegration < Minitest::Test
  def setup
    @evaluator = Evaluator.new
  end

  def evaluate_expression(expression)
    lexer = Lexer.new(expression)
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    @evaluator.evaluate(ast)
  end

  def test_complete_pipeline_simple_number
    result = evaluate_expression("42")
    assert_equal 42, result
  end

  def test_complete_pipeline_basic_arithmetic
    assert_equal 5, evaluate_expression("2 + 3")
    assert_equal 7, evaluate_expression("10 - 3")
    assert_equal 12, evaluate_expression("3 * 4")
    assert_equal 4, evaluate_expression("12 / 3")
  end

  def test_complete_pipeline_operator_precedence
    # Multiplication has higher precedence than addition
    assert_equal 14, evaluate_expression("2 + 3 * 4")
    assert_equal 10, evaluate_expression("5 * 2 + 0")
    assert_equal 9, evaluate_expression("10 - 2 / 2")
  end

  def test_complete_pipeline_parentheses
    # Parentheses override operator precedence
    assert_equal 20, evaluate_expression("(2 + 3) * 4")
    assert_equal 8, evaluate_expression("(10 - 6) * 2")
    assert_equal 3, evaluate_expression("15 / (2 + 3)")
  end

  def test_complete_pipeline_complex_expressions
    # More complex multi-operator expressions
    assert_equal 5, evaluate_expression("10 - 2 * 3 + 1")
    assert_equal 10, evaluate_expression("1 + 2 * 3 - 4 / 2 + 5")
    assert_equal 5, evaluate_expression("(1 + 2) * (3 - 1) - 5 / 5")
  end

  def test_complete_pipeline_nested_parentheses
    assert_equal 5, evaluate_expression("(10 + 5) / (2 + 1)")
    assert_equal 25, evaluate_expression("((2 + 3) * (4 + 1))")
    assert_equal 1.75, evaluate_expression("((10 - 5) + (3 - 1)) / 4")
  end

  def test_complete_pipeline_float_results
    assert_equal 2.5, evaluate_expression("5 / 2")
    assert_equal 1.5, evaluate_expression("3 / 2")
    assert_equal 3.5, evaluate_expression("7 / 2")
  end

  def test_error_propagation_division_by_zero
    assert_raises(StandardError) do
      evaluate_expression("10 / 0")
    end
    
    assert_raises(StandardError) do
      evaluate_expression("5 + 10 / 0")
    end
  end

  def test_error_propagation_syntax_errors
    # Test that syntax errors are properly propagated
    assert_raises(RuntimeError) do
      evaluate_expression("2 +")
    end
    
    assert_raises(RuntimeError) do
      evaluate_expression("(2 + 3")
    end
    
    assert_raises(RuntimeError) do
      evaluate_expression("2 + + 3")
    end
  end

  def test_error_propagation_empty_expression
    # Improved error handling: empty expression now evaluates to nil gracefully
    result = evaluate_expression("")
    assert_nil result
  end

  def test_whitespace_handling
    # Test that whitespace is properly handled throughout pipeline
    assert_equal 5, evaluate_expression("  2   +   3  ")
    assert_equal 14, evaluate_expression(" 2+3*4 ")
    assert_equal 20, evaluate_expression("( 2 + 3 ) * 4")
  end

  def test_decimal_literals
    # Test that decimal literals are properly handled
    assert_equal 3.14, evaluate_expression("3.14")
    assert_equal 6.0, evaluate_expression("3.14 + 2.86")
    assert_equal 10.0, evaluate_expression("2.5 * 4")
    assert_equal 3.0, evaluate_expression("7.5 / 2.5")
  end

  def test_mixed_integer_decimal
    # Test mixed integer and decimal arithmetic
    assert_equal 13.5, evaluate_expression("10 + 3.5")
    assert_equal 15.2, evaluate_expression("12.2 + 3")
    assert_equal 21.0, evaluate_expression("3.5 * 6")
  end

  # ========================================
  # Variable Integration Tests for v0.2.0
  # ========================================

  def test_variable_assignment_basic
    # Test basic variable assignment
    result = evaluate_expression("x = 42")
    assert_equal 42, result
    
    # Verify variable is stored and can be retrieved
    result = evaluate_expression("x")
    assert_equal 42, result
  end

  def test_variable_assignment_decimal
    # Test decimal variable assignment
    result = evaluate_expression("y = 3.14")
    assert_equal 3.14, result
    
    # Verify decimal variable retrieval
    result = evaluate_expression("y")
    assert_equal 3.14, result
  end

  def test_variable_workflow_complete
    # Test complete variable workflow: assignment → lookup → arithmetic
    # This tests the exact v0.2.0 roadmap examples
    
    # Step 1: x = 42
    result = evaluate_expression("x = 42")
    assert_equal 42, result
    
    # Step 2: y = 3.14
    result = evaluate_expression("y = 3.14")
    assert_equal 3.14, result
    
    # Step 3: x + y * 2 → should be 42 + (3.14 * 2) = 48.28
    result = evaluate_expression("x + y * 2")
    assert_equal 48.28, result
    
    # Step 4: result = (x + y) / 2 → should be (42 + 3.14) / 2 = 22.57
    result = evaluate_expression("result = (x + y) / 2")
    assert_equal 22.57, result
    
    # Verify result variable is stored
    result = evaluate_expression("result")
    assert_equal 22.57, result
  end

  def test_variable_reassignment
    # Test variable reassignment scenarios
    result = evaluate_expression("a = 10")
    assert_equal 10, result
    
    # Reassign with new value
    result = evaluate_expression("a = 20")
    assert_equal 20, result
    
    # Verify new value is stored
    result = evaluate_expression("a")
    assert_equal 20, result
    
    # Reassign with expression using other variables
    evaluate_expression("b = 5")
    result = evaluate_expression("a = a + b")
    assert_equal 25, result
  end

  def test_variable_arithmetic_combinations
    # Test complex expressions mixing variables and arithmetic
    evaluate_expression("num1 = 15")
    evaluate_expression("num2 = 7")
    evaluate_expression("num3 = 2.5")
    
    # Test various arithmetic combinations
    assert_equal 22, evaluate_expression("num1 + num2")
    assert_equal 8, evaluate_expression("num1 - num2")
    assert_equal 105, evaluate_expression("num1 * num2")
    assert_in_delta 2.14, evaluate_expression("num1 / num2"), 0.01
    
    # Test with mixed integer/decimal
    assert_equal 17.5, evaluate_expression("num1 + num3")
    assert_equal 37.5, evaluate_expression("num1 * num3")
    
    # Test complex expressions with precedence
    assert_equal 32.5, evaluate_expression("num1 + num2 * num3")
    assert_equal 55.0, evaluate_expression("(num1 + num2) * num3")
  end

  def test_variable_in_parentheses
    # Test variables work correctly within parentheses
    evaluate_expression("a = 4")
    evaluate_expression("b = 6")
    evaluate_expression("c = 2")
    
    assert_equal 20, evaluate_expression("(a + b) * c")
    assert_equal 16, evaluate_expression("a * (b - c)")
    assert_equal 5, evaluate_expression("(a + b) / c + c - 2")
  end

  def test_variable_multiple_assignments_in_sequence
    # Test sequential assignment and usage
    evaluate_expression("step1 = 5")
    evaluate_expression("step2 = step1 * 2")
    evaluate_expression("step3 = step2 + step1")
    evaluate_expression("final = step3 / step1")
    
    assert_equal 5, evaluate_expression("step1")
    assert_equal 10, evaluate_expression("step2")
    assert_equal 15, evaluate_expression("step3")
    assert_equal 3, evaluate_expression("final")
  end

  def test_repl_variable_persistence
    # Test that variables persist across multiple evaluations (REPL simulation)
    # This simulates the REPL behavior where variables remain in scope
    
    # Initial session
    evaluator = Evaluator.new
    
    # Define helper to evaluate with same evaluator instance
    def evaluate_with_evaluator(evaluator, expression)
      lexer = Lexer.new(expression)
      tokens = lexer.tokenize
      parser = Parser.new(tokens)
      ast = parser.parse
      evaluator.evaluate(ast)
    end
    
    # Session commands
    result1 = evaluate_with_evaluator(evaluator, "session_var = 100")
    assert_equal 100, result1
    
    result2 = evaluate_with_evaluator(evaluator, "session_var * 2")
    assert_equal 200, result2
    
    result3 = evaluate_with_evaluator(evaluator, "temp = session_var + 50")
    assert_equal 150, result3
    
    # Verify both variables are still accessible
    result4 = evaluate_with_evaluator(evaluator, "session_var + temp")
    assert_equal 250, result4
  end

  # ========================================
  # Error Handling Tests for Variables
  # ========================================

  def test_undefined_variable_error
    # Test error when accessing undefined variable
    assert_raises(RuntimeError) do
      evaluate_expression("undefined_var")
    end
    
    # Test error in arithmetic expression with undefined variable
    assert_raises(RuntimeError) do
      evaluate_expression("10 + undefined_var")
    end
    
    # Test error in complex expression
    assert_raises(RuntimeError) do
      evaluate_expression("(5 + undefined_var) * 2")
    end
  end

  def test_undefined_variable_in_assignment_expression
    # Test error when undefined variable is used in assignment expression
    assert_raises(RuntimeError) do
      evaluate_expression("new_var = old_var + 5")
    end
  end

  def test_error_propagation_with_variables
    # Test that errors propagate correctly through variable operations
    evaluate_expression("divisor = 0")
    
    # Division by zero with variable
    assert_raises(StandardError) do
      evaluate_expression("10 / divisor")
    end
    
    # Division by zero in variable assignment
    assert_raises(StandardError) do
      evaluate_expression("result = 5 / divisor")
    end
  end

  def test_syntax_error_in_variable_context
    # Test syntax errors in variable assignments
    assert_raises(RuntimeError) do
      evaluate_expression("invalid_var = ")
    end
    
    assert_raises(RuntimeError) do
      evaluate_expression("= 42")
    end
    
    assert_raises(RuntimeError) do
      evaluate_expression("x = 5 +")
    end
  end

  # ========================================
  # Edge Cases and Complex Scenarios
  # ========================================

  def test_variable_names_case_sensitivity
    # Test that variable names are case sensitive
    evaluate_expression("Var = 10")
    evaluate_expression("var = 20")
    evaluate_expression("VAR = 30")
    
    assert_equal 10, evaluate_expression("Var")
    assert_equal 20, evaluate_expression("var")
    assert_equal 30, evaluate_expression("VAR")
  end

  def test_variable_assignment_returns_value
    # Test that assignment expressions return the assigned value
    result = evaluate_expression("return_test = 99")
    assert_equal 99, result
    
    # Test chained usage
    result = evaluate_expression("chained = return_test + 1")
    assert_equal 100, result
    assert_equal 100, evaluate_expression("chained")
  end

  def test_complex_nested_variable_expressions
    # Test deeply nested expressions with variables
    evaluate_expression("base = 2")
    evaluate_expression("multiplier = 3")
    evaluate_expression("offset = 1")
    
    # Nested expression: ((base * multiplier) + offset) * base
    result = evaluate_expression("((base * multiplier) + offset) * base")
    assert_equal 14, result
    
    # Store result and use it
    evaluate_expression("complex_result = ((base * multiplier) + offset) * base")
    assert_equal 14, evaluate_expression("complex_result")
    
    # Use in further calculations
    result = evaluate_expression("complex_result / (base + offset)")
    assert_in_delta 4.67, result, 0.01
  end

  def test_v0_2_0_specification_compliance
    # Test exact specification from v0.2.0 roadmap
    # This ensures we meet the exact requirements
    
    # Reset evaluator for clean test
    clean_evaluator = Evaluator.new
    
    def evaluate_clean(evaluator, expression)
      lexer = Lexer.new(expression)
      tokens = lexer.tokenize
      parser = Parser.new(tokens)
      ast = parser.parse
      evaluator.evaluate(ast)
    end
    
    # Test sequence as specified in v0.2.0
    result1 = evaluate_clean(clean_evaluator, "x = 42")
    assert_equal 42, result1, "x = 42 should return 42"
    
    result2 = evaluate_clean(clean_evaluator, "y = 3.14")
    assert_equal 3.14, result2, "y = 3.14 should return 3.14"
    
    result3 = evaluate_clean(clean_evaluator, "x + y * 2")
    assert_equal 48.28, result3, "x + y * 2 should return 48.28"
    
    result4 = evaluate_clean(clean_evaluator, "result = (x + y) / 2")
    assert_equal 22.57, result4, "result = (x + y) / 2 should return 22.57"
    
    # Verify all variables are accessible
    assert_equal 42, evaluate_clean(clean_evaluator, "x")
    assert_equal 3.14, evaluate_clean(clean_evaluator, "y")
    assert_equal 22.57, evaluate_clean(clean_evaluator, "result")
  end
end