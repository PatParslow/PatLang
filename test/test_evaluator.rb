require 'minitest/autorun'
require_relative '../src/evaluator'
require_relative '../src/lexer'
require_relative '../src/parser'
require_relative '../src/ast_nodes'

class TestEvaluator < Minitest::Test
  def test_evaluate_simple_number
    lexer = Lexer.new("42")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(ast)
    assert_equal 42, result
  end

  def test_evaluate_simple_addition
    lexer = Lexer.new("2 + 3")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(ast)
    assert_equal 5, result
  end

  def test_evaluate_simple_subtraction
    lexer = Lexer.new("8 - 3")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(ast)
    assert_equal 5, result
  end

  def test_evaluate_simple_multiplication
    lexer = Lexer.new("4 * 5")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(ast)
    assert_equal 20, result
  end

  def test_evaluate_simple_division
    lexer = Lexer.new("15 / 3")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(ast)
    assert_equal 5, result
  end

  def test_evaluate_operator_precedence
    # 2 + 3 * 4 should evaluate to 14 (not 20)
    lexer = Lexer.new("2 + 3 * 4")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(ast)
    assert_equal 14, result
  end

  def test_evaluate_parentheses
    # (2 + 3) * 4 should evaluate to 20
    lexer = Lexer.new("(2 + 3) * 4")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(ast)
    assert_equal 20, result
  end

  def test_evaluate_complex_expression
    # 10 - 2 * 3 + 1 should evaluate to 5 (10 - 6 + 1)
    lexer = Lexer.new("10 - 2 * 3 + 1")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(ast)
    assert_equal 5, result
  end

  def test_evaluate_nested_parentheses
    # (10 + 5) / (2 + 1) should evaluate to 5
    lexer = Lexer.new("(10 + 5) / (2 + 1)")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(ast)
    assert_equal 5, result
  end

  def test_evaluate_division_by_zero
    lexer = Lexer.new("10 / 0")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    assert_raises(StandardError) do
      evaluator.evaluate(ast)
    end
  end

  def test_evaluate_float_result
    # 5 / 2 should handle float division
    lexer = Lexer.new("5 / 2")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(ast)
    assert_equal 2.5, result
  end

  def test_evaluate_large_expression
    # 1 + 2 * 3 - 4 / 2 + 5 should evaluate to 10
    # 1 + 6 - 2 + 5 = 10
    lexer = Lexer.new("1 + 2 * 3 - 4 / 2 + 5")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(ast)
    assert_equal 10, result
  end
end