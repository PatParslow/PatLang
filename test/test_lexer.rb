require 'minitest/autorun'
require_relative '../src/lexer'
require_relative '../src/token'

class TestLexer < Minitest::Test
  def test_single_number
    lexer = Lexer.new("42")
    tokens = lexer.tokenize
    
    assert_equal 2, tokens.length
    assert_equal Token::TOKEN_TYPES[:NUMBER], tokens[0].type
    assert_equal 42, tokens[0].value
    assert_equal Token::TOKEN_TYPES[:EOF], tokens[1].type
  end

  def test_simple_addition
    lexer = Lexer.new("2 + 3")
    tokens = lexer.tokenize
    
    expected_types = [
      Token::TOKEN_TYPES[:NUMBER],
      Token::TOKEN_TYPES[:PLUS],
      Token::TOKEN_TYPES[:NUMBER],
      Token::TOKEN_TYPES[:EOF]
    ]
    
    assert_equal 4, tokens.length
    expected_types.each_with_index do |expected_type, i|
      assert_equal expected_type, tokens[i].type
    end
    
    assert_equal 2, tokens[0].value
    assert_equal 3, tokens[2].value
  end

  def test_complex_expression
    lexer = Lexer.new("2 + 3 * 4")
    tokens = lexer.tokenize
    
    expected_types = [
      Token::TOKEN_TYPES[:NUMBER],
      Token::TOKEN_TYPES[:PLUS],
      Token::TOKEN_TYPES[:NUMBER],
      Token::TOKEN_TYPES[:MULTIPLY],
      Token::TOKEN_TYPES[:NUMBER],
      Token::TOKEN_TYPES[:EOF]
    ]
    
    assert_equal 6, tokens.length
    expected_types.each_with_index do |expected_type, i|
      assert_equal expected_type, tokens[i].type
    end
  end

  def test_parentheses
    lexer = Lexer.new("(2 + 3) * 4")
    tokens = lexer.tokenize
    
    expected_types = [
      Token::TOKEN_TYPES[:LPAREN],
      Token::TOKEN_TYPES[:NUMBER],
      Token::TOKEN_TYPES[:PLUS],
      Token::TOKEN_TYPES[:NUMBER],
      Token::TOKEN_TYPES[:RPAREN],
      Token::TOKEN_TYPES[:MULTIPLY],
      Token::TOKEN_TYPES[:NUMBER],
      Token::TOKEN_TYPES[:EOF]
    ]
    
    assert_equal 8, tokens.length
    expected_types.each_with_index do |expected_type, i|
      assert_equal expected_type, tokens[i].type
    end
  end

  def test_all_operators
    lexer = Lexer.new("1 + 2 - 3 * 4 / 5")
    tokens = lexer.tokenize
    
    expected_types = [
      Token::TOKEN_TYPES[:NUMBER],
      Token::TOKEN_TYPES[:PLUS],
      Token::TOKEN_TYPES[:NUMBER],
      Token::TOKEN_TYPES[:MINUS],
      Token::TOKEN_TYPES[:NUMBER],
      Token::TOKEN_TYPES[:MULTIPLY],
      Token::TOKEN_TYPES[:NUMBER],
      Token::TOKEN_TYPES[:DIVIDE],
      Token::TOKEN_TYPES[:NUMBER],
      Token::TOKEN_TYPES[:EOF]
    ]
    
    assert_equal 10, tokens.length
    expected_types.each_with_index do |expected_type, i|
      assert_equal expected_type, tokens[i].type
    end
  end

  def test_whitespace_handling
    lexer = Lexer.new("  42   +   3  ")
    tokens = lexer.tokenize
    
    assert_equal 4, tokens.length
    assert_equal Token::TOKEN_TYPES[:NUMBER], tokens[0].type
    assert_equal 42, tokens[0].value
    assert_equal Token::TOKEN_TYPES[:PLUS], tokens[1].type
    assert_equal Token::TOKEN_TYPES[:NUMBER], tokens[2].type
    assert_equal 3, tokens[2].value
  end

  def test_invalid_character
    lexer = Lexer.new("2 @ 3")
    
    assert_raises(RuntimeError) do
      lexer.tokenize
    end
  end

  def test_decimal_numbers
    lexer = Lexer.new("3.14")
    tokens = lexer.tokenize
    
    assert_equal 2, tokens.length
    assert_equal Token::TOKEN_TYPES[:NUMBER], tokens[0].type
    assert_equal 3.14, tokens[0].value
    assert_equal Token::TOKEN_TYPES[:EOF], tokens[1].type
  end

  def test_decimal_arithmetic
    lexer = Lexer.new("2.5 + 1.75")
    tokens = lexer.tokenize
    
    expected_types = [
      Token::TOKEN_TYPES[:NUMBER],
      Token::TOKEN_TYPES[:PLUS],
      Token::TOKEN_TYPES[:NUMBER],
      Token::TOKEN_TYPES[:EOF]
    ]
    
    assert_equal 4, tokens.length
    expected_types.each_with_index do |expected_type, i|
      assert_equal expected_type, tokens[i].type
    end
    
    assert_equal 2.5, tokens[0].value
    assert_equal 1.75, tokens[2].value
  end

  def test_mixed_integer_and_decimal
    lexer = Lexer.new("42 * 3.14")
    tokens = lexer.tokenize
    
    assert_equal 4, tokens.length
    assert_equal 42, tokens[0].value
    assert_equal 3.14, tokens[2].value
  end
  def test_identifier_tokens
    lexer = Lexer.new('x variable _test var123 _var_name')
    tokens = lexer.tokenize
    
    assert_equal 6, tokens.length # 5 identifiers + EOF
    
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], tokens[0].type
    assert_equal 'x', tokens[0].value
    
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], tokens[1].type
    assert_equal 'variable', tokens[1].value
    
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], tokens[2].type
    assert_equal '_test', tokens[2].value
    
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], tokens[3].type
    assert_equal 'var123', tokens[3].value
    
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], tokens[4].type
    assert_equal '_var_name', tokens[4].value
    
    assert_equal Token::TOKEN_TYPES[:EOF], tokens[5].type
  end

  def test_equals_token
    lexer = Lexer.new('=')
    tokens = lexer.tokenize
    
    assert_equal 2, tokens.length
    assert_equal Token::TOKEN_TYPES[:EQUALS], tokens[0].type
    assert_equal '=', tokens[0].value
    assert_equal Token::TOKEN_TYPES[:EOF], tokens[1].type
  end

  def test_assignment_expression
    lexer = Lexer.new('x = 42')
    tokens = lexer.tokenize
    
    assert_equal 4, tokens.length
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], tokens[0].type
    assert_equal 'x', tokens[0].value
    assert_equal Token::TOKEN_TYPES[:EQUALS], tokens[1].type
    assert_equal '=', tokens[1].value
    assert_equal Token::TOKEN_TYPES[:NUMBER], tokens[2].type
    assert_equal 42, tokens[2].value
    assert_equal Token::TOKEN_TYPES[:EOF], tokens[3].type
  end

  def test_complex_expression_with_variables
    lexer = Lexer.new('result = x + y * 2')
    tokens = lexer.tokenize
    
    expected_types = [
      Token::TOKEN_TYPES[:IDENTIFIER],  # result
      Token::TOKEN_TYPES[:EQUALS],      # =
      Token::TOKEN_TYPES[:IDENTIFIER],  # x
      Token::TOKEN_TYPES[:PLUS],        # +
      Token::TOKEN_TYPES[:IDENTIFIER],  # y
      Token::TOKEN_TYPES[:MULTIPLY],    # *
      Token::TOKEN_TYPES[:NUMBER],      # 2
      Token::TOKEN_TYPES[:EOF]
    ]
    
    assert_equal expected_types.length, tokens.length
    expected_types.each_with_index do |expected_type, index|
      assert_equal expected_type, tokens[index].type
    end
    
    assert_equal 'result', tokens[0].value
    assert_equal 'x', tokens[2].value
    assert_equal 'y', tokens[4].value
    assert_equal 2, tokens[6].value
  end

  def test_identifier_edge_cases
    # Test that identifiers can start with underscore
    lexer = Lexer.new('_start')
    tokens = lexer.tokenize
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], tokens[0].type
    assert_equal '_start', tokens[0].value
    
    # Test mixed alphanumeric identifiers
    lexer = Lexer.new('var_2_test')
    tokens = lexer.tokenize
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], tokens[0].type
    assert_equal 'var_2_test', tokens[0].value
    
    # Test single character identifier
    lexer = Lexer.new('a')
    tokens = lexer.tokenize
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], tokens[0].type
    assert_equal 'a', tokens[0].value
  end

  def test_mixed_tokens_with_assignment
    lexer = Lexer.new('y = 3.14')
    tokens = lexer.tokenize
    
    expected_types = [
      Token::TOKEN_TYPES[:IDENTIFIER],
      Token::TOKEN_TYPES[:EQUALS],
      Token::TOKEN_TYPES[:NUMBER],
      Token::TOKEN_TYPES[:EOF]
    ]
    
    assert_equal 4, tokens.length
    expected_types.each_with_index do |expected_type, index|
      assert_equal expected_type, tokens[index].type
    end
    
    assert_equal 'y', tokens[0].value
    assert_equal '=', tokens[1].value
    assert_equal 3.14, tokens[2].value
  end

  def test_assignment_with_parentheses
    lexer = Lexer.new('result = (x + y)')
    tokens = lexer.tokenize
    
    expected_types = [
      Token::TOKEN_TYPES[:IDENTIFIER],  # result
      Token::TOKEN_TYPES[:EQUALS],      # =
      Token::TOKEN_TYPES[:LPAREN],      # (
      Token::TOKEN_TYPES[:IDENTIFIER],  # x
      Token::TOKEN_TYPES[:PLUS],        # +
      Token::TOKEN_TYPES[:IDENTIFIER],  # y
      Token::TOKEN_TYPES[:RPAREN],      # )
      Token::TOKEN_TYPES[:EOF]
    ]
    
    assert_equal expected_types.length, tokens.length
    expected_types.each_with_index do |expected_type, index|
      assert_equal expected_type, tokens[index].type
    end
  end

  def test_invalid_identifier_start
    # Test that identifiers cannot start with numbers (should be parsed as number then identifier)
    lexer = Lexer.new('123abc')
    tokens = lexer.tokenize
    
    # This should tokenize as a number (123) followed by identifier (abc)
    assert_equal 3, tokens.length
    assert_equal Token::TOKEN_TYPES[:NUMBER], tokens[0].type
    assert_equal 123, tokens[0].value
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], tokens[1].type
    assert_equal 'abc', tokens[1].value
    assert_equal Token::TOKEN_TYPES[:EOF], tokens[2].type
  end
end

  # Tests for boolean literals
  def test_boolean_true_token
    lexer = Lexer.new('true')
    tokens = lexer.tokenize
    
    assert_equal 2, tokens.length
    assert_equal Token::TOKEN_TYPES[:TRUE], tokens[0].type
    assert_equal 'true', tokens[0].value
    assert_equal Token::TOKEN_TYPES[:EOF], tokens[1].type
  end

  def test_boolean_false_token
    lexer = Lexer.new('false')
    tokens = lexer.tokenize
    
    assert_equal 2, tokens.length
    assert_equal Token::TOKEN_TYPES[:FALSE], tokens[0].type
    assert_equal 'false', tokens[0].value
    assert_equal Token::TOKEN_TYPES[:EOF], tokens[1].type
  end

  def test_boolean_tokens_in_expression
    lexer = Lexer.new('x = true')
    tokens = lexer.tokenize
    
    expected_types = [
      Token::TOKEN_TYPES[:IDENTIFIER],
      Token::TOKEN_TYPES[:EQUALS],
      Token::TOKEN_TYPES[:TRUE],
      Token::TOKEN_TYPES[:EOF]
    ]
    
    assert_equal 4, tokens.length
    expected_types.each_with_index do |expected_type, index|
      assert_equal expected_type, tokens[index].type
    end
    
    assert_equal 'x', tokens[0].value
    assert_equal 'true', tokens[2].value
  end

  # Tests for comparison operators
  def test_equal_operator
    lexer = Lexer.new('==')
    tokens = lexer.tokenize
    
    assert_equal 2, tokens.length
    assert_equal Token::TOKEN_TYPES[:EQUAL], tokens[0].type
    assert_equal '==', tokens[0].value
    assert_equal Token::TOKEN_TYPES[:EOF], tokens[1].type
  end

  def test_not_equal_operator
    lexer = Lexer.new('!=')
    tokens = lexer.tokenize
    
    assert_equal 2, tokens.length
    assert_equal Token::TOKEN_TYPES[:NOT_EQUAL], tokens[0].type
    assert_equal '!=', tokens[0].value
    assert_equal Token::TOKEN_TYPES[:EOF], tokens[1].type
  end

  def test_less_than_operator
    lexer = Lexer.new('<')
    tokens = lexer.tokenize
    
    assert_equal 2, tokens.length
    assert_equal Token::TOKEN_TYPES[:LESS_THAN], tokens[0].type
    assert_equal '<', tokens[0].value
    assert_equal Token::TOKEN_TYPES[:EOF], tokens[1].type
  end

  def test_greater_than_operator
    lexer = Lexer.new('>')
    tokens = lexer.tokenize
    
    assert_equal 2, tokens.length
    assert_equal Token::TOKEN_TYPES[:GREATER_THAN], tokens[0].type
    assert_equal '>', tokens[0].value
    assert_equal Token::TOKEN_TYPES[:EOF], tokens[1].type
  end

  def test_less_equal_operator
    lexer = Lexer.new('<=')
    tokens = lexer.tokenize
    
    assert_equal 2, tokens.length
    assert_equal Token::TOKEN_TYPES[:LESS_EQUAL], tokens[0].type
    assert_equal '<=', tokens[0].value
    assert_equal Token::TOKEN_TYPES[:EOF], tokens[1].type
  end

  def test_greater_equal_operator
    lexer = Lexer.new('>=')
    tokens = lexer.tokenize
    
    assert_equal 2, tokens.length
    assert_equal Token::TOKEN_TYPES[:GREATER_EQUAL], tokens[0].type
    assert_equal '>=', tokens[0].value
    assert_equal Token::TOKEN_TYPES[:EOF], tokens[1].type
  end

  def test_comparison_expression
    lexer = Lexer.new('x == 42')
    tokens = lexer.tokenize
    
    expected_types = [
      Token::TOKEN_TYPES[:IDENTIFIER],
      Token::TOKEN_TYPES[:EQUAL],
      Token::TOKEN_TYPES[:NUMBER],
      Token::TOKEN_TYPES[:EOF]
    ]
    
    assert_equal 4, tokens.length
    expected_types.each_with_index do |expected_type, index|
      assert_equal expected_type, tokens[index].type
    end
    
    assert_equal 'x', tokens[0].value
    assert_equal '==', tokens[1].value
    assert_equal 42, tokens[2].value
  end

  def test_all_comparison_operators_in_sequence
    lexer = Lexer.new('a == b != c < d > e <= f >= g')
    tokens = lexer.tokenize
    
    expected_types = [
      Token::TOKEN_TYPES[:IDENTIFIER],   # a
      Token::TOKEN_TYPES[:EQUAL],        # ==
      Token::TOKEN_TYPES[:IDENTIFIER],   # b
      Token::TOKEN_TYPES[:NOT_EQUAL],    # !=
      Token::TOKEN_TYPES[:IDENTIFIER],   # c
      Token::TOKEN_TYPES[:LESS_THAN],    # <
      Token::TOKEN_TYPES[:IDENTIFIER],   # d
      Token::TOKEN_TYPES[:GREATER_THAN], # >
      Token::TOKEN_TYPES[:IDENTIFIER],   # e
      Token::TOKEN_TYPES[:LESS_EQUAL],   # <=
      Token::TOKEN_TYPES[:IDENTIFIER],   # f
      Token::TOKEN_TYPES[:GREATER_EQUAL],# >=
      Token::TOKEN_TYPES[:IDENTIFIER],   # g
      Token::TOKEN_TYPES[:EOF]
    ]
    
    assert_equal expected_types.length, tokens.length
    expected_types.each_with_index do |expected_type, index|
      assert_equal expected_type, tokens[index].type
    end
  end

  # Tests for control flow keywords
  def test_if_keyword
    lexer = Lexer.new('if')
    tokens = lexer.tokenize
    
    assert_equal 2, tokens.length
    assert_equal Token::TOKEN_TYPES[:IF], tokens[0].type
    assert_equal 'if', tokens[0].value
    assert_equal Token::TOKEN_TYPES[:EOF], tokens[1].type
  end

  def test_then_keyword
    lexer = Lexer.new('then')
    tokens = lexer.tokenize
    
    assert_equal 2, tokens.length
    assert_equal Token::TOKEN_TYPES[:THEN], tokens[0].type
    assert_equal 'then', tokens[0].value
    assert_equal Token::TOKEN_TYPES[:EOF], tokens[1].type
  end

  def test_else_keyword
    lexer = Lexer.new('else')
    tokens = lexer.tokenize
    
    assert_equal 2, tokens.length
    assert_equal Token::TOKEN_TYPES[:ELSE], tokens[0].type
    assert_equal 'else', tokens[0].value
    assert_equal Token::TOKEN_TYPES[:EOF], tokens[1].type
  end

  def test_end_keyword
    lexer = Lexer.new('end')
    tokens = lexer.tokenize
    
    assert_equal 2, tokens.length
    assert_equal Token::TOKEN_TYPES[:END], tokens[0].type
    assert_equal 'end', tokens[0].value
    assert_equal Token::TOKEN_TYPES[:EOF], tokens[1].type
  end

  def test_while_keyword
    lexer = Lexer.new('while')
    tokens = lexer.tokenize
    
    assert_equal 2, tokens.length
    assert_equal Token::TOKEN_TYPES[:WHILE], tokens[0].type
    assert_equal 'while', tokens[0].value
    assert_equal Token::TOKEN_TYPES[:EOF], tokens[1].type
  end

  def test_do_keyword
    lexer = Lexer.new('do')
    tokens = lexer.tokenize
    
    assert_equal 2, tokens.length
    assert_equal Token::TOKEN_TYPES[:DO], tokens[0].type
    assert_equal 'do', tokens[0].value
    assert_equal Token::TOKEN_TYPES[:EOF], tokens[1].type
  end

  def test_if_statement_keywords
    lexer = Lexer.new('if x == 42 then y = 1 else y = 0 end')
    tokens = lexer.tokenize
    
    expected_types = [
      Token::TOKEN_TYPES[:IF],         # if
      Token::TOKEN_TYPES[:IDENTIFIER], # x
      Token::TOKEN_TYPES[:EQUAL],      # ==
      Token::TOKEN_TYPES[:NUMBER],     # 42
      Token::TOKEN_TYPES[:THEN],       # then
      Token::TOKEN_TYPES[:IDENTIFIER], # y
      Token::TOKEN_TYPES[:EQUALS],     # =
      Token::TOKEN_TYPES[:NUMBER],     # 1
      Token::TOKEN_TYPES[:ELSE],       # else
      Token::TOKEN_TYPES[:IDENTIFIER], # y
      Token::TOKEN_TYPES[:EQUALS],     # =
      Token::TOKEN_TYPES[:NUMBER],     # 0
      Token::TOKEN_TYPES[:END],        # end
      Token::TOKEN_TYPES[:EOF]
    ]
    
    assert_equal expected_types.length, tokens.length
    expected_types.each_with_index do |expected_type, index|
      assert_equal expected_type, tokens[index].type
    end
  end

  def test_while_statement_keywords
    lexer = Lexer.new('while x < 10 do x = x + 1 end')
    tokens = lexer.tokenize
    
    expected_types = [
      Token::TOKEN_TYPES[:WHILE],      # while
      Token::TOKEN_TYPES[:IDENTIFIER], # x
      Token::TOKEN_TYPES[:LESS_THAN],  # <
      Token::TOKEN_TYPES[:NUMBER],     # 10
      Token::TOKEN_TYPES[:DO],         # do
      Token::TOKEN_TYPES[:IDENTIFIER], # x
      Token::TOKEN_TYPES[:EQUALS],     # =
      Token::TOKEN_TYPES[:IDENTIFIER], # x
      Token::TOKEN_TYPES[:PLUS],       # +
      Token::TOKEN_TYPES[:NUMBER],     # 1
      Token::TOKEN_TYPES[:END],        # end
      Token::TOKEN_TYPES[:EOF]
    ]
    
    assert_equal expected_types.length, tokens.length
    expected_types.each_with_index do |expected_type, index|
      assert_equal expected_type, tokens[index].type
    end
  end

  # Test edge cases and error conditions
  def test_single_equals_vs_double_equals
    # Single equals should be EQUALS token
    lexer = Lexer.new('x = 5')
    tokens = lexer.tokenize
    assert_equal Token::TOKEN_TYPES[:EQUALS], tokens[1].type
    assert_equal '=', tokens[1].value
    
    # Double equals should be EQUAL token
    lexer = Lexer.new('x == 5')
    tokens = lexer.tokenize
    assert_equal Token::TOKEN_TYPES[:EQUAL], tokens[1].type
    assert_equal '==', tokens[1].value
  end

  def test_invalid_exclamation_mark
    lexer = Lexer.new('!')
    
    assert_raises(RuntimeError) do
      lexer.tokenize
    end
  end

  def test_keywords_case_sensitive
    # Keywords should be case sensitive
    lexer = Lexer.new('True FALSE If THEN')
    tokens = lexer.tokenize
    
    # These should all be identifiers, not keywords
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], tokens[0].type
    assert_equal 'True', tokens[0].value
    
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], tokens[1].type
    assert_equal 'FALSE', tokens[1].value
    
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], tokens[2].type
    assert_equal 'If', tokens[2].value
    
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], tokens[3].type
    assert_equal 'THEN', tokens[3].value
  end