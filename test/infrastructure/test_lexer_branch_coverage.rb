require_relative '../helpers/test_helper'
require_relative '../../patlang-core/lexer/lexer'
require_relative '../../patlang-core/lexer/token'

class TestLexerBranchCoverage < Minitest::Test
  def setup
    @lexer = nil
  end

  # Test error handling for invalid characters - HIGH PRIORITY
  # Invalid characters should produce UNKNOWN tokens (lexer never fails)
  def test_error_handling_invalid_characters
    # Test that truly invalid characters produce UNKNOWN tokens
    invalid_chars = ['$', '&', '~', '`', '§', 'ñ', 'ü']
    invalid_chars.each do |char|
      @lexer = Lexer.new(char)
      tokens = @lexer.tokenize
      assert_equal 2, tokens.length, "Should produce UNKNOWN token and EOF for invalid char: #{char}"
      assert_equal :UNKNOWN, tokens[0].type, "Should produce UNKNOWN token for invalid char: #{char}"
      assert_equal char, tokens[0].value, "UNKNOWN token should contain the invalid character: #{char}"
      assert_equal :EOF, tokens[1].type, "Should produce EOF token after UNKNOWN token"
    end
    
    # Test that valid special characters produce proper tokens (not errors)
    @lexer = Lexer.new("@")  # AT token
    tokens = @lexer.tokenize
    assert_equal :AT, tokens[0].type, "@ should produce AT token"
    
    @lexer = Lexer.new("%")  # PERCENT token
    tokens = @lexer.tokenize
    assert_equal :PERCENT, tokens[0].type, "% should produce PERCENT token"
  end

  # Test nil character handling in advance method - HIGH PRIORITY
  def test_nil_character_handling
    @lexer = Lexer.new("")
    @lexer.advance  # Should not crash on nil character
    assert_nil @lexer.instance_variable_get(:@current_char)
    
    # Test advance at end of string
    @lexer = Lexer.new("a")
    @lexer.advance  # Move past 'a'
    @lexer.advance  # Should handle nil gracefully
    assert_nil @lexer.instance_variable_get(:@current_char)
  end

  # Test newline handling in advance method - MEDIUM PRIORITY
  def test_newline_handling_in_advance
    @lexer = Lexer.new("line1\nline2\n")
    
    # Verify line counting
    assert_equal 1, @lexer.instance_variable_get(:@line)
    
    # Advance through first line
    while @lexer.instance_variable_get(:@current_char) != "\n"
      @lexer.advance
    end
    
    # Advance past newline
    @lexer.advance
    assert_equal 2, @lexer.instance_variable_get(:@line)
    assert_equal 1, @lexer.instance_variable_get(:@column)
  end

  # Test edge cases in number parsing - HIGH PRIORITY
  def test_number_parsing_edge_cases
    # Test leading zeros - lexer converts to integer
    @lexer = Lexer.new("007")
    tokens = @lexer.tokenize
    assert_equal :NUMBER, tokens[0].type
    assert_equal 7, tokens[0].value  # Leading zeros are stripped when converted to integer
    
    # Test decimal numbers
    @lexer = Lexer.new("3.14")
    tokens = @lexer.tokenize
    assert_equal :NUMBER, tokens[0].type
    assert_equal 3.14, tokens[0].value  # Converted to float
    
    # Test zero
    @lexer = Lexer.new("0")
    tokens = @lexer.tokenize
    assert_equal :NUMBER, tokens[0].type
    assert_equal 0, tokens[0].value
    
    # Test large numbers
    @lexer = Lexer.new("999999999")
    tokens = @lexer.tokenize
    assert_equal :NUMBER, tokens[0].type
    assert_equal 999999999, tokens[0].value
  end

  # Test comment handling at end of file - HIGH PRIORITY
  def test_comment_handling_end_of_file
    # Comment at end without newline
    @lexer = Lexer.new("# This is a comment")
    tokens = @lexer.tokenize
    assert_equal 1, tokens.length
    assert_equal :EOF, tokens[0].type
    
    # Comment with newline at end
    @lexer = Lexer.new("# Comment\n")
    tokens = @lexer.tokenize
    assert_equal 1, tokens.length
    assert_equal :EOF, tokens[0].type
    
    # Multiple comments
    @lexer = Lexer.new("# Comment 1\n# Comment 2")
    tokens = @lexer.tokenize
    assert_equal 1, tokens.length
    assert_equal :EOF, tokens[0].type
  end

  # Test string parsing with escape sequences - HIGH PRIORITY
  def test_string_parsing_with_escapes
    # Test basic escape sequences - lexer properly interprets escape sequences
    @lexer = Lexer.new('"Hello\\nWorld"')
    tokens = @lexer.tokenize
    assert_equal :STRING, tokens[0].type
    assert_equal "Hello\nWorld", tokens[0].value  # Escape sequence is interpreted
    
    # Test quote escapes
    @lexer = Lexer.new('"Say \\"Hello\\""')
    tokens = @lexer.tokenize
    assert_equal :STRING, tokens[0].type
    assert_equal "Say \"Hello\"", tokens[0].value  # Quotes are unescaped
    
    # Test backslash escapes
    @lexer = Lexer.new('"Path\\\\to\\\\file"')
    tokens = @lexer.tokenize
    assert_equal :STRING, tokens[0].type
    assert_equal "Path\\to\\file", tokens[0].value  # Double backslashes become single
  end

  # Test whitespace detection edge cases - HIGH PRIORITY
  def test_whitespace_detection_edge_cases
    # Test various whitespace combinations
    whitespace_tests = [
      "   \t\n\r  ",
      "\t\t\t",
      "\n\n\n",
      "   ",
      "\r\n\r\n"
    ]
    
    whitespace_tests.each do |ws|
      @lexer = Lexer.new(ws)
      tokens = @lexer.tokenize
      assert_equal 1, tokens.length
      assert_equal :EOF, tokens[0].type
    end
  end

  # Test peek character functionality - HIGH PRIORITY
  def test_peek_char_functionality
    @lexer = Lexer.new("123")
    
    # Test peek without advancing
    current_pos = @lexer.instance_variable_get(:@position)
    peek_result = @lexer.send(:peek_char)
    assert_equal current_pos, @lexer.instance_variable_get(:@position)
    assert_equal '2', peek_result
    
    # Test peek at end of string
    @lexer = Lexer.new("a")
    @lexer.advance  # Move to end
    peek_result = @lexer.send(:peek_char)
    assert_nil peek_result
  end

  # Test ambiguous token scenarios - HIGH PRIORITY
  def test_ambiguous_token_scenarios
    # Test identifier vs keyword ambiguity
    @lexer = Lexer.new("if_statement")
    tokens = @lexer.tokenize
    assert_equal :IDENTIFIER, tokens[0].type
    assert_equal "if_statement", tokens[0].value
    
    # Test number vs decimal ambiguity - lexer converts to float
    @lexer = Lexer.new("1.0")
    tokens = @lexer.tokenize
    assert_equal :NUMBER, tokens[0].type
    assert_equal 1.0, tokens[0].value  # Converted to float, not string
  end

  # Test error recovery mechanisms - HIGH PRIORITY
  def test_error_recovery_mechanisms
    # Test partial tokenization with invalid characters
    @lexer = Lexer.new("valid_token @invalid")
    
    # Should tokenize everything without raising errors
    tokens = @lexer.tokenize
    assert tokens.any?, "Should produce tokens for mixed valid/invalid input"
    
    # Should contain identifier for 'valid_token'
    identifiers = tokens.select { |t| t.type == :IDENTIFIER }
    identifier_values = identifiers.map(&:value)
    assert_includes identifier_values, 'valid_token'
    assert_includes identifier_values, 'invalid'
    
    # Should contain AT token for '@'
    at_tokens = tokens.select { |t| t.type == :AT }
    assert at_tokens.any?, "Should produce AT token for @ character"
  end

  # Test boundary conditions - HIGH PRIORITY
  def test_boundary_conditions
    # Empty string
    @lexer = Lexer.new("")
    tokens = @lexer.tokenize
    assert_equal 1, tokens.length
    assert_equal :EOF, tokens[0].type
    
    # Single character - "a" produces ambiguous token that defaults to :A (first possibility)
    @lexer = Lexer.new("a")
    tokens = @lexer.tokenize
    assert_equal 2, tokens.length
    # "a" creates AmbiguousToken that defaults to :A (first possibility)
    assert_equal :A, tokens[0].type
    # Verify it's actually an ambiguous token
    assert tokens[0].ambiguous?, "Token 'a' should be ambiguous"
    assert tokens[0].can_be?(:IDENTIFIER), "Token 'a' should be resolvable to :IDENTIFIER"
    assert_equal :EOF, tokens[1].type
    
    # Very long string
    long_string = "a" * 10000
    @lexer = Lexer.new(long_string)
    tokens = @lexer.tokenize
    assert_equal 2, tokens.length
    assert_equal :IDENTIFIER, tokens[0].type
    assert_equal long_string, tokens[0].value
  end

  # Test line and column tracking - MEDIUM PRIORITY
  def test_line_column_tracking
    @lexer = Lexer.new("line1\n  line2\n    line3")
    
    tokens = @lexer.tokenize
    
    # First identifier should be at line 1
    assert_equal 1, tokens[0].line
    assert_equal 1, tokens[0].column
    
    # Second identifier should be at line 2
    assert_equal 2, tokens[1].line
    assert_equal 3, tokens[1].column
    
    # Third identifier should be at line 3
    assert_equal 3, tokens[2].line
    assert_equal 5, tokens[2].column
  end

  # Test position tracking - MEDIUM PRIORITY
  def test_position_tracking
    @lexer = Lexer.new("abc def")
    tokens = @lexer.tokenize
    
    # First token position
    assert_equal 0, tokens[0].position
    
    # Second token position (after "abc ")
    assert_equal 4, tokens[1].position
  end
end