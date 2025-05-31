require 'minitest/autorun'
require_relative '../src/lexer'
require_relative '../src/parser'
require_relative '../src/evaluator'

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
    assert_raises(RuntimeError) do
      evaluate_expression("")
    end
  end

  def test_whitespace_handling
    # Test that whitespace is properly handled throughout pipeline
    assert_equal 5, evaluate_expression("  2   +   3  ")
    assert_equal 14, evaluate_expression(" 2+3*4 ")
    assert_equal 20, evaluate_expression("( 2 + 3 ) * 4")
  end
end