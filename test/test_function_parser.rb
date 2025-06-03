require_relative 'test_helper'
require_relative '../src/parser'
require_relative '../src/lexer'
require_relative '../src/token'

class TestFunctionParser < Minitest::Test
  def setup
    # No setup needed, lexer will be created per test
  end

  def parse_input(input)
    lexer = Lexer.new(input)
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    parser.parse
  end

  def test_basic_function_definition_without_parameters
    input = "make a function called greet { x = 5 }"
    ast = parse_input(input)
    
    assert_instance_of FunctionDefinitionNode, ast
    assert_equal "greet", ast.name
    assert_empty ast.parameters
    assert_nil ast.return_type
    assert_instance_of BlockNode, ast.body
  end

  def test_function_definition_with_single_parameter
    input = "make a function called add takes: x { return x }"
    ast = parse_input(input)
    
    assert_instance_of FunctionDefinitionNode, ast
    assert_equal "add", ast.name
    assert_equal 1, ast.parameters.length
    assert_equal "x", ast.parameters[0].name
    assert_nil ast.parameters[0].type
    assert_nil ast.return_type
  end

  def test_function_definition_with_typed_parameter
    input = "make a function called add takes: x-number { return x }"
    ast = parse_input(input)
    
    assert_instance_of FunctionDefinitionNode, ast
    assert_equal "add", ast.name
    assert_equal 1, ast.parameters.length
    assert_equal "x", ast.parameters[0].name
    assert_equal "number", ast.parameters[0].type
  end

  def test_function_definition_with_multiple_parameters
    input = "make a function called calculate takes: x-number, y-string, z { return x }"
    ast = parse_input(input)
    
    assert_instance_of FunctionDefinitionNode, ast
    assert_equal "calculate", ast.name
    assert_equal 3, ast.parameters.length
    
    assert_equal "x", ast.parameters[0].name
    assert_equal "number", ast.parameters[0].type
    
    assert_equal "y", ast.parameters[1].name
    assert_equal "string", ast.parameters[1].type
    
    assert_equal "z", ast.parameters[2].name
    assert_nil ast.parameters[2].type
  end

  def test_function_definition_with_return_type
    input = "make a function called getValue returns: number { return 42 }"
    ast = parse_input(input)
    
    assert_instance_of FunctionDefinitionNode, ast
    assert_equal "getValue", ast.name
    assert_empty ast.parameters
    assert_equal "number", ast.return_type
  end

  def test_function_definition_with_parameters_and_return_type
    input = "make a function called process takes: data-string returns: boolean { return true }"
    ast = parse_input(input)
    
    assert_instance_of FunctionDefinitionNode, ast
    assert_equal "process", ast.name
    assert_equal 1, ast.parameters.length
    assert_equal "data", ast.parameters[0].name
    assert_equal "string", ast.parameters[0].type
    assert_equal "boolean", ast.return_type
  end

  def test_function_definition_with_complex_body
    input = "make a function called complex takes: x, y { if x then z = y else z = 0 end return z }"
    ast = parse_input(input)
    
    assert_instance_of FunctionDefinitionNode, ast
    assert_equal "complex", ast.name
    assert_equal 2, ast.parameters.length
    assert_instance_of BlockNode, ast.body
    assert_equal 2, ast.body.statements.length
    assert_instance_of IfNode, ast.body.statements[0]
    assert_instance_of ReturnNode, ast.body.statements[1]
  end

  def test_basic_function_call_without_arguments
    input = "call greet"
    ast = parse_input(input)
    
    assert_instance_of FunctionCallNode, ast
    assert_equal "greet", ast.function_name
    assert_empty ast.arguments
  end

  def test_function_call_with_single_argument
    input = "call add with 5"
    ast = parse_input(input)
    
    assert_instance_of FunctionCallNode, ast
    assert_equal "add", ast.function_name
    assert_equal 1, ast.arguments.length
    assert_instance_of NumberNode, ast.arguments[0]
    assert_equal 5, ast.arguments[0].value
  end

  def test_function_call_with_multiple_arguments
    input = "call calculate with 10, \"hello\", x"
    ast = parse_input(input)
    
    assert_instance_of FunctionCallNode, ast
    assert_equal "calculate", ast.function_name
    assert_equal 3, ast.arguments.length
    
    assert_instance_of NumberNode, ast.arguments[0]
    assert_equal 10, ast.arguments[0].value
    
    assert_instance_of StringNode, ast.arguments[1]
    assert_equal "hello", ast.arguments[1].value
    
    assert_instance_of VariableNode, ast.arguments[2]
    assert_equal "x", ast.arguments[2].name
  end

  def test_function_call_with_complex_arguments
    input = "call process with x + y, call helper"
    ast = parse_input(input)
    
    assert_instance_of FunctionCallNode, ast
    assert_equal "process", ast.function_name
    assert_equal 2, ast.arguments.length
    
    assert_instance_of BinaryOpNode, ast.arguments[0]
    assert_instance_of FunctionCallNode, ast.arguments[1]
    assert_equal "helper", ast.arguments[1].function_name
  end

  def test_function_call_in_expression
    input = "x = call getValue"
    ast = parse_input(input)
    
    assert_instance_of AssignmentNode, ast
    assert_equal "x", ast.name
    assert_instance_of FunctionCallNode, ast.expression
    assert_equal "getValue", ast.expression.function_name
  end

  def test_function_call_in_arithmetic
    input = "result = call add with 5, 3 + 2"
    ast = parse_input(input)
    
    assert_instance_of AssignmentNode, ast
    assert_instance_of FunctionCallNode, ast.expression
    assert_equal "add", ast.expression.function_name
    assert_equal 2, ast.expression.arguments.length
    assert_instance_of BinaryOpNode, ast.expression.arguments[1]
  end

  def test_return_statement_without_expression
    input = "return"
    ast = parse_input(input)
    
    assert_instance_of ReturnNode, ast
    assert_nil ast.expression
  end

  def test_return_statement_with_value
    input = "return 42"
    ast = parse_input(input)
    
    assert_instance_of ReturnNode, ast
    assert_instance_of NumberNode, ast.expression
    assert_equal 42, ast.expression.value
  end

  def test_return_statement_with_expression
    input = "return x + y * 2"
    ast = parse_input(input)
    
    assert_instance_of ReturnNode, ast
    assert_instance_of BinaryOpNode, ast.expression
    assert_equal "+", ast.expression.operator
  end

  def test_return_statement_with_function_call
    input = "return call helper with x"
    ast = parse_input(input)
    
    assert_instance_of ReturnNode, ast
    assert_instance_of FunctionCallNode, ast.expression
    assert_equal "helper", ast.expression.function_name
  end

  def test_return_statement_with_string
    input = "return \"success\""
    ast = parse_input(input)
    
    assert_instance_of ReturnNode, ast
    assert_instance_of StringNode, ast.expression
    assert_equal "success", ast.expression.value
  end

  def test_nested_function_calls
    input = "call outer with call inner"
    ast = parse_input(input)
    
    assert_instance_of FunctionCallNode, ast
    assert_equal "outer", ast.function_name
    assert_equal 1, ast.arguments.length
    assert_instance_of FunctionCallNode, ast.arguments[0]
    assert_equal "inner", ast.arguments[0].function_name
  end

  def test_function_definition_with_nested_function_calls
    input = "make a function called wrapper { return call helper with call getValue }"
    ast = parse_input(input)
    
    assert_instance_of FunctionDefinitionNode, ast
    assert_equal "wrapper", ast.name
    assert_instance_of BlockNode, ast.body
    assert_equal 1, ast.body.statements.length
    
    return_stmt = ast.body.statements[0]
    assert_instance_of ReturnNode, return_stmt
    assert_instance_of FunctionCallNode, return_stmt.expression
    assert_equal "helper", return_stmt.expression.function_name
  end

  def test_function_with_control_flow
    input = "make a function called conditional takes: flag { if flag then return call success else return call failure end }"
    ast = parse_input(input)
    
    assert_instance_of FunctionDefinitionNode, ast
    assert_equal "conditional", ast.name
    assert_equal 1, ast.parameters.length
    
    if_stmt = ast.body.statements[0]
    assert_instance_of IfNode, if_stmt
    
    # Check then branch
    then_return = if_stmt.then_body.statements[0]
    assert_instance_of ReturnNode, then_return
    assert_instance_of FunctionCallNode, then_return.expression
    assert_equal "success", then_return.expression.function_name
    
    # Check else branch
    else_return = if_stmt.else_body.statements[0]
    assert_instance_of ReturnNode, else_return
    assert_instance_of FunctionCallNode, else_return.expression
    assert_equal "failure", else_return.expression.function_name
  end

  def test_multiple_function_definitions
    input = "make a function called first { return 1 } make a function called second { return 2 }"
    ast = parse_input(input)
    
    assert_instance_of BlockNode, ast
    assert_equal 2, ast.statements.length
    
    assert_instance_of FunctionDefinitionNode, ast.statements[0]
    assert_equal "first", ast.statements[0].name
    
    assert_instance_of FunctionDefinitionNode, ast.statements[1]
    assert_equal "second", ast.statements[1].name
  end

  def test_function_definition_error_missing_name
    input = "make a function called { return 42 }"
    
    error = assert_raises(RuntimeError) do
      parse_input(input)
    end
    assert_includes error.message, "Expected"
  end

  def test_function_definition_error_missing_body
    input = "make a function called test"
    
    error = assert_raises(RuntimeError) do
      parse_input(input)
    end
    assert_includes error.message, "Expected"
  end

  def test_function_call_error_missing_name
    input = "call"
    
    error = assert_raises(RuntimeError) do
      parse_input(input)
    end
    assert_includes error.message, "Expected"
  end

  def test_parameter_parsing_error_missing_name
    input = "make a function called test takes: -string { return \"\" }"
    
    error = assert_raises(RuntimeError) do
      parse_input(input)
    end
    assert_includes error.message, "Expected"
  end

  def test_return_type_parsing_error
    input = "make a function called test returns: { return \"\" }"
    
    error = assert_raises(RuntimeError) do
      parse_input(input)
    end
    assert_includes error.message, "Expected"
  end

  def test_integration_with_existing_features
    input = "x = 5 make a function called test { if x > 0 then return call helper with x else return \"zero\" end } result = call test"
    ast = parse_input(input)
    
    assert_instance_of BlockNode, ast
    assert_equal 3, ast.statements.length
    
    # Assignment
    assert_instance_of AssignmentNode, ast.statements[0]
    
    # Function definition
    assert_instance_of FunctionDefinitionNode, ast.statements[1]
    
    # Function call assignment
    assert_instance_of AssignmentNode, ast.statements[2]
    assert_instance_of FunctionCallNode, ast.statements[2].expression
  end

  def test_function_call_with_method_chaining
    input = "result = call getData.length()"
    
    # This should parse the function call "getData" successfully
    # The .length() part will be parsed as method call on the result
    ast = parse_input(input)
    assert_instance_of AssignmentNode, ast
  end

  def test_empty_parameter_list
    input = "make a function called empty takes: { return nil }"
    
    # Improved error handling: empty parameter list now parses successfully
    # as function definition with no parameters
    result = parse_input(input)
    refute_nil result
    assert_instance_of FunctionDefinitionNode, result
  end

  def test_function_definition_with_while_loop
    input = "make a function called loop takes: n { while n > 0 do n = n - 1 end return n }"
    ast = parse_input(input)
    
    assert_instance_of FunctionDefinitionNode, ast
    assert_equal "loop", ast.name
    assert_instance_of BlockNode, ast.body
    assert_equal 2, ast.body.statements.length
    assert_instance_of WhileNode, ast.body.statements[0]
    assert_instance_of ReturnNode, ast.body.statements[1]
  end
end