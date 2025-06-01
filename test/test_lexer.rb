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
# Additional coverage tests for new lexer features
  def test_comprehensive_boolean_and_comparison_mix
    lexer = Lexer.new('true == false != x < y > z <= a >= b')
    tokens = lexer.tokenize
    
    expected_types = [
      Token::TOKEN_TYPES[:TRUE],         # true
      Token::TOKEN_TYPES[:EQUAL],        # ==
      Token::TOKEN_TYPES[:FALSE],        # false
      Token::TOKEN_TYPES[:NOT_EQUAL],    # !=
      Token::TOKEN_TYPES[:IDENTIFIER],   # x
      Token::TOKEN_TYPES[:LESS_THAN],    # <
      Token::TOKEN_TYPES[:IDENTIFIER],   # y
      Token::TOKEN_TYPES[:GREATER_THAN], # >
      Token::TOKEN_TYPES[:IDENTIFIER],   # z
      Token::TOKEN_TYPES[:LESS_EQUAL],   # <=
      Token::TOKEN_TYPES[:IDENTIFIER],   # a
      Token::TOKEN_TYPES[:GREATER_EQUAL],# >=
      Token::TOKEN_TYPES[:IDENTIFIER],   # b
      Token::TOKEN_TYPES[:EOF]
    ]
    
    assert_equal expected_types.length, tokens.length
    expected_types.each_with_index do |expected_type, index|
      assert_equal expected_type, tokens[index].type
    end
  end

  def test_all_new_keywords_in_complex_expression
    lexer = Lexer.new('if true then x = 1 else y = 2 end while false do z = 3 end')
    tokens = lexer.tokenize
    
    expected_types = [
      Token::TOKEN_TYPES[:IF],           # if
      Token::TOKEN_TYPES[:TRUE],         # true
      Token::TOKEN_TYPES[:THEN],         # then
      Token::TOKEN_TYPES[:IDENTIFIER],   # x
      Token::TOKEN_TYPES[:EQUALS],       # =
      Token::TOKEN_TYPES[:NUMBER],       # 1
      Token::TOKEN_TYPES[:ELSE],         # else
      Token::TOKEN_TYPES[:IDENTIFIER],   # y
      Token::TOKEN_TYPES[:EQUALS],       # =
      Token::TOKEN_TYPES[:NUMBER],       # 2
      Token::TOKEN_TYPES[:END],          # end
      Token::TOKEN_TYPES[:WHILE],        # while
      Token::TOKEN_TYPES[:FALSE],        # false
      Token::TOKEN_TYPES[:DO],           # do
      Token::TOKEN_TYPES[:IDENTIFIER],   # z
      Token::TOKEN_TYPES[:EQUALS],       # =
      Token::TOKEN_TYPES[:NUMBER],       # 3
      Token::TOKEN_TYPES[:END],          # end
      Token::TOKEN_TYPES[:EOF]
    ]
    
    assert_equal expected_types.length, tokens.length
    expected_types.each_with_index do |expected_type, index|
      assert_equal expected_type, tokens[index].type
    end
  end

  def test_peek_char_functionality_with_lookahead
    # Test that peek_char works correctly for multi-character tokens
    lexer = Lexer.new('== != <= >=')
    tokens = lexer.tokenize
    
    assert_equal 5, tokens.length
    assert_equal Token::TOKEN_TYPES[:EQUAL], tokens[0].type
    assert_equal '==', tokens[0].value
    assert_equal Token::TOKEN_TYPES[:NOT_EQUAL], tokens[1].type
    assert_equal '!=', tokens[1].value
    assert_equal Token::TOKEN_TYPES[:LESS_EQUAL], tokens[2].type
    assert_equal '<=', tokens[2].value
    assert_equal Token::TOKEN_TYPES[:GREATER_EQUAL], tokens[3].type
    assert_equal '>=', tokens[3].value
    assert_equal Token::TOKEN_TYPES[:EOF], tokens[4].type
  end

  def test_mixed_single_and_double_character_operators
    lexer = Lexer.new('x = y == z != a < b > c <= d >= e')
    tokens = lexer.tokenize
    
    expected_values = ['x', '=', 'y', '==', 'z', '!=', 'a', '<', 'b', '>', 'c', '<=', 'd', '>=', 'e']
    
    assert_equal expected_values.length + 1, tokens.length # +1 for EOF
    expected_values.each_with_index do |expected_value, index|
      assert_equal expected_value, tokens[index].value
    end
  end

  def test_keywords_as_part_of_identifiers
    # Test that keywords don't get matched when they're part of larger identifiers
    lexer = Lexer.new('truthy falsey iff thence elsewhere endgame whiletrue document')
    tokens = lexer.tokenize
    
    expected_values = ['truthy', 'falsey', 'iff', 'thence', 'elsewhere', 'endgame', 'whiletrue', 'document']
    
    assert_equal expected_values.length + 1, tokens.length # +1 for EOF
    expected_values.each_with_index do |expected_value, index|
      assert_equal Token::TOKEN_TYPES[:IDENTIFIER], tokens[index].type
      assert_equal expected_value, tokens[index].value
    end
  end

  def test_error_handling_comprehensive
    # Test various invalid character combinations
    invalid_inputs = ['@', '#', '$', '%', '^', '&', '~', '`']
    
    invalid_inputs.each do |invalid_char|
      lexer = Lexer.new(invalid_char)
      assert_raises(RuntimeError) do
        lexer.tokenize
      end
    end
  end

  def test_position_tracking_for_new_tokens
    lexer = Lexer.new('true == false')
    tokens = lexer.tokenize
    
    # Check that positions are correctly tracked
    assert_equal 0, tokens[0].position  # true at position 0
    assert_equal 5, tokens[1].position  # == at position 5
    assert_equal 8, tokens[2].position  # false at position 8
  end

  def test_whitespace_around_new_operators
    lexer = Lexer.new('  true   ==   false   !=   x   ')
    tokens = lexer.tokenize
    
    expected_types = [
      Token::TOKEN_TYPES[:TRUE],
      Token::TOKEN_TYPES[:EQUAL],
      Token::TOKEN_TYPES[:FALSE],
      Token::TOKEN_TYPES[:NOT_EQUAL],
      Token::TOKEN_TYPES[:IDENTIFIER],
      Token::TOKEN_TYPES[:EOF]
    ]
    
    assert_equal expected_types.length, tokens.length
    expected_types.each_with_index do |expected_type, index|
      assert_equal expected_type, tokens[index].type
    end
  end

  def test_edge_case_empty_input
    lexer = Lexer.new('')
    tokens = lexer.tokenize
    
    assert_equal 1, tokens.length
    assert_equal Token::TOKEN_TYPES[:EOF], tokens[0].type
  end

  def test_edge_case_only_whitespace
    lexer = Lexer.new('   \t  \n  ')
    tokens = lexer.tokenize
    
    assert_equal 1, tokens.length
    assert_equal Token::TOKEN_TYPES[:EOF], tokens[0].type
  end

  def test_complex_nested_comparison_expression
    lexer = Lexer.new('if (x >= 10) then if (y != 5) then z = true else z = false end end')
    tokens = lexer.tokenize
    
    # This tests complex nesting with all our new token types
    assert tokens.length > 15
    
    # Verify key tokens are present
    token_values = tokens.map(&:value)
    assert_includes token_values, 'if'
    assert_includes token_values, '>='
    assert_includes token_values, 'then'
    assert_includes token_values, '!='
    assert_includes token_values, 'true'
    assert_includes token_values, 'false'
    assert_includes token_values, 'else'
    assert_includes token_values, 'end'
  end
# Additional lexer coverage tests for edge cases and error paths
  def test_get_next_token_method_directly
    # Test the get_next_token method for all token types
    lexer = Lexer.new('42')
    token = lexer.get_next_token
    assert_equal Token::TOKEN_TYPES[:NUMBER], token.type
    assert_equal 42, token.value
    
    # Get EOF token
    token = lexer.get_next_token
    assert_equal Token::TOKEN_TYPES[:EOF], token.type
  end

  def test_read_number_with_decimal_edge_cases
    # Test decimal number parsing edge cases
    lexer = Lexer.new('0.5')
    tokens = lexer.tokenize
    assert_equal 0.5, tokens[0].value
    
    lexer = Lexer.new('123.0')
    tokens = lexer.tokenize
    assert_equal 123.0, tokens[0].value
    
    lexer = Lexer.new('0.0')
    tokens = lexer.tokenize
    assert_equal 0.0, tokens[0].value
  end

  def test_advance_method_at_end_of_input
    lexer = Lexer.new('x')
    # Manually advance to test edge case
    lexer.get_next_token  # Consume 'x'
    token = lexer.get_next_token  # Should be EOF
    assert_equal Token::TOKEN_TYPES[:EOF], token.type
  end

  def test_skip_whitespace_various_characters
    # Test all whitespace characters: space, tab, newline
    lexer = Lexer.new("  \t\n\r  42")
    tokens = lexer.tokenize
    assert_equal Token::TOKEN_TYPES[:NUMBER], tokens[0].type
    assert_equal 42, tokens[0].value
  end

  def test_alpha_helper_method_coverage
    # Test identifier starting with various valid characters
    test_cases = [
      'a123', 'Z999', '_test', 'A_B_C', 'z', 'X'
    ]
    
    test_cases.each do |identifier|
      lexer = Lexer.new(identifier)
      tokens = lexer.tokenize
      assert_equal Token::TOKEN_TYPES[:IDENTIFIER], tokens[0].type
      assert_equal identifier, tokens[0].value
    end
  end

  def test_alphanumeric_helper_method_coverage
    # Test identifiers with numbers and underscores
    lexer = Lexer.new('var_123_test')
    tokens = lexer.tokenize
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], tokens[0].type
    assert_equal 'var_123_test', tokens[0].value
  end

  def test_read_identifier_position_tracking
    lexer = Lexer.new('hello world')
    tokens = lexer.tokenize
    
    assert_equal 0, tokens[0].position  # 'hello' starts at position 0
    assert_equal 6, tokens[1].position  # 'world' starts at position 6
  end

  def test_all_single_character_tokens
    single_char_tests = [
      ['+', Token::TOKEN_TYPES[:PLUS]],
      ['-', Token::TOKEN_TYPES[:MINUS]],
      ['*', Token::TOKEN_TYPES[:MULTIPLY]],
      ['/', Token::TOKEN_TYPES[:DIVIDE]],
      ['(', Token::TOKEN_TYPES[:LPAREN]],
      [')', Token::TOKEN_TYPES[:RPAREN]]
    ]
    
    single_char_tests.each do |char, expected_type|
      lexer = Lexer.new(char)
      tokens = lexer.tokenize
      assert_equal expected_type, tokens[0].type
      assert_equal char, tokens[0].value
    end
  end

  def test_number_token_position_tracking
    lexer = Lexer.new('123 + 456')
    tokens = lexer.tokenize
    
    assert_equal 0, tokens[0].position   # 123 starts at position 0
    assert_equal 4, tokens[1].position   # + starts at position 4
    assert_equal 6, tokens[2].position   # 456 starts at position 6
  end

  def test_error_method_with_invalid_characters
    # Test error method is called for various invalid characters
    invalid_chars = ['@', '#', '$', '%', '^', '&', '~', '`', '\\', '|']
    
    invalid_chars.each do |char|
      lexer = Lexer.new(char)
      error_raised = false
      begin
        lexer.tokenize
      rescue RuntimeError => e
        error_raised = true
        assert_includes e.message, "Invalid character"
        assert_includes e.message, char
      end
      assert error_raised, "Expected error for character: #{char}"
    end
  end

  def test_peek_char_at_end_of_input
    # Test peek_char when at end of input
    lexer = Lexer.new('x')
    lexer.get_next_token  # Consume 'x'
    # peek_char should return nil when at end
    token = lexer.get_next_token  # This should be EOF
    assert_equal Token::TOKEN_TYPES[:EOF], token.type
  end

  def test_tokenize_method_returns_all_tokens
    lexer = Lexer.new('1 + 2')
    tokens = lexer.tokenize
    
    # Verify all expected tokens are present
    assert_equal 4, tokens.length
    assert_equal Token::TOKEN_TYPES[:NUMBER], tokens[0].type
    assert_equal Token::TOKEN_TYPES[:PLUS], tokens[1].type
    assert_equal Token::TOKEN_TYPES[:NUMBER], tokens[2].type
    assert_equal Token::TOKEN_TYPES[:EOF], tokens[3].type
  end

  def test_comparison_operators_without_second_character
    # Test single < and > (not <= or >=)
    lexer = Lexer.new('< >')
    tokens = lexer.tokenize
    
    assert_equal 3, tokens.length
    assert_equal Token::TOKEN_TYPES[:LESS_THAN], tokens[0].type
    assert_equal '<', tokens[0].value
    assert_equal Token::TOKEN_TYPES[:GREATER_THAN], tokens[1].type
    assert_equal '>', tokens[1].value
    assert_equal Token::TOKEN_TYPES[:EOF], tokens[2].type
  end

  def test_equals_vs_double_equals_edge_cases
    # Test various combinations
    lexer = Lexer.new('= == === ====')
    tokens = lexer.tokenize
    
    # Should tokenize as: =, ==, ==, =, ==, ==
    expected_types = [
      Token::TOKEN_TYPES[:EQUALS],  # =
      Token::TOKEN_TYPES[:EQUAL],   # ==
      Token::TOKEN_TYPES[:EQUAL],   # ==
      Token::TOKEN_TYPES[:EQUALS],  # =
      Token::TOKEN_TYPES[:EQUAL],   # ==
      Token::TOKEN_TYPES[:EQUAL],   # ==
      Token::TOKEN_TYPES[:EOF]
    ]
    
    assert_equal expected_types.length, tokens.length
    expected_types.each_with_index do |expected_type, index|
      assert_equal expected_type, tokens[index].type
    end
  end

  def test_exclamation_mark_error_conditions
    # Test ! without = following it
    lexer = Lexer.new('!x')
    assert_raises(RuntimeError) do
      lexer.tokenize
    end
    
    lexer = Lexer.new('! ')
    assert_raises(RuntimeError) do
      lexer.tokenize
    end
  end

  def test_mixed_numbers_and_operators_comprehensive
    lexer = Lexer.new('1+2-3*4/5')  # No spaces
    tokens = lexer.tokenize
    
    expected_values = [1, '+', 2, '-', 3, '*', 4, '/', 5]
    
    assert_equal expected_values.length + 1, tokens.length  # +1 for EOF
    expected_values.each_with_index do |expected_value, index|
      assert_equal expected_value, tokens[index].value
    end
  end

  def test_keyword_boundary_detection
    # Test that keywords must be complete words
    lexer = Lexer.new('truefalse ifx thenor elsebut endian whilex doit')
    tokens = lexer.tokenize
    
    # All should be identifiers, not keywords
    expected_identifiers = ['truefalse', 'ifx', 'thenor', 'elsebut', 'endian', 'whilex', 'doit']
    
    assert_equal expected_identifiers.length + 1, tokens.length  # +1 for EOF
    expected_identifiers.each_with_index do |expected_id, index|
      assert_equal Token::TOKEN_TYPES[:IDENTIFIER], tokens[index].type
      assert_equal expected_id, tokens[index].value
    end
  end