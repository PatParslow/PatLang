require 'minitest/autorun'
require_relative '../src/parser'
require_relative '../src/lexer'
require_relative '../src/ast_nodes'

class TestParser < Minitest::Test
  def test_parse_simple_number
    lexer = Lexer.new("42")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of NumberNode, ast
    assert_equal 42, ast.value
  end

  def test_parse_simple_addition
    lexer = Lexer.new("2 + 3")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of BinaryOpNode, ast
    assert_instance_of NumberNode, ast.left
    assert_equal 2, ast.left.value
    assert_equal '+', ast.operator
    assert_instance_of NumberNode, ast.right
    assert_equal 3, ast.right.value
  end

  def test_parse_simple_multiplication
    lexer = Lexer.new("4 * 5")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of BinaryOpNode, ast
    assert_instance_of NumberNode, ast.left
    assert_equal 4, ast.left.value
    assert_equal '*', ast.operator
    assert_instance_of NumberNode, ast.right
    assert_equal 5, ast.right.value
  end

  def test_parse_operator_precedence
    # 2 + 3 * 4 should parse as 2 + (3 * 4)
    lexer = Lexer.new("2 + 3 * 4")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of BinaryOpNode, ast
    assert_equal '+', ast.operator
    assert_instance_of NumberNode, ast.left
    assert_equal 2, ast.left.value
    
    # Right side should be multiplication
    assert_instance_of BinaryOpNode, ast.right
    assert_equal '*', ast.right.operator
    assert_equal 3, ast.right.left.value
    assert_equal 4, ast.right.right.value
  end

  def test_parse_parentheses
    # (2 + 3) * 4 should parse as (2 + 3) * 4
    lexer = Lexer.new("(2 + 3) * 4")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of BinaryOpNode, ast
    assert_equal '*', ast.operator
    
    # Left side should be addition in parentheses
    assert_instance_of BinaryOpNode, ast.left
    assert_equal '+', ast.left.operator
    assert_equal 2, ast.left.left.value
    assert_equal 3, ast.left.right.value
    
    # Right side should be number
    assert_instance_of NumberNode, ast.right
    assert_equal 4, ast.right.value
  end

  def test_parse_complex_expression
    # 1 + 2 * 3 + 4 should parse as ((1 + (2 * 3)) + 4)
    lexer = Lexer.new("1 + 2 * 3 + 4")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of BinaryOpNode, ast
    assert_equal '+', ast.operator
    
    # Right side should be 4
    assert_instance_of NumberNode, ast.right
    assert_equal 4, ast.right.value
    
    # Left side should be 1 + (2 * 3)
    assert_instance_of BinaryOpNode, ast.left
    assert_equal '+', ast.left.operator
    assert_equal 1, ast.left.left.value
    
    # Middle should be multiplication
    assert_instance_of BinaryOpNode, ast.left.right
    assert_equal '*', ast.left.right.operator
    assert_equal 2, ast.left.right.left.value
    assert_equal 3, ast.left.right.right.value
  end

  def test_parse_all_operators
    # Test all four operators: 8 / 2 - 1
    lexer = Lexer.new("8 / 2 - 1")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of BinaryOpNode, ast
    assert_equal '-', ast.operator
    
    # Left side should be division
    assert_instance_of BinaryOpNode, ast.left
    assert_equal '/', ast.left.operator
    assert_equal 8, ast.left.left.value
    assert_equal 2, ast.left.right.value
    
    # Right side should be 1
    assert_instance_of NumberNode, ast.right
    assert_equal 1, ast.right.value
  end

  def test_parse_empty_expression
    lexer = Lexer.new("")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    
    assert_raises(RuntimeError) do
      parser.parse
    end
  end
end