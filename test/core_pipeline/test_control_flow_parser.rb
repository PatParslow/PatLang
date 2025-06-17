# frozen_string_literal: true

require_relative '../helpers/test_helper'

class TestControlFlowParser < Minitest::Test
  def setup
    @lexer = Lexer.new("")
    @parser = Parser.new([])
    @control_flow_parser = ParserModules::ControlFlowParser.new(@parser)
  end

  # Test if statement parsing - basic functionality
  def test_basic_if_statement_parsing
    tokens = [
      Token.new(Token::TOKEN_TYPES[:IF], 'if', 0, 1, 1),
      Token.new(Token::TOKEN_TYPES[:TRUE], 'true', 1, 1, 4),
      Token.new(Token::TOKEN_TYPES[:THEN], 'then', 2, 1, 9),
      Token.new(Token::TOKEN_TYPES[:NUMBER], 42, 3, 1, 14),
      Token.new(Token::TOKEN_TYPES[:END], 'end', 4, 1, 17),
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 5, 1, 20)
    ]
    
    parser = Parser.new(tokens)
    control_flow_parser = ParserModules::ControlFlowParser.new(parser)
    
    result = control_flow_parser.parse_if_statement
    
    assert_kind_of IfNode, result
    assert_not_nil result.condition
    assert_not_nil result.then_branch
    assert_nil result.else_branch
  end

  def test_if_else_statement_parsing
    tokens = [
      Token.new(Token::TOKEN_TYPES[:IF], 'if', 0, 1, 1),
      Token.new(Token::TOKEN_TYPES[:TRUE], 'true', 1, 1, 4),
      Token.new(Token::TOKEN_TYPES[:THEN], 'then', 2, 1, 9),
      Token.new(Token::TOKEN_TYPES[:NUMBER], 42, 3, 1, 14),
      Token.new(Token::TOKEN_TYPES[:ELSE], 'else', 4, 1, 17),
      Token.new(Token::TOKEN_TYPES[:NUMBER], 24, 5, 1, 22),
      Token.new(Token::TOKEN_TYPES[:END], 'end', 6, 1, 25),
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 7, 1, 28)
    ]
    
    parser = Parser.new(tokens)
    control_flow_parser = ParserModules::ControlFlowParser.new(parser)
    
    result = control_flow_parser.parse_if_statement
    
    assert_kind_of IfNode, result
    assert_not_nil result.condition
    assert_not_nil result.then_branch
    assert_not_nil result.else_branch
  end

  def test_if_statement_with_multiple_statements_in_branches
    tokens = [
      Token.new(Token::TOKEN_TYPES[:IF], 'if', 0, 1, 1),
      Token.new(Token::TOKEN_TYPES[:TRUE], 'true', 1, 1, 4),
      Token.new(Token::TOKEN_TYPES[:THEN], 'then', 2, 1, 9),
      Token.new(Token::TOKEN_TYPES[:IDENTIFIER], 'x', 3, 1, 14),
      Token.new(Token::TOKEN_TYPES[:ASSIGN], '=', 4, 1, 16),
      Token.new(Token::TOKEN_TYPES[:NUMBER], 1, 5, 1, 18),
      Token.new(Token::TOKEN_TYPES[:IDENTIFIER], 'y', 6, 1, 20),
      Token.new(Token::TOKEN_TYPES[:ASSIGN], '=', 7, 1, 22),
      Token.new(Token::TOKEN_TYPES[:NUMBER], 2, 8, 1, 24),
      Token.new(Token::TOKEN_TYPES[:ELSE], 'else', 9, 1, 26),
      Token.new(Token::TOKEN_TYPES[:IDENTIFIER], 'x', 10, 1, 31),
      Token.new(Token::TOKEN_TYPES[:ASSIGN], '=', 11, 1, 33),
      Token.new(Token::TOKEN_TYPES[:NUMBER], 3, 12, 1, 35),
      Token.new(Token::TOKEN_TYPES[:END], 'end', 13, 1, 37),
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 14, 1, 40)
    ]
    
    parser = Parser.new(tokens)
    control_flow_parser = ParserModules::ControlFlowParser.new(parser)
    
    result = control_flow_parser.parse_if_statement
    
    assert_kind_of IfNode, result
    assert_kind_of BlockNode, result.then_branch
    assert_kind_of BlockNode, result.else_branch
    assert_operator result.then_branch.statements.length, :>, 0
    assert_operator result.else_branch.statements.length, :>, 0
  end

  # Test while statement parsing
  def test_basic_while_statement_parsing
    tokens = [
      Token.new(Token::TOKEN_TYPES[:WHILE], 'while', 0, 1, 1),
      Token.new(Token::TOKEN_TYPES[:TRUE], 'true', 1, 1, 7),
      Token.new(Token::TOKEN_TYPES[:DO], 'do', 2, 1, 12),
      Token.new(Token::TOKEN_TYPES[:NUMBER], 42, 3, 1, 15),
      Token.new(Token::TOKEN_TYPES[:END], 'end', 4, 1, 18),
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 5, 1, 21)
    ]
    
    parser = Parser.new(tokens)
    control_flow_parser = ParserModules::ControlFlowParser.new(parser)
    
    result = control_flow_parser.parse_while_statement
    
    assert_kind_of WhileNode, result
    assert_not_nil result.condition
    assert_not_nil result.body
  end

  def test_while_statement_with_multiple_body_statements
    tokens = [
      Token.new(Token::TOKEN_TYPES[:WHILE], 'while', 0, 1, 1),
      Token.new(Token::TOKEN_TYPES[:TRUE], 'true', 1, 1, 7),
      Token.new(Token::TOKEN_TYPES[:DO], 'do', 2, 1, 12),
      Token.new(Token::TOKEN_TYPES[:IDENTIFIER], 'counter', 3, 1, 15),
      Token.new(Token::TOKEN_TYPES[:ASSIGN], '=', 4, 1, 23),
      Token.new(Token::TOKEN_TYPES[:NUMBER], 0, 5, 1, 25),
      Token.new(Token::TOKEN_TYPES[:IDENTIFIER], 'value', 6, 1, 27),
      Token.new(Token::TOKEN_TYPES[:ASSIGN], '=', 7, 1, 33),
      Token.new(Token::TOKEN_TYPES[:NUMBER], 100, 8, 1, 35),
      Token.new(Token::TOKEN_TYPES[:END], 'end', 9, 1, 39),
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 10, 1, 42)
    ]
    
    parser = Parser.new(tokens)
    control_flow_parser = ParserModules::ControlFlowParser.new(parser)
    
    result = control_flow_parser.parse_while_statement
    
    assert_kind_of WhileNode, result
    assert_kind_of BlockNode, result.body
    assert_operator result.body.statements.length, :>, 0
  end

  # Test error handling scenarios
  def test_if_statement_missing_condition
    tokens = [
      Token.new(Token::TOKEN_TYPES[:IF], 'if', 0, 1, 1),
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 1, 1, 3)
    ]
    
    parser = Parser.new(tokens)
    control_flow_parser = ParserModules::ControlFlowParser.new(parser)
    
    result = control_flow_parser.parse_if_statement
    
    # Should return ErrorNode for missing condition
    assert_kind_of ErrorNode, result
    assert_includes result.message, "condition after 'if'"
  end

  def test_if_statement_missing_then
    tokens = [
      Token.new(Token::TOKEN_TYPES[:IF], 'if', 0, 1, 1),
      Token.new(Token::TOKEN_TYPES[:TRUE], 'true', 1, 1, 4),
      Token.new(Token::TOKEN_TYPES[:NUMBER], 42, 2, 1, 9),
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 3, 1, 11)
    ]
    
    parser = Parser.new(tokens)
    control_flow_parser = ParserModules::ControlFlowParser.new(parser)
    
    # Should raise RuntimeError for missing 'then'
    assert_raises(RuntimeError) do
      control_flow_parser.parse_if_statement
    end
  end

  def test_if_statement_missing_end
    tokens = [
      Token.new(Token::TOKEN_TYPES[:IF], 'if', 0, 1, 1),
      Token.new(Token::TOKEN_TYPES[:TRUE], 'true', 1, 1, 4),
      Token.new(Token::TOKEN_TYPES[:THEN], 'then', 2, 1, 9),
      Token.new(Token::TOKEN_TYPES[:NUMBER], 42, 3, 1, 14),
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 4, 1, 16)
    ]
    
    parser = Parser.new(tokens)
    control_flow_parser = ParserModules::ControlFlowParser.new(parser)
    
    # Should raise RuntimeError for missing 'end'
    assert_raises(RuntimeError) do
      control_flow_parser.parse_if_statement
    end
  end

  def test_while_statement_missing_condition
    tokens = [
      Token.new(Token::TOKEN_TYPES[:WHILE], 'while', 0, 1, 1),
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 1, 1, 6)
    ]
    
    parser = Parser.new(tokens)
    control_flow_parser = ParserModules::ControlFlowParser.new(parser)
    
    result = control_flow_parser.parse_while_statement
    
    # Should return ErrorNode for missing condition
    assert_kind_of ErrorNode, result
    assert_includes result.message, "condition after 'while'"
  end

  def test_while_statement_missing_do
    tokens = [
      Token.new(Token::TOKEN_TYPES[:WHILE], 'while', 0, 1, 1),
      Token.new(Token::TOKEN_TYPES[:TRUE], 'true', 1, 1, 7),
      Token.new(Token::TOKEN_TYPES[:NUMBER], 42, 2, 1, 12),
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 3, 1, 14)
    ]
    
    parser = Parser.new(tokens)
    control_flow_parser = ParserModules::ControlFlowParser.new(parser)
    
    # Should raise RuntimeError for missing 'do'
    assert_raises(RuntimeError) do
      control_flow_parser.parse_while_statement
    end
  end

  def test_while_statement_missing_end
    tokens = [
      Token.new(Token::TOKEN_TYPES[:WHILE], 'while', 0, 1, 1),
      Token.new(Token::TOKEN_TYPES[:TRUE], 'true', 1, 1, 7),
      Token.new(Token::TOKEN_TYPES[:DO], 'do', 2, 1, 12),
      Token.new(Token::TOKEN_TYPES[:NUMBER], 42, 3, 1, 15),
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 4, 1, 17)
    ]
    
    parser = Parser.new(tokens)
    control_flow_parser = ParserModules::ControlFlowParser.new(parser)
    
    # Should raise RuntimeError for missing 'end'
    assert_raises(RuntimeError) do
      control_flow_parser.parse_while_statement
    end
  end

  # Test safety limits and edge cases
  def test_if_statement_safety_limit_protection
    # Create a scenario that could trigger the safety limit
    tokens = [Token.new(Token::TOKEN_TYPES[:IF], 'if', 0, 1, 1)]
    
    # Add many statements to test loop limit
    1500.times do |i|
      tokens << Token.new(Token::TOKEN_TYPES[:NUMBER], i, i + 1, 1, i + 4)
    end
    
    tokens << Token.new(Token::TOKEN_TYPES[:THEN], 'then', 1501, 1, 1505)
    tokens << Token.new(Token::TOKEN_TYPES[:END], 'end', 1502, 1, 1510)
    tokens << Token.new(Token::TOKEN_TYPES[:EOF], nil, 1503, 1, 1513)
    
    parser = Parser.new(tokens)
    control_flow_parser = ParserModules::ControlFlowParser.new(parser)
    
    # Should not hang due to safety limit
    assert_nothing_raised do
      with_test_timeout(2) do
        result = control_flow_parser.parse_if_statement
        assert_not_nil result
      end
    end
  end

  def test_while_statement_safety_limit_protection
    # Create a scenario that could trigger the safety limit
    tokens = [
      Token.new(Token::TOKEN_TYPES[:WHILE], 'while', 0, 1, 1),
      Token.new(Token::TOKEN_TYPES[:TRUE], 'true', 1, 1, 7),
      Token.new(Token::TOKEN_TYPES[:DO], 'do', 2, 1, 12)
    ]
    
    # Add many statements to test loop limit
    1500.times do |i|
      tokens << Token.new(Token::TOKEN_TYPES[:NUMBER], i, i + 3, 1, i + 15)
    end
    
    tokens << Token.new(Token::TOKEN_TYPES[:END], 'end', 1503, 1, 1518)
    tokens << Token.new(Token::TOKEN_TYPES[:EOF], nil, 1504, 1, 1521)
    
    parser = Parser.new(tokens)
    control_flow_parser = ParserModules::ControlFlowParser.new(parser)
    
    # Should not hang due to safety limit
    assert_nothing_raised do
      with_test_timeout(2) do
        result = control_flow_parser.parse_while_statement
        assert_not_nil result
      end
    end
  end

  # Test complex nested control flow
  def test_nested_if_statements
    # Test basic nested if support through parser integration
    nested_input = "if true then if false then 1 else 2 end else 3 end"
    lexer = Lexer.new(nested_input)
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    
    # Should handle nested control flow without crashing
    assert_nothing_raised do
      with_test_timeout(3) do
        result = parser.parse
        assert_not_nil result
      end
    end
  end

  def test_nested_while_statements
    # Test basic nested while support through parser integration
    nested_input = "while true do while false do 42 end end"
    lexer = Lexer.new(nested_input)
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    
    # Should handle nested control flow without crashing
    assert_nothing_raised do
      with_test_timeout(3) do
        result = parser.parse
        assert_not_nil result
      end
    end
  end

  # Test ParseError handling in control flow
  def test_parse_error_handling_in_if_statement
    # Create tokens that will cause a ParseError during expression parsing
    tokens = [
      Token.new(Token::TOKEN_TYPES[:IF], 'if', 0, 1, 1),
      Token.new(Token::TOKEN_TYPES[:UNKNOWN], '$', 1, 1, 4),  # Invalid token
      Token.new(Token::TOKEN_TYPES[:THEN], 'then', 2, 1, 6),
      Token.new(Token::TOKEN_TYPES[:NUMBER], 42, 3, 1, 11),
      Token.new(Token::TOKEN_TYPES[:END], 'end', 4, 1, 14),
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 5, 1, 17)
    ]
    
    parser = Parser.new(tokens)
    control_flow_parser = ParserModules::ControlFlowParser.new(parser)
    
    # Should handle ParseError gracefully and return ErrorNode
    result = control_flow_parser.parse_if_statement
    
    assert_kind_of ErrorNode, result
    assert_includes result.message.downcase, "parse error"
  end

  def test_parse_error_handling_in_while_statement
    # Create tokens that will cause a ParseError during expression parsing
    tokens = [
      Token.new(Token::TOKEN_TYPES[:WHILE], 'while', 0, 1, 1),
      Token.new(Token::TOKEN_TYPES[:UNKNOWN], '&', 1, 1, 7),  # Invalid token
      Token.new(Token::TOKEN_TYPES[:DO], 'do', 2, 1, 9),
      Token.new(Token::TOKEN_TYPES[:NUMBER], 42, 3, 1, 12),
      Token.new(Token::TOKEN_TYPES[:END], 'end', 4, 1, 15),
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 5, 1, 18)
    ]
    
    parser = Parser.new(tokens)
    control_flow_parser = ParserModules::ControlFlowParser.new(parser)
    
    # Should handle ParseError gracefully and return ErrorNode
    result = control_flow_parser.parse_while_statement
    
    assert_kind_of ErrorNode, result
    assert_includes result.message.downcase, "parse error"
  end

  # Test edge cases with empty branches
  def test_if_statement_with_empty_branches
    tokens = [
      Token.new(Token::TOKEN_TYPES[:IF], 'if', 0, 1, 1),
      Token.new(Token::TOKEN_TYPES[:TRUE], 'true', 1, 1, 4),
      Token.new(Token::TOKEN_TYPES[:THEN], 'then', 2, 1, 9),
      Token.new(Token::TOKEN_TYPES[:ELSE], 'else', 3, 1, 14),
      Token.new(Token::TOKEN_TYPES[:END], 'end', 4, 1, 19),
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 5, 1, 22)
    ]
    
    parser = Parser.new(tokens)
    control_flow_parser = ParserModules::ControlFlowParser.new(parser)
    
    result = control_flow_parser.parse_if_statement
    
    assert_kind_of IfNode, result
    assert_kind_of BlockNode, result.then_branch
    assert_kind_of BlockNode, result.else_branch
    assert_equal 0, result.then_branch.statements.length
    assert_equal 0, result.else_branch.statements.length
  end

  def test_while_statement_with_empty_body
    tokens = [
      Token.new(Token::TOKEN_TYPES[:WHILE], 'while', 0, 1, 1),
      Token.new(Token::TOKEN_TYPES[:TRUE], 'true', 1, 1, 7),
      Token.new(Token::TOKEN_TYPES[:DO], 'do', 2, 1, 12),
      Token.new(Token::TOKEN_TYPES[:END], 'end', 3, 1, 15),
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 4, 1, 18)
    ]
    
    parser = Parser.new(tokens)
    control_flow_parser = ParserModules::ControlFlowParser.new(parser)
    
    result = control_flow_parser.parse_while_statement
    
    assert_kind_of WhileNode, result
    assert_kind_of BlockNode, result.body
    assert_equal 0, result.body.statements.length
  end

  # Test memory and performance characteristics
  def test_control_flow_parser_memory_efficiency
    # Test that control flow parser doesn't accumulate excessive memory
    original_object_count = ObjectSpace.each_object(IfNode).count
    
    # Create many if statements
    100.times do
      tokens = [
        Token.new(Token::TOKEN_TYPES[:IF], 'if', 0, 1, 1),
        Token.new(Token::TOKEN_TYPES[:TRUE], 'true', 1, 1, 4),
        Token.new(Token::TOKEN_TYPES[:THEN], 'then', 2, 1, 9),
        Token.new(Token::TOKEN_TYPES[:NUMBER], 42, 3, 1, 14),
        Token.new(Token::TOKEN_TYPES[:END], 'end', 4, 1, 17),
        Token.new(Token::TOKEN_TYPES[:EOF], nil, 5, 1, 20)
      ]
      
      parser = Parser.new(tokens)
      control_flow_parser = ParserModules::ControlFlowParser.new(parser)
      result = control_flow_parser.parse_if_statement
      
      assert_kind_of IfNode, result
    end
    
    # Allow some increase but ensure it's reasonable
    new_object_count = ObjectSpace.each_object(IfNode).count
    assert_operator new_object_count - original_object_count, :<=, 150
  end
end