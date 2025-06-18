#!/usr/bin/env ruby

require 'minitest/autorun'
require 'simplecov'

# Configure SimpleCov for lexer-focused coverage measurement
SimpleCov.configure do
  add_filter '/test/'
  add_group 'Target: Lexer', 'src/lexer.rb'
  minimum_coverage 80
end

SimpleCov.start

require_relative 'src/lexer'
require_relative 'src/token'
require_relative 'src/ambiguous_token'

# Comprehensive Lexer Test Suite - Target: 80%+ Coverage
# Focus: Efficiently hitting uncovered lines identified in gap analysis
# Strategy: Target 309 additional lines through systematic edge case testing

class LexerEightyPercentCoverageTest < Minitest::Test
  
  def setup
    # Fresh lexer for each test
  end

  # =============================================================================
  # STRATEGY 1: ERROR METHOD COVERAGE (Lines 30-49) - Target: ~20 lines
  # =============================================================================
  
  def test_error_method_invalid_character_battery
    # Test every possible invalid character to trigger error method
    invalid_chars = ['@', '#', '$', '&', '~', '`', '§', 'ñ', 'ü', '€', '™', '©']
    
    invalid_chars.each do |char|
      lexer = Lexer.new(char)
      token = lexer.get_next_token
      
      assert_equal Token::TOKEN_TYPES[:UNKNOWN], token.type, "Expected UNKNOWN token for '#{char}'"
      assert_equal char, token.value, "Expected value '#{char}' for UNKNOWN token"
      
      # Verify position advancement after error
      eof_token = lexer.get_next_token
      assert_equal Token::TOKEN_TYPES[:EOF], eof_token.type
    end
  end

  def test_error_method_unicode_edge_cases
    # Unicode characters that should trigger error method
    unicode_chars = [
      "\u{FEFF}",  # BOM (Byte Order Mark)
      "\u{200B}",  # Zero-width space
      "\u{00A0}",  # Non-breaking space (if not handled as whitespace)
      "\u{2603}",  # Snowman
      "\u{1F600}", # Emoji
    ]

    unicode_chars.each do |char|
      lexer = Lexer.new(char)
      token = lexer.get_next_token
      
      # Should create UNKNOWN token via error method
      assert_equal Token::TOKEN_TYPES[:UNKNOWN], token.type
    end
  end

  def test_error_method_position_tracking
    # Verify error method correctly tracks line/column positions
    lexer = Lexer.new("valid + @invalid")
    
    # First token should be identifier
    token1 = lexer.get_next_token
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], token1.type
    
    # Second token should be plus
    token2 = lexer.get_next_token
    assert_equal Token::TOKEN_TYPES[:PLUS], token2.type
    
    # Third token should be UNKNOWN via error method
    token3 = lexer.get_next_token
    assert_equal Token::TOKEN_TYPES[:UNKNOWN], token3.type
    assert_equal '@', token3.value
    assert_equal 1, token3.line
    assert_equal 9, token3.column
  end

  # =============================================================================
  # STRATEGY 2: GET_NEXT_TOKEN BRANCH COVERAGE (Lines 97-271) - Target: ~60 lines
  # =============================================================================

  def test_get_next_token_comment_context_branches
    # Test comment_context? method through get_next_token
    
    # Hash at start of line (should be comment)
    lexer = Lexer.new("# this is a comment\n42")
    token = lexer.get_next_token
    assert_equal Token::TOKEN_TYPES[:NUMBER], token.type  # Comment should be skipped
    
    # Hash after whitespace (should be comment)  
    lexer = Lexer.new("   # this is a comment\n42")
    token = lexer.get_next_token
    assert_equal Token::TOKEN_TYPES[:NUMBER], token.type
    
    # Hash NOT in comment context (should be UNKNOWN)
    lexer = Lexer.new("abc#def")
    token1 = lexer.get_next_token
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], token1.type
    assert_equal 'abc', token1.value
    
    token2 = lexer.get_next_token
    assert_equal Token::TOKEN_TYPES[:UNKNOWN], token2.type  # Hash not in comment context
    assert_equal '#', token2.value
  end

  def test_get_next_token_decimal_number_branches
    # Test decimal number detection in get_next_token (lines 194-202)
    
    # Decimal number starting with dot
    lexer = Lexer.new(".5")
    token = lexer.get_next_token
    assert_equal Token::TOKEN_TYPES[:NUMBER], token.type
    assert_equal 0.5, token.value
    
    # Dot not followed by digit (should be DOT token)
    lexer = Lexer.new(".method")
    token = lexer.get_next_token
    assert_equal Token::TOKEN_TYPES[:DOT], token.type
    
    # Dot at end of input
    lexer = Lexer.new(".")
    token = lexer.get_next_token
    assert_equal Token::TOKEN_TYPES[:DOT], token.type
  end

  def test_get_next_token_all_operators
    # Systematically test every operator branch in get_next_token
    operators = {
      '*' => :STAR,
      '/' => :SLASH, 
      '%' => :PERCENT,
      '^' => :CARET,
      '<' => :LESS,
      '>' => :GREATER,
      '?' => :QUESTION
    }
    
    operators.each do |op, expected_type|
      lexer = Lexer.new(op)
      token = lexer.get_next_token
      assert_equal expected_type, token.type
      assert_equal op, token.value
    end
  end

  def test_get_next_token_compound_operators
    # Test compound operator branches (==, !=, <=, >=, ::, ?-)
    compounds = {
      '==' => Token::TOKEN_TYPES[:EQUAL],
      '!=' => Token::TOKEN_TYPES[:NOT_EQUAL], 
      '<=' => Token::TOKEN_TYPES[:LESS_EQUAL],
      '>=' => Token::TOKEN_TYPES[:GREATER_EQUAL],
      '::' => Token::TOKEN_TYPES[:DOUBLE_COLON],
      '?-' => Token::TOKEN_TYPES[:QUERY_PREFIX]
    }
    
    compounds.each do |op, expected_type|
      lexer = Lexer.new(op)
      token = lexer.get_next_token
      assert_equal expected_type, token.type
      assert_equal op, token.value
    end
  end

  def test_get_next_token_single_vs_compound
    # Test single character vs compound operator logic
    
    # Single equals vs double equals
    lexer = Lexer.new("=")
    token = lexer.get_next_token
    assert_equal :ASSIGN, token.type
    
    # Single exclamation vs not-equal
    lexer = Lexer.new("!")
    token = lexer.get_next_token
    assert_equal Token::TOKEN_TYPES[:NOT], token.type
    assert_equal '!', token.value
  end

  # =============================================================================
  # STRATEGY 3: BACKSLASH HANDLING (Lines 247-258) - Target: ~12 lines
  # =============================================================================

  def test_backslash_standalone
    # Test standalone backslash handling (lines 247-258)
    lexer = Lexer.new("\\")
    token = lexer.get_next_token
    assert_equal :UNKNOWN, token.type
    assert_equal "\\", token.value
  end

  def test_backslash_with_escape_chars
    # Test backslash followed by escape-like characters outside string context
    escape_chars = ['n', 't', 'r', '"', "'", '\\']
    
    escape_chars.each do |char|
      lexer = Lexer.new("\\#{char}")
      token1 = lexer.get_next_token
      assert_equal :UNKNOWN, token1.type
      assert_equal "\\", token1.value
      
      # Next character should be processed normally
      token2 = lexer.get_next_token
      if char.match(/[a-zA-Z]/)
        assert_equal Token::TOKEN_TYPES[:IDENTIFIER], token2.type
      end
    end
  end

  def test_backslash_context_variations
    # Test backslash in different contexts
    contexts = [
      "abc\\def",    # Middle of identifier context
      "123\\456",    # After number
      "\\+",         # Before operator
      "\\\\",        # Double backslash
    ]
    
    contexts.each do |context|
      lexer = Lexer.new(context)
      tokens = []
      while (token = lexer.get_next_token).type != Token::TOKEN_TYPES[:EOF]
        tokens << token
      end
      
      # Should contain at least one UNKNOWN token for backslash
      unknown_tokens = tokens.select { |t| t.type == :UNKNOWN }
      assert unknown_tokens.any? { |t| t.value == "\\" }, "Expected UNKNOWN backslash token in '#{context}'"
    end
  end

  # =============================================================================
  # STRATEGY 4: STRING TOKENIZATION EDGE CASES (Lines 460-461, 438-475) - Target: ~15 lines
  # =============================================================================

  def test_string_incomplete_escape_sequence
    # Test line 460-461: incomplete escape sequence error
    incomplete_escapes = [
      '"incomplete\\',     # Backslash at end
      "'incomplete\\",     # Single quote version
      '"test\\',          # Backslash at end after content
    ]
    
    incomplete_escapes.each do |str|
      lexer = Lexer.new(str)
      
      # Should raise error as per line 460
      assert_raises(RuntimeError, "Expected error for incomplete escape: #{str}") do
        lexer.get_next_token
      end
    end
  end

  def test_string_all_escape_sequences
    # Test all escape sequence branches in tokenize_string (lines 442-457)
    escapes = {
      '"\\n"' => "\n",
      '"\\t"' => "\t", 
      '"\\r"' => "\r",
      '"\\\\"' => "\\",
      '"\\"' => '"',
      '"\\\'"' => "'",
    }
    
    escapes.each do |input, expected|
      lexer = Lexer.new(input)
      token = lexer.get_next_token
      assert_equal Token::TOKEN_TYPES[:STRING], token.type
      assert_equal expected, token.value
    end
  end

  def test_string_invalid_escape_sequences
    # Test invalid escape sequences (line 456: else branch)
    invalid_escapes = [
      '"\\x"',    # Invalid hex escape
      '"\\u"',    # Invalid unicode escape  
      '"\\z"',    # Random invalid escape
    ]
    
    invalid_escapes.each do |str|
      lexer = Lexer.new(str)
      token = lexer.get_next_token
      assert_equal Token::TOKEN_TYPES[:STRING], token.type
      # Should include the escaped character literally (line 456)
    end
  end

  def test_unterminated_string_token
    # Test UNTERMINATED_STRING token creation (lines 468-471)
    unterminated = [
      '"unterminated string',
      "'unterminated single quote",
      '"string with\nnewline but no end',
    ]
    
    unterminated.each do |str|
      lexer = Lexer.new(str)
      token = lexer.get_next_token
      assert_equal :UNTERMINATED_STRING, token.type
    end
  end

  # =============================================================================
  # STRATEGY 5: AMBIGUOUS TOKEN RESOLUTION (Lines 323-349) - Target: ~27 lines
  # =============================================================================

  def test_ambiguous_token_make
    # Test 'make' ambiguous token creation (lines 323-329)
    lexer = Lexer.new("make")
    token = lexer.get_next_token
    
    assert_instance_of AmbiguousToken, token
    assert_equal 2, token.possibilities.length
    
    types = token.possibilities.map { |p| p[:type] }
    assert_includes types, Token::TOKEN_TYPES[:MAKE]
    assert_includes types, Token::TOKEN_TYPES[:IDENTIFIER]
  end

  def test_ambiguous_token_a
    # Test 'a' ambiguous token creation (lines 330-336)
    lexer = Lexer.new("a")
    token = lexer.get_next_token
    
    assert_instance_of AmbiguousToken, token
    types = token.possibilities.map { |p| p[:type] }
    assert_includes types, Token::TOKEN_TYPES[:A]
    assert_includes types, Token::TOKEN_TYPES[:IDENTIFIER]
  end

  def test_ambiguous_token_function
    # Test 'function' ambiguous token creation (lines 337-342)
    lexer = Lexer.new("function")
    token = lexer.get_next_token
    
    assert_instance_of AmbiguousToken, token
    types = token.possibilities.map { |p| p[:type] }
    assert_includes types, Token::TOKEN_TYPES[:FUNCTION]
    assert_includes types, Token::TOKEN_TYPES[:IDENTIFIER]
  end

  def test_ambiguous_token_called
    # Test 'called' ambiguous token creation (lines 343-348)
    lexer = Lexer.new("called")
    token = lexer.get_next_token
    
    assert_instance_of AmbiguousToken, token
    types = token.possibilities.map { |p| p[:type] }
    assert_includes types, Token::TOKEN_TYPES[:CALLED]
    assert_includes types, Token::TOKEN_TYPES[:IDENTIFIER]
  end

  def test_ambiguous_token_end
    # Test 'end' ambiguous token creation (lines 364-369)
    lexer = Lexer.new("end")
    token = lexer.get_next_token
    
    assert_instance_of AmbiguousToken, token
    types = token.possibilities.map { |p| p[:type] }
    assert_includes types, Token::TOKEN_TYPES[:END]
    assert_includes types, Token::TOKEN_TYPES[:IDENTIFIER]
  end

  # =============================================================================
  # STRATEGY 6: PRIVATE HELPER METHOD COVERAGE (Lines 477-546) - Target: ~70 lines
  # =============================================================================

  def test_context_detection_methods
    # Test in_function_definition_context? (lines 477-485)
    # This is triggered indirectly by complex parsing scenarios
    
    # Context that should trigger function definition detection
    function_contexts = [
      "make a function",
      "let's make something", 
      "I want to make a new function",
    ]
    
    function_contexts.each do |context|
      lexer = Lexer.new(context)
      # Process tokens to trigger context detection
      tokens = []
      while (token = lexer.get_next_token).type != Token::TOKEN_TYPES[:EOF]
        tokens << token
      end
      
      # Should have processed all tokens without error
      assert tokens.length > 0
    end
  end

  def test_arithmetic_context_detection
    # Test in_arithmetic_context? (lines 487-498)
    arithmetic_contexts = [
      "x = a + b",
      "result = a * b",
      "value = a - b", 
      "calc = a / b",
    ]
    
    arithmetic_contexts.each do |context|
      lexer = Lexer.new(context)
      tokens = []
      while (token = lexer.get_next_token).type != Token::TOKEN_TYPES[:EOF]
        tokens << token
      end
      
      # Should contain identifier tokens for 'a'
      identifier_tokens = tokens.select { |t| t.type == Token::TOKEN_TYPES[:IDENTIFIER] }
      a_tokens = identifier_tokens.select { |t| t.value == 'a' }
      assert a_tokens.length > 0, "Expected 'a' to be treated as identifier in arithmetic context"
    end
  end

  def test_peek_word_functionality
    # Test peek_word method (lines 503-519) through complex identifier parsing
    complex_identifiers = [
      "identifier_with_underscores",
      "CamelCaseIdentifier", 
      "mixed123Numbers",
      "predicate_method?",
    ]
    
    complex_identifiers.each do |id|
      lexer = Lexer.new(id)
      token = lexer.get_next_token
      assert_equal Token::TOKEN_TYPES[:IDENTIFIER], token.type
      assert_equal id, token.value
    end
  end

  def test_comment_context_detection
    # Test comment_context? method (lines 538-546)
    comment_scenarios = [
      ["# at start", true],
      ["  # after spaces", true], 
      ["\t# after tab", true],
      ["abc#not comment", false],
      ["123#not comment", false],
    ]
    
    comment_scenarios.each do |scenario, should_be_comment|
      lexer = Lexer.new(scenario)
      tokens = []
      while (token = lexer.get_next_token).type != Token::TOKEN_TYPES[:EOF]
        tokens << token
      end
      
      if should_be_comment
        # Comment should be skipped, only tokens before # should remain
        hash_tokens = tokens.select { |t| t.value == '#' }
        assert_equal 0, hash_tokens.length, "Hash should be consumed as comment in '#{scenario}'"
      else
        # Hash should appear as UNKNOWN token
        hash_tokens = tokens.select { |t| t.value == '#' && t.type == Token::TOKEN_TYPES[:UNKNOWN] }
        assert hash_tokens.length > 0, "Hash should be UNKNOWN token in '#{scenario}'"
      end
    end
  end

  # =============================================================================
  # STRATEGY 7: COMPREHENSIVE KEYWORD COVERAGE - Target: ~30 lines
  # =============================================================================

  def test_all_non_ambiguous_keywords
    # Test all keywords that don't create ambiguous tokens (lines 352-426)
    keywords = {
      'true' => Token::TOKEN_TYPES[:TRUE],
      'false' => Token::TOKEN_TYPES[:FALSE],
      'if' => Token::TOKEN_TYPES[:IF],
      'then' => Token::TOKEN_TYPES[:THEN],
      'else' => Token::TOKEN_TYPES[:ELSE],
      'while' => Token::TOKEN_TYPES[:WHILE],
      'do' => Token::TOKEN_TYPES[:DO],
      'print' => Token::TOKEN_TYPES[:PRINT],
      'takes' => Token::TOKEN_TYPES[:TAKES],
      'returns' => Token::TOKEN_TYPES[:RETURNS],
      'return' => Token::TOKEN_TYPES[:RETURN],
      'call' => Token::TOKEN_TYPES[:CALL],
      'with' => Token::TOKEN_TYPES[:WITH],
      'is' => Token::TOKEN_TYPES[:IS],
      'reasoning' => Token::TOKEN_TYPES[:REASONING],
      'mode' => Token::TOKEN_TYPES[:MODE],
      'on' => Token::TOKEN_TYPES[:ON],
      'off' => Token::TOKEN_TYPES[:OFF],
      'constrain' => Token::TOKEN_TYPES[:CONSTRAIN],
      'assert' => Token::TOKEN_TYPES[:ASSERT],
      'fact' => Token::TOKEN_TYPES[:FACT],
      'goal' => Token::TOKEN_TYPES[:GOAL],
      'pursue' => Token::TOKEN_TYPES[:PURSUE],
      'query' => Token::TOKEN_TYPES[:QUERY],
      'rule' => Token::TOKEN_TYPES[:RULE],
      'where' => Token::TOKEN_TYPES[:WHERE],
      'and' => Token::TOKEN_TYPES[:AND],
      'or' => Token::TOKEN_TYPES[:OR],
      'precondition' => Token::TOKEN_TYPES[:PRECONDITION],
      'postcondition' => Token::TOKEN_TYPES[:POSTCONDITION],
      'strategy' => Token::TOKEN_TYPES[:STRATEGY],
    }
    
    keywords.each do |keyword, expected_type|
      lexer = Lexer.new(keyword)
      token = lexer.get_next_token
      assert_equal expected_type, token.type, "Expected #{expected_type} for keyword '#{keyword}'"
      assert_equal keyword, token.value
    end
  end

  # =============================================================================
  # STRATEGY 8: NUMBER PARSING EDGE CASES - Target: ~15 lines  
  # =============================================================================

  def test_read_number_complex_scenarios
    # Test read_number method edge cases (lines 82-95)
    number_tests = {
      '0' => 0,
      '42' => 42,
      '3.14' => 3.14,
      '0.5' => 0.5,
      '999.999' => 999.999,
      '100' => 100,
    }
    
    number_tests.each do |input, expected|
      lexer = Lexer.new(input)
      token = lexer.get_next_token
      assert_equal Token::TOKEN_TYPES[:NUMBER], token.type
      assert_equal expected, token.value
    end
  end

  def test_number_followed_by_identifier
    # Test boundary between numbers and identifiers
    lexer = Lexer.new("42abc")
    
    token1 = lexer.get_next_token
    assert_equal Token::TOKEN_TYPES[:NUMBER], token1.type
    assert_equal 42, token1.value
    
    token2 = lexer.get_next_token
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], token2.type
    assert_equal 'abc', token2.value
  end

  def test_decimal_validation_logic
    # Test has_decimal logic in read_number (line 86-92)
    lexer = Lexer.new("3.14.159")  # Multiple decimals
    
    token1 = lexer.get_next_token
    assert_equal Token::TOKEN_TYPES[:NUMBER], token1.type
    assert_equal 3.14, token1.value  # Should stop at second decimal
    
    token2 = lexer.get_next_token
    assert_equal Token::TOKEN_TYPES[:DOT], token2.type  # Second decimal as DOT
    
    token3 = lexer.get_next_token
    assert_equal Token::TOKEN_TYPES[:NUMBER], token3.type
    assert_equal 159, token3.value
  end

  # =============================================================================
  # COMPREHENSIVE INTEGRATION TESTS - Target: Additional coverage
  # =============================================================================

  def test_mixed_complex_input
    # Complex input that exercises multiple code paths
    complex_input = 'make a function called "test_func" with (x + y) { return x * y; } # comment'
    
    lexer = Lexer.new(complex_input)
    tokens = []
    while (token = lexer.get_next_token).type != Token::TOKEN_TYPES[:EOF]
      tokens << token
    end
    
    # Should successfully tokenize without errors
    assert tokens.length > 10, "Expected multiple tokens from complex input"
    
    # Should contain various token types
    token_types = tokens.map(&:type).uniq
    assert token_types.length > 5, "Expected diverse token types"
  end

  def test_position_tracking_comprehensive
    # Test line and column tracking across various scenarios
    multi_line_input = "line1\n  line2\n\tline3"
    
    lexer = Lexer.new(multi_line_input)
    tokens = []
    while (token = lexer.get_next_token).type != Token::TOKEN_TYPES[:EOF]
      tokens << token
    end
    
    # Verify position tracking
    assert tokens.any? { |t| t.line == 1 }, "Expected tokens on line 1"
    assert tokens.any? { |t| t.line == 2 }, "Expected tokens on line 2" 
    assert tokens.any? { |t| t.line == 3 }, "Expected tokens on line 3"
  end
end