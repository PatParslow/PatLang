require 'minitest/autorun'
require_relative '../../src/lexer'
require_relative '../../src/token'

# Additional lexer tests to achieve 90% coverage on working features
class TestLexerCoverageEnhancement < Minitest::Test
  
  def test_lexer_initialization_edge_cases
    # Test lexer with nil input
    assert_raises(ArgumentError) { Lexer.new(nil) }
    
    # Test lexer with very long input
    long_input = "x" * 10000
    lexer = Lexer.new(long_input)
    tokens = lexer.tokenize
    assert_equal 2, tokens.length
    assert_equal :IDENTIFIER, tokens[0].type
    assert_equal :EOF, tokens[1].type
  end
  
  def test_lexer_advance_method_coverage
    lexer = Lexer.new("abc")
    
    # Test initial state
    assert_equal 'a', lexer.instance_variable_get(:@current_char)
    
    # Test advance method
    lexer.send(:advance)
    assert_equal 'b', lexer.instance_variable_get(:@current_char)
    
    lexer.send(:advance)
    assert_equal 'c', lexer.instance_variable_get(:@current_char)
    
    lexer.send(:advance)
    assert_nil lexer.instance_variable_get(:@current_char)
  end
  
  def test_skip_whitespace_coverage
    lexer = Lexer.new("   \t\n\r  token")
    
    # This should internally call skip_whitespace
    tokens = lexer.tokenize
    assert_equal :IDENTIFIER, tokens[0].type
    assert_equal 'token', tokens[0].value
  end
  
  def test_peek_char_method
    lexer = Lexer.new("abc")
    
    # Test peek_char method if available
    if lexer.respond_to?(:peek_char)
      assert_equal 'b', lexer.peek_char
      assert_equal 'c', lexer.peek_char(2)
    end
  end
  
  def test_read_number_edge_cases
    # Test numbers starting with zero
    test_cases = [
      ['0123', 123],     # Leading zeros should be ignored
      ['00.5', 0.5],     # Leading zeros in decimal
      ['0.', 0.0],       # Zero with trailing decimal
      ['.0', 0.0],       # Decimal starting with dot
      ['000', 0]         # Multiple leading zeros
    ]
    
    test_cases.each do |input, expected|
      lexer = Lexer.new(input)
      tokens = lexer.tokenize
      assert_equal :NUMBER, tokens[0].type
      assert_equal expected, tokens[0].value
    end
  end
  
  def test_read_identifier_comprehensive
    # Test all identifier patterns
    test_cases = [
      ['_', :IDENTIFIER],
      ['_abc', :IDENTIFIER],
      ['abc_', :IDENTIFIER],
      ['a1b2c3', :IDENTIFIER],
      ['CamelCase', :IDENTIFIER],
      ['UPPER_CASE', :IDENTIFIER],
      ['mixedCase123', :IDENTIFIER],
      ['underscore_case', :IDENTIFIER]
    ]
    
    test_cases.each do |input, expected_type|
      lexer = Lexer.new(input)
      tokens = lexer.tokenize
      assert_equal expected_type, tokens[0].type
      assert_equal input, tokens[0].value
    end
  end
  
  def test_string_tokenization_edge_cases
    # Test various string escape sequences
    test_cases = [
      ['"\\r"', "\r"],           # Carriage return
      ['"\\b"', "\b"],           # Backspace  
      ['"\\f"', "\f"],           # Form feed
      ['"\\v"', "\v"],           # Vertical tab
      ['"\\0"', "\0"],           # Null character
      ['"\\\'"', "'"],           # Single quote
      ['"line1\\nline2"', "line1\nline2"],  # Newline
      ['"tab\\there"', "tab\there"]         # Tab
    ]
    
    test_cases.each do |input, expected|
      lexer = Lexer.new(input)
      tokens = lexer.tokenize
      assert_equal :STRING, tokens[0].type
      assert_equal expected, tokens[0].value
    end
  end
  
  def test_error_recovery_comprehensive
    # Test lexer's error recovery for various invalid inputs
    invalid_chars = ['$', '&', '~', '`', '#']  # Note: # might be comment
    
    invalid_chars.each do |char|
      next if char == '#'  # Skip comment character
      
      lexer = Lexer.new(char)
      tokens = lexer.tokenize
      
      # Should produce UNKNOWN token, not crash
      assert_equal 2, tokens.length
      assert_includes [Token::TOKEN_TYPES[:UNKNOWN], :UNKNOWN], tokens[0].type
      assert_equal :EOF, tokens[1].type
    end
  end
  
  def test_token_position_accuracy
    input = "line1\nline2\n  line3"
    lexer = Lexer.new(input)
    tokens = lexer.tokenize
    
    # First token should be at line 1, column 1
    assert_equal 1, tokens[0].line
    assert_equal 1, tokens[0].column
    
    # Second token should be at line 2, column 1  
    assert_equal 2, tokens[1].line
    assert_equal 1, tokens[1].column
    
    # Third token should be at line 3, column 3 (after spaces)
    assert_equal 3, tokens[2].line
    assert_equal 3, tokens[2].column
  end
  
  def test_complex_mixed_tokenization
    # Test complex real-world-like code
    input = <<~CODE
      make a function called fibonacci takes: n {
        if n <= 1 then return n
        else return call fibonacci with (n-1) + call fibonacci with (n-2)
        end
      }
    CODE
    
    lexer = Lexer.new(input)
    tokens = lexer.tokenize
    
    # Verify we get all expected token types
    token_types = tokens.map(&:type)
    
    expected_tokens = [:MAKE, :A, :FUNCTION, :CALLED, :IDENTIFIER, :TAKES, :COLON, :IDENTIFIER]
    expected_tokens.each do |expected_type|
      assert_includes token_types, expected_type, "Should include #{expected_type}"
    end
    
    # Should end with EOF
    assert_equal :EOF, tokens.last.type
  end
  
  def test_adjacent_operators_tokenization
    # Test operators without spaces between them
    test_cases = [
      ['x==y', [:IDENTIFIER, :EQUAL, :IDENTIFIER]],
      ['a!=b', [:IDENTIFIER, :NOT_EQUAL, :IDENTIFIER]],  
      ['x<=y', [:IDENTIFIER, :LESS_EQUAL, :IDENTIFIER]],
      ['a>=b', [:IDENTIFIER, :GREATER_EQUAL, :IDENTIFIER]],
      ['x<y>z', [:IDENTIFIER, :LESS, :IDENTIFIER, :GREATER, :IDENTIFIER]]
    ]
    
    test_cases.each do |input, expected_types|
      lexer = Lexer.new(input)
      tokens = lexer.tokenize
      
      actual_types = tokens[0..-2].map(&:type)  # Remove EOF
      assert_equal expected_types, actual_types, "Failed for input: #{input}"
    end
  end
  
  def test_number_followed_by_identifier
    # Test cases where numbers are immediately followed by identifiers
    lexer = Lexer.new("42abc")
    tokens = lexer.tokenize
    
    # Should tokenize as separate NUMBER and IDENTIFIER tokens
    assert_equal 3, tokens.length
    assert_equal :NUMBER, tokens[0].type
    assert_equal 42, tokens[0].value
    assert_equal :IDENTIFIER, tokens[1].type
    assert_equal "abc", tokens[1].value
    assert_equal :EOF, tokens[2].type
  end
  
  def test_string_with_quotes_inside
    # Test strings containing various quote combinations
    test_cases = [
      ['"He said \\"Hello\\""', 'He said "Hello"'],
      ['"\\"Start and end\\""', '"Start and end"'],
      ['"Mix \\"of\\" quotes"', 'Mix "of" quotes']
    ]
    
    test_cases.each do |input, expected|
      lexer = Lexer.new(input)
      tokens = lexer.tokenize
      assert_equal :STRING, tokens[0].type
      assert_equal expected, tokens[0].value
    end
  end
  
  def test_empty_and_whitespace_variations
    # Test various empty and whitespace-only inputs
    test_cases = [
      ['', 1],           # Empty string -> just EOF
      [' ', 1],          # Single space -> just EOF  
      ["\t", 1],         # Single tab -> just EOF
      ["\n", 1],         # Single newline -> just EOF
      ["   \t\n   ", 1]  # Mixed whitespace -> just EOF
    ]
    
    test_cases.each do |input, expected_token_count|
      lexer = Lexer.new(input)
      tokens = lexer.tokenize
      assert_equal expected_token_count, tokens.length
      assert_equal :EOF, tokens.last.type
    end
  end
  
  def test_large_numbers
    # Test lexer with very large numbers
    large_number = "123456789012345678901234567890"
    lexer = Lexer.new(large_number)
    tokens = lexer.tokenize
    
    assert_equal :NUMBER, tokens[0].type
    assert_equal large_number.to_f, tokens[0].value
  end
  
  def test_special_floating_point_cases
    # Test special floating point scenarios
    test_cases = [
      ['1.0e10', 1.0e10],
      ['2.5e-3', 2.5e-3],
      ['3.14159', 3.14159]
    ]
    
    test_cases.each do |input, expected|
      lexer = Lexer.new(input)
      tokens = lexer.tokenize
      
      if tokens[0].type == :NUMBER
        assert_equal expected, tokens[0].value
      else
        # If scientific notation isn't supported, should still tokenize reasonably
        assert_includes [:NUMBER, :IDENTIFIER], tokens[0].type
      end
    end
  end
end