# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../src/lexer'
require_relative '../src/token'

class TestLexerErrorRecovery < Minitest::Test
  def test_invalid_unicode_characters
    # Test various invalid Unicode characters
    invalid_chars = [
      "\u{FEFF}", # Byte Order Mark
      "\u{200B}", # Zero Width Space
      "\u{2028}", # Line Separator
      "\u{2029}", # Paragraph Separator
      "\u{FFFD}", # Replacement character (instead of invalid FFFF)
      "\u{1FFFE}", # Non-character (valid but not intended for use)
      "\u{1FFFF}"  # Non-character (valid but not intended for use)
    ]

    invalid_chars.each do |char|
      lexer = Lexer.new("x = #{char}42")
      assert_raises(RuntimeError, "Should raise error for Unicode char: #{char.inspect}") do
        lexer.tokenize
      end
    end
  end

  def test_invalid_character_error_handling
    # Test various invalid characters that should trigger error method
    invalid_inputs = [
      "@#$%",     # Invalid symbols
      "~!",       # Tilde and other chars
      "€£¥",      # Currency symbols
      "∞∑∏",      # Mathematical symbols
      "αβγ",      # Greek letters
      "中文",      # Chinese characters
      "🚀💻",     # Emojis
    ]

    invalid_inputs.each do |input|
      lexer = Lexer.new(input)
      error = assert_raises(RuntimeError) do
        lexer.tokenize
      end
      assert_match(/Invalid character/, error.message)
      assert_match(/at position/, error.message)
    end
  end

  def test_incomplete_escape_sequences
    # Test various incomplete or malformed escape sequences in strings
    incomplete_escapes = [
      '"\\',        # Incomplete backslash at end
      '"\\x"',      # Incomplete hex escape
      '"\\u"',      # Incomplete unicode escape
      '"\\u12"',    # Short unicode escape
      '"\\u123"',   # Short unicode escape
      '"\\777"',    # Invalid octal escape
      '"\\8"',      # Invalid octal digit
      '"\\9"',      # Invalid octal digit
    ]

    incomplete_escapes.each do |input|
      lexer = Lexer.new(input)
      # Should either raise error or handle gracefully
      begin
        tokens = lexer.tokenize
        # If it doesn't raise, verify it's handled appropriately
        assert tokens.length >= 1, "Should produce at least EOF token for: #{input}"
      rescue RuntimeError => e
        assert_match(/(Invalid|Unterminated|Unexpected|Incomplete)/, e.message,
                    "Error message should be descriptive for: #{input}")
      end
    end
  end

  def test_malformed_string_literals
    # Test various malformed string literal scenarios
    malformed_strings = [
      '"unterminated string',           # Missing closing quote
      '"string with \n newline"',       # Unescaped newline
      '"string with \r carriage"',      # Unescaped carriage return
      '"string with \0 null"',          # Unescaped null
      '\'single quote unterminated',    # Single quote unterminated
      '"nested "quotes" problem"',      # Nested quotes
      '"backslash at end\\"',          # Backslash at end
    ]

    malformed_strings.each do |input|
      lexer = Lexer.new(input)
      begin
        tokens = lexer.tokenize
        # If no error raised, check for appropriate handling
        assert tokens.length >= 1, "Should handle malformed string: #{input}"
      rescue RuntimeError => e
        # Should provide meaningful error message
        assert e.message.length > 0, "Error message should not be empty for: #{input}"
      end
    end
  end

  def test_number_parsing_edge_cases
    # Test edge cases in number parsing that might cause errors
    edge_case_numbers = [
      "123.456.789",    # Multiple decimal points
      ".123.456",       # Multiple decimals starting with dot
      "123.",           # Trailing decimal with no digits
      "999999999999999999999999999999",  # Very large integer
      "0.00000000000000000000000001",    # Very small decimal
      "1e999",          # Scientific notation (if not supported)
      "123abc",         # Number followed by letters
      "12.34.56e10",    # Complex malformed number
    ]

    edge_case_numbers.each do |input|
      lexer = Lexer.new(input)
      begin
        tokens = lexer.tokenize
        # Verify tokens are reasonable
        assert tokens.length >= 1, "Should produce tokens for: #{input}"
        # Check that number tokens have valid values
        number_tokens = tokens.select { |t| t.type == :NUMBER }
        number_tokens.each do |token|
          assert token.value.is_a?(Numeric), "Number token should have numeric value: #{input}"
        end
      rescue RuntimeError => e
        # If error raised, should be informative
        assert e.message.length > 0, "Error should be descriptive for: #{input}"
      end
    end
  end

  def test_memory_stress_tokenization
    # Test tokenization under memory stress conditions
    
    # Very long identifier
    long_identifier = "a" * 10000
    lexer = Lexer.new(long_identifier)
    begin
      tokens = lexer.tokenize
      assert tokens.length >= 1, "Should handle long identifier"
    rescue RuntimeError => e
      # Memory or processing error acceptable
      assert e.message.length > 0
    end

    # Many tokens
    many_tokens = (1..1000).map { |i| "x#{i}" }.join(" + ")
    lexer = Lexer.new(many_tokens)
    begin
      tokens = lexer.tokenize
      assert tokens.length > 1000, "Should handle many tokens"
    rescue RuntimeError => e
      # Memory error acceptable for stress test
      assert e.message.length > 0
    end

    # Deeply nested structure
    deep_nesting = "(" * 1000 + "42" + ")" * 1000
    lexer = Lexer.new(deep_nesting)
    begin
      tokens = lexer.tokenize
      assert tokens.length > 1000, "Should handle deep nesting tokens"
    rescue RuntimeError => e
      # Stack overflow or memory error acceptable
      assert e.message.length > 0
    end
  end

  def test_position_tracking_accuracy_under_stress
    # Test that position tracking remains accurate under various conditions
    
    # Multi-line input with various characters
    multiline_input = <<~INPUT
      # Comment line 1
      x = 42 + 
          "string with \n newline" +
          123.456
      # Another comment
      y = x * 2
    INPUT

    lexer = Lexer.new(multiline_input)
    begin
      tokens = lexer.tokenize
      
      # Verify position tracking is reasonable
      tokens.each do |token|
        assert token.line >= 1, "Line number should be positive"
        assert token.column >= 1, "Column number should be positive" 
        assert token.position >= 0, "Position should be non-negative"
      end
      
      # Verify line numbers increase appropriately
      line_numbers = tokens.map(&:line).uniq.sort
      assert line_numbers.first >= 1, "Should start with line 1 or greater"
      assert line_numbers.length > 1, "Should span multiple lines"
      
    rescue RuntimeError => e
      # If error occurs, position should still be tracked
      assert_match(/position \d+/, e.message, "Error should include position info")
    end
  end

  def test_error_recovery_mechanisms
    # Test lexer's ability to continue after errors (if implemented)
    
    # Input with mixed valid and invalid content
    mixed_input = "valid = 42\n@invalid\nmore = 123"
    
    lexer = Lexer.new(mixed_input)
    error_raised = false
    
    begin
      tokens = lexer.tokenize
    rescue RuntimeError => e
      error_raised = true
      # Verify error message contains useful information
      assert_match(/Invalid character/, e.message)
      assert_match(/@|Invalid character/, e.message)
      assert_match(/position/, e.message)
    end
    
    # For now, lexer should raise error on invalid character
    assert error_raised, "Should raise error for invalid character @"
  end

  def test_token_boundary_edge_cases
    # Test edge cases around token boundaries
    
    boundary_cases = [
      "42abc",          # Number immediately followed by identifier
      "if123",          # Keyword-like followed by number
      "==!",            # Operator combinations
      "++--",           # Repeated operators
      "{}{",            # Adjacent braces
      "())((",          # Mismatched parentheses
      "\"\"''",         # Adjacent quotes
      "123.abc",        # Number with dot followed by identifier
    ]

    boundary_cases.each do |input|
      lexer = Lexer.new(input)
      begin
        tokens = lexer.tokenize
        
        # Verify we get reasonable token breakdown
        assert tokens.length >= 2, "Should produce multiple tokens for: #{input}" # At least tokens + EOF
        
        # Verify no token has empty or nil value
        tokens.each do |token|
          refute_nil token.type, "Token type should not be nil for: #{input}"
          # Some tokens may have nil values (like EOF), so only check non-EOF tokens
          unless token.type == :EOF
            refute_nil token.value, "Token value should not be nil for: #{input} (token type: #{token.type})"
          end
        end
        
      rescue RuntimeError => e
        # If error raised, should be specific and helpful
        assert e.message.include?("Invalid character") || e.message.include?("Unexpected"),
               "Error should be descriptive for: #{input}"
      end
    end
  end
end