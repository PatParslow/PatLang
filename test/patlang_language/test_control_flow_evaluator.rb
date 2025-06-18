require_relative '../helpers/test_helper'
require_relative '../../patlang-core/evaluator/evaluator'
require_relative '../../patlang-core/lexer/lexer'
require_relative '../../patlang-core/parser/parser'
require_relative '../../patlang-core/ast/ast_nodes'

class TestControlFlowEvaluator < Minitest::Test
  # Boolean literal evaluation tests
  def test_evaluate_boolean_true
    lexer = Lexer.new("true")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(ast)
    assert_equal true, result
  end

  def test_evaluate_boolean_false
    lexer = Lexer.new("false")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(ast)
    assert_equal false, result
  end

  # Comparison operator evaluation tests
  def test_evaluate_equality_true
    lexer = Lexer.new("5 == 5")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(ast)
    assert_equal true, result
  end

  def test_evaluate_equality_false
    lexer = Lexer.new("5 == 3")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(ast)
    assert_equal false, result
  end

  def test_evaluate_not_equal_true
    lexer = Lexer.new("5 != 3")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(ast)
    assert_equal true, result
  end

  def test_evaluate_not_equal_false
    lexer = Lexer.new("5 != 5")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(ast)
    assert_equal false, result
  end

  def test_evaluate_less_than_true
    lexer = Lexer.new("3 < 5")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(ast)
    assert_equal true, result
  end

  def test_evaluate_less_than_false
    lexer = Lexer.new("5 < 3")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(ast)
    assert_equal false, result
  end

  def test_evaluate_greater_than_true
    lexer = Lexer.new("5 > 3")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(ast)
    assert_equal true, result
  end

  def test_evaluate_greater_than_false
    lexer = Lexer.new("3 > 5")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(ast)
    assert_equal false, result
  end

  def test_evaluate_less_equal_true
    lexer = Lexer.new("3 <= 5")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(ast)
    assert_equal true, result
  end

  def test_evaluate_less_equal_equal
    lexer = Lexer.new("5 <= 5")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(ast)
    assert_equal true, result
  end

  def test_evaluate_less_equal_false
    lexer = Lexer.new("5 <= 3")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(ast)
    assert_equal false, result
  end

  def test_evaluate_greater_equal_true
    lexer = Lexer.new("5 >= 3")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(ast)
    assert_equal true, result
  end

  def test_evaluate_greater_equal_equal
    lexer = Lexer.new("5 >= 5")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(ast)
    assert_equal true, result
  end

  def test_evaluate_greater_equal_false
    lexer = Lexer.new("3 >= 5")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(ast)
    assert_equal false, result
  end

  def test_evaluate_comparison_with_variables
    evaluator = Evaluator.new
    
    # Set up variables
    lexer = Lexer.new("x = 10")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator.evaluate(ast)
    
    lexer = Lexer.new("y = 5")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator.evaluate(ast)
    
    # Test comparison
    lexer = Lexer.new("x > y")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    result = evaluator.evaluate(ast)
    assert_equal true, result
  end

  def test_evaluate_comparison_with_booleans
    lexer = Lexer.new("true == true")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(ast)
    assert_equal true, result
  end

  # Conditional statement evaluation tests
  def test_evaluate_if_true_condition
    lexer = Lexer.new("if true then x = 5 end")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(ast)
    assert_equal 5, result
    assert_equal 5, evaluator.instance_variable_get(:@variables)['x']
  end

  def test_evaluate_if_false_condition
    lexer = Lexer.new("if false then x = 5 end")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(ast)
    assert_nil result
    assert_nil evaluator.instance_variable_get(:@variables)['x']
  end

  def test_evaluate_if_else_true_condition
    lexer = Lexer.new("if true then x = 5 else x = 10 end")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(ast)
    assert_equal 5, result
    assert_equal 5, evaluator.instance_variable_get(:@variables)['x']
  end

  def test_evaluate_if_else_false_condition
    lexer = Lexer.new("if false then x = 5 else x = 10 end")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(ast)
    assert_equal 10, result
    assert_equal 10, evaluator.instance_variable_get(:@variables)['x']
  end

  def test_evaluate_if_with_comparison
    lexer = Lexer.new("if 5 > 3 then x = 42 end")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(ast)
    assert_equal 42, result
    assert_equal 42, evaluator.instance_variable_get(:@variables)['x']
  end

  def test_evaluate_if_with_variable_condition
    evaluator = Evaluator.new
    
    # Set up condition variable
    lexer = Lexer.new("condition = true")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator.evaluate(ast)
    
    # Test if with variable condition
    lexer = Lexer.new("if condition then result = 100 end")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    result = evaluator.evaluate(ast)
    assert_equal 100, result
    assert_equal 100, evaluator.instance_variable_get(:@variables)['result']
  end

  # While loop evaluation tests
  def test_evaluate_while_simple_countdown
    evaluator = Evaluator.new
    
    # First set up the variable
    lexer = Lexer.new("x = 3")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator.evaluate(ast)
    
    # Then run the while loop
    lexer = Lexer.new("while x > 0 do x = x - 1 end")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    result = evaluator.evaluate(ast)
    assert_equal 0, evaluator.instance_variable_get(:@variables)['x']
  end

  def test_evaluate_while_no_iterations
    evaluator = Evaluator.new
    
    # First set up the variable
    lexer = Lexer.new("x = 0")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator.evaluate(ast)
    
    # Then run the while loop (should not execute)
    lexer = Lexer.new("while x > 0 do x = x - 1 end")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    result = evaluator.evaluate(ast)
    assert_equal 0, evaluator.instance_variable_get(:@variables)['x']
  end

  def test_evaluate_while_with_accumulator
    evaluator = Evaluator.new
    
    # Set up variables
    lexer = Lexer.new("x = 0")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator.evaluate(ast)
    
    lexer = Lexer.new("sum = 0")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator.evaluate(ast)
    
    # Run the while loop with multiple statements in body
    lexer = Lexer.new("while x < 5 do sum = sum + x x = x + 1 end")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    result = evaluator.evaluate(ast)
    assert_equal 5, evaluator.instance_variable_get(:@variables)['x']
    assert_equal 10, evaluator.instance_variable_get(:@variables)['sum']  # 0+1+2+3+4 = 10
  end

  def test_evaluate_while_infinite_loop_protection
    evaluator = Evaluator.new
    
    # Set up variable
    lexer = Lexer.new("x = 1")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator.evaluate(ast)
    
    # Run infinite loop (should be caught)
    lexer = Lexer.new("while x > 0 do x = x + 1 end")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_raises(StandardError) do
      evaluator.evaluate(ast)
    end
  end

  # Block statement evaluation tests
  def test_evaluate_empty_block
    block_node = BlockNode.new([])
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(block_node)
    assert_nil result
  end

  def test_evaluate_block_single_statement
    number_node = NumberNode.new(42)
    block_node = BlockNode.new([number_node])
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(block_node)
    assert_equal 42, result
  end

  def test_evaluate_block_multiple_statements
    assign1 = AssignmentNode.new('x', NumberNode.new(10))
    assign2 = AssignmentNode.new('y', NumberNode.new(20))
    var_node = VariableNode.new('x')
    block_node = BlockNode.new([assign1, assign2, var_node])
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(block_node)
    assert_equal 10, result  # Should return value of last statement
    assert_equal 10, evaluator.instance_variable_get(:@variables)['x']
    assert_equal 20, evaluator.instance_variable_get(:@variables)['y']
  end

  # Nested control flow tests
  def test_evaluate_nested_if_in_while
    evaluator = Evaluator.new
    
    # Set up variables
    lexer = Lexer.new("x = 0")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator.evaluate(ast)
    
    lexer = Lexer.new("sum = 0")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator.evaluate(ast)
    
    # Run nested control flow
    lexer = Lexer.new("while x < 3 do if x > 0 then sum = sum + x end x = x + 1 end")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    result = evaluator.evaluate(ast)
    assert_equal 3, evaluator.instance_variable_get(:@variables)['x']
    assert_equal 3, evaluator.instance_variable_get(:@variables)['sum']  # 1+2 = 3
  end

  def test_evaluate_while_in_if
    evaluator = Evaluator.new
    
    # Set up condition variable
    lexer = Lexer.new("condition = true")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator.evaluate(ast)
    
    # Run if with nested while
    lexer = Lexer.new("if condition then x = 5 while x > 0 do x = x - 1 end end")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    result = evaluator.evaluate(ast)
    assert_equal 0, evaluator.instance_variable_get(:@variables)['x']
  end

  # Truthiness tests
  def test_evaluate_truthiness_numbers
    # Non-zero numbers should be truthy
    lexer = Lexer.new("if 1 then x = 5 end")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator = Evaluator.new
    
    result = evaluator.evaluate(ast)
    assert_equal 5, result
    
    # Zero should be truthy (only false and nil are falsy)
    lexer = Lexer.new("if 0 then y = 10 end")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    result = evaluator.evaluate(ast)
    assert_equal 10, result
    assert_equal 10, evaluator.instance_variable_get(:@variables)['y']
  end

  def test_evaluate_complex_control_flow
    # Test complex nested structure with multiple control flow elements
    evaluator = Evaluator.new
    
    # Set up variables
    lexer = Lexer.new("result = 0")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator.evaluate(ast)
    
    lexer = Lexer.new("x = 1")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    evaluator.evaluate(ast)
    
    # Run complex nested control flow
    lexer = Lexer.new("while x <= 3 do if x == 2 then result = result + 10 else result = result + x end x = x + 1 end")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    result = evaluator.evaluate(ast)
    # Should execute: result = 0 + 1 + 10 + 3 = 14
    assert_equal 14, evaluator.instance_variable_get(:@variables)['result']
  end
end