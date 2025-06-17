# frozen_string_literal: true

require_relative '../helpers/test_helper'

class TestExceptionHandling < Minitest::Test
  def setup
    @mock_evaluator = MockEvaluator.new
  end

  # Test PatlangError base exception functionality
  def test_patlang_error_basic_creation
    error = PatlangError.new("Test error message")
    
    assert_equal "Test error message", error.message
    assert_equal "Test error message", error.simple_message
    assert_equal "Test error message", error.detailed_message
    assert_nil error.original_error
    assert_equal({}, error.context)
  end

  def test_patlang_error_with_context
    context = { operation: "addition", left_operand: 5, right_operand: 10 }
    error = PatlangError.new("Context test", context: context)
    
    assert_equal "Context test", error.simple_message
    assert_equal "Context test (operation: addition, left: 5, right: 10)", error.detailed_message
    assert_equal context, error.context
  end

  def test_patlang_error_with_original_error
    original = StandardError.new("Original error")
    error = PatlangError.new("Wrapped error", original_error: original)
    
    assert_equal original, error.original_error
    assert_equal "Wrapped error", error.message
  end

  # Test ParseError specific functionality
  def test_parse_error_with_position_info
    error = ParseError.new("Syntax error", line: 5, column: 10, position: 45)
    
    assert_equal 5, error.line
    assert_equal 10, error.column
    assert_equal 45, error.position
    assert_equal "Syntax error at line 5, column 10", error.to_s
  end

  def test_parse_error_with_token_info
    mock_token = Object.new
    error = ParseError.new("Token error", token: mock_token, line: 3)
    
    assert_equal mock_token, error.token
    assert_equal 3, error.line
    assert_equal "Token error at line 3", error.to_s
  end

  def test_parse_error_position_only
    error = ParseError.new("Position error", position: 100)
    
    assert_equal "Position error at position 100", error.to_s
  end

  # Test TypeConstraintViolation
  def test_type_constraint_violation_creation
    error = TypeConstraintViolation.new("x", 42, "must be string", constraint: "String")
    
    assert_equal "x", error.variable
    assert_equal 42, error.value
    assert_equal "String", error.constraint
    assert_equal "Variable x: must be string", error.message
  end

  def test_type_constraint_violation_with_context
    context = { function: "validate_input" }
    error = TypeConstraintViolation.new("param", nil, "cannot be nil", context: context)
    
    assert_equal "Variable param: cannot be nil (function: validate_input)", error.detailed_message
  end

  # Test PatlangArithmeticError
  def test_arithmetic_error_creation
    error = PatlangArithmeticError.new("Invalid operation", 
                                      operator: "+", 
                                      left_operand: "string", 
                                      right_operand: 5)
    
    assert_equal "+", error.operator
    assert_equal "string", error.left_operand
    assert_equal 5, error.right_operand
    assert_equal "Invalid operation (operator: +, left: string, right: 5)", error.detailed_message
  end

  def test_arithmetic_error_operand_validation
    error = PatlangArithmeticError.new("Test", left_operand: 5, right_operand: 10)
    assert error.validate_operands
    
    error = PatlangArithmeticError.new("Test", left_operand: "string", right_operand: 10)
    assert_not error.validate_operands
    
    error = PatlangArithmeticError.new("Test", left_operand: nil, right_operand: 10)
    assert_not error.validate_operands
  end

  # Test PatlangDivisionByZeroError
  def test_division_by_zero_error
    error = PatlangDivisionByZeroError.new("Cannot divide", dividend: 10)
    
    assert_equal 10, error.dividend
    assert_equal "/", error.operator
    assert_equal 10, error.left_operand
    assert_equal 0, error.right_operand
    assert error.validate_division
  end

  def test_division_by_zero_default_message
    error = PatlangDivisionByZeroError.new
    
    assert_equal "Division by zero", error.message
    assert_equal "/", error.operator
    assert_equal 0, error.right_operand
  end

  # Test PatlangFunctionError
  def test_function_error_creation
    args = [1, 2, "three"]
    error = PatlangFunctionError.new("Function failed", 
                                    function_name: "test_func",
                                    arguments: args,
                                    expected_params: 2,
                                    actual_params: 3)
    
    assert_equal "test_func", error.function_name
    assert_equal args, error.arguments
    assert_equal 2, error.expected_params
    assert_equal 3, error.actual_params
    assert_includes error.detailed_message, "function: test_func"
    assert_includes error.detailed_message, "expected_params: 2"
    assert_includes error.detailed_message, "actual_params: 3"
  end

  # Test PatlangTypeError
  def test_type_error_creation
    error = PatlangTypeError.new("Type mismatch",
                                expected_type: "Number",
                                actual_type: "String",
                                value: "hello",
                                conversion_attempted: true)
    
    assert_equal "Number", error.expected_type
    assert_equal "String", error.actual_type
    assert_equal "hello", error.value
    assert error.conversion_attempted
    assert_includes error.detailed_message, "expected_type: Number"
    assert_includes error.detailed_message, "actual_type: String"
  end

  # Test PatlangIndexError
  def test_index_error_creation
    error = PatlangIndexError.new("Index out of bounds",
                                 index: 5,
                                 collection_size: 3,
                                 collection_type: "Array",
                                 zero_based: true)
    
    assert_equal 5, error.index
    assert_equal 3, error.collection_size
    assert_equal "Array", error.collection_type
    assert error.zero_based
    assert_includes error.detailed_message, "index: 5"
    assert_includes error.detailed_message, "collection_size: 3"
  end

  # Test PatlangRuntimeError
  def test_runtime_error_creation
    exec_context = { variables: { x: 10 } }
    error = PatlangRuntimeError.new("Runtime failure",
                                   operation: "evaluation",
                                   execution_context: exec_context,
                                   function_name: "main",
                                   line_number: 42)
    
    assert_equal "evaluation", error.operation
    assert_equal exec_context, error.execution_context
    assert_equal "main", error.function_name
    assert_equal 42, error.line_number
    assert_includes error.detailed_message, "operation: evaluation"
    assert_includes error.detailed_message, "function: main"
    assert_includes error.detailed_message, "line: 42"
  end

  # Test specialized error types
  def test_logic_error_inheritance
    error = LogicError.new("Logic programming error")
    assert_kind_of PatlangError, error
    assert_equal "Logic programming error", error.message
  end

  def test_query_error_inheritance
    error = QueryError.new("Query execution failed")
    assert_kind_of LogicError, error
    assert_kind_of PatlangError, error
  end

  def test_unification_error_inheritance
    error = UnificationError.new("Unification failed")
    assert_kind_of LogicError, error
    assert_kind_of PatlangError, error
  end

  def test_reasoning_mode_error
    error = ReasoningModeError.new
    assert_equal "Reasoning mode not enabled", error.message
    
    error = ReasoningModeError.new("Custom reasoning error")
    assert_equal "Custom reasoning error", error.message
  end

  def test_goal_resolution_error_inheritance
    error = GoalResolutionError.new("Goal resolution failed")
    assert_kind_of PatlangError, error
  end

  # Test exception propagation scenarios
  def test_exception_propagation_through_evaluator
    begin
      @mock_evaluator.evaluate_string("undefined_variable")
      assert false, "Expected exception to be raised"
    rescue RuntimeError => e
      assert_equal "Undefined variable: undefined_variable", e.message
    end
  end

  def test_division_by_zero_propagation
    begin
      @mock_evaluator.evaluate_string("10 / 0")
      assert false, "Expected ZeroDivisionError to be raised"
    rescue ZeroDivisionError => e
      assert_equal "divided by 0", e.message
    end
  end

  # Test error message formatting consistency
  def test_error_message_consistency
    errors = [
      PatlangError.new("Base error"),
      ParseError.new("Parse error", line: 1, column: 1),
      TypeConstraintViolation.new("x", 42, "invalid type"),
      PatlangArithmeticError.new("Math error", operator: "+"),
      PatlangFunctionError.new("Function error", function_name: "test")
    ]
    
    errors.each do |error|
      assert_respond_to error, :simple_message
      assert_respond_to error, :detailed_message
      assert_respond_to error, :to_s
      assert_kind_of String, error.simple_message
      assert_kind_of String, error.detailed_message
      assert_kind_of String, error.to_s
    end
  end

  # Test context preservation across error chain
  def test_context_preservation_chain
    original_context = { file: "test.pat", line: 10 }
    base_error = PatlangError.new("Base", context: original_context)
    
    wrapped_error = PatlangRuntimeError.new("Wrapped", 
                                           original_error: base_error,
                                           operation: "parse",
                                           context: { function: "main" })
    
    assert_equal base_error, wrapped_error.original_error
    assert_includes wrapped_error.detailed_message, "function: main"
  end

  # Test memory allocation failure scenarios (simulated)
  def test_memory_allocation_failure_handling
    # Simulate memory pressure scenario
    large_context = {}
    1000.times { |i| large_context["key_#{i}"] = "value_#{i}" * 100 }
    
    assert_nothing_raised do
      error = PatlangError.new("Memory test", context: large_context)
      assert_kind_of PatlangError, error
      assert_equal large_context, error.context
    end
  end

  # Test exception handling with nil values
  def test_nil_value_handling
    assert_nothing_raised do
      error = PatlangArithmeticError.new("Test", left_operand: nil, right_operand: nil)
      assert_not error.validate_operands
    end
    
    assert_nothing_raised do
      error = TypeConstraintViolation.new("x", nil, "cannot be nil")
      assert_nil error.value
    end
  end

  # Test complex error scenarios
  def test_complex_error_scenario_simulation
    # Simulate a complex parsing scenario with nested errors
    begin
      # Simulate parser encountering multiple issues
      original_parse_error = ParseError.new("Unexpected token", line: 5, column: 10)
      
      # Wrap in a runtime error during evaluation
      runtime_error = PatlangRuntimeError.new("Evaluation failed",
                                             original_error: original_parse_error,
                                             operation: "parse_and_evaluate",
                                             function_name: "execute",
                                             line_number: 5)
      
      raise runtime_error
    rescue PatlangRuntimeError => e
      assert_kind_of ParseError, e.original_error
      assert_equal "parse_and_evaluate", e.operation
      assert_equal "execute", e.function_name
      assert_equal 5, e.line_number
      assert_includes e.detailed_message, "operation: parse_and_evaluate"
    end
  end
end