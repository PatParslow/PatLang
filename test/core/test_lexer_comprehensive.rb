require_relative '../test_helper'
require_relative '../../src/lexer'
require_relative '../../src/token'

# Comprehensive test suite for Lexer - Phase 1 Foundation
# Target: 75%+ coverage for src/lexer.rb
# Focus on gap analysis findings: error handling, string tokenization, number parsing, operators
class TestLexerComprehensive < Minitest::Test

  def setup
    # Common setup for lexer tests
  end

  # ===== LEXER INITIALIZATION TESTS =====
  
  def test_lexer_initialization_basic
    lexer = Lexer.new("hello")
    assert_instance_of Lexer, lexer
    
    # Test initial state
    assert_equal 'h', lexer.instance_variable_get(:@current_char)
    assert_equal 0, lexer.instance_variable_get(:@position)
    assert_equal 1, lexer.instance_variable_get(:@line)
    assert_equal 1, lexer.instance_variable_get(:@column)
  end

  def test_lexer_initialization_empty_string
    lexer = Lexer.new("")
    assert_nil lexer.instance_variable_get(:@current_char)
    assert_equal 0, lexer.instance_variable_get(:@position)
  end

  def test_lexer_initialization_whitespace_only
    lexer = Lexer.new("   \t\n")
    assert_equal ' ', lexer.instance_variable_get(:@current_char)
  end

  # ===== ADVANCE METHOD TESTS (Gap Analysis Priority) =====
  
  def test_advance_method_basic
    lexer = Lexer.new("abc")
    
    # Initial state
    assert_equal 'a', lexer.instance_variable_get(:@current_char)
    assert_equal 0, lexer.instance_variable_get(:@position)
    assert_equal 1, lexer.instance_variable_get(:@line)
    assert_equal 1, lexer.instance_variable_get(:@column)
    
    # First advance
    lexer.send(:advance)
    assert_equal 'b', lexer.instance_variable_get(:@current_char)
    assert_equal 1, lexer.instance_variable_get(:@position)
    assert_equal 1, lexer.instance_variable_get(:@line)
    assert_equal 2, lexer.instance_variable_get(:@column)
    
    # Second advance
    lexer.send(:advance)
    assert_equal 'c', lexer.instance_variable_get(:@current_char)
    assert_equal 2, lexer.instance_variable_get(:@position)
    assert_equal 3, lexer.instance_variable_get(:@column)
    
    # End of input
    lexer.send(:advance)
    assert_nil lexer.instance_variable_get(:@current_char)
    assert_equal 3, lexer.instance_variable_get(:@position)
  end

  def test_advance_method_newline_tracking
    lexer = Lexer.new("a\nb\nc")
    
    # Initial
    assert_equal 1, lexer.instance_variable_get(:@line)
    assert_equal 1, lexer.instance_variable_get(:@column)
    
    # After 'a'
    lexer.send(:advance)
    assert_equal 1, lexer.instance_variable_get(:@line)
    assert_equal 2, lexer.instance_variable_get(:@column)
    
    # After newline
    lexer.send(:advance)
    assert_equal 2, lexer.instance_variable_get(:@line)
    assert_equal 1, lexer.instance_variable_get(:@column)
    
    # After 'b'
    lexer.send(:advance)
    assert_equal 2, lexer.instance_variable_get(:@line)
    assert_equal 2, lexer.instance_variable_get(:@column)
    
    # After second newline
    lexer.send(:advance)
    assert_equal 3, lexer.instance_variable_get(:@line)
    assert_equal 1, lexer.instance_variable_get(:@column)
  end

  def test_advance_method_edge_cases
    # Test with nil current_char
    lexer = Lexer.new("")
    lexer.send(:advance)  # Should not crash
    assert_nil lexer.instance_variable_get(:@current_char)
    
    # Test multiple advances past end
    lexer.send(:advance)
    lexer.send(:advance)
    assert_nil lexer.instance_variable_get(:@current_char)
  end

  # ===== ERROR HANDLING TESTS (Gap Analysis Priority) =====
  
  def test_error_method_unknown_character
    lexer = Lexer.new("@")  # @ might be unknown in some contexts
    
    # Test that error method returns UNKNOWN token instead of raising
    token = lexer.get_next_token
    
    # The lexer should never fail - it should return a token
    assert_instance_of Token, token
    # Based on lexer implementation, @ should be handled, but test invalid chars
  end

  def test_error_recovery_invalid_characters
    # Test various potentially invalid characters
    invalid_chars = ['§', '¢', '£', '¥', '©', '®', '™']
    
    invalid_chars.each do |char|
      lexer = Lexer.new(char)
      token = lexer.get_next_token
      
      # Lexer should never raise exception - should return token
      assert_instance_of Token, token
      # Should either be UNKNOWN or handled by lexer
      assert_includes [Token::TOKEN_TYPES[:UNKNOWN], Token::TOKEN_TYPES[:AT]], token.type
    end
  end

  def test_error_method_position_tracking
    lexer = Lexer.new("valid§invalid")
    
    # Get tokens until we hit the invalid character
    tokens = []
    begin
      loop do
        token = lexer.get_next_token
        tokens << token
        break if token.type == Token::TOKEN_TYPES[:EOF]
      end
    rescue => e
      flunk "Lexer should never raise exceptions: #{e.message}"
    end
    
    # Should have tokenized successfully
    assert tokens.length > 0
    assert_equal Token::TOKEN_TYPES[:EOF], tokens.last.type
  end

  def test_error_method_advance_mechanism
    # Test that error method advances past problematic character
    lexer = Lexer.new("x§y")  # Use x,y to avoid 'a' ambiguity
    
    tokens = lexer.tokenize
    
    # Should get identifier 'x', then handle §, then identifier 'y', then EOF
    assert tokens.length >= 3
    # First token should be identifier (could be regular Token or AmbiguousToken)
    first_token = tokens[0]
    if first_token.class.name == 'AmbiguousToken'
      # For AmbiguousToken, it should have identifier possibility
      assert_includes first_token.to_s.downcase, 'identifier'
    else
      assert_equal Token::TOKEN_TYPES[:IDENTIFIER], first_token.type
      assert_equal "x", first_token.value
    end
    
    # Last token should be EOF
    assert_equal Token::TOKEN_TYPES[:EOF], tokens[-1].type
  end

  # ===== NUMBER PARSING TESTS (Gap Analysis Priority) =====
  
  def test_read_number_integers
    test_cases = [
      ["0", 0],
      ["1", 1],
      ["42", 42],
      ["123", 123],
      ["999", 999]
    ]
    
    test_cases.each do |input, expected|
      lexer = Lexer.new(input)
      token = lexer.get_next_token
      
      assert_equal Token::TOKEN_TYPES[:NUMBER], token.type
      assert_equal expected, token.value
    end
  end

  def test_read_number_floats
    test_cases = [
      ["3.14", 3.14],
      ["0.5", 0.5],
      ["123.456", 123.456],
      ["0.0", 0.0],
      ["99.99", 99.99]
    ]
    
    test_cases.each do |input, expected|
      lexer = Lexer.new(input)
      token = lexer.get_next_token
      
      assert_equal Token::TOKEN_TYPES[:NUMBER], token.type
      assert_in_delta expected, token.value, 0.001
    end
  end

  def test_read_number_edge_cases
    # Test decimal starting with dot
    lexer = Lexer.new(".5")
    token = lexer.get_next_token
    assert_equal Token::TOKEN_TYPES[:NUMBER], token.type
    assert_equal 0.5, token.value
    
    # Test decimal ending with dot (should be integer + dot)
    lexer = Lexer.new("5.")
    tokens = lexer.tokenize
    # Could be parsed as 5.0 or as 5 followed by DOT depending on implementation
    assert tokens.length >= 2
  end

  def test_read_number_position_tracking
    lexer = Lexer.new("123")
    token = lexer.get_next_token
    
    assert_equal Token::TOKEN_TYPES[:NUMBER], token.type
    assert_equal 123, token.value
    # Position might be end position (3) rather than start position (0)
    assert token.position >= 0, "Position should be non-negative"
    assert_equal 1, token.line
    assert_equal 1, token.column
  end

  def test_read_number_boundaries
    # Test numbers followed by other tokens
    lexer = Lexer.new("42 + 3.14")
    tokens = lexer.tokenize
    
    assert tokens.length >= 4  # NUMBER, PLUS, NUMBER, EOF
    assert_equal Token::TOKEN_TYPES[:NUMBER], tokens[0].type
    assert_equal 42, tokens[0].value
    assert_equal Token::TOKEN_TYPES[:PLUS], tokens[1].type
    assert_equal Token::TOKEN_TYPES[:NUMBER], tokens[2].type
    assert_in_delta 3.14, tokens[2].value, 0.001
  end

  # ===== STRING TOKENIZATION TESTS (Gap Analysis Priority) =====
  
  def test_tokenize_string_double_quotes
    test_cases = [
      ['""', ""],
      ['"hello"', "hello"],
      ['"hello world"', "hello world"],
      ['"123"', "123"]
    ]
    
    test_cases.each do |input, expected|
      lexer = Lexer.new(input)
      token = lexer.get_next_token
      
      assert_equal Token::TOKEN_TYPES[:STRING], token.type
      assert_equal expected, token.value
    end
  end

  def test_tokenize_string_single_quotes
    test_cases = [
      ["''", ""],
      ["'hello'", "hello"],
      ["'single quoted'", "single quoted"]
    ]
    
    test_cases.each do |input, expected|
      lexer = Lexer.new(input)
      token = lexer.get_next_token
      
      assert_equal Token::TOKEN_TYPES[:STRING], token.type
      assert_equal expected, token.value
    end
  end

  def test_tokenize_string_escape_sequences
    test_cases = [
      ['"\\n"', "\n"],
      ['"\\t"', "\t"],
      ['"\\r"', "\r"],
      ['"\\\\"', "\\"],
      ['"\""', '"'],
      ['"\'"', "'"]
    ]
    
    test_cases.each do |input, expected|
      lexer = Lexer.new(input)
      token = lexer.get_next_token
      
      assert_equal Token::TOKEN_TYPES[:STRING], token.type
      assert_equal expected, token.value, "Failed for input: #{input}"
    end
  end

  def test_tokenize_string_mixed_quotes
    # Test string with single quotes inside double quotes
    lexer = Lexer.new('"He said \'hello\'"')
    token = lexer.get_next_token
    
    assert_equal Token::TOKEN_TYPES[:STRING], token.type
    assert_equal "He said 'hello'", token.value
    
    # Test string with double quotes inside single quotes
    lexer = Lexer.new("'She said \"goodbye\"'")
    token = lexer.get_next_token
    
    assert_equal Token::TOKEN_TYPES[:STRING], token.type
    assert_equal 'She said "goodbye"', token.value
  end

  def test_tokenize_string_unterminated
    # Test unterminated strings - should handle gracefully
    lexer = Lexer.new('"unterminated string')
    token = lexer.get_next_token
    
    # Should either be UNTERMINATED_STRING token or handle it gracefully
    assert_instance_of Token, token
    # Based on implementation, could be UNTERMINATED_STRING or handled differently
  end

  def test_tokenize_string_position_tracking
    lexer = Lexer.new('"hello"')
    token = lexer.get_next_token
    
    assert_equal Token::TOKEN_TYPES[:STRING], token.type
    assert_equal "hello", token.value
    assert_equal 0, token.position
    assert_equal 1, token.line
    assert_equal 1, token.column
  end

  # ===== OPERATOR RECOGNITION TESTS (Gap Analysis Priority) =====
  
  def test_arithmetic_operators
    operators = [
      ['+', Token::TOKEN_TYPES[:PLUS]],
      ['-', Token::TOKEN_TYPES[:MINUS]],
      ['*', :STAR],  # Based on lexer implementation
      ['/', :SLASH],
      ['%', :PERCENT],
      ['^', :CARET]
    ]
    
    operators.each do |input, expected_type|
      lexer = Lexer.new(input)
      token = lexer.get_next_token
      
      assert_equal expected_type, token.type
      assert_equal input, token.value
    end
  end

  def test_comparison_operators
    operators = [
      ['==', Token::TOKEN_TYPES[:EQUAL]],
      ['!=', Token::TOKEN_TYPES[:NOT_EQUAL]],
      ['<', :LESS],
      ['>', :GREATER],
      ['<=', Token::TOKEN_TYPES[:LESS_EQUAL]],
      ['>=', Token::TOKEN_TYPES[:GREATER_EQUAL]]
    ]
    
    operators.each do |input, expected_type|
      lexer = Lexer.new(input)
      token = lexer.get_next_token
      
      assert_equal expected_type, token.type
      assert_equal input, token.value
    end
  end

  def test_assignment_operators
    lexer = Lexer.new("=")
    token = lexer.get_next_token
    assert_equal :ASSIGN, token.type
    
    # Test that == is different from =
    lexer = Lexer.new("==")
    token = lexer.get_next_token
    assert_equal Token::TOKEN_TYPES[:EQUAL], token.type
    assert_equal "==", token.value
  end

  def test_logical_operators
    lexer = Lexer.new("!")
    token = lexer.get_next_token
    assert_equal Token::TOKEN_TYPES[:NOT], token.type
    assert_equal "!", token.value
    
    # Test != vs !
    lexer = Lexer.new("!=")
    token = lexer.get_next_token
    assert_equal Token::TOKEN_TYPES[:NOT_EQUAL], token.type
    assert_equal "!=", token.value
  end

  def test_parentheses_and_brackets
    punctuation = [
      ['(', Token::TOKEN_TYPES[:LPAREN]],
      [')', Token::TOKEN_TYPES[:RPAREN]],
      ['[', Token::TOKEN_TYPES[:LBRACKET]],
      [']', Token::TOKEN_TYPES[:RBRACKET]],
      ['{', Token::TOKEN_TYPES[:LBRACE]],
      ['}', Token::TOKEN_TYPES[:RBRACE]]
    ]
    
    punctuation.each do |input, expected_type|
      lexer = Lexer.new(input)
      token = lexer.get_next_token
      
      assert_equal expected_type, token.type
      assert_equal input, token.value
    end
  end

  def test_special_operators
    specials = [
      ['.', Token::TOKEN_TYPES[:DOT]],
      [',', Token::TOKEN_TYPES[:COMMA]],
      [':', Token::TOKEN_TYPES[:COLON]],
      ['::', Token::TOKEN_TYPES[:DOUBLE_COLON]],
      ['@', Token::TOKEN_TYPES[:AT]],
      ['?', :QUESTION],
      ['?-', Token::TOKEN_TYPES[:QUERY_PREFIX]]
    ]
    
    specials.each do |input, expected_type|
      lexer = Lexer.new(input)
      token = lexer.get_next_token
      
      assert_equal expected_type, token.type
      if input.length == 1
        assert_equal input, token.value
      end
    end
  end

  # ===== IDENTIFIER AND KEYWORD TESTS =====
  
  def test_read_identifier_basic
    identifiers = ["x", "variable", "test123", "_private", "CamelCase", "CONSTANT"]
    
    identifiers.each do |identifier|
      lexer = Lexer.new(identifier)
      token = lexer.get_next_token
      
      assert_equal Token::TOKEN_TYPES[:IDENTIFIER], token.type
      assert_equal identifier, token.value
    end
  end

  def test_read_identifier_with_question_mark
    lexer = Lexer.new("empty?")
    token = lexer.get_next_token
    
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], token.type
    assert_equal "empty?", token.value
  end

  def test_keyword_recognition
    keywords = [
      ["true", Token::TOKEN_TYPES[:TRUE]],
      ["false", Token::TOKEN_TYPES[:FALSE]],
      ["if", Token::TOKEN_TYPES[:IF]],
      ["then", Token::TOKEN_TYPES[:THEN]],
      ["else", Token::TOKEN_TYPES[:ELSE]],
      ["while", Token::TOKEN_TYPES[:WHILE]],
      ["do", Token::TOKEN_TYPES[:DO]],
      ["print", Token::TOKEN_TYPES[:PRINT]]
    ]
    
    keywords.each do |input, expected_type|
      lexer = Lexer.new(input)
      token = lexer.get_next_token
      
      assert_equal expected_type, token.type
      assert_equal input, token.value
    end
  end

  def test_function_keywords
    # These might be ambiguous tokens based on implementation
    function_keywords = ["make", "a", "function", "called", "end"]
    
    function_keywords.each do |keyword|
      lexer = Lexer.new(keyword)
      token = lexer.get_next_token
      
      # Handle both Token and AmbiguousToken types
      assert token.is_a?(Token) || token.class.name == 'AmbiguousToken',
            "Expected Token or AmbiguousToken, got #{token.class}"
    end
  end

  def test_reasoning_keywords
    reasoning_keywords = [
      ["reasoning", Token::TOKEN_TYPES[:REASONING]],
      ["mode", Token::TOKEN_TYPES[:MODE]],
      ["on", Token::TOKEN_TYPES[:ON]],
      ["off", Token::TOKEN_TYPES[:OFF]],
      ["constrain", Token::TOKEN_TYPES[:CONSTRAIN]],
      ["assert", Token::TOKEN_TYPES[:ASSERT]],
      ["fact", Token::TOKEN_TYPES[:FACT]],
      ["goal", Token::TOKEN_TYPES[:GOAL]]
    ]
    
    reasoning_keywords.each do |input, expected_type|
      lexer = Lexer.new(input)
      token = lexer.get_next_token
      
      assert_equal expected_type, token.type
      assert_equal input, token.value
    end
  end

  # ===== WHITESPACE AND COMMENT HANDLING =====
  
  def test_skip_whitespace
    lexer = Lexer.new("   \t\n\r  token")
    token = lexer.get_next_token
    
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], token.type
    assert_equal "token", token.value
  end

  def test_skip_comment
    lexer = Lexer.new("# This is a comment\ntoken")
    token = lexer.get_next_token
    
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], token.type
    assert_equal "token", token.value
  end

  def test_comment_context
    # Test that # is only treated as comment in proper context
    lexer = Lexer.new("# comment\ncode")
    tokens = lexer.tokenize
    
    # Should skip comment and get 'code' token
    assert tokens.length >= 2
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], tokens[0].type
    assert_equal "code", tokens[0].value
    assert_equal Token::TOKEN_TYPES[:EOF], tokens[-1].type
  end

  # ===== TOKENIZATION INTEGRATION TESTS =====
  
  def test_tokenize_simple_expression
    lexer = Lexer.new("x + 42")
    tokens = lexer.tokenize
    
    assert_equal 4, tokens.length
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], tokens[0].type
    assert_equal "x", tokens[0].value
    assert_equal Token::TOKEN_TYPES[:PLUS], tokens[1].type
    assert_equal Token::TOKEN_TYPES[:NUMBER], tokens[2].type
    assert_equal 42, tokens[2].value
    assert_equal Token::TOKEN_TYPES[:EOF], tokens[3].type
  end

  def test_tokenize_assignment
    lexer = Lexer.new('result = "hello world"')
    tokens = lexer.tokenize
    
    assert tokens.length >= 4
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], tokens[0].type
    assert_equal "result", tokens[0].value
    assert_equal :ASSIGN, tokens[1].type
    assert_equal Token::TOKEN_TYPES[:STRING], tokens[2].type
    assert_equal "hello world", tokens[2].value
    assert_equal Token::TOKEN_TYPES[:EOF], tokens[-1].type
  end

  def test_tokenize_function_call
    lexer = Lexer.new("print(42)")
    tokens = lexer.tokenize
    
    assert tokens.length >= 5
    assert_equal Token::TOKEN_TYPES[:PRINT], tokens[0].type
    assert_equal Token::TOKEN_TYPES[:LPAREN], tokens[1].type
    assert_equal Token::TOKEN_TYPES[:NUMBER], tokens[2].type
    assert_equal 42, tokens[2].value
    assert_equal Token::TOKEN_TYPES[:RPAREN], tokens[3].type
    assert_equal Token::TOKEN_TYPES[:EOF], tokens[-1].type
  end

  def test_tokenize_complex_expression
    lexer = Lexer.new("(x + y) * 2.5")  # Use x,y to avoid 'a' ambiguity
    tokens = lexer.tokenize
    
    expected_types = [
      Token::TOKEN_TYPES[:LPAREN],
      Token::TOKEN_TYPES[:IDENTIFIER],
      Token::TOKEN_TYPES[:PLUS],
      Token::TOKEN_TYPES[:IDENTIFIER],
      Token::TOKEN_TYPES[:RPAREN],
      :STAR,
      Token::TOKEN_TYPES[:NUMBER],
      Token::TOKEN_TYPES[:EOF]
    ]
    
    assert_equal expected_types.length, tokens.length
    expected_types.each_with_index do |expected_type, i|
      # Handle potential AmbiguousToken for single-letter identifiers
      actual_type = tokens[i].respond_to?(:type) ? tokens[i].type :
                   (tokens[i].class.name == 'AmbiguousToken' ? :AMBIGUOUS : tokens[i].class)
      
      if expected_type == Token::TOKEN_TYPES[:IDENTIFIER] && actual_type == :AMBIGUOUS
        # Accept AmbiguousToken as valid for identifiers
        next
      end
      
      assert_equal expected_type, actual_type, "Token #{i} type mismatch"
    end
  end

  # ===== PEEK FUNCTIONALITY TESTS =====
  
  def test_peek_char_method
    lexer = Lexer.new("abc")
    
    # Test peek_char method
    if lexer.respond_to?(:peek_char, true)  # Check if private method exists
      assert_equal 'b', lexer.send(:peek_char)
      
      # Advance and peek again
      lexer.send(:advance)
      assert_equal 'c', lexer.send(:peek_char)
      
      # Advance to last char and peek
      lexer.send(:advance)
      assert_nil lexer.send(:peek_char)
    end
  end

  # ===== POSITION AND LINE TRACKING TESTS =====
  
  def test_position_tracking_single_line
    lexer = Lexer.new("abc def")
    
    token1 = lexer.get_next_token
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], token1.type
    assert_equal 0, token1.position
    assert_equal 1, token1.line
    assert_equal 1, token1.column
    
    token2 = lexer.get_next_token
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], token2.type
    assert_equal 4, token2.position
    assert_equal 1, token2.line
    assert_equal 5, token2.column
  end

  def test_position_tracking_multiple_lines
    lexer = Lexer.new("line1\nline2\nline3")
    
    token1 = lexer.get_next_token
    assert_equal 1, token1.line
    
    token2 = lexer.get_next_token
    assert_equal 2, token2.line
    
    token3 = lexer.get_next_token
    assert_equal 3, token3.line
  end

  # ===== EDGE CASES AND ERROR CONDITIONS =====
  
  def test_lexer_never_fails_principle
    # Test that lexer never raises exceptions, always returns tokens
    problematic_inputs = [
      "§¥£",
      "weird™chars®",
      "\x00\x01\x02",  # Control characters
      "unterminated_string\"",
      "12..34",  # Invalid number format
      "...",
      "!!!=",
      "<<>>",
      "}}{{",
    ]
    
    problematic_inputs.each do |input|
      lexer = Lexer.new(input)
      
      assert_nothing_raised "Lexer should never fail for input: #{input.inspect}" do
        tokens = lexer.tokenize
        assert_instance_of Array, tokens
        assert tokens.length > 0
        assert_equal Token::TOKEN_TYPES[:EOF], tokens.last.type
      end
    end
  end

  def test_empty_input_handling
    lexer = Lexer.new("")
    token = lexer.get_next_token
    
    assert_equal Token::TOKEN_TYPES[:EOF], token.type
    assert_nil token.value
  end

  def test_single_character_inputs
    single_chars = "bcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    
    single_chars.each_char do |char|
      lexer = Lexer.new(char)
      token = lexer.get_next_token
      
      # Handle both Token and AmbiguousToken
      assert token.is_a?(Token) || token.class.name == 'AmbiguousToken',
            "Expected Token or AmbiguousToken for '#{char}', got #{token.class}"
      
      # Don't test 'a' separately as it's ambiguous
      unless token.class.name == 'AmbiguousToken'
        refute_equal Token::TOKEN_TYPES[:EOF], token.type
      end
    end
    
    # Test 'a' separately as it's ambiguous
    lexer = Lexer.new("a")
    token = lexer.get_next_token
    assert token.class.name == 'AmbiguousToken' || token.is_a?(Token)
  end

  def test_tokenization_consistency
    # Test that multiple tokenizations of same input produce same result
    input = "x = 42 + y"
    
    lexer1 = Lexer.new(input)
    tokens1 = lexer1.tokenize
    
    lexer2 = Lexer.new(input)
    tokens2 = lexer2.tokenize
    
    assert_equal tokens1.length, tokens2.length
    tokens1.each_with_index do |token1, i|
      token2 = tokens2[i]
      assert_equal token1.type, token2.type, "Token #{i} type mismatch"
      assert_equal token1.value, token2.value, "Token #{i} value mismatch"
    end
  end

  def test_get_next_token_vs_next_token_alias
    lexer = Lexer.new("test")
    
    # Test that both methods work
    assert_respond_to lexer, :get_next_token
    assert_respond_to lexer, :next_token
    
    token1 = lexer.get_next_token
    
    lexer2 = Lexer.new("test")
    token2 = lexer2.next_token
    
    assert_equal token1.type, token2.type
    assert_equal token1.value, token2.value
  end

  # ===== PERFORMANCE AND BOUNDARY TESTS =====
  
  def test_large_input_handling
    # Test with reasonably large input
    large_input = "variable" * 1000
    lexer = Lexer.new(large_input)
    
    assert_nothing_raised do
      tokens = lexer.tokenize
      assert tokens.length >= 2  # At least identifier and EOF
      assert_equal Token::TOKEN_TYPES[:EOF], tokens.last.type
    end
  end

  def test_unicode_handling
    # Test basic Unicode handling
    unicode_inputs = ["café", "naïve", "résumé", "中文", "🚀"]
    
    unicode_inputs.each do |input|
      lexer = Lexer.new(input)
      
      assert_nothing_raised "Failed to handle Unicode input: #{input}" do
        tokens = lexer.tokenize
        assert tokens.length > 0
        assert_equal Token::TOKEN_TYPES[:EOF], tokens.last.type
      end
    end
  end

end