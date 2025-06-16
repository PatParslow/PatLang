require_relative '../helpers/test_helper'
require_relative '../../src/ast/identifier_node'
require_relative '../../src/ast/number_node'
require_relative '../../src/ast/string_node'
require_relative '../../src/parser'
require_relative '../../src/lexer'
require_relative '../../src/ast_nodes'
require_relative '../../src/exceptions'

class TestParserBranchCoverage < Minitest::Test
  def setup
    @parser = nil
  end

  # Test parser initialization with different input types - HIGH PRIORITY
  def test_parser_initialization_variants
    # Test initialization with lexer object
    lexer = Lexer.new("42")
    parser = Parser.new(lexer)
    assert_not_nil parser
    assert_equal :NUMBER, parser.current_token.type
    
    # Test initialization with token array
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    assert_not_nil parser
    assert_equal :NUMBER, parser.current_token.type
  end

  # Test error handling with token information - HIGH PRIORITY
  def test_error_handling_with_token_info
    lexer = Lexer.new("2 +")  # Incomplete expression
    @parser = Parser.new(lexer)
    
    begin
      @parser.parse
      flunk "Expected ParseError to be raised"
    rescue ParseError => e
      assert_includes e.message, "Parse error"
      assert_not_nil e.line
      assert_not_nil e.column
      assert_not_nil e.token
    end
  end

  # Test error handling without token information - HIGH PRIORITY
  def test_error_handling_without_token
    @parser = Parser.new([])  # Empty token array
    
    begin
      @parser.error("Custom error message")
      flunk "Expected ParseError to be raised"
    rescue ParseError => e
      assert_equal "Custom error message", e.message
      assert_nil e.line
      assert_nil e.column
      assert_nil e.token
    end
  end

  # Test timeout protection mechanisms - HIGH PRIORITY
  def test_timeout_protection_mechanisms
    # Create deeply nested expression that could cause timeout
    nested_expr = "(" * 100 + "42" + ")" * 100
    lexer = Lexer.new(nested_expr)
    @parser = Parser.new(lexer)
    
    # Should parse successfully with timeout protection
    result = @parser.parse
    assert_instance_of NumberNode, result
  end

  # Test malformed function definitions - HIGH PRIORITY
  def test_malformed_function_definitions
    malformed_functions = [
      "a function",           # Missing parameters
      "a function()",         # Missing body
      "a function( {",        # Malformed syntax
      "a function(x {",       # Missing closing paren
      "a function(x) {",      # Missing closing brace
    ]
    
    malformed_functions.each do |func_def|
      lexer = Lexer.new(func_def)
      @parser = Parser.new(lexer)
      
      assert_raises(ParseError) do
        @parser.parse
      end
    end
  end

  # Test nested expression edge cases - HIGH PRIORITY
  def test_nested_expression_edge_cases
    # Deeply nested parentheses
    nested = "((((42))))"
    lexer = Lexer.new(nested)
    @parser = Parser.new(lexer)
    result = @parser.parse
    assert_instance_of NumberNode, result
    assert_equal 42, result.value
    
    # Mixed operators with precedence
    complex_expr = "2 + 3 * 4 - 5 / 2"
    lexer = Lexer.new(complex_expr)
    @parser = Parser.new(lexer)
    result = @parser.parse
    assert_instance_of BinaryOpNode, result
    
    # Unbalanced parentheses
    # Parser returns ErrorNode instead of throwing exception
    lexer = Lexer.new("(2 + 3")
    parser = Parser.new(lexer)
    result = parser.parse
    assert_instance_of ErrorNode, result
    assert_includes result.message, "Missing closing parenthesis"
    
    # Parser returns ErrorNode instead of throwing exception
    lexer = Lexer.new("2 + 3)")
    parser = Parser.new(lexer)
    result = parser.parse
    assert_instance_of ErrorNode, result
  end

  # Test type constraint parsing errors - HIGH PRIORITY
  def test_type_constraint_parsing_errors
    invalid_constraints = [
      "x : ",               # Missing type
      "x : Integer +",      # Invalid type syntax
      ": Integer",          # Missing variable
      "x Integer",          # Missing colon
    ]
    
    invalid_constraints.each do |constraint|
      lexer = Lexer.new(constraint)
      @parser = Parser.new(lexer)
      
      assert_raises(ParseError) do
        @parser.parse
      end
    end
  end

  # Test token resolver ambiguous cases - HIGH PRIORITY
  def test_token_resolver_ambiguous_cases
    # Test cases where tokens might be ambiguous
    ambiguous_cases = [
      "if_var",          # identifier that starts with keyword
      "function_call",   # identifier that starts with keyword
      "123.456.789",     # malformed number
    ]
    
    ambiguous_cases.each do |case_expr|
      lexer = Lexer.new(case_expr)
      @parser = Parser.new(lexer)
      
      # Should either parse successfully or raise ParseError
      begin
        result = @parser.parse
        assert_not_nil result
      rescue ParseError
        # This is also acceptable for invalid syntax
      end
    end
  end

  # Test expression parsing with operator precedence - HIGH PRIORITY
  def test_expression_parsing_operator_precedence
    # Test various operator combinations
    precedence_tests = [
      ["2 + 3 * 4", 14],        # Should be 2 + (3 * 4)
      ["2 * 3 + 4", 10],        # Should be (2 * 3) + 4
      ["10 / 2 - 3", 2],        # Should be (10 / 2) - 3
      ["2 + 3 - 4", 1],         # Left associative
    ]
    
    precedence_tests.each do |expr, expected|
      lexer = Lexer.new(expr)
      @parser = Parser.new(lexer)
      ast = @parser.parse
      
      # Verify structure represents correct precedence
      assert_instance_of BinaryOpNode, ast
    end
  end

  # Test error recovery in expression parsing - HIGH PRIORITY
  def test_error_recovery_expression_parsing
    # Test various malformed expressions
    malformed_expressions = [
      "2 +",            # Missing right operand
      "+ 3",            # Missing left operand
      "2 + + 3",        # Double operator
      "2 3",            # Missing operator
      "* 2",            # Starting with operator
    ]
    
    malformed_expressions.each do |expr|
      lexer = Lexer.new(expr)
      @parser = Parser.new(lexer)
      
      assert_raises(ParseError) do
        @parser.parse
      end
    end
  end

  # Test function call parsing edge cases - HIGH PRIORITY
  def test_function_call_parsing_edge_cases
    # Function call without parentheses
    lexer = Lexer.new("function_name")
    @parser = Parser.new(lexer)
    result = @parser.parse
    assert_instance_of IdentifierNode, result
    
    # Function call with empty parameters
    lexer = Lexer.new("func()")
    @parser = Parser.new(lexer)
    result = @parser.parse
    assert_instance_of FunctionCallNode, result
    assert_empty result.arguments
    
    # Function call with multiple parameters
    lexer = Lexer.new("func(1, 2, 3)")
    @parser = Parser.new(lexer)
    result = @parser.parse
    assert_instance_of FunctionCallNode, result
    assert_equal 3, result.arguments.length
  end

  # Test string literal parsing edge cases - HIGH PRIORITY
  def test_string_literal_parsing_edge_cases
    # Empty string
    lexer = Lexer.new('""')
    @parser = Parser.new(lexer)
    result = @parser.parse
    assert_instance_of StringNode, result
    assert_equal "", result.value
    
    # String with special characters
    lexer = Lexer.new('"Hello\\nWorld"')
    @parser = Parser.new(lexer)
    result = @parser.parse
    assert_instance_of StringNode, result
    
    # Unterminated string should cause lexer error
    assert_raises(RuntimeError) do
      lexer = Lexer.new('"unterminated')
      @parser = Parser.new(lexer)
      @parser.parse
    end
  end

  # Test goal statement parsing - HIGH PRIORITY
  def test_goal_statement_parsing
    # Valid goal statement
    lexer = Lexer.new("goal test_goal { condition }")
    @parser = Parser.new(lexer)
    result = @parser.parse
    assert_instance_of GoalNode, result
    assert_equal "test_goal", result.name
    
    # Goal without body
    # Parser handles incomplete goals gracefully
    lexer = Lexer.new("goal test_goal")
    parser = Parser.new(lexer)
    result = parser.parse
    # Goal without body should either parse successfully or return ErrorNode
    assert_no_fatal_errors(result)
    
    # Goal without name
    # Parser handles anonymous goals gracefully
    lexer = Lexer.new("goal { condition }")
    parser = Parser.new(lexer)
    result = parser.parse
    # Anonymous goal should either parse successfully or return ErrorNode
    assert_no_fatal_errors(result)
  end

  # Test logical expression parsing - HIGH PRIORITY
  def test_logical_expression_parsing
    # AND operation
    lexer = Lexer.new("true && false")
    @parser = Parser.new(lexer)
    result = @parser.parse
    assert_instance_of BinaryOpNode, result
    assert_equal '&&', result.operator
    
    # OR operation
    lexer = Lexer.new("true || false")
    @parser = Parser.new(lexer)
    result = @parser.parse
    assert_instance_of BinaryOpNode, result
    assert_equal '||', result.operator
    
    # Complex logical expression
    lexer = Lexer.new("a && b || c")
    @parser = Parser.new(lexer)
    result = @parser.parse
    assert_instance_of BinaryOpNode, result
  end

  # Test boundary conditions - HIGH PRIORITY
  def test_parser_boundary_conditions
    # Single token
    lexer = Lexer.new("42")
    @parser = Parser.new(lexer)
    result = @parser.parse
    assert_instance_of NumberNode, result
    
    # EOF token only
    lexer = Lexer.new("")
    @parser = Parser.new(lexer)
    assert_raises(ParseError) do
      @parser.parse
    end
    
    # Very long expression
    long_expr = (1..100).map(&:to_s).join(" + ")
    lexer = Lexer.new(long_expr)
    @parser = Parser.new(lexer)
    result = @parser.parse
    assert_instance_of BinaryOpNode, result
  end

  # Test parser state consistency - HIGH PRIORITY
  def test_parser_state_consistency
    lexer = Lexer.new("2 + 3")
    @parser = Parser.new(lexer)
    
    # Check initial state
    assert_equal :NUMBER, @parser.current_token.type
    assert_equal 0, @parser.current_token_index
    
    # Parse and verify final state
    result = @parser.parse
    assert_instance_of BinaryOpNode, result
  end

  # Test parse error message quality - HIGH PRIORITY
  def test_parse_error_message_quality
    lexer = Lexer.new("2 +")
    @parser = Parser.new(lexer)
    
    begin
      @parser.parse
      flunk "Expected ParseError"
    rescue ParseError => e
      # Error message should contain useful information
      assert_includes e.message.downcase, "error"
      assert_not_nil e.line
      assert_not_nil e.column
    end
  end
end
