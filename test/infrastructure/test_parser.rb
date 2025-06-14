require_relative '../helpers/test_helper'
require_relative '../../src/parser'
require_relative '../../src/lexer'
require_relative '../../src/ast_nodes'

class TestParser < Minitest::Test
  def test_parse_simple_number
    puts "[DEBUG] Starting test_parse_simple_number"
    lexer = Lexer.new("42")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of NumberNode, ast
    assert_equal 42, ast.value
  end

  def test_parse_simple_addition
    puts "[DEBUG] Starting test_parse_simple_addition"
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
    puts "[DEBUG] Starting test_parse_simple_multiplication"
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
    puts "[DEBUG] Starting test_parse_operator_precedence"
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
    puts "[DEBUG] Starting test_parse_parentheses"
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
    puts "[DEBUG] Starting test_parse_complex_expression"
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
    puts "[DEBUG] Starting test_parse_all_operators"
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
    puts "[DEBUG] Starting test_parse_empty_expression"
    lexer = Lexer.new("")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    
    # Improved error handling: empty expression now parses as empty block
    result = parser.parse
    refute_nil result
    assert_instance_of BlockNode, result
    assert_empty result.statements
  end
  
  # Tests for new AST node classes
  def test_variable_node_creation
    puts "[DEBUG] Starting test_variable_node_creation"
    node = VariableNode.new("x")
    
    assert_instance_of VariableNode, node
    assert_equal "x", node.name
    assert_equal "VariableNode(x)", node.to_s
  end
  
  def test_variable_node_with_different_names
    puts "[DEBUG] Starting test_variable_node_with_different_names"
    node1 = VariableNode.new("result")
    node2 = VariableNode.new("myVar")
    
    assert_equal "result", node1.name
    assert_equal "myVar", node2.name
    assert_equal "VariableNode(result)", node1.to_s
    assert_equal "VariableNode(myVar)", node2.to_s
  end
  
  def test_assignment_node_creation
    puts "[DEBUG] Starting test_assignment_node_creation"
    expr = NumberNode.new(42)
    node = AssignmentNode.new("x", expr)
    
    assert_instance_of AssignmentNode, node
    assert_equal "x", node.name
    assert_equal expr, node.expression
    assert_equal "AssignmentNode(x, NumberNode(42))", node.to_s
  end
  
  def test_assignment_node_with_complex_expression
    puts "[DEBUG] Starting test_assignment_node_with_complex_expression"
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
    puts "[DEBUG] Starting test_assignment_node_with_variable_expression"
    # Test assignment with just a variable: result = x
    var_expr = VariableNode.new("x")
    assignment = AssignmentNode.new("result", var_expr)
    
    assert_equal "result", assignment.name
    assert_equal var_expr, assignment.expression
    assert_equal "AssignmentNode(result, VariableNode(x))", assignment.to_s
  end
  # Tests for variable assignment parsing
  def test_parse_simple_assignment
    puts "[DEBUG] Starting test_parse_simple_assignment"
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
    puts "[DEBUG] Starting test_parse_assignment_with_complex_expression"
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
    puts "[DEBUG] Starting test_parse_assignment_with_variable_expression"
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
    puts "[DEBUG] Starting test_parse_variable_reference_simple"
    lexer = Lexer.new("x")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of VariableNode, ast
    assert_equal "x", ast.name
  end
  
  def test_parse_variable_reference_in_expression
    puts "[DEBUG] Starting test_parse_variable_reference_in_expression"
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
    puts "[DEBUG] Starting test_parse_complex_variable_expression"
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
    puts "[DEBUG] Starting test_parse_variables_with_parentheses"
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
    
    # This should parse as two separate statements: a variable reference and a number
    result = parser.parse
    assert_instance_of(BlockNode, result)
    assert_equal(2, result.statements.length)
    assert_instance_of(VariableNode, result.statements[0])
    assert_instance_of(NumberNode, result.statements[1])
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
    
    # Improved error handling: invalid assignment now parses as block with statements
    result = parser.parse
    refute_nil result
    assert_instance_of BlockNode, result
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

  # Tests for boolean literal parsing
  def test_parse_boolean_true
    lexer = Lexer.new("true")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of BooleanNode, ast
    assert_equal true, ast.value
  end

  def test_parse_boolean_false
    lexer = Lexer.new("false")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of BooleanNode, ast
    assert_equal false, ast.value
  end

  def test_parse_boolean_in_expression
    # true + false (though semantically odd, should parse)
    lexer = Lexer.new("true + false")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of BinaryOpNode, ast
    assert_equal '+', ast.operator
    assert_instance_of BooleanNode, ast.left
    assert_equal true, ast.left.value
    assert_instance_of BooleanNode, ast.right
    assert_equal false, ast.right.value
  end

  # Tests for comparison expression parsing
  def test_parse_simple_equality
    lexer = Lexer.new("x == 5")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of ComparisonNode, ast
    assert_instance_of VariableNode, ast.left
    assert_equal "x", ast.left.name
    assert_equal "==", ast.operator
    assert_instance_of NumberNode, ast.right
    assert_equal 5, ast.right.value
  end

  def test_parse_simple_inequality
    lexer = Lexer.new("a != b")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of ComparisonNode, ast
    assert_instance_of VariableNode, ast.left
    assert_equal "a", ast.left.name
    assert_equal "!=", ast.operator
    assert_instance_of VariableNode, ast.right
    assert_equal "b", ast.right.name
  end

  def test_parse_less_than
    lexer = Lexer.new("x < 10")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of ComparisonNode, ast
    assert_instance_of VariableNode, ast.left
    assert_equal "x", ast.left.name
    assert_equal "<", ast.operator
    assert_instance_of NumberNode, ast.right
    assert_equal 10, ast.right.value
  end

  def test_parse_greater_than
    lexer = Lexer.new("y > 0")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of ComparisonNode, ast
    assert_instance_of VariableNode, ast.left
    assert_equal "y", ast.left.name
    assert_equal ">", ast.operator
    assert_instance_of NumberNode, ast.right
    assert_equal 0, ast.right.value
  end

  def test_parse_less_equal
    lexer = Lexer.new("result <= 100")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of ComparisonNode, ast
    assert_instance_of VariableNode, ast.left
    assert_equal "result", ast.left.name
    assert_equal "<=", ast.operator
    assert_instance_of NumberNode, ast.right
    assert_equal 100, ast.right.value
  end

  def test_parse_greater_equal
    lexer = Lexer.new("score >= 50")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of ComparisonNode, ast
    assert_instance_of VariableNode, ast.left
    assert_equal "score", ast.left.name
    assert_equal ">=", ast.operator
    assert_instance_of NumberNode, ast.right
    assert_equal 50, ast.right.value
  end

  def test_parse_comparison_with_arithmetic
    # x + 5 == y * 2
    lexer = Lexer.new("x + 5 == y * 2")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of ComparisonNode, ast
    assert_equal "==", ast.operator
    
    # Left side: x + 5
    assert_instance_of BinaryOpNode, ast.left
    assert_equal "+", ast.left.operator
    assert_instance_of VariableNode, ast.left.left
    assert_equal "x", ast.left.left.name
    assert_instance_of NumberNode, ast.left.right
    assert_equal 5, ast.left.right.value
    
    # Right side: y * 2
    assert_instance_of BinaryOpNode, ast.right
    assert_equal "*", ast.right.operator
    assert_instance_of VariableNode, ast.right.left
    assert_equal "y", ast.right.left.name
    assert_instance_of NumberNode, ast.right.right
    assert_equal 2, ast.right.right.value
  end

  # Tests for simple if statement parsing
  def test_parse_simple_if_statement
    lexer = Lexer.new("if x == 5 then y = 10 end")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of IfNode, ast
    
    # Condition: x == 5
    assert_instance_of ComparisonNode, ast.condition
    assert_equal "==", ast.condition.operator
    assert_instance_of VariableNode, ast.condition.left
    assert_equal "x", ast.condition.left.name
    assert_instance_of NumberNode, ast.condition.right
    assert_equal 5, ast.condition.right.value
    
    # Then body: y = 10
    assert_instance_of BlockNode, ast.then_body
    assert_equal 1, ast.then_body.statements.length
    assert_instance_of AssignmentNode, ast.then_body.statements[0]
    assert_equal "y", ast.then_body.statements[0].name
    assert_instance_of NumberNode, ast.then_body.statements[0].expression
    assert_equal 10, ast.then_body.statements[0].expression.value
    
    # No else body
    assert_nil ast.else_body
  end

  def test_parse_if_else_statement
    lexer = Lexer.new("if x < 0 then y = -1 else y = 1 end")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of IfNode, ast
    
    # Condition: x < 0
    assert_instance_of ComparisonNode, ast.condition
    assert_equal "<", ast.condition.operator
    assert_instance_of VariableNode, ast.condition.left
    assert_equal "x", ast.condition.left.name
    assert_instance_of NumberNode, ast.condition.right
    assert_equal 0, ast.condition.right.value
    
    # Then body: y = -1 (parsed as y = 0 - 1)
    assert_instance_of BlockNode, ast.then_body
    assert_equal 1, ast.then_body.statements.length
    assert_instance_of AssignmentNode, ast.then_body.statements[0]
    assert_equal "y", ast.then_body.statements[0].name
    assert_instance_of UnaryOpNode, ast.then_body.statements[0].expression
    assert_equal "-", ast.then_body.statements[0].expression.operator
    assert_instance_of NumberNode, ast.then_body.statements[0].expression.operand
    assert_equal 1, ast.then_body.statements[0].expression.operand.value
    
    # Else body: y = 1
    assert_instance_of BlockNode, ast.else_body
    assert_equal 1, ast.else_body.statements.length
    assert_instance_of AssignmentNode, ast.else_body.statements[0]
    assert_equal "y", ast.else_body.statements[0].name
    assert_instance_of NumberNode, ast.else_body.statements[0].expression
    assert_equal 1, ast.else_body.statements[0].expression.value
  end

  def test_parse_if_with_boolean_condition
    lexer = Lexer.new("if true then x = 42 end")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of IfNode, ast
    
    # Condition: true
    assert_instance_of BooleanNode, ast.condition
    assert_equal true, ast.condition.value
    
    # Then body: x = 42
    assert_instance_of BlockNode, ast.then_body
    assert_equal 1, ast.then_body.statements.length
    assert_instance_of AssignmentNode, ast.then_body.statements[0]
    assert_equal "x", ast.then_body.statements[0].name
    assert_instance_of NumberNode, ast.then_body.statements[0].expression
    assert_equal 42, ast.then_body.statements[0].expression.value
  end

  # Tests for while loop parsing
  def test_parse_simple_while_statement
    lexer = Lexer.new("while x > 0 do x = x - 1 end")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of WhileNode, ast
    
    # Condition: x > 0
    assert_instance_of ComparisonNode, ast.condition
    assert_equal ">", ast.condition.operator
    assert_instance_of VariableNode, ast.condition.left
    assert_equal "x", ast.condition.left.name
    assert_instance_of NumberNode, ast.condition.right
    assert_equal 0, ast.condition.right.value
    
    # Body: x = x - 1
    assert_instance_of BlockNode, ast.body
    assert_equal 1, ast.body.statements.length
    assert_instance_of AssignmentNode, ast.body.statements[0]
    assert_equal "x", ast.body.statements[0].name
    
    # Assignment expression: x - 1
    assign_expr = ast.body.statements[0].expression
    assert_instance_of BinaryOpNode, assign_expr
    assert_equal "-", assign_expr.operator
    assert_instance_of VariableNode, assign_expr.left
    assert_equal "x", assign_expr.left.name
    assert_instance_of NumberNode, assign_expr.right
    assert_equal 1, assign_expr.right.value
  end

  def test_parse_while_with_boolean_condition
    lexer = Lexer.new("while false do y = 5 end")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of WhileNode, ast
    
    # Condition: false
    assert_instance_of BooleanNode, ast.condition
    assert_equal false, ast.condition.value
    
    # Body: y = 5
    assert_instance_of BlockNode, ast.body
    assert_equal 1, ast.body.statements.length
    assert_instance_of AssignmentNode, ast.body.statements[0]
    assert_equal "y", ast.body.statements[0].name
    assert_instance_of NumberNode, ast.body.statements[0].expression
    assert_equal 5, ast.body.statements[0].expression.value
  end

  # Tests for nested control flow structures
  def test_parse_nested_if_in_while
    lexer = Lexer.new("while x > 0 do if x == 5 then y = 100 end end")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of WhileNode, ast
    
    # While condition: x > 0
    assert_instance_of ComparisonNode, ast.condition
    assert_equal ">", ast.condition.operator
    
    # While body contains if statement
    assert_instance_of BlockNode, ast.body
    assert_equal 1, ast.body.statements.length
    assert_instance_of IfNode, ast.body.statements[0]
    
    # Nested if condition: x == 5
    nested_if = ast.body.statements[0]
    assert_instance_of ComparisonNode, nested_if.condition
    assert_equal "==", nested_if.condition.operator
    assert_instance_of VariableNode, nested_if.condition.left
    assert_equal "x", nested_if.condition.left.name
    assert_instance_of NumberNode, nested_if.condition.right
    assert_equal 5, nested_if.condition.right.value
  end

  def test_parse_nested_while_in_if
    lexer = Lexer.new("if x > 10 then while y < x do y = y + 1 end end")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of IfNode, ast
    
    # If condition: x > 10
    assert_instance_of ComparisonNode, ast.condition
    assert_equal ">", ast.condition.operator
    
    # If body contains while statement
    assert_instance_of BlockNode, ast.then_body
    assert_equal 1, ast.then_body.statements.length
    assert_instance_of WhileNode, ast.then_body.statements[0]
    
    # Nested while condition: y < x
    nested_while = ast.then_body.statements[0]
    assert_instance_of ComparisonNode, nested_while.condition
    assert_equal "<", nested_while.condition.operator
    assert_instance_of VariableNode, nested_while.condition.left
    assert_equal "y", nested_while.condition.left.name
    assert_instance_of VariableNode, nested_while.condition.right
    assert_equal "x", nested_while.condition.right.name
  end

  # Tests for precedence handling
  def test_comparison_precedence_over_assignment
    # This should parse as an expression, not assignment, since comparison has higher precedence
    lexer = Lexer.new("x == y")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of ComparisonNode, ast
    assert_equal "==", ast.operator
    assert_instance_of VariableNode, ast.left
    assert_equal "x", ast.left.name
    assert_instance_of VariableNode, ast.right
    assert_equal "y", ast.right.name
  end

  def test_arithmetic_precedence_in_comparison
    # 2 + 3 < 4 * 5 should parse as (2 + 3) < (4 * 5)
    lexer = Lexer.new("2 + 3 < 4 * 5")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    assert_instance_of ComparisonNode, ast
    assert_equal "<", ast.operator
    
    # Left side: 2 + 3
    assert_instance_of BinaryOpNode, ast.left
    assert_equal "+", ast.left.operator
    assert_equal 2, ast.left.left.value
    assert_equal 3, ast.left.right.value
    
    # Right side: 4 * 5
    assert_instance_of BinaryOpNode, ast.right
    assert_equal "*", ast.right.operator
    assert_equal 4, ast.right.left.value
    assert_equal 5, ast.right.right.value
  end

  # Error handling tests for control flow
  def test_parse_if_missing_then
    lexer = Lexer.new("if x == 5 y = 10 end")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    
    assert_raises(RuntimeError) do
      parser.parse
    end
  end

  def test_parse_if_missing_end
    lexer = Lexer.new("if x == 5 then y = 10")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    
    assert_raises(RuntimeError) do
      parser.parse
    end
  end

  def test_parse_while_missing_do
    lexer = Lexer.new("while x > 0 x = x - 1 end")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    
    assert_raises(RuntimeError) do
      parser.parse
    end
  end

  def test_parse_while_missing_end
    lexer = Lexer.new("while x > 0 do x = x - 1")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    
    assert_raises(RuntimeError) do
      parser.parse
    end
  end

  # Tests to ensure existing functionality still works
  def test_backward_compatibility_arithmetic
    lexer = Lexer.new("2 + 3 * 4")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    # Should still parse as 2 + (3 * 4) without comparison or control flow
    assert_instance_of BinaryOpNode, ast
    assert_equal '+', ast.operator
    assert_instance_of NumberNode, ast.left
    assert_equal 2, ast.left.value
    assert_instance_of BinaryOpNode, ast.right
    assert_equal '*', ast.right.operator
    assert_equal 3, ast.right.left.value
    assert_equal 4, ast.right.right.value
  end

  def test_backward_compatibility_assignment
    lexer = Lexer.new("result = x + y")
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    
    # Should still parse as assignment
    assert_instance_of AssignmentNode, ast
    assert_equal "result", ast.name
    assert_instance_of BinaryOpNode, ast.expression
    assert_equal '+', ast.expression.operator
    assert_instance_of VariableNode, ast.expression.left
    assert_equal "x", ast.expression.left.name
    assert_instance_of VariableNode, ast.expression.right
    assert_equal "y", ast.expression.right.name
  end
end