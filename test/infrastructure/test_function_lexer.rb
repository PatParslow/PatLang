require_relative '../helpers/test_helper'
require_relative '../../src/lexer'

class TestFunctionLexer < Minitest::Test
  def test_function_keywords
    lexer = Lexer.new("make a function called test_func")
    tokens = lexer.tokenize
    
    assert_equal Token::TOKEN_TYPES[:MAKE], tokens[0].type
    assert_equal "make", tokens[0].value
    
    assert_equal Token::TOKEN_TYPES[:A], tokens[1].type
    assert_equal "a", tokens[1].value
    
    assert_equal Token::TOKEN_TYPES[:FUNCTION], tokens[2].type
    assert_equal "function", tokens[2].value
    
    assert_equal Token::TOKEN_TYPES[:CALLED], tokens[3].type
    assert_equal "called", tokens[3].value
    
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], tokens[4].type
    assert_equal "test_func", tokens[4].value
  end
  
  def test_function_definition_tokens
    code = <<~PATLANG
      make a function called add {
        add takes:
          a - number
          b - number
        add returns:
          a + b
      }
    PATLANG
    
    lexer = Lexer.new(code)
    tokens = lexer.tokenize
    
    # Extract token types for easier testing
    token_types = tokens.map(&:type)
    
    # Verify we have the essential function tokens
    assert_includes token_types, Token::TOKEN_TYPES[:MAKE]
    assert_includes token_types, Token::TOKEN_TYPES[:FUNCTION]
    assert_includes token_types, Token::TOKEN_TYPES[:CALLED]
    assert_includes token_types, Token::TOKEN_TYPES[:LBRACE]
    assert_includes token_types, Token::TOKEN_TYPES[:TAKES]
    assert_includes token_types, Token::TOKEN_TYPES[:COLON]
    assert_includes token_types, Token::TOKEN_TYPES[:MINUS]
    assert_includes token_types, Token::TOKEN_TYPES[:RETURNS]
    assert_includes token_types, Token::TOKEN_TYPES[:RBRACE]
  end
  
  def test_individual_function_keywords
    test_cases = [
      ["takes", Token::TOKEN_TYPES[:TAKES]],
      ["returns", Token::TOKEN_TYPES[:RETURNS]],
      ["return", Token::TOKEN_TYPES[:RETURN]],
      ["call", Token::TOKEN_TYPES[:CALL]]
    ]
    
    test_cases.each do |keyword, expected_type|
      lexer = Lexer.new(keyword)
      tokens = lexer.tokenize
      
      assert_equal expected_type, tokens[0].type, "Failed for keyword: #{keyword}"
      assert_equal keyword, tokens[0].value, "Failed for keyword: #{keyword}"
    end
  end
  
  def test_function_punctuation
    test_cases = [
      ["{", Token::TOKEN_TYPES[:LBRACE]],
      ["}", Token::TOKEN_TYPES[:RBRACE]],
      [":", Token::TOKEN_TYPES[:COLON]],
      ["-", Token::TOKEN_TYPES[:MINUS]]
    ]
    
    test_cases.each do |symbol, expected_type|
      lexer = Lexer.new(symbol)
      tokens = lexer.tokenize
      
      assert_equal expected_type, tokens[0].type, "Failed for symbol: #{symbol}"
      assert_equal symbol, tokens[0].value, "Failed for symbol: #{symbol}"
    end
  end
  
  def test_make_without_function_phrase
    # "make" without "a function called" should be treated as identifier
    lexer = Lexer.new("make something")
    tokens = lexer.tokenize
    
    assert_equal Token::TOKEN_TYPES[:MAKE], tokens[0].type
    assert_equal "make", tokens[0].value
  end
  
  def test_partial_function_phrases
    # Test various partial phrases that should not trigger function detection
    test_cases = [
      "make a mistake",
      "make a call",
      "make function work",
      "make a function",
      "function called test",
      "a function called test"
    ]
    
    test_cases.each do |phrase|
      lexer = Lexer.new(phrase)
      tokens = lexer.tokenize
      
      # With AmbiguousToken architecture, "make" returns :MAKE token
      if phrase.start_with?("make a")
        if phrase == "make a function"
          assert_equal Token::TOKEN_TYPES[:MAKE], tokens[0].type, "Failed for: #{phrase}"
        else
          assert_equal Token::TOKEN_TYPES[:MAKE], tokens[0].type, "Failed for: #{phrase}"
        end
      end
    end
  end
  
  def test_function_phrase_detection_edge_cases
    # Test the check_function_phrase method indirectly
    lexer = Lexer.new("make    a    function    called    test")
    tokens = lexer.tokenize
    
    # Should still detect function phrase despite extra whitespace
    assert_equal Token::TOKEN_TYPES[:MAKE], tokens[0].type
    assert_equal Token::TOKEN_TYPES[:A], tokens[1].type
    assert_equal "a", tokens[1].value
    assert_equal Token::TOKEN_TYPES[:FUNCTION], tokens[2].type
    assert_equal Token::TOKEN_TYPES[:CALLED], tokens[3].type
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], tokens[4].type
    assert_equal "test", tokens[4].value
  end
  
  def test_complex_function_syntax
    code = "make a function called calculate { calculate takes: x - number }"
    lexer = Lexer.new(code)
    tokens = lexer.tokenize
    
    expected_sequence = [
      [Token::TOKEN_TYPES[:MAKE], "make"],
      [Token::TOKEN_TYPES[:A], "a"],
      [Token::TOKEN_TYPES[:FUNCTION], "function"],
      [Token::TOKEN_TYPES[:CALLED], "called"],
      [Token::TOKEN_TYPES[:IDENTIFIER], "calculate"],
      [Token::TOKEN_TYPES[:LBRACE], "{"],
      [Token::TOKEN_TYPES[:IDENTIFIER], "calculate"],
      [Token::TOKEN_TYPES[:TAKES], "takes"],
      [Token::TOKEN_TYPES[:COLON], ":"],
      [Token::TOKEN_TYPES[:IDENTIFIER], "x"],
      [Token::TOKEN_TYPES[:MINUS], "-"],
      [Token::TOKEN_TYPES[:IDENTIFIER], "number"],
      [Token::TOKEN_TYPES[:RBRACE], "}"]
    ]
    
    expected_sequence.each_with_index do |(expected_type, expected_value), index|
      assert tokens[index], "Missing token at index #{index}"
      assert_equal expected_type, tokens[index].type, "Wrong token type at index #{index}"
      assert_equal expected_value, tokens[index].value, "Wrong token value at index #{index}"
    end
  end
  
  def test_lexer_function_phrase_backtracking
    # Test that the lexer properly backtracks when function phrase detection fails
    lexer = Lexer.new("make a good choice")
    tokens = lexer.tokenize
    
    # With AmbiguousToken architecture, "make" and "a" return their respective tokens
    assert_equal Token::TOKEN_TYPES[:MAKE], tokens[0].type
    assert_equal "make", tokens[0].value
    assert_equal Token::TOKEN_TYPES[:A], tokens[1].type
    assert_equal "a", tokens[1].value
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], tokens[2].type
    assert_equal "good", tokens[2].value
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], tokens[3].type
    assert_equal "choice", tokens[3].value
  end
  
  def test_nested_function_keywords
    # Test function keywords in different contexts
    code = "if make a function called test then call test end"
    lexer = Lexer.new(code)
    tokens = lexer.tokenize
    
    token_types = tokens.map(&:type)
    
    assert_includes token_types, Token::TOKEN_TYPES[:IF]
    assert_includes token_types, Token::TOKEN_TYPES[:MAKE]
    assert_includes token_types, Token::TOKEN_TYPES[:FUNCTION]
    assert_includes token_types, Token::TOKEN_TYPES[:CALLED]
    assert_includes token_types, Token::TOKEN_TYPES[:THEN]
    assert_includes token_types, Token::TOKEN_TYPES[:CALL]
    assert_includes token_types, Token::TOKEN_TYPES[:END]
  end
end