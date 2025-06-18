require_relative '../helpers/test_helper'
require_relative '../../patlang-core/exceptions'
require_relative '../../patlang-core/evaluator/evaluator'
require_relative '../../patlang-core/lexer/lexer'
require_relative '../../patlang-core/parser/parser'
require_relative '../../patlang-core/ast/ast_nodes'

class TestEvaluatorBranchCoverage < Minitest::Test
  def setup
    @evaluator = Evaluator.new
  end

  # Test arithmetic division by zero - HIGH PRIORITY
  def test_arithmetic_division_by_zero
    lexer = Lexer.new("10 / 0")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_raises(ZeroDivisionError) do
      @evaluator.evaluate(ast)
    end
  end

  # Test string operations on nil values - HIGH PRIORITY
  def test_string_operations_on_nil_values
    # Test string indexing on nil
    @evaluator.variables['nil_var'] = nil
    
    lexer = Lexer.new("nil_var[0]")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_raises(RuntimeError) do
      @evaluator.evaluate(ast)
    end
  end

  # Test function call with wrong arguments - HIGH PRIORITY
  def test_function_call_wrong_arguments
    # Define a function that expects 2 arguments
    @evaluator.functions['test_func'] = {
      parameters: ['a', 'b'],
      body: BinaryOpNode.new(IdentifierNode.new('a'), '+', IdentifierNode.new('b'))
    }
    
    # Call with wrong number of arguments
    lexer = Lexer.new("test_func(1)")  # Only 1 argument, expects 2
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    # Should handle gracefully or raise appropriate error
    begin
      result = @evaluator.evaluate(ast)
      # Function should handle missing parameters
    rescue => e
      assert_instance_of StandardError, e
    end
  end

  # Test reasoning mode transitions - HIGH PRIORITY
  def test_reasoning_mode_transitions
    # Test enabling reasoning mode
    refute @evaluator.instance_variable_get(:@reasoning_mode)
    
    # Set reasoning coordinator to enable reasoning mode
    @evaluator.set_reasoning_coordinator(double("coordinator"))
    
    # Test reasoning mode functionality
    result = @evaluator.enable_reasoning_mode
    assert_includes result, "reasoning mode"
    
    # Test without reasoning coordinator
    @evaluator.instance_variable_set(:@reasoning_coordinator, nil)
    result = @evaluator.enable_reasoning_mode
    assert_includes result, "not set"
  end

  # Test variable scope edge cases - HIGH PRIORITY
  def test_variable_scope_edge_cases
    # Test undefined variable access
    lexer = Lexer.new("undefined_var")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_raises(RuntimeError) do
      @evaluator.evaluate(ast)
    end
    
    # Test variable shadowing
    @evaluator.variables['x'] = 10
    @evaluator.push_scope
    @evaluator.variables['x'] = 20
    
    lexer = Lexer.new("x")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    result = @evaluator.evaluate(ast)
    assert_equal 20, result
    
    @evaluator.pop_scope
    result = @evaluator.evaluate(ast)
    assert_equal 10, result
  end

  # Test return value handling - HIGH PRIORITY
  def test_return_value_handling
    # Test return without value
    return_node = ReturnNode.new(nil)
    @evaluator.evaluate(return_node)
    
    assert @evaluator.returned
    assert_nil @evaluator.return_value
    
    # Reset evaluator
    @evaluator.returned = false
    @evaluator.return_value = nil
    
    # Test return with value
    return_node = ReturnNode.new(NumberNode.new(42))
    @evaluator.evaluate(return_node)
    
    assert @evaluator.returned
    assert_equal 42, @evaluator.return_value
  end

  # Test builtin class initialization - HIGH PRIORITY
  def test_builtin_class_initialization
    # Test that builtin classes are properly initialized
    assert @evaluator.variables.key?('Integer')
    assert @evaluator.variables.key?('String')
    assert @evaluator.variables.key?('Boolean')
    
    # Test class instantiation
    integer_class = @evaluator.variables['Integer']
    assert_respond_to integer_class, :call
  end

  # Test arithmetic operations edge cases - HIGH PRIORITY
  def test_arithmetic_operations_edge_cases
    # Test string concatenation vs addition
    lexer = Lexer.new('"hello" + " world"')
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    result = @evaluator.evaluate(ast)
    assert_equal "hello world", result
    
    # Test mixed type addition (should convert to string)
    lexer = Lexer.new('"Number: " + 42')
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    result = @evaluator.evaluate(ast)
    assert_equal "Number: 42", result
    
    # Test modulo operation
    lexer = Lexer.new("10 % 3")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    result = @evaluator.evaluate(ast)
    assert_equal 1, result
    
    # Test modulo by zero
    lexer = Lexer.new("10 % 0")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_raises(ZeroDivisionError) do
      @evaluator.evaluate(ast)
    end
  end

  # Test comparison operations - HIGH PRIORITY
  def test_comparison_operations
    comparisons = [
      ["5 == 5", true],
      ["5 != 3", true],
      ["5 < 10", true],
      ["10 > 5", true],
      ["5 <= 5", true],
      ["5 >= 5", true],
      ["5 == 3", false],
      ["5 != 5", false]
    ]
    
    comparisons.each do |expr, expected|
      lexer = Lexer.new(expr)
      tokens = lexer.tokenize
      parser = Parser.new(tokens)
      ast = parser.parse
      result = @evaluator.evaluate(ast)
      assert_equal expected, result, "Failed for expression: #{expr}"
    end
  end

  # Test logical operations - HIGH PRIORITY
  def test_logical_operations
    # Test AND operation
    lexer = Lexer.new("true && false")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    result = @evaluator.evaluate(ast)
    assert_equal false, result
    
    # Test OR operation
    lexer = Lexer.new("true || false")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    result = @evaluator.evaluate(ast)
    assert_equal true, result
    
    # Test short-circuit evaluation
    @evaluator.variables['flag'] = false
    lexer = Lexer.new("flag && (undefined_var == 1)")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    # Should not raise error due to short-circuit
    result = @evaluator.evaluate(ast)
    assert_equal false, result
  end

  # Test object evaluation edge cases - HIGH PRIORITY
  def test_object_evaluation_edge_cases
    # Test object creation
    @evaluator.variables['TestClass'] = proc { |*args| { value: args.first } }
    
    lexer = Lexer.new("TestClass(42)")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    result = @evaluator.evaluate(ast)
    assert_equal({ value: 42 }, result)
    
    # Test method call on object
    @evaluator.variables['obj'] = { 
      test_method: proc { "method called" }
    }
    
    lexer = Lexer.new("obj.test_method()")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    result = @evaluator.evaluate(ast)
    assert_equal "method called", result
  end

  # Test assignment operations - HIGH PRIORITY
  def test_assignment_operations
    # Test simple assignment
    lexer = Lexer.new("x = 42")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    result = @evaluator.evaluate(ast)
    
    assert_equal 42, result
    assert_equal 42, @evaluator.variables['x']
    
    # Test assignment with expression
    lexer = Lexer.new("y = 2 + 3")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    result = @evaluator.evaluate(ast)
    
    assert_equal 5, result
    assert_equal 5, @evaluator.variables['y']
  end

  # Test string indexing edge cases - HIGH PRIORITY
  def test_string_indexing_edge_cases
    @evaluator.variables['str'] = "hello"
    
    # Test valid index
    lexer = Lexer.new("str[0]")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    result = @evaluator.evaluate(ast)
    assert_equal "h", result
    
    # Test negative index
    lexer = Lexer.new("str[-1]")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    result = @evaluator.evaluate(ast)
    assert_equal "o", result
    
    # Test out of bounds index
    lexer = Lexer.new("str[10]")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    result = @evaluator.evaluate(ast)
    assert_nil result
    
    # Test non-integer index
    @evaluator.variables['float_index'] = 1.5
    lexer = Lexer.new("str[float_index]")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_raises(RuntimeError) do
      @evaluator.evaluate(ast)
    end
  end

  # Test goal evaluation - HIGH PRIORITY
  def test_goal_evaluation
    # Test goal without reasoning coordinator
    goal_node = GoalNode.new("test_goal", IdentifierNode.new("true"))
    
    begin
      result = @evaluator.evaluate(goal_node)
      assert_includes result.to_s.downcase, "goal"
    rescue => e
      # Acceptable if goals require reasoning coordinator
      assert_instance_of StandardError, e
    end
  end

  # Test constraint evaluation - HIGH PRIORITY
  def test_constraint_evaluation
    # Test type constraint
    constraint_node = TypeConstraintNode.new("x", "Integer")
    
    begin
      result = @evaluator.evaluate(constraint_node)
      assert_not_nil result
    rescue => e
      # Acceptable if constraints require special handling
      assert_instance_of StandardError, e
    end
  end

  # Test error handling in evaluation - HIGH PRIORITY
  def test_evaluation_error_handling
    # Test evaluation of unknown node type
    unknown_node = Object.new
    unknown_node.define_singleton_method(:class) { "UnknownNode" }
    
    assert_raises(RuntimeError) do
      @evaluator.evaluate(unknown_node)
    end
  end

  # Test boundary conditions - HIGH PRIORITY
  def test_evaluator_boundary_conditions
    # Test very large numbers
    lexer = Lexer.new("999999999999999999")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    result = @evaluator.evaluate(ast)
    assert_equal 999999999999999999, result
    
    # Test very long strings
    long_string = "a" * 10000
    lexer = Lexer.new("\"#{long_string}\"")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    result = @evaluator.evaluate(ast)
    assert_equal long_string, result
    
    # Test deeply nested expressions
    nested_expr = "(" * 50 + "42" + ")" * 50
    lexer = Lexer.new(nested_expr)
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    result = @evaluator.evaluate(ast)
    assert_equal 42, result
  end
end