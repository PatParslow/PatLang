require_relative '../test_helper'
require_relative '../../patlang-core/ast/ast_nodes'

# Comprehensive test suite for AST Nodes - Phase 1 Foundation
# Target: 80%+ coverage for src/ast_nodes.rb
class TestASTNodesComprehensive < Minitest::Test

  # ===== BASE AST NODE TESTS =====
  
  def test_ast_node_base_class
    node = ASTNode.new
    assert_equal "ASTNode", node.to_s
    assert_instance_of ASTNode, node
  end

  # ===== NUMBER NODE TESTS =====
  
  def test_number_node_integer
    node = NumberNode.new(42)
    assert_equal 42, node.value
    assert_equal "NumberNode(42)", node.to_s
    assert_instance_of NumberNode, node
    assert_kind_of ASTNode, node  # Use assert_kind_of for inheritance check
  end

  def test_number_node_float
    node = NumberNode.new(3.14)
    assert_equal 3.14, node.value
    assert_equal "NumberNode(3.14)", node.to_s
  end

  def test_number_node_zero
    node = NumberNode.new(0)
    assert_equal 0, node.value
    assert_equal "NumberNode(0)", node.to_s
  end

  def test_number_node_negative
    node = NumberNode.new(-42)
    assert_equal(-42, node.value)
    assert_equal "NumberNode(-42)", node.to_s
  end

  def test_number_node_edge_cases
    # Test with various numeric edge cases
    [Float::INFINITY, -Float::INFINITY, 0.0, -0.0].each do |value|
      node = NumberNode.new(value)
      assert_equal value, node.value
      assert_includes node.to_s, value.to_s
    end
  end

  # ===== BINARY OPERATION NODE TESTS =====
  
  def test_binary_op_node_basic
    left = NumberNode.new(1)
    right = NumberNode.new(2)
    node = BinaryOpNode.new(left, :+, right)
    
    assert_equal left, node.left
    assert_equal :+, node.operator
    assert_equal right, node.right
    assert_equal "BinaryOpNode(NumberNode(1), +, NumberNode(2))", node.to_s
  end

  def test_binary_op_node_all_operators
    left = NumberNode.new(5)
    right = NumberNode.new(3)
    
    operators = [:+, :-, :*, :/, :%, :==, :!=, :<, :>, :<=, :>=, :and, :or]
    operators.each do |op|
      node = BinaryOpNode.new(left, op, right)
      assert_equal op, node.operator
      assert_includes node.to_s, op.to_s
    end
  end

  def test_binary_op_node_nested
    # Test nested binary operations
    inner_left = NumberNode.new(1)
    inner_right = NumberNode.new(2)
    inner_node = BinaryOpNode.new(inner_left, :+, inner_right)
    
    outer_right = NumberNode.new(3)
    outer_node = BinaryOpNode.new(inner_node, :*, outer_right)
    
    assert_equal inner_node, outer_node.left
    assert_equal :*, outer_node.operator
    assert_equal outer_right, outer_node.right
    assert_includes outer_node.to_s, "BinaryOpNode"
  end

  # ===== UNARY OPERATION NODE TESTS =====
  
  def test_unary_op_node_basic
    operand = NumberNode.new(42)
    node = UnaryOpNode.new(:-, operand)
    
    assert_equal :-, node.operator
    assert_equal operand, node.operand
    assert_equal "UnaryOpNode(-, NumberNode(42))", node.to_s
  end

  def test_unary_op_node_all_operators
    operand = NumberNode.new(5)
    operators = [:-, :+, :!, :not]
    
    operators.each do |op|
      node = UnaryOpNode.new(op, operand)
      assert_equal op, node.operator
      assert_equal operand, node.operand
      assert_includes node.to_s, op.to_s
    end
  end

  def test_unary_op_node_nested
    inner_operand = NumberNode.new(42)
    inner_node = UnaryOpNode.new(:-, inner_operand)
    outer_node = UnaryOpNode.new(:!, inner_node)
    
    assert_equal :!, outer_node.operator
    assert_equal inner_node, outer_node.operand
  end

  # ===== VARIABLE NODE TESTS =====
  
  def test_variable_node_basic
    node = VariableNode.new("x")
    assert_equal "x", node.name
    assert_equal "x", node.value  # Test alias method
    assert_equal "VariableNode(x)", node.to_s
  end

  def test_variable_node_complex_names
    names = ["variable", "var_123", "_private", "CamelCase", "CONSTANT", "a", "xyz"]
    names.each do |name|
      node = VariableNode.new(name)
      assert_equal name, node.name
      assert_equal name, node.value
      assert_includes node.to_s, name
    end
  end

  def test_variable_node_edge_cases
    # Test with nil and empty string
    node_nil = VariableNode.new(nil)
    assert_nil node_nil.name
    assert_nil node_nil.value

    node_empty = VariableNode.new("")
    assert_equal "", node_empty.name
    assert_equal "", node_empty.value
  end

  # ===== ASSIGNMENT NODE TESTS =====
  
  def test_assignment_node_basic
    expr = NumberNode.new(42)
    node = AssignmentNode.new("x", expr)
    
    assert_equal "x", node.name
    assert_equal expr, node.expression
    assert_equal "AssignmentNode(x, NumberNode(42))", node.to_s
  end

  def test_assignment_node_complex_expression
    # Test with binary operation as expression
    left = NumberNode.new(1)
    right = NumberNode.new(2)
    expr = BinaryOpNode.new(left, :+, right)
    node = AssignmentNode.new("result", expr)
    
    assert_equal "result", node.name
    assert_equal expr, node.expression
    assert_includes node.to_s, "BinaryOpNode"
  end

  def test_assignment_node_various_names
    expr = NumberNode.new(1)
    names = ["a", "variable_name", "_private", "CONSTANT"]
    
    names.each do |name|
      node = AssignmentNode.new(name, expr)
      assert_equal name, node.name
      assert_includes node.to_s, name
    end
  end

  # ===== PROPERTY ASSIGNMENT NODE TESTS =====
  
  def test_property_assignment_node_basic
    expr = NumberNode.new(42)
    node = PropertyAssignmentNode.new("obj", "prop", expr)
    
    assert_equal "obj", node.object_name
    assert_equal "prop", node.property_name
    assert_equal expr, node.expression
    assert_equal "PropertyAssignmentNode(obj.prop, NumberNode(42))", node.to_s
  end

  def test_property_assignment_node_complex
    expr = BinaryOpNode.new(NumberNode.new(1), :+, NumberNode.new(2))
    node = PropertyAssignmentNode.new("myObject", "myProperty", expr)
    
    assert_equal "myObject", node.object_name
    assert_equal "myProperty", node.property_name
    assert_equal expr, node.expression
    assert_includes node.to_s, "myObject.myProperty"
  end

  # ===== BOOLEAN NODE TESTS =====
  
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

  def test_boolean_node_edge_cases
    # Test with nil and other truthy/falsy values
    node_nil = BooleanNode.new(nil)
    assert_nil node_nil.value
    assert_equal "BooleanNode()", node_nil.to_s

    node_string = BooleanNode.new("true")
    assert_equal "true", node_string.value
    assert_equal "BooleanNode(true)", node_string.to_s
  end

  # ===== COMPARISON NODE TESTS =====
  
  def test_comparison_node_basic
    left = NumberNode.new(5)
    right = NumberNode.new(3)
    node = ComparisonNode.new(left, :>, right)
    
    assert_equal left, node.left
    assert_equal :>, node.operator
    assert_equal right, node.right
    assert_equal "ComparisonNode(NumberNode(5), >, NumberNode(3))", node.to_s
  end

  def test_comparison_node_all_operators
    left = NumberNode.new(1)
    right = NumberNode.new(2)
    operators = [:==, :!=, :<, :>, :<=, :>=]
    
    operators.each do |op|
      node = ComparisonNode.new(left, op, right)
      assert_equal op, node.operator
      assert_includes node.to_s, op.to_s
    end
  end

  def test_comparison_node_complex_operands
    # Test with variable nodes
    left = VariableNode.new("x")
    right = VariableNode.new("y")
    node = ComparisonNode.new(left, :==, right)
    
    assert_equal left, node.left
    assert_equal right, node.right
    assert_includes node.to_s, "VariableNode"
  end

  # ===== IF NODE TESTS =====
  
  def test_if_node_basic
    condition = BooleanNode.new(true)
    then_body = NumberNode.new(1)
    node = IfNode.new(condition, then_body)
    
    assert_equal condition, node.condition
    assert_equal then_body, node.then_body
    assert_nil node.else_body
    assert_equal "IfNode(BooleanNode(true), NumberNode(1))", node.to_s
  end

  def test_if_node_with_else
    condition = BooleanNode.new(false)
    then_body = NumberNode.new(1)
    else_body = NumberNode.new(2)
    node = IfNode.new(condition, then_body, else_body)
    
    assert_equal condition, node.condition
    assert_equal then_body, node.then_body
    assert_equal else_body, node.else_body
    assert_includes node.to_s, "NumberNode(1), NumberNode(2)"
  end

  def test_if_node_complex_condition
    left = VariableNode.new("x")
    right = NumberNode.new(5)
    condition = ComparisonNode.new(left, :>, right)
    then_body = AssignmentNode.new("result", NumberNode.new(1))
    
    node = IfNode.new(condition, then_body)
    assert_equal condition, node.condition
    assert_equal then_body, node.then_body
    assert_includes node.to_s, "ComparisonNode"
  end

  # ===== WHILE NODE TESTS =====
  
  def test_while_node_basic
    condition = BooleanNode.new(true)
    body = AssignmentNode.new("x", NumberNode.new(1))
    node = WhileNode.new(condition, body)
    
    assert_equal condition, node.condition
    assert_equal body, node.body
    assert_equal "WhileNode(BooleanNode(true), AssignmentNode(x, NumberNode(1)))", node.to_s
  end

  def test_while_node_complex
    left = VariableNode.new("i")
    right = NumberNode.new(10)
    condition = ComparisonNode.new(left, :<, right)
    
    body = AssignmentNode.new("i", BinaryOpNode.new(VariableNode.new("i"), :+, NumberNode.new(1)))
    node = WhileNode.new(condition, body)
    
    assert_equal condition, node.condition
    assert_equal body, node.body
    assert_includes node.to_s, "ComparisonNode"
  end

  # ===== BLOCK NODE TESTS =====
  
  def test_block_node_empty
    node = BlockNode.new
    assert_equal [], node.statements
    assert_equal "BlockNode([])", node.to_s
  end

  def test_block_node_single_statement
    stmt = NumberNode.new(42)
    node = BlockNode.new([stmt])
    
    assert_equal [stmt], node.statements
    assert_equal "BlockNode([NumberNode(42)])", node.to_s
  end

  def test_block_node_multiple_statements
    stmt1 = AssignmentNode.new("x", NumberNode.new(1))
    stmt2 = AssignmentNode.new("y", NumberNode.new(2))
    stmt3 = BinaryOpNode.new(VariableNode.new("x"), :+, VariableNode.new("y"))
    
    node = BlockNode.new([stmt1, stmt2, stmt3])
    assert_equal 3, node.statements.length
    assert_equal stmt1, node.statements[0]
    assert_equal stmt2, node.statements[1]
    assert_equal stmt3, node.statements[2]
    assert_includes node.to_s, "AssignmentNode"
    assert_includes node.to_s, "BinaryOpNode"
  end

  def test_block_node_nested
    inner_block = BlockNode.new([NumberNode.new(1)])
    outer_block = BlockNode.new([inner_block, NumberNode.new(2)])
    
    assert_equal 2, outer_block.statements.length
    assert_equal inner_block, outer_block.statements[0]
    assert_includes outer_block.to_s, "BlockNode"
  end

  # ===== STRING NODE TESTS =====
  
  def test_string_node_basic
    node = StringNode.new("hello")
    assert_equal "hello", node.value
    assert_equal 'StringNode("hello")', node.to_s
  end

  def test_string_node_empty
    node = StringNode.new("")
    assert_equal "", node.value
    assert_equal 'StringNode("")', node.to_s
  end

  def test_string_node_special_characters
    test_cases = [
      "hello\nworld",
      "tab\there",
      "quote\"inside",
      "backslash\\path",
      "unicode: 🚀"
    ]
    
    test_cases.each do |str|
      node = StringNode.new(str)
      assert_equal str, node.value
      assert_includes node.to_s, str.inspect
    end
  end

  def test_string_node_nil
    node = StringNode.new(nil)
    assert_nil node.value
    assert_includes node.to_s, "nil"
  end

  # ===== INDEX ACCESS NODE TESTS =====
  
  def test_index_access_node_basic
    obj = VariableNode.new("array")
    index = NumberNode.new(0)
    node = IndexAccessNode.new(obj, index)
    
    assert_equal obj, node.object
    assert_equal index, node.index
    assert_equal "IndexAccessNode(VariableNode(array), NumberNode(0))", node.to_s
  end

  def test_index_access_node_string_index
    obj = StringNode.new("hello")
    index = NumberNode.new(1)
    node = IndexAccessNode.new(obj, index)
    
    assert_equal obj, node.object
    assert_equal index, node.index
    assert_includes node.to_s, "StringNode"
    assert_includes node.to_s, "NumberNode(1)"
  end

  def test_index_access_node_variable_index
    obj = VariableNode.new("data")
    index = VariableNode.new("i")
    node = IndexAccessNode.new(obj, index)
    
    assert_equal obj, node.object
    assert_equal index, node.index
    assert_includes node.to_s, "VariableNode(data)"
    assert_includes node.to_s, "VariableNode(i)"
  end

  # ===== METHOD CALL NODE TESTS =====
  
  def test_method_call_node_no_args
    obj = VariableNode.new("string")
    node = MethodCallNode.new(obj, "length")
    
    assert_equal obj, node.object
    assert_equal "length", node.method_name
    assert_equal [], node.arguments
    assert_equal "MethodCallNode(VariableNode(string), length, [])", node.to_s
  end

  def test_method_call_node_with_args
    obj = VariableNode.new("string")
    args = [NumberNode.new(0), NumberNode.new(5)]
    node = MethodCallNode.new(obj, "substring", args)
    
    assert_equal obj, node.object
    assert_equal "substring", node.method_name
    assert_equal args, node.arguments
    assert_includes node.to_s, "substring"
    # Array objects in to_s don't expand to individual node strings
    assert_includes node.to_s, args.inspect
  end

  def test_method_call_node_complex
    obj = StringNode.new("hello world")
    args = [StringNode.new(" ")]
    node = MethodCallNode.new(obj, "split", args)
    
    assert_equal obj, node.object
    assert_equal "split", node.method_name
    assert_equal args, node.arguments
    assert_includes node.to_s, "split"
  end

  # ===== FUNCTION DEFINITION NODE TESTS =====
  
  def test_function_definition_node_basic
    params = [ParameterNode.new("x")]
    body = BlockNode.new([ReturnNode.new(VariableNode.new("x"))])
    node = FunctionDefinitionNode.new("identity", params, body)
    
    assert_equal "identity", node.name
    assert_equal params, node.parameters
    assert_equal body, node.body
    assert_nil node.return_type
    assert_includes node.to_s, "identity"
  end

  def test_function_definition_node_with_return_type
    params = [ParameterNode.new("x")]
    body = BlockNode.new([ReturnNode.new(VariableNode.new("x"))])
    node = FunctionDefinitionNode.new("func", params, body, "Number")
    
    assert_equal "func", node.name
    assert_equal params, node.parameters
    assert_equal body, node.body
    assert_equal "Number", node.return_type
  end

  def test_function_definition_node_no_params
    body = BlockNode.new([ReturnNode.new(NumberNode.new(42))])
    node = FunctionDefinitionNode.new("answer", [], body)
    
    assert_equal "answer", node.name
    assert_equal [], node.parameters
    assert_equal body, node.body
  end

  # ===== FUNCTION CALL NODE TESTS =====
  
  def test_function_call_node_no_args
    node = FunctionCallNode.new("function")
    
    assert_equal "function", node.function_name
    assert_equal [], node.arguments
    assert_equal "FunctionCallNode(function, [])", node.to_s
  end

  def test_function_call_node_with_args
    args = [NumberNode.new(1), NumberNode.new(2)]
    node = FunctionCallNode.new("add", args)
    
    assert_equal "add", node.function_name
    assert_equal args, node.arguments
    assert_includes node.to_s, "add"
    # Array objects in to_s don't expand to individual node strings
    assert_includes node.to_s, args.inspect
  end

  # ===== PARAMETER NODE TESTS =====
  
  def test_parameter_node_basic
    node = ParameterNode.new("x")
    
    assert_equal "x", node.name
    assert_nil node.type
    assert_nil node.default_value
    assert_equal true, node.required?
    # Check the actual format from the implementation
    assert_includes node.to_s, "x"
    assert_includes node.to_s, "ParameterNode"
  end

  def test_parameter_node_with_type
    node = ParameterNode.new("x", "Number")
    
    assert_equal "x", node.name
    assert_equal "Number", node.type
    assert_equal "Number", node.type_constraint  # Test alias
    assert_nil node.default_value
    assert_equal true, node.required?
  end

  def test_parameter_node_with_default
    default_val = NumberNode.new(0)
    node = ParameterNode.new("x", "Number", default_val)
    
    assert_equal "x", node.name
    assert_equal "Number", node.type
    assert_equal default_val, node.default_value
    assert_equal true, node.required?
  end

  def test_parameter_node_optional
    node = ParameterNode.new("x", "Number", nil, false)
    
    assert_equal "x", node.name
    assert_equal "Number", node.type
    assert_nil node.default_value
    assert_equal false, node.required?
    assert_includes node.to_s, "?"
  end

  # ===== RETURN NODE TESTS =====
  
  def test_return_node_with_expression
    expr = NumberNode.new(42)
    node = ReturnNode.new(expr)
    
    assert_equal expr, node.expression
    assert_equal "ReturnNode(NumberNode(42))", node.to_s
  end

  def test_return_node_without_expression
    node = ReturnNode.new
    
    assert_nil node.expression
    assert_equal "ReturnNode()", node.to_s
  end

  def test_return_node_complex_expression
    expr = BinaryOpNode.new(NumberNode.new(1), :+, NumberNode.new(2))
    node = ReturnNode.new(expr)
    
    assert_equal expr, node.expression
    assert_includes node.to_s, "BinaryOpNode"
  end

  # ===== AUTO OUTPUT NODE TESTS =====
  
  def test_auto_output_node_basic
    expr = StringNode.new("Hello, World!")
    node = AutoOutputNode.new(expr)
    
    assert_equal expr, node.expression
    assert_equal "AutoOutputNode(StringNode(\"Hello, World!\"))", node.to_s
  end

  def test_auto_output_node_complex
    expr = BinaryOpNode.new(NumberNode.new(2), :*, NumberNode.new(3))
    node = AutoOutputNode.new(expr)
    
    assert_equal expr, node.expression
    assert_includes node.to_s, "BinaryOpNode"
  end

  # ===== PRINT NODE TESTS =====
  
  def test_print_node_basic
    expr = StringNode.new("Debug output")
    node = PrintNode.new(expr)
    
    assert_equal expr, node.expression
    assert_equal "PrintNode(StringNode(\"Debug output\"))", node.to_s
  end

  def test_print_node_variable
    expr = VariableNode.new("result")
    node = PrintNode.new(expr)
    
    assert_equal expr, node.expression
    assert_includes node.to_s, "VariableNode(result)"
  end

  # ===== ERROR NODE TESTS =====
  
  def test_error_node_basic
    node = ErrorNode.new("Syntax error")
    
    assert_equal "Syntax error", node.message
    assert_nil node.recovered_value
    assert_equal "ErrorNode(\"Syntax error\")", node.to_s
  end

  def test_error_node_with_recovery
    recovery = NumberNode.new(0)
    node = ErrorNode.new("Parse error", recovery)
    
    assert_equal "Parse error", node.message
    assert_equal recovery, node.recovered_value
    assert_includes node.to_s, "Parse error"
  end

  # ===== PROGRAM NODE TESTS =====
  
  def test_program_node_empty
    node = ProgramNode.new([])
    
    assert_equal [], node.statements
    assert_equal "ProgramNode(0 statements)", node.to_s
  end

  def test_program_node_with_statements
    stmts = [
      AssignmentNode.new("x", NumberNode.new(1)),
      AssignmentNode.new("y", NumberNode.new(2)),
      BinaryOpNode.new(VariableNode.new("x"), :+, VariableNode.new("y"))
    ]
    node = ProgramNode.new(stmts)
    
    assert_equal stmts, node.statements
    assert_equal "ProgramNode(3 statements)", node.to_s
  end

  # ===== EDGE CASES AND ERROR CONDITIONS =====
  
  def test_node_inheritance_hierarchy
    # Test that all nodes inherit from ASTNode
    node_classes = [
      NumberNode, BinaryOpNode, UnaryOpNode, VariableNode, AssignmentNode,
      PropertyAssignmentNode, BooleanNode, ComparisonNode, IfNode, WhileNode,
      BlockNode, StringNode, IndexAccessNode, MethodCallNode, FunctionDefinitionNode,
      FunctionCallNode, ParameterNode, ReturnNode, AutoOutputNode, PrintNode,
      ErrorNode, ProgramNode
    ]
    
    node_classes.each do |klass|
      assert klass < ASTNode, "#{klass} should inherit from ASTNode"
    end
  end

  def test_node_serialization_consistency
    # Test that to_s is consistent and doesn't raise errors
    nodes = [
      NumberNode.new(42),
      BinaryOpNode.new(NumberNode.new(1), :+, NumberNode.new(2)),
      VariableNode.new("test"),
      StringNode.new("hello"),
      BooleanNode.new(true),
      ErrorNode.new("test error")
    ]
    
    nodes.each do |node|
      assert_nothing_raised { node.to_s }
      assert_instance_of String, node.to_s
      refute_empty node.to_s
    end
  end

  def test_node_attribute_access
    # Test that all expected attributes are accessible
    number_node = NumberNode.new(42)
    assert_respond_to number_node, :value

    binary_node = BinaryOpNode.new(NumberNode.new(1), :+, NumberNode.new(2))
    assert_respond_to binary_node, :left
    assert_respond_to binary_node, :operator
    assert_respond_to binary_node, :right

    variable_node = VariableNode.new("x")
    assert_respond_to variable_node, :name
    assert_respond_to variable_node, :value
  end

end