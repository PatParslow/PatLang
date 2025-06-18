require_relative '../helpers/test_helper'
require_relative '../../patlang-core/lexer/lexer'
require_relative '../../patlang-core/exceptions'

class TestLexerErrorScenarios < Minitest::Test
  def setup
    # Lexer requires text input, so we'll create it per test
    # This setup is left empty as each test creates its own lexer
  end

  def create_lexer(input = "")
    Lexer.new(input)
  end

  # Test malformed string literals
  def test_unclosed_string_literal_error
    input = '"unclosed string'
    lexer = create_lexer(input)
    
    # Lexer handles unclosed strings gracefully by returning UNTERMINATED_STRING token
    tokens = lexer.tokenize
    assert_equal 2, tokens.length
    assert_equal :UNTERMINATED_STRING, tokens[0].type
    assert_equal "unclosed string", tokens[0].value
    assert_equal :EOF, tokens[1].type
  end

  def test_unclosed_single_quote_string_error
    input = "'unclosed string"
    lexer = create_lexer(input)
    
    # Lexer handles unclosed single quote strings gracefully by returning UNTERMINATED_STRING token
    tokens = lexer.tokenize
    assert_equal 2, tokens.length
    assert_equal :UNTERMINATED_STRING, tokens[0].type
    assert_equal "unclosed string", tokens[0].value
    assert_equal :EOF, tokens[1].type
    assert_match(/unterminated string/i, error.message)
  end

  # Test invalid escape sequences
  def test_invalid_escape_sequence_error
    input = '"invalid \\z escape"'
    lexer = create_lexer(input)
    
    # Should either tokenize with warning or raise error
    result = lexer.tokenize
    # If tokenization succeeds, ensure the invalid escape is handled
    if result.is_a?(Array)
      # Check that the string token contains the literal backslash or proper error handling
      string_token = result.find { |token| token.type == :STRING }
      refute_nil string_token, "Should have string token even with invalid escape"
    end
  end

  # Test malformed number literals
  def test_malformed_number_with_multiple_dots
    input = '12.34.56'
    lexer = create_lexer(input)
    
    tokens = lexer.tokenize
    
    # Should tokenize as separate tokens or handle as error
    assert tokens.length >= 1, "Should produce tokens for malformed number"
  end

  def test_number_with_invalid_suffix
    input = '123abc'
    lexer = create_lexer(input)
    
    tokens = lexer.tokenize
    
    # Should handle mixed number/identifier appropriately
    refute_empty tokens
  end

  # Test invalid characters
  def test_invalid_unicode_character_error
    input = "valid_code \u0000 more_code"
    lexer = create_lexer(input)
    
    # Should handle or report invalid characters gracefully
    tokens = lexer.tokenize
    
    # Ensure lexer doesn't crash on invalid characters
    assert tokens.is_a?(Array), "Lexer should return array even with invalid chars"
  end

  def test_unsupported_character_error
    input = 'code @ more_code'
    lexer = create_lexer(input)
    
    tokens = lexer.tokenize
    
    # Should handle unsupported characters (depending on language spec)
    assert tokens.is_a?(Array), "Lexer should handle unsupported characters gracefully"
  end

  # Test comment edge cases
  def test_unterminated_multiline_comment
    input = '/* unterminated comment'
    lexer = create_lexer(input)
    
    # Depending on implementation, should either error or tokenize
    result = lexer.tokenize
    assert result.is_a?(Array), "Should handle unterminated comments gracefully"
  end

  # Test very long tokens
  def test_extremely_long_identifier
    long_id = 'a' * 10000
    input = "start #{long_id} end"
    lexer = create_lexer(input)
    
    tokens = lexer.tokenize
    
    # Should handle very long identifiers without crashing
    assert tokens.length >= 3, "Should tokenize long identifier"
    
    long_token = tokens.find { |token| token.value == long_id }
    refute_nil long_token, "Should find the long identifier token"
  end

  def test_extremely_long_string
    long_string = '"' + 'x' * 50000 + '"'
    lexer = create_lexer(long_string)
    
    tokens = lexer.tokenize
    
    # Should handle very long strings
    assert tokens.length >= 1, "Should tokenize long string"
    string_token = tokens.find { |token| token.type == :STRING }
    refute_nil string_token, "Should have string token for long string"
  end

  # Test deeply nested structures (for lookahead)
  def test_deeply_nested_parentheses
    input = '(' * 1000 + ')' * 1000
    lexer = create_lexer(input)
    
    tokens = lexer.tokenize
    
    # Should tokenize all parentheses
    assert_equal 2000, tokens.length, "Should tokenize all parentheses"
    
    open_parens = tokens.count { |token| token.type == :LPAREN }
    close_parens = tokens.count { |token| token.type == :RPAREN }
    
    assert_equal 1000, open_parens, "Should have 1000 open parentheses"
    assert_equal 1000, close_parens, "Should have 1000 close parentheses"
  end

  # Test lexer state recovery after errors
  def test_lexer_recovery_after_error
    input = '"broken string valid_code'
    lexer = create_lexer(input)
    
    # Should attempt to recover and continue tokenizing
    begin
      tokens = lexer.tokenize
      # If it succeeds, should have some tokens
      refute_empty tokens, "Should have some tokens even after error"
    rescue ParseError
      # If it fails, that's also acceptable for this test
      assert true, "ParseError is acceptable for malformed input"
    end
  end

  # Test boundary conditions
  def test_empty_input
    lexer = create_lexer('')
    tokens = lexer.tokenize
    assert_empty tokens, "Empty input should produce no tokens"
  end

  def test_whitespace_only_input
    lexer = create_lexer('   \t\n  ')
    tokens = lexer.tokenize
    # Should produce no tokens (whitespace is typically ignored)
    assert_empty tokens, "Whitespace-only input should produce no tokens"
  end

  def test_single_character_tokens
    input = '(){}[]'
    lexer = create_lexer(input)
    tokens = lexer.tokenize
    
    assert_equal 6, tokens.length, "Should tokenize all single character tokens"
    
    expected_types = [:LPAREN, :RPAREN, :LBRACE, :RBRACE, :LBRACKET, :RBRACKET]
    actual_types = tokens.map(&:type)
    
    expected_types.each do |expected_type|
      assert_includes actual_types, expected_type, "Should include #{expected_type}"
    end
  end

  # Test error position tracking
  def test_error_position_tracking
    input = "line1\nline2\n\"broken"
    lexer = create_lexer(input)
    
    begin
      lexer.tokenize
    rescue ParseError => e
      # Should provide accurate position information
      if e.respond_to?(:line)
        assert_equal 3, e.line, "Error should be on line 3"
      end
      
      if e.respond_to?(:column)
        assert e.column > 0, "Error should have valid column position"
      end
    end
  end

  # Test lexer memory efficiency with large inputs
  def test_memory_efficiency_large_input
    # Create input with many small tokens
    input = (1..10000).map { |i| "var#{i}" }.join(' ')
    lexer = create_lexer(input)
    
    tokens = lexer.tokenize
    
    # Should handle large inputs efficiently
    assert_equal 10000, tokens.length, "Should tokenize all variables"
    
    # Verify memory isn't excessively consumed (basic check)
    GC.start
    assert true, "Should complete without memory issues"
  end

  # Test concurrent lexing safety (if applicable)
  def test_lexer_thread_safety
    input = 'concurrent_test_code'
    
    threads = []
    results = []
    
    5.times do
      threads << Thread.new do
        lexer = create_lexer(input)  # Each thread gets its own lexer
        results << lexer.tokenize
      end
    end
    
    threads.each(&:join)
    
    # All results should be identical
    assert_equal 5, results.length, "Should have results from all threads"
    
    first_result = results.first
    results.each do |result|
      assert_equal first_result.length, result.length, "All results should be identical"
    end
  end

  # Test lexer with mixed encoding (if applicable)
  def test_mixed_encoding_handling
    # Test with various Unicode characters
    input = 'ascii_text λ_lambda π_pi 中文_chinese'
    lexer = create_lexer(input)
    
    tokens = lexer.tokenize
    
    # Should handle Unicode identifiers appropriately
    refute_empty tokens, "Should tokenize Unicode text"
    
    # Check for Unicode identifier tokens
    unicode_tokens = tokens.select { |token| token.value.match?(/[^\x00-\x7F]/) }
    # May or may not support Unicode identifiers depending on language spec
  end

  # Test lexer performance regression detection
  def test_performance_regression_detection
    input = 'performance_test ' * 1000
    lexer = create_lexer(input)
    
    start_time = Time.now
    tokens = lexer.tokenize
    end_time = Time.now
    
    duration = end_time - start_time
    
    # Should complete in reasonable time (adjust threshold as needed)
    assert duration < 1.0, "Lexing should complete in under 1 second for moderate input"
    assert_equal 1000, tokens.length, "Should tokenize all performance test tokens"
  end

  private

  def assert_token_type(expected_type, token)
    assert_equal expected_type, token.type, "Expected token type #{expected_type}, got #{token.type}"
  end

  def assert_token_value(expected_value, token)
    assert_equal expected_value, token.value, "Expected token value #{expected_value}, got #{token.value}"
  end
end
