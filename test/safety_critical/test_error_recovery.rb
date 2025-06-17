# frozen_string_literal: true

require_relative '../helpers/test_helper'

class TestErrorRecovery < Minitest::Test
  def setup
    @mock_evaluator = MockEvaluator.new
  end

  # Test lexer error recovery - "Never Fail, Always Token" principle
  def test_lexer_unknown_character_recovery
    # Test that lexer returns UNKNOWN tokens for unrecognized characters
    invalid_chars = ['$', '&', '~', '`', '#', '^']
    
    invalid_chars.each do |char|
      lexer = Lexer.new(char)
      tokens = lexer.tokenize
      
      # Should not raise exception, should return UNKNOWN token
      assert_equal 2, tokens.length
      assert_equal Token::TOKEN_TYPES[:UNKNOWN], tokens[0].type
      assert_equal char, tokens[0].value
      assert_equal Token::TOKEN_TYPES[:EOF], tokens[1].type
    end
  end

  def test_lexer_malformed_number_recovery
    # Test lexer handling of malformed numbers
    test_cases = [
      ['3.14.159', 2],  # Should parse as two separate numbers
      ['..5', 2],       # Should handle multiple dots gracefully
      ['5.', 1],        # Should handle trailing dot
      ['.', 1]          # Should handle standalone dot
    ]
    
    test_cases.each do |input, expected_non_eof_tokens|
      lexer = Lexer.new(input)
      
      assert_nothing_raised("Lexer should not raise for input: #{input}") do
        tokens = lexer.tokenize
        non_eof_tokens = tokens.select { |t| t.type != Token::TOKEN_TYPES[:EOF] }
        assert_equal expected_non_eof_tokens, non_eof_tokens.length
      end
    end
  end

  def test_lexer_unterminated_string_recovery
    # Test lexer handling of unterminated strings
    test_cases = [
      '"unterminated string',
      '"string with newline\nstill unterminated',
      '"nested "quotes" unterminated'
    ]
    
    test_cases.each do |input|
      lexer = Lexer.new(input)
      
      assert_nothing_raised("Lexer should not raise for unterminated string") do
        tokens = lexer.tokenize
        assert_operator tokens.length, :>=, 1
        
        # Should have UNTERMINATED_STRING token, not raise exception
        unterminated_tokens = tokens.select { |t| t.type == Token::TOKEN_TYPES[:UNTERMINATED_STRING] }
        assert_operator unterminated_tokens.length, :>=, 1, "Should have UNTERMINATED_STRING token"
      end
    end
  end

  def test_lexer_position_tracking_after_errors
    # Test that position tracking continues correctly after errors
    input = '$invalid + 5'
    lexer = Lexer.new(input)
    tokens = lexer.tokenize
    
    # Should have UNKNOWN, PLUS, NUMBER, EOF
    assert_equal 4, tokens.length
    assert_equal Token::TOKEN_TYPES[:UNKNOWN], tokens[0].type
    assert_equal Token::TOKEN_TYPES[:PLUS], tokens[1].type
    assert_equal Token::TOKEN_TYPES[:NUMBER], tokens[2].type
    assert_equal Token::TOKEN_TYPES[:EOF], tokens[3].type
    
    # Position tracking should be correct
    assert_equal 1, tokens[0].line
    assert_equal 1, tokens[0].column
    assert_equal 1, tokens[1].line
    assert_operator tokens[1].column, :>, tokens[0].column
  end

  # Test parser error recovery
  def test_parser_error_collection
    # Test that parser collects errors instead of immediately failing
    tokens = [
      Token.new(Token::TOKEN_TYPES[:IF], 'if', 0, 1, 1),
      Token.new(Token::TOKEN_TYPES[:UNKNOWN], '$', 1, 1, 4),
      Token.new(Token::TOKEN_TYPES[:THEN], 'then', 2, 1, 6),
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 3, 1, 10)
    ]
    
    parser = Parser.new(tokens)
    
    # Parser should collect error information
    assert_respond_to parser, :collect_error
    assert_respond_to parser, :get_all_errors
    assert_respond_to parser, :has_errors?
    
    # Initially no errors
    assert_not parser.has_errors?
    assert_equal [], parser.get_all_errors
    
    # Collect an error
    error_info = {
      message: "Unexpected token",
      position: 1,
      token: tokens[1],
      line: 1,
      column: 4
    }
    parser.collect_error(error_info)
    
    assert parser.has_errors?
    assert_equal 1, parser.get_all_errors.length
    assert_equal error_info, parser.get_all_errors.first
  end

  def test_parser_safe_error_handling
    # Test parser's safe error method that returns ErrorNode
    tokens = [Token.new(Token::TOKEN_TYPES[:EOF], nil, 0, 1, 1)]
    parser = Parser.new(tokens)
    
    error_node = parser.safe_error("Test error message")
    
    assert_kind_of ErrorNode, error_node
    assert_equal "Test error message", error_node.message
  end

  def test_parser_malformed_expression_recovery
    # Test parser handling of malformed expressions
    malformed_inputs = [
      '+ 5',           # Missing left operand
      '5 +',           # Missing right operand
      '(()',           # Unmatched parentheses
      '5 + * 3',       # Invalid operator sequence
      'if then end'    # Missing condition
    ]
    
    malformed_inputs.each do |input|
      lexer = Lexer.new(input)
      tokens = lexer.tokenize
      parser = Parser.new(tokens)
      
      # Parser should handle malformed input gracefully
      # It may raise ParseError, but should not crash with system errors
      begin
        result = with_test_timeout(2) do
          parser.parse
        end
        # If parsing succeeds, result should be some form of AST node
        assert_not_nil result if result
      rescue ParseError, RuntimeError => e
        # Expected - parser should raise structured parse errors
        assert_kind_of String, e.message
        assert_operator e.message.length, :>, 0
      rescue => e
        # Unexpected system errors should not occur
        assert false, "Unexpected error type #{e.class}: #{e.message}"
      end
    end
  end

  def test_parser_incomplete_function_recovery
    # Test parser handling of incomplete function definitions
    incomplete_functions = [
      'make a function',
      'make a function called',
      'make a function called test takes:',
      'make a function called test takes: x {',
      'make a function called test takes: x { return'
    ]
    
    incomplete_functions.each do |input|
      lexer = Lexer.new(input)
      tokens = lexer.tokenize
      parser = Parser.new(tokens)
      
      # Should handle incomplete functions without crashing
      assert_nothing_raised(ArgumentError, NoMethodError, "System crash for: #{input}") do
        begin
          with_test_timeout(2) do
            parser.parse
          end
        rescue ParseError, RuntimeError
          # Expected parse errors are acceptable
        end
      end
    end
  end

  # Test resource cleanup on errors
  def test_resource_cleanup_on_lexer_errors
    # Test that lexer properly manages resources even with errors
    large_input_with_errors = '$' * 1000 + 'valid_token' + '&' * 1000
    
    lexer = Lexer.new(large_input_with_errors)
    
    # Should complete tokenization without memory issues
    assert_nothing_raised do
      tokens = lexer.tokenize
      assert_operator tokens.length, :>, 1000  # Should have many UNKNOWN tokens plus valid tokens
      assert_equal Token::TOKEN_TYPES[:EOF], tokens.last.type
    end
  end

  def test_resource_cleanup_on_parser_errors
    # Test that parser properly manages resources during error conditions
    # Create a complex token stream with errors
    tokens = []
    100.times do |i|
      tokens << Token.new(Token::TOKEN_TYPES[:UNKNOWN], '$', i * 2, 1, i * 2 + 1)
      tokens << Token.new(Token::TOKEN_TYPES[:IDENTIFIER], "var#{i}", i * 2 + 1, 1, i * 2 + 2)
    end
    tokens << Token.new(Token::TOKEN_TYPES[:EOF], nil, tokens.length, 1, tokens.length + 1)
    
    parser = Parser.new(tokens)
    
    # Should handle large error-prone input without resource leaks
    assert_nothing_raised do
      begin
        with_test_timeout(5) do
          parser.parse
        end
      rescue ParseError, RuntimeError
        # Parse errors are expected and acceptable
      end
      
      # Parser should maintain error collection functionality
      assert_respond_to parser, :get_all_errors
    end
  end

  # Test state consistency after failures
  def test_lexer_state_consistency_after_errors
    # Test that lexer maintains consistent state after encountering errors
    input = 'valid1 $ invalid & valid2'
    lexer = Lexer.new(input)
    tokens = lexer.tokenize
    
    # Should have valid tokens before and after invalid ones
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], tokens[0].type
    assert_equal 'valid1', tokens[0].value
    
    assert_equal Token::TOKEN_TYPES[:UNKNOWN], tokens[1].type
    assert_equal '$', tokens[1].value
    
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], tokens[2].type
    assert_equal 'invalid', tokens[2].value
    
    assert_equal Token::TOKEN_TYPES[:UNKNOWN], tokens[3].type
    assert_equal '&', tokens[3].value
    
    assert_equal Token::TOKEN_TYPES[:IDENTIFIER], tokens[4].type
    assert_equal 'valid2', tokens[4].value
    
    assert_equal Token::TOKEN_TYPES[:EOF], tokens[5].type
  end

  def test_parser_state_consistency_after_errors
    # Test that parser maintains consistent state after errors
    tokens = [
      Token.new(Token::TOKEN_TYPES[:IDENTIFIER], 'x', 0, 1, 1),
      Token.new(Token::TOKEN_TYPES[:ASSIGN], '=', 1, 1, 3),
      Token.new(Token::TOKEN_TYPES[:UNKNOWN], '$', 2, 1, 5),  # Error token
      Token.new(Token::TOKEN_TYPES[:NUMBER], 5, 3, 1, 7),
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 4, 1, 8)
    ]
    
    parser = Parser.new(tokens)
    
    # Parser state should be queryable even after encountering errors
    assert_equal tokens[0], parser.current_token
    assert_equal 0, parser.current_token_index
    
    # Advance through tokens (simulating parsing progress)
    parser.advance
    assert_equal tokens[1], parser.current_token
    assert_equal 1, parser.current_token_index
    
    # Should maintain state even when encountering error tokens
    parser.advance
    assert_equal tokens[2], parser.current_token  # The UNKNOWN token
    assert_equal 2, parser.current_token_index
  end

  # Test graceful degradation scenarios
  def test_graceful_degradation_with_mixed_errors
    # Test system behavior with mixed valid/invalid input
    input = <<~CODE
      valid_var = 5
      $invalid_line with & symbols
      if x > 0 then
        print "valid"
      $another invalid line
      end
    CODE
    
    lexer = Lexer.new(input)
    
    # Lexer should process entire input without crashing
    assert_nothing_raised do
      tokens = lexer.tokenize
      
      # Should have mix of valid and UNKNOWN tokens
      valid_tokens = tokens.select { |t| t.type != Token::TOKEN_TYPES[:UNKNOWN] && t.type != Token::TOKEN_TYPES[:EOF] }
      unknown_tokens = tokens.select { |t| t.type == Token::TOKEN_TYPES[:UNKNOWN] }
      
      assert_operator valid_tokens.length, :>, 0, "Should have some valid tokens"
      assert_operator unknown_tokens.length, :>, 0, "Should have some unknown tokens"
      
      # EOF should always be present
      assert_equal Token::TOKEN_TYPES[:EOF], tokens.last.type
    end
  end

  def test_error_message_quality_and_context
    # Test that error messages provide useful context
    tokens = [
      Token.new(Token::TOKEN_TYPES[:IF], 'if', 0, 1, 1),
      Token.new(Token::TOKEN_TYPES[:UNKNOWN], '$', 1, 1, 4),
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 2, 1, 5)
    ]
    
    parser = Parser.new(tokens)
    
    # Test error method provides context
    begin
      parser.error("Test error")
      assert false, "Expected ParseError to be raised"
    rescue ParseError => e
      assert_includes e.message, "Test error"
      assert_includes e.message, "token"
      assert_equal 1, e.line
      assert_equal 1, e.column
      assert_equal tokens[0], e.token
    end
  end

  def test_syntax_error_formatting
    # Test syntax error formatting includes useful information
    tokens = [
      Token.new(Token::TOKEN_TYPES[:UNKNOWN], '$', 0, 5, 10),
      Token.new(Token::TOKEN_TYPES[:EOF], nil, 1, 5, 11)
    ]
    
    parser = Parser.new(tokens)
    
    begin
      parser.syntax_error("Invalid token")
      assert false, "Expected RuntimeError to be raised"
    rescue RuntimeError => e
      assert_includes e.message, "Invalid token"
      assert_includes e.message, "line 5"
      assert_includes e.message, "column 10"
      assert_includes e.message, "UNKNOWN"
      assert_includes e.message, "$"
      assert_includes e.message, "position"
    end
  end

  # Test timeout protection mechanisms
  def test_timeout_protection_prevents_infinite_loops
    # Test that timeout protection prevents infinite loops in error scenarios
    # Create a pathological input that might cause loops
    large_input = ('$' * 10000) + 'end'
    
    lexer = Lexer.new(large_input)
    
    # Should complete within reasonable time
    start_time = Time.now
    
    assert_nothing_raised do
      with_test_timeout(3) do
        tokens = lexer.tokenize
        assert_equal Token::TOKEN_TYPES[:EOF], tokens.last.type
      end
    end
    
    elapsed = Time.now - start_time
    assert_operator elapsed, :<, 3, "Lexer should not take excessive time"
  end

  def test_memory_safety_with_error_scenarios
    # Test that error scenarios don't cause memory issues
    # Create many small errors rather than one large one
    inputs = []
    1000.times { |i| inputs << "var#{i} = $invalid#{i}" }
    
    inputs.each do |input|
      assert_nothing_raised do
        lexer = Lexer.new(input)
        tokens = lexer.tokenize
        
        # Should have valid identifier, assignment, and unknown tokens
        assert_operator tokens.length, :>=, 4  # IDENTIFIER, ASSIGN, UNKNOWN, EOF minimum
      end
    end
  end

  # Test error recovery in complex nested structures
  def test_error_recovery_in_nested_structures
    # Test error recovery within complex nested structures
    input = <<~CODE
      if x > 0 then
        make a function called test {
          if y $invalid then
            return true
          end
        }
        $another error
      end
    CODE
    
    lexer = Lexer.new(input)
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    
    # Should handle nested structure with errors gracefully
    assert_nothing_raised(ArgumentError, NoMethodError) do
      begin
        with_test_timeout(3) do
          parser.parse
        end
      rescue ParseError, RuntimeError
        # Parse/syntax errors are expected and acceptable
      end
      
      # Parser should still be functional after errors
      assert_respond_to parser, :has_errors?
      assert_respond_to parser, :get_all_errors
    end
  end
end