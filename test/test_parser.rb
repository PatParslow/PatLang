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
  
  # Tests for new AST node classes
  def test_variable_node_creation
    node = VariableNode.new("x")
    
    assert_instance_of VariableNode, node
    assert_equal "x", node.name
    assert_equal "VariableNode(x)", node.to_s
  end
  
  def test_variable_node_with_different_names
    node1 = VariableNode.new("result")
    node2 = VariableNode.new("myVar")
    
    assert_equal "result", node1.name
    assert_equal "myVar", node2.name
    assert_equal "VariableNode(result)", node1.to_s
    assert_equal "VariableNode(myVar)", node2.to_s
  end
  
  def test_assignment_node_creation
    expr = NumberNode.new(42)
    node = AssignmentNode.new("x", expr)
    
    assert_instance_of AssignmentNode, node
    assert_equal "x", node.name
    assert_equal expr, node.expression
    assert_equal "AssignmentNode(x, NumberNode(42))", node.to_s
  end
  
  def test_assignment_node_with_complex_expression
    # Test assignment with a binary operation: y = x + 5
    var_node = VariableNode.new("x")
    num_node = NumberNode.new(5)
    binary_expr = BinaryOpNode.new(var_node, "+", num_node)
    assignment = AssignmentNode.new("y", binary_expr)
    
    assert_instance_of AssignmentNode, assignment
    assert_equal "y", assignment.name
    assert_equal binary_expr, assignment.expression
    assert_equal "AssignmentNode(y, BinaryOpNode(VariableNode(x), +, NumberNode(5)))", assignment.to_s
  end
  
  def test_assignment_node_with_variable_expression
    # Test assignment with just a variable: result = x
    var_expr = VariableNode.new("x")
    assignment = AssignmentNode.new("result", var_expr)
    
    assert_equal "result", assignment.name
    assert_equal var_expr, assignment.expression
    assert_equal "AssignmentNode(result, VariableNode(x))", assignment.to_s
  end
  # Tests for variable assignment parsing
  def test_parse_simple_assignment
    lexer = Lexer.new("x = 42")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of AssignmentNode, ast
    assert_equal "x", ast.name
    assert_instance_of NumberNode, ast.expression
    assert_equal 42, ast.expression.value
  end
  
  def test_parse_assignment_with_complex_expression
    # result = x + y * 2
    lexer = Lexer.new("result = x + y * 2")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of AssignmentNode, ast
    assert_equal "result", ast.name
    
    # Expression should be x + (y * 2)
    expr = ast.expression
    assert_instance_of BinaryOpNode, expr
    assert_equal '+', expr.operator
    
    # Left side should be variable x
    assert_instance_of VariableNode, expr.left
    assert_equal "x", expr.left.name
    
    # Right side should be y * 2
    assert_instance_of BinaryOpNode, expr.right
    assert_equal '*', expr.right.operator
    assert_instance_of VariableNode, expr.right.left
    assert_equal "y", expr.right.left.name
    assert_instance_of NumberNode, expr.right.right
    assert_equal 2, expr.right.right.value
  end
  
  def test_parse_assignment_with_variable_expression
    # result = x
    lexer = Lexer.new("result = x")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of AssignmentNode, ast
    assert_equal "result", ast.name
    assert_instance_of VariableNode, ast.expression
    assert_equal "x", ast.expression.name
  end
  
  def test_parse_variable_reference_simple
    lexer = Lexer.new("x")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of VariableNode, ast
    assert_equal "x", ast.name
  end
  
  def test_parse_variable_reference_in_expression
    # x + 5
    lexer = Lexer.new("x + 5")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of BinaryOpNode, ast
    assert_equal '+', ast.operator
    assert_instance_of VariableNode, ast.left
    assert_equal "x", ast.left.name
    assert_instance_of NumberNode, ast.right
    assert_equal 5, ast.right.value
  end
  
  def test_parse_complex_variable_expression
    # x * y + z
    lexer = Lexer.new("x * y + z")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of BinaryOpNode, ast
    assert_equal '+', ast.operator
    
    # Left side should be x * y
    assert_instance_of BinaryOpNode, ast.left
    assert_equal '*', ast.left.operator
    assert_instance_of VariableNode, ast.left.left
    assert_equal "x", ast.left.left.name
    assert_instance_of VariableNode, ast.left.right
    assert_equal "y", ast.left.right.name
    
    # Right side should be z
    assert_instance_of VariableNode, ast.right
    assert_equal "z", ast.right.name
  end
  
  def test_parse_variables_with_parentheses
    # (x + y) * z
    lexer = Lexer.new("(x + y) * z")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of BinaryOpNode, ast
    assert_equal '*', ast.operator
    
    # Left side should be (x + y)
    assert_instance_of BinaryOpNode, ast.left
    assert_equal '+', ast.left.operator
    assert_instance_of VariableNode, ast.left.left
    assert_equal "x", ast.left.left.name
    assert_instance_of VariableNode, ast.left.right
    assert_equal "y", ast.left.right.name
    
    # Right side should be z
    assert_instance_of VariableNode, ast.right
    assert_equal "z", ast.right.name
  end
  
  def test_parse_assignment_with_parentheses
    # result = (x + y) * 2
    lexer = Lexer.new("result = (x + y) * 2")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of AssignmentNode, ast
    assert_equal "result", ast.name
    
    # Expression should be (x + y) * 2
    expr = ast.expression
    assert_instance_of BinaryOpNode, expr
    assert_equal '*', expr.operator
    
    # Left side should be (x + y)
    assert_instance_of BinaryOpNode, expr.left
    assert_equal '+', expr.left.operator
    assert_instance_of VariableNode, expr.left.left
    assert_equal "x", expr.left.left.name
    assert_instance_of VariableNode, expr.left.right
    assert_equal "y", expr.left.right.name
    
    # Right side should be 2
    assert_instance_of NumberNode, expr.right
    assert_equal 2, expr.right.value
  end
  
  def test_parse_mixed_numbers_and_variables
    # 10 + x * 3 - y
    lexer = Lexer.new("10 + x * 3 - y")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of BinaryOpNode, ast
    assert_equal '-', ast.operator
    
    # Right side should be y
    assert_instance_of VariableNode, ast.right
    assert_equal "y", ast.right.name
    
    # Left side should be 10 + (x * 3)
    assert_instance_of BinaryOpNode, ast.left
    assert_equal '+', ast.left.operator
    assert_instance_of NumberNode, ast.left.left
    assert_equal 10, ast.left.left.value
    
    # Middle should be x * 3
    assert_instance_of BinaryOpNode, ast.left.right
    assert_equal '*', ast.left.right.operator
    assert_instance_of VariableNode, ast.left.right.left
    assert_equal "x", ast.left.right.left.name
    assert_instance_of NumberNode, ast.left.right.right
    assert_equal 3, ast.left.right.right.value
  end
  
  # Error handling tests
  def test_parse_assignment_missing_equals
    lexer = Lexer.new("x 42")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    
    assert_raises(RuntimeError) do
      parser.parse
    end
  end
  
  def test_parse_assignment_missing_expression
    lexer = Lexer.new("x =")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    
    assert_raises(RuntimeError) do
      parser.parse
    end
  end
  
  def test_parse_assignment_invalid_variable_name
    # Test that numbers can't be assignment targets
    lexer = Lexer.new("42 = x")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    
    # This should parse as an expression "42" and fail on the unexpected "=" token
    assert_raises(RuntimeError) do
      parser.parse
    end
  end
  
  # Ensure existing arithmetic parsing still works
  def test_existing_arithmetic_still_works
    lexer = Lexer.new("2 + 3 * 4")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    # Should still parse as 2 + (3 * 4)
    assert_instance_of BinaryOpNode, ast
    assert_equal '+', ast.operator
    assert_instance_of NumberNode, ast.left
    assert_equal 2, ast.left.value
    assert_instance_of BinaryOpNode, ast.right
    assert_equal '*', ast.right.operator
    assert_equal 3, ast.right.left.value
    assert_equal 4, ast.right.right.value
  end
end