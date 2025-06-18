# frozen_string_literal: true

require_relative '../helpers/test_helper'
require_relative '../../patlang-core/lexer/lexer'
require_relative '../../patlang-core/lexer/token'

class TestLexerErrorRecovery < Minitest::Test
  def test_unicode_characters_produce_tokens
    # Test that lexer creates tokens for Unicode characters instead of raising errors
    # The lexer should NEVER raise RuntimeError - it should tokenize everything
    unicode_chars = [
      "\u{FEFF}", # Byte Order Mark
      "\u{200B}", # Zero Width Space
      "\u{2028}", # Line Separator
      "\u{2029}", # Paragraph Separator
      "\u{FFFD}", # Replacement character
      "\u{1FFFE}", # Non-character
      "\u{1FFFF}"  # Non-character
    ]

    unicode_chars.each do |char|
      lexer = Lexer.new("x = #{char}42")
      
      # Lexer should NEVER raise errors - it should always produce tokens
      tokens = lexer.tokenize
      assert tokens.any?, "Should produce tokens for Unicode char: #{char.inspect}"
      
      # Should have identifiers and numbers
      identifiers = tokens.select { |token| token.type == :IDENTIFIER }
      numbers = tokens.select { |token| token.type == :NUMBER }
      
      assert identifiers.any?, "Should produce identifier 'x' for input with Unicode char: #{char.inspect}"
      assert numbers.any?, "Should produce number '42' for input with Unicode char: #{char.inspect}"
    end
  end

  def test_lexer_creates_tokens_for_all_characters
    # Test that lexer creates tokens for all characters instead of raising errors
    # The lexer should NEVER raise RuntimeError - it should tokenize everything
    test_inputs = [
      "@",        # AT character - should produce AT token
      "$",        # Dollar sign - should produce UNKNOWN token
      "~",        # Tilde - should produce UNKNOWN token
      "€",        # Euro symbol - should produce UNKNOWN token
      "∞",        # Mathematical symbol - should produce UNKNOWN token
      "α",        # Greek letter - should produce UNKNOWN token
      "中",        # Chinese character - should produce UNKNOWN token
      "🚀",       # Emoji - should produce UNKNOWN token
      "@#$%",     # Mixed characters including AT
    ]

    test_inputs.each do |input|
      lexer = Lexer.new(input)
      
      # Lexer should NEVER raise errors - it should always produce tokens
      tokens = lexer.tokenize
      assert tokens.any?, "Should produce tokens for input: #{input.inspect}"
      
      # Should have at least one non-EOF token
      non_eof_tokens = tokens.reject { |token| token.type == :EOF }
      assert non_eof_tokens.any?, "Should produce at least one non-EOF token for: #{input.inspect}"
      
      # For '@' specifically, should produce AT token
      if input.include?('@')
        at_tokens = tokens.select { |token| token.type == :AT }
        assert at_tokens.any?, "Should produce AT token for input containing '@': #{input.inspect}"
      end
    end
  end

  def test_at_character_produces_valid_tokens
    # Test that '@' character correctly produces AT tokens
    at_inputs = [
      "@",           # Simple @ character
      "@identifier", # @ followed by identifier
      "@#$%",        # @ followed by other chars
    ]

    at_inputs.each do |input|
      lexer = Lexer.new(input)
      tokens = lexer.tokenize
      
      # Should have at least one AT token
      at_tokens = tokens.select { |token| token.type == :AT }
      assert at_tokens.any?, "Should produce AT token for input: #{input.inspect}"
      
      # First AT token should be at position 0
      first_at = at_tokens.first
      assert_equal '@', first_at.value
      assert_equal 0, first_at.position
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

  def test_mixed_content_tokenization
    # Test lexer's ability to handle mixed valid and special character content
    # The lexer should tokenize everything, never raise errors
    
    # Input with mixed valid content and special characters
    mixed_input = "valid = 42\n@invalid\n$unknown\nmore = 123"
    
    lexer = Lexer.new(mixed_input)
    tokens = lexer.tokenize
    
    # Should successfully tokenize without errors
    assert tokens.any?, "Should successfully tokenize mixed content"
    
    # Should contain AT token for the @ character
    at_tokens = tokens.select { |token| token.type == :AT }
    assert at_tokens.any?, "Should produce AT token for @ character"
    
    # Should contain identifiers for 'valid', 'invalid', and 'more'
    identifiers = tokens.select { |token| token.type == :IDENTIFIER }
    identifier_values = identifiers.map(&:value)
    assert_includes identifier_values, 'valid'
    assert_includes identifier_values, 'invalid'
    assert_includes identifier_values, 'more'
    
    # Should contain numbers for 42 and 123
    numbers = tokens.select { |token| token.type == :NUMBER }
    number_values = numbers.map(&:value)
    assert_includes number_values, 42
    assert_includes number_values, 123
    
    # Should handle the $ character (as UNKNOWN token or similar)
    # The key point is that it should NOT raise an error
    puts "Tokens produced: #{tokens.map { |t| "#{t.type}:#{t.value}" }.join(', ')}"
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