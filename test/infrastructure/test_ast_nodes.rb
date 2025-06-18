require 'minitest/autorun'
require_relative '../../patlang-core/ast/ast_nodes'

class TestASTNodes < Minitest::Test
  # Tests for BooleanNode
  def test_boolean_node_true
    node = BooleanNode.new(true)
    assert_equal true, node.value
    assert_equal "BooleanNode(true)", node.to_s
  end

  def test_boolean_node_false
    node = BooleanNode.new(false)
    assert_equal false, node.value
    assert_equal "BooleanNode(false)", node.to_s
  end

  # Tests for ComparisonNode
  def test_comparison_node_equal
    left = NumberNode.new(5)
    right = NumberNode.new(10)
    node = ComparisonNode.new(left, '==', right)
    
    assert_equal left, node.left
    assert_equal '==', node.operator
    assert_equal right, node.right
    assert_equal "ComparisonNode(NumberNode(5), ==, NumberNode(10))", node.to_s
  end

  def test_comparison_node_not_equal
    left = VariableNode.new('x')
    right = NumberNode.new(42)
    node = ComparisonNode.new(left, '!=', right)
    
    assert_equal left, node.left
    assert_equal '!=', node.operator
    assert_equal right, node.right
    assert_equal "ComparisonNode(VariableNode(x), !=, NumberNode(42))", node.to_s
  end

  def test_comparison_node_less_than
    left = VariableNode.new('age')
    right = NumberNode.new(18)
    node = ComparisonNode.new(left, '<', right)
    
    assert_equal left, node.left
    assert_equal '<', node.operator
    assert_equal right, node.right
    assert_equal "ComparisonNode(VariableNode(age), <, NumberNode(18))", node.to_s
  end

  def test_comparison_node_greater_than
    left = VariableNode.new('score')
    right = NumberNode.new(90)
    node = ComparisonNode.new(left, '>', right)
    
    assert_equal left, node.left
    assert_equal '>', node.operator
    assert_equal right, node.right
    assert_equal "ComparisonNode(VariableNode(score), >, NumberNode(90))", node.to_s
  end

  def test_comparison_node_less_equal
    left = NumberNode.new(10)
    right = VariableNode.new('max_value')
    node = ComparisonNode.new(left, '<=', right)
    
    assert_equal left, node.left
    assert_equal '<=', node.operator
    assert_equal right, node.right
    assert_equal "ComparisonNode(NumberNode(10), <=, VariableNode(max_value))", node.to_s
  end

  def test_comparison_node_greater_equal
    left = VariableNode.new('temperature')
    right = NumberNode.new(32)
    node = ComparisonNode.new(left, '>=', right)
    
    assert_equal left, node.left
    assert_equal '>=', node.operator
    assert_equal right, node.right
    assert_equal "ComparisonNode(VariableNode(temperature), >=, NumberNode(32))", node.to_s
  end

  # Tests for IfNode
  def test_if_node_without_else
    condition = ComparisonNode.new(VariableNode.new('x'), '>', NumberNode.new(0))
    then_body = AssignmentNode.new('result', NumberNode.new(1))
    node = IfNode.new(condition, then_body)
    
    assert_equal condition, node.condition
    assert_equal then_body, node.then_body
    assert_nil node.else_body
    assert_equal "IfNode(ComparisonNode(VariableNode(x), >, NumberNode(0)), AssignmentNode(result, NumberNode(1)))", node.to_s
  end

  def test_if_node_with_else
    condition = ComparisonNode.new(VariableNode.new('x'), '>', NumberNode.new(0))
    then_body = AssignmentNode.new('result', NumberNode.new(1))
    else_body = AssignmentNode.new('result', NumberNode.new(-1))
    node = IfNode.new(condition, then_body, else_body)
    
    assert_equal condition, node.condition
    assert_equal then_body, node.then_body
    assert_equal else_body, node.else_body
    assert_equal "IfNode(ComparisonNode(VariableNode(x), >, NumberNode(0)), AssignmentNode(result, NumberNode(1)), AssignmentNode(result, NumberNode(-1)))", node.to_s
  end

  def test_if_node_with_boolean_condition
    condition = BooleanNode.new(true)
    then_body = VariableNode.new('success')
    node = IfNode.new(condition, then_body)
    
    assert_equal condition, node.condition
    assert_equal then_body, node.then_body
    assert_nil node.else_body
    assert_equal "IfNode(BooleanNode(true), VariableNode(success))", node.to_s
  end

  # Tests for WhileNode
  def test_while_node_simple
    condition = ComparisonNode.new(VariableNode.new('i'), '<', NumberNode.new(10))
    body = AssignmentNode.new('i', BinaryOpNode.new(VariableNode.new('i'), '+', NumberNode.new(1)))
    node = WhileNode.new(condition, body)
    
    assert_equal condition, node.condition
    assert_equal body, node.body
    assert_equal "WhileNode(ComparisonNode(VariableNode(i), <, NumberNode(10)), AssignmentNode(i, BinaryOpNode(VariableNode(i), +, NumberNode(1))))", node.to_s
  end

  def test_while_node_with_boolean_condition
    condition = BooleanNode.new(true)
    body = VariableNode.new('infinite_loop')
    node = WhileNode.new(condition, body)
    
    assert_equal condition, node.condition
    assert_equal body, node.body
    assert_equal "WhileNode(BooleanNode(true), VariableNode(infinite_loop))", node.to_s
  end

  # Tests for BlockNode
  def test_block_node_empty
    node = BlockNode.new
    
    assert_equal [], node.statements
    assert_equal "BlockNode([])", node.to_s
  end

  def test_block_node_with_statements
    statements = [
      AssignmentNode.new('x', NumberNode.new(5)),
      AssignmentNode.new('y', NumberNode.new(10)),
      BinaryOpNode.new(VariableNode.new('x'), '+', VariableNode.new('y'))
    ]
    node = BlockNode.new(statements)
    
    assert_equal statements, node.statements
    assert_equal 3, node.statements.length
    assert_equal "BlockNode([AssignmentNode(x, NumberNode(5)), AssignmentNode(y, NumberNode(10)), BinaryOpNode(VariableNode(x), +, VariableNode(y))])", node.to_s
  end

  def test_block_node_single_statement
    statement = NumberNode.new(42)
    node = BlockNode.new([statement])
    
    assert_equal [statement], node.statements
    assert_equal 1, node.statements.length
    assert_equal "BlockNode([NumberNode(42)])", node.to_s
  end

  # Tests for nested structures
  def test_nested_if_in_while
    # while x < 10 do
    #   if x > 5 then
    #     y = 1
    #   else
    #     y = 0
    #   end
    #   x = x + 1
    # end
    
    while_condition = ComparisonNode.new(VariableNode.new('x'), '<', NumberNode.new(10))
    if_condition = ComparisonNode.new(VariableNode.new('x'), '>', NumberNode.new(5))
    if_then = AssignmentNode.new('y', NumberNode.new(1))
    if_else = AssignmentNode.new('y', NumberNode.new(0))
    if_node = IfNode.new(if_condition, if_then, if_else)
    
    increment = AssignmentNode.new('x', BinaryOpNode.new(VariableNode.new('x'), '+', NumberNode.new(1)))
    while_body = BlockNode.new([if_node, increment])
    while_node = WhileNode.new(while_condition, while_body)
    
    assert_equal while_condition, while_node.condition
    assert_equal while_body, while_node.body
    assert_equal 2, while_body.statements.length
    assert_equal if_node, while_body.statements[0]
    assert_equal increment, while_body.statements[1]
  end

  def test_comparison_with_boolean_literals
    left = BooleanNode.new(true)
    right = BooleanNode.new(false)
    node = ComparisonNode.new(left, '==', right)
    
    assert_equal left, node.left
    assert_equal '==', node.operator
    assert_equal right, node.right
    assert_equal "ComparisonNode(BooleanNode(true), ==, BooleanNode(false))", node.to_s
  end

  # Test inheritance from ASTNode
  def test_ast_node_inheritance
    boolean_node = BooleanNode.new(true)
    comparison_node = ComparisonNode.new(NumberNode.new(1), '==', NumberNode.new(2))
    if_node = IfNode.new(BooleanNode.new(true), NumberNode.new(1))
    while_node = WhileNode.new(BooleanNode.new(true), NumberNode.new(1))
    block_node = BlockNode.new([])
    
    assert_kind_of ASTNode, boolean_node
    assert_kind_of ASTNode, comparison_node
    assert_kind_of ASTNode, if_node
    assert_kind_of ASTNode, while_node
    assert_kind_of ASTNode, block_node
  end
  
  # Tests for new function-related AST nodes
  def test_function_definition_node
    params = [ParameterNode.new("x", "number"), ParameterNode.new("y", "number")]
    body = NumberNode.new(42)
    func_def = FunctionDefinitionNode.new("add", params, body, "number")
    
    assert_equal "add", func_def.name
    assert_equal params, func_def.parameters
    assert_equal body, func_def.body
    assert_equal "number", func_def.return_type
    assert_includes func_def.to_s, "FunctionDefinitionNode"
    assert_includes func_def.to_s, "add"
  end
  
  def test_function_definition_node_without_return_type
    params = []
    body = NumberNode.new(42)
    func_def = FunctionDefinitionNode.new("simple", params, body)
    
    assert_equal "simple", func_def.name
    assert_equal params, func_def.parameters
    assert_equal body, func_def.body
    assert_nil func_def.return_type
  end
  
  def test_function_call_node
    args = [NumberNode.new(1), NumberNode.new(2)]
    func_call = FunctionCallNode.new("add", args)
    
    assert_equal "add", func_call.function_name
    assert_equal args, func_call.arguments
    assert_includes func_call.to_s, "FunctionCallNode"
    assert_includes func_call.to_s, "add"
  end
  
  def test_function_call_node_without_arguments
    func_call = FunctionCallNode.new("get_value")
    
    assert_equal "get_value", func_call.function_name
    assert_equal [], func_call.arguments
  end
  
  def test_parameter_node
    param = ParameterNode.new("count", "number", NumberNode.new(0))
    
    assert_equal "count", param.name
    assert_equal "number", param.type
    assert_equal 0, param.default_value.value
    assert_includes param.to_s, "ParameterNode"
    assert_includes param.to_s, "count"
    assert_includes param.to_s, "number"
  end
  
  def test_parameter_node_without_default
    param = ParameterNode.new("name", "string")
    
    assert_equal "name", param.name
    assert_equal "string", param.type
    assert_nil param.default_value
    refute_includes param.to_s, "NumberNode"
  end
  
  def test_parameter_node_minimal
    param = ParameterNode.new("x")
    
    assert_equal "x", param.name
    assert_nil param.type
    assert_nil param.default_value
  end
  
  def test_return_node_with_expression
    expr = NumberNode.new(42)
    return_node = ReturnNode.new(expr)
    
    assert_equal expr, return_node.expression
    assert_includes return_node.to_s, "ReturnNode"
    assert_includes return_node.to_s, "NumberNode"
  end
  
  def test_return_node_without_expression
    return_node = ReturnNode.new
    
    assert_nil return_node.expression
    assert_includes return_node.to_s, "ReturnNode()"
  end
  
  def test_function_nodes_inheritance
    # Test that function nodes inherit from ASTNode
    func_def = FunctionDefinitionNode.new("test", [], NumberNode.new(1))
    func_call = FunctionCallNode.new("test")
    param = ParameterNode.new("x")
    return_node = ReturnNode.new
    
    assert_kind_of ASTNode, func_def
    assert_kind_of ASTNode, func_call
    assert_kind_of ASTNode, param
    assert_kind_of ASTNode, return_node
  end
end