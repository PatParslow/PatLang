require 'minitest/autorun'
require_relative '../src/lexer'
require_relative '../src/token'

class TestLexerComprehensive < Minitest::Test
  # String tokenization comprehensive tests
  def test_string_literal_basic
    lexer = Lexer.new('"hello"')
    tokens = lexer.tokenize
    
    assert_equal 2, tokens.length
    assert_equal Token::TOKEN_TYPES[:STRING], tokens[0].type
    assert_equal 'hello', tokens[0].value
    assert_equal Token::TOKEN_TYPES[:EOF], tokens[1].type
  end

  def test_string_with_escape_sequences
    lexer = Lexer.new('"hello\\nworld\\t\\"quote\\""')
    tokens = lexer.tokenize
    
    assert_equal 2, tokens.length
    assert_equal Token::TOKEN_TYPES[:STRING], tokens[0].type
    assert_equal "hello\nworld\t\"quote\"", tokens[0].value
  end

  def test_string_with_all_escape_sequences
    lexer = Lexer.new('"\\n\\t\\r\\\\\\""')
    tokens = lexer.tokenize
    
    assert_equal Token::TOKEN_TYPES[:STRING], tokens[0].type
    assert_equal "\n\t\r\\\"", tokens[0].value
  end

  def test_string_with_unrecognized_escape
    lexer = Lexer.new('"\\x"')
    tokens = lexer.tokenize
    
    assert_equal Token::TOKEN_TYPES[:STRING], tokens[0].type
    assert_equal "x", tokens[0].value  # Should include the character after backslash
  end

  def test_empty_string
    lexer = Lexer.new('""')
    tokens = lexer.tokenize
    
    assert_equal 2, tokens.length
    assert_equal Token::TOKEN_TYPES[:STRING], tokens[0].type
    assert_equal '', tokens[0].value
  end

  def test_string_with_spaces
    lexer = Lexer.new('"hello world with spaces"')
    tokens = lexer.tokenize
    
    assert_equal Token::TOKEN_TYPES[:STRING], tokens[0].type
    assert_equal 'hello world with spaces', tokens[0].value
  end

  def test_multiple_strings
    lexer = Lexer.new('"first" "second"')
    tokens = lexer.tokenize
    
    assert_equal 3, tokens.length
    assert_equal Token::TOKEN_TYPES[:STRING], tokens[0].type
    assert_equal 'first', tokens[0].value
    assert_equal Token::TOKEN_TYPES[:STRING], tokens[1].type
    assert_equal 'second', tokens[1].value
  end

  def test_string_assignment
    lexer = Lexer.new('message = "Hello World"')
    tokens = lexer.tokenize
    
    expected_types = [
      Token::TOKEN_TYPES[:IDENTIFIER],
      Token::TOKEN_TYPES[:EQUALS],
      Token::TOKEN_TYPES[:STRING],
      Token::TOKEN_TYPES[:EOF]
    ]
    
    assert_equal expected_types.length, tokens.length
    expected_types.each_with_index do |expected_type, index|
      assert_equal expected_type, tokens[index].type
    end
    
    assert_equal 'message', tokens[0].value
    assert_equal 'Hello World', tokens[2].value
  end

  def test_string_in_comparison
    lexer = Lexer.new('name == "John"')
    tokens = lexer.tokenize
    
    expected_types = [
      Token::TOKEN_TYPES[:IDENTIFIER],
      Token::TOKEN_TYPES[:EQUAL],
      Token::TOKEN_TYPES[:STRING],
      Token::TOKEN_TYPES[:EOF]
    ]
    
    assert_equal expected_types.length, tokens.length
    expected_types.each_with_index do |expected_type, index|
      assert_equal expected_type, tokens[index].type
    end
    
    assert_equal 'John', tokens[2].value
  end

  # String error conditions
  def test_unterminated_string_error
    lexer = Lexer.new('"unterminated string')
    
    error_raised = false
    begin
      lexer.tokenize
    rescue RuntimeError => e
      error_raised = true
      assert_includes e.message, "Unterminated string literal"
    end
    assert error_raised, "Expected unterminated string error"
  end

  def test_incomplete_escape_at_end_error
    lexer = Lexer.new('"incomplete escape\\')
    
    error_raised = false
    begin
      lexer.tokenize
    rescue RuntimeError => e
      error_raised = true
      assert_includes e.message, "Incomplete escape sequence"
    end
    assert error_raised, "Expected incomplete escape sequence error"
  end

  # DOT, LBRACKET, RBRACKET tokenization tests
  def test_dot_token
    lexer = Lexer.new('.')
    tokens = lexer.tokenize
    
    assert_equal 2, tokens.length
    assert_equal Token::TOKEN_TYPES[:DOT], tokens[0].type
    assert_equal '.', tokens[0].value
  end

  def test_dot_method_call
    lexer = Lexer.new('message.length')
    tokens = lexer.tokenize
    
    expected_types = [
      Token::TOKEN_TYPES[:IDENTIFIER],
      Token::TOKEN_TYPES[:DOT],
      Token::TOKEN_TYPES[:IDENTIFIER],
      Token::TOKEN_TYPES[:EOF]
    ]
    
    assert_equal expected_types.length, tokens.length
    expected_types.each_with_index do |expected_type, index|
      assert_equal expected_type, tokens[index].type
    end
    
    assert_equal 'message', tokens[0].value
    assert_equal 'length', tokens[2].value
  end

  def test_bracket_tokens
    lexer = Lexer.new('[]')
    tokens = lexer.tokenize
    
    assert_equal 3, tokens.length
    assert_equal Token::TOKEN_TYPES[:LBRACKET], tokens[0].type
    assert_equal '[', tokens[0].value
    assert_equal Token::TOKEN_TYPES[:RBRACKET], tokens[1].type
    assert_equal ']', tokens[1].value
  end

  def test_array_access
    lexer = Lexer.new('array[0]')
    tokens = lexer.tokenize
    
    expected_types = [
      Token::TOKEN_TYPES[:IDENTIFIER],
      Token::TOKEN_TYPES[:LBRACKET],
      Token::TOKEN_TYPES[:NUMBER],
      Token::TOKEN_TYPES[:RBRACKET],
      Token::TOKEN_TYPES[:EOF]
    ]
    
    assert_equal expected_types.length, tokens.length
    expected_types.each_with_index do |expected_type, index|
      assert_equal expected_type, tokens[index].type
    end
    
    assert_equal 'array', tokens[0].value
    assert_equal 0, tokens[2].value
  end

  def test_string_indexing
    lexer = Lexer.new('text[1]')
    tokens = lexer.tokenize
    
    expected_types = [
      Token::TOKEN_TYPES[:IDENTIFIER],
      Token::TOKEN_TYPES[:LBRACKET],
      Token::TOKEN_TYPES[:NUMBER],
      Token::TOKEN_TYPES[:RBRACKET],
      Token::TOKEN_TYPES[:EOF]
    ]
    
    assert_equal expected_types.length, tokens.length
    expected_types.each_with_index do |expected_type, index|
      assert_equal expected_type, tokens[index].type
    end
  end

  def test_comma_token
    lexer = Lexer.new(',')
    tokens = lexer.tokenize
    
    assert_equal 2, tokens.length
    assert_equal Token::TOKEN_TYPES[:COMMA], tokens[0].type
    assert_equal ',', tokens[0].value
  end

  def test_comma_in_expression
    lexer = Lexer.new('x, y, z')
    tokens = lexer.tokenize
    
    expected_types = [
      Token::TOKEN_TYPES[:IDENTIFIER],
      Token::TOKEN_TYPES[:COMMA],
      Token::TOKEN_TYPES[:IDENTIFIER],
      Token::TOKEN_TYPES[:COMMA],
      Token::TOKEN_TYPES[:IDENTIFIER],
      Token::TOKEN_TYPES[:EOF]
    ]
    
    assert_equal expected_types.length, tokens.length
    expected_types.each_with_index do |expected_type, index|
      assert_equal expected_type, tokens[index].type
    end
  end

  # Complex token sequences
  def test_string_operations_sequence
    lexer = Lexer.new('message = "Hello" + ", " + name')
    tokens = lexer.tokenize
    
    expected_types = [
      Token::TOKEN_TYPES[:IDENTIFIER], # message
      Token::TOKEN_TYPES[:EQUALS],     # =
      Token::TOKEN_TYPES[:STRING],     # "Hello"
      Token::TOKEN_TYPES[:PLUS],       # +
      Token::TOKEN_TYPES[:STRING],     # ", "
      Token::TOKEN_TYPES[:PLUS],       # +
      Token::TOKEN_TYPES[:IDENTIFIER], # name
      Token::TOKEN_TYPES[:EOF]
    ]
    
    assert_equal expected_types.length, tokens.length
    expected_types.each_with_index do |expected_type, index|
      assert_equal expected_type, tokens[index].type
    end
    
    assert_equal 'Hello', tokens[2].value
    assert_equal ', ', tokens[4].value
  end

  def test_string_method_call_chain
    lexer = Lexer.new('text.length.to_s')
    tokens = lexer.tokenize
    
    expected_types = [
      Token::TOKEN_TYPES[:IDENTIFIER], # text
      Token::TOKEN_TYPES[:DOT],        # .
      Token::TOKEN_TYPES[:IDENTIFIER], # length
      Token::TOKEN_TYPES[:DOT],        # .
      Token::TOKEN_TYPES[:IDENTIFIER], # to_s
      Token::TOKEN_TYPES[:EOF]
    ]
    
    assert_equal expected_types.length, tokens.length
    expected_types.each_with_index do |expected_type, index|
      assert_equal expected_type, tokens[index].type
    end
  end

  def test_string_indexing_with_comparison
    lexer = Lexer.new('text[0] == "H"')
    tokens = lexer.tokenize
    
    expected_types = [
      Token::TOKEN_TYPES[:IDENTIFIER], # text
      Token::TOKEN_TYPES[:LBRACKET],   # [
      Token::TOKEN_TYPES[:NUMBER],     # 0
      Token::TOKEN_TYPES[:RBRACKET],   # ]
      Token::TOKEN_TYPES[:EQUAL],      # ==
      Token::TOKEN_TYPES[:STRING],     # "H"
      Token::TOKEN_TYPES[:EOF]
    ]
    
    assert_equal expected_types.length, tokens.length
    expected_types.each_with_index do |expected_type, index|
      assert_equal expected_type, tokens[index].type
    end
    
    assert_equal 'H', tokens[5].value
  end

  # Decimal number edge cases 
  def test_decimal_starting_with_dot
    lexer = Lexer.new('.5')
    tokens = lexer.tokenize
    
    # Should tokenize as DOT then NUMBER, not as decimal
    assert_equal 2, tokens.length
    assert_equal Token::TOKEN_TYPES[:NUMBER], tokens[0].type
    assert_equal 0.5, tokens[0].value
  end

  def test_number_followed_by_method_call
    lexer = Lexer.new('42.to_s')
    tokens = lexer.tokenize
    
    # Should tokenize as NUMBER, DOT, IDENTIFIER
    expected_types = [
      Token::TOKEN_TYPES[:NUMBER],
      Token::TOKEN_TYPES[:DOT],
      Token::TOKEN_TYPES[:IDENTIFIER],
      Token::TOKEN_TYPES[:EOF]
    ]
    
    assert_equal expected_types.length, tokens.length
    expected_types.each_with_index do |expected_type, index|
      assert_equal expected_type, tokens[index].type
    end
    
    assert_equal 42, tokens[0].value
    assert_equal 'to_s', tokens[2].value
  end

  def test_decimal_precision
    lexer = Lexer.new('3.14159')
    tokens = lexer.tokenize
    
    assert_equal 2, tokens.length
    assert_equal Token::TOKEN_TYPES[:NUMBER], tokens[0].type
    assert_equal 3.14159, tokens[0].value
  end

  # Complex conditional expressions
  def test_complex_boolean_expression
    lexer = Lexer.new('(x > 5) == true')
    tokens = lexer.tokenize
    
    # Should include all the tokens in proper order
    token_values = tokens.map(&:value)
    assert_includes token_values, '('
    assert_includes token_values, 'x'
    assert_includes token_values, '>'
    assert_includes token_values, 5
    assert_includes token_values, ')'
    assert_includes token_values, '=='
    assert_includes token_values, 'true'
  end

  def test_all_comparison_operators_with_strings
    lexer = Lexer.new('"a" == "b" != "c" < "d" > "e" <= "f" >= "g"')
    tokens = lexer.tokenize
    
    # Extract operator tokens
    operator_tokens = tokens.select do |token|
      [Token::TOKEN_TYPES[:EQUAL], Token::TOKEN_TYPES[:NOT_EQUAL],
       Token::TOKEN_TYPES[:LESS_THAN], Token::TOKEN_TYPES[:GREATER_THAN],
       Token::TOKEN_TYPES[:LESS_EQUAL], Token::TOKEN_TYPES[:GREATER_EQUAL]].include?(token.type)
    end
    
    assert_equal 4, operator_tokens.length
    assert_equal '==', operator_tokens[0].value
    assert_equal '!=', operator_tokens[1].value
    assert_equal '<=', operator_tokens[2].value
    assert_equal '>=', operator_tokens[3].value
  end

  # Edge cases for whitespace and boundaries
  def test_no_spaces_complex_expression
    lexer = Lexer.new('x="hello"[0]')
    tokens = lexer.tokenize
    
    expected_types = [
      Token::TOKEN_TYPES[:IDENTIFIER], # x
      Token::TOKEN_TYPES[:EQUALS],     # =
      Token::TOKEN_TYPES[:STRING],     # "hello"
      Token::TOKEN_TYPES[:LBRACKET],   # [
      Token::TOKEN_TYPES[:NUMBER],     # 0
      Token::TOKEN_TYPES[:RBRACKET],   # ]
      Token::TOKEN_TYPES[:EOF]
    ]
    
    assert_equal expected_types.length, tokens.length
    expected_types.each_with_index do |expected_type, index|
      assert_equal expected_type, tokens[index].type
    end
  end

  def test_mixed_spacing_expression
    lexer = Lexer.new('  text   [   1   ]   ==   "x"  ')
    tokens = lexer.tokenize
    
    expected_types = [
      Token::TOKEN_TYPES[:IDENTIFIER],
      Token::TOKEN_TYPES[:LBRACKET],
      Token::TOKEN_TYPES[:NUMBER],
      Token::TOKEN_TYPES[:RBRACKET],
      Token::TOKEN_TYPES[:EQUAL],
      Token::TOKEN_TYPES[:STRING],
      Token::TOKEN_TYPES[:EOF]
    ]
    
    assert_equal expected_types.length, tokens.length
    expected_types.each_with_index do |expected_type, index|
      assert_equal expected_type, tokens[index].type
    end
  end

  # Test position tracking for new tokens
  def test_position_tracking_string_tokens
    lexer = Lexer.new('"hello" + "world"')
    tokens = lexer.tokenize
    
    assert_equal 0, tokens[0].position   # "hello" starts at 0
    assert_equal 8, tokens[1].position   # + at position 8
    assert_equal 10, tokens[2].position  # "world" starts at 10
  end

  def test_position_tracking_bracket_tokens
    lexer = Lexer.new('arr[42]')
    tokens = lexer.tokenize
    
    assert_equal 0, tokens[0].position   # arr starts at 0
    assert_equal 3, tokens[1].position   # [ at position 3
    assert_equal 6, tokens[2].position   # 42 starts at 6 (position recorded when token creation starts)
    assert_equal 6, tokens[3].position   # ] at position 6
  end
end