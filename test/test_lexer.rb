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
end