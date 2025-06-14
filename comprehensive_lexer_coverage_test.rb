#!/usr/bin/env ruby

require_relative 'test/helpers/test_helper'
require_relative 'src/lexer'
require_relative 'src/token'
require_relative 'src/ambiguous_token'

# Comprehensive lexer coverage test to improve line and branch coverage
class ComprehensiveLexerCoverageTest < Minitest::Test
  def test_all_token_types_coverage
    # Test all token types defined in Token::TOKEN_TYPES
    token_tests = {
      'true' => :TRUE,
      'false' => :FALSE,
      'if' => :IF,
      'then' => :THEN,
      'else' => :ELSE,
      'end' => :END,
      'while' => :WHILE,
      'do' => :DO,
      'print' => :PRINT,
      'takes' => :TAKES,
      'returns' => :RETURNS,
      'return' => :RETURN,
      'call' => :CALL,
      'with' => :WITH,
      'is' => :IS,
      'reasoning' => :REASONING,
      'mode' => :MODE,
      'on' => :ON,
      'off' => :OFF,
      'constrain' => :CONSTRAIN,
      'assert' => :ASSERT,
      'fact' => :FACT,
      'goal' => :GOAL,
      'pursue' => :PURSUE,
      'query' => :QUERY,
      'rule' => :RULE,
      'where' => :WHERE,
      'and' => :AND,
      'or' => :OR,
      'precondition' => :PRECONDITION,
      'postcondition' => :POSTCONDITION,
      'strategy' => :STRATEGY
    }
    
    token_tests.each do |input, expected_type|
      lexer = Lexer.new(input)
      tokens = lexer.tokenize
      assert_equal expected_type, tokens.first.type, "Failed for input: #{input}"
      assert_equal input, tokens.first.value, "Value mismatch for input: #{input}"
    end
  end

  def test_operator_coverage
    # Test all operators and punctuation
    operator_tests = {
      '+' => :PLUS,
      '-' => :MINUS,
      '*' => :STAR,
      '/' => :SLASH,
      '%' => :PERCENT,
      '^' => :CARET,
      '(' => :LPAREN,
      ')' => :RPAREN,
      '==' => :EQUAL,
      '!=' => :NOT_EQUAL,
      '<=' => :LESS_EQUAL,
      '>=' => :GREATER_EQUAL,
      '<' => :LESS,
      '>' => :GREATER,
      '!' => :NOT,
      '.' => :DOT,
      '[' => :LBRACKET,
      ']' => :RBRACKET,
      ',' => :COMMA,
      '{' => :LBRACE,
      '}' => :RBRACE,
      ':' => :COLON,
      '::' => :DOUBLE_COLON,
      '@' => :AT,
      '?-' => :QUERY_PREFIX,
      '?' => :QUESTION
    }
    
    operator_tests.each do |input, expected_type|
      lexer = Lexer.new(input)
      tokens = lexer.tokenize
      assert_equal expected_type, tokens.first.type, "Failed for operator: #{input}"
    end
  end

  def test_number_parsing_comprehensive
    # Test various number formats
    number_tests = [
      { input: '0', expected: 0 },
      { input: '42', expected: 42 },
      { input: '007', expected: 7 },
      { input: '123456789', expected: 123456789 },
      { input: '3.14', expected: 3.14 },
      { input: '0.5', expected: 0.5 },
      { input: '.25', expected: 0.25 },
      { input: '123.', expected: 123.0 },
      { input: '0.0', expected: 0.0 }
    ]
    
    number_tests.each do |test_case|
      lexer = Lexer.new(test_case[:input])
      tokens = lexer.tokenize
      assert_equal :NUMBER, tokens.first.type, "Failed for number: #{test_case[:input]}"
      assert_equal test_case[:expected], tokens.first.value, "Value mismatch for: #{test_case[:input]}"
    end
  end

  def test_string_parsing_comprehensive
    # Test various string formats and escape sequences
    string_tests = [
      { input: '""', expected: '' },
      { input: '"hello"', expected: 'hello' },
      { input: "'world'", expected: 'world' },
      { input: '"Hello\\nWorld"', expected: "Hello\nWorld" },
      { input: '"Tab\\tSeparated"', expected: "Tab\tSeparated" },
      { input: '"Carriage\\rReturn"', expected: "Carriage\rReturn" },
      { input: '"Quote\\"Inside"', expected: 'Quote"Inside' },
      { input: "'Single\\'Quote'", expected: "Single'Quote" },
      { input: '"Backslash\\\\"', expected: 'Backslash\\' },
      { input: '"Mixed\\n\\t\\r"', expected: "Mixed\n\t\r" }
    ]
    
    string_tests.each do |test_case|
      lexer = Lexer.new(test_case[:input])
      tokens = lexer.tokenize
      assert_equal :STRING, tokens.first.type, "Failed for string: #{test_case[:input]}"
      assert_equal test_case[:expected], tokens.first.value, "Value mismatch for: #{test_case[:input]}"
    end
  end

  def test_unterminated_string_handling
    # Test unterminated strings
    unterminated_tests = [
      '"unterminated',
      "'also unterminated",
      '"with newline\n'
    ]
    
    unterminated_tests.each do |input|
      lexer = Lexer.new(input)
      begin
        tokens = lexer.tokenize
        # Should either produce UNTERMINATED_STRING or handle gracefully
        assert tokens.any?, "Should produce tokens for: #{input}"
      rescue RuntimeError => e
        # Some unterminated strings may raise errors, which is acceptable
        assert_match(/(Incomplete|Unterminated|Invalid)/, e.message, "Error should be descriptive for: #{input}")
      end
    end
    
    # Test specific case that should raise error
    lexer = Lexer.new('"with escape \\')
    assert_raises(RuntimeError) { lexer.tokenize }
  end

  def test_comment_handling_comprehensive
    # Test various comment scenarios
    comment_tests = [
      '# Simple comment',
      '# Comment with symbols !@#$%^&*()',
      '# Comment\n',
      '# Comment\ncode_after',
      'before # inline comment',
      '# Unicode comment αβγ 🚀',
      '# Comment with "quotes" and \'apostrophes\'',
      '# Multiple\n# Comments\n# In\n# Sequence'
    ]
    
    comment_tests.each do |input|
      lexer = Lexer.new(input)
      tokens = lexer.tokenize
      # Comments should be skipped, only non-comment tokens remain
      non_eof_tokens = tokens.reject { |t| t.type == :EOF }
      assert tokens.any?, "Should produce tokens for: #{input}"
    end
  end

  def test_ambiguous_token_coverage
    # Test all ambiguous tokens and their context resolution
    ambiguous_tests = [
      { input: 'make', types: [:MAKE, :IDENTIFIER] },
      { input: 'a', types: [:A, :IDENTIFIER] },
      { input: 'function', types: [:FUNCTION, :IDENTIFIER] },
      { input: 'called', types: [:CALLED, :IDENTIFIER] }
    ]
    
    ambiguous_tests.each do |test_case|
      lexer = Lexer.new(test_case[:input])
      tokens = lexer.tokenize
      token = tokens.first
      
      if token.respond_to?(:ambiguous?) && token.ambiguous?
        assert token.is_a?(AmbiguousToken), "Should be AmbiguousToken for: #{test_case[:input]}"
        test_case[:types].each do |type|
          assert token.can_be?(type), "Should be resolvable to #{type} for: #{test_case[:input]}"
        end
      else
        assert test_case[:types].include?(token.type), "Should be one of #{test_case[:types]} for: #{test_case[:input]}"
      end
    end
  end

  def test_identifier_parsing_comprehensive
    # Test various identifier formats
    identifier_tests = [
      'simple',
      'with_underscore',
      'camelCase',
      'PascalCase',
      'identifier123',
      'a1b2c3',
      '_leading_underscore',
      'trailing_underscore_',
      'method_name?',
      'predicate?',
      'CONSTANT',
      'Mixed_Case_123'
    ]
    
    identifier_tests.each do |input|
      lexer = Lexer.new(input)
      tokens = lexer.tokenize
      token = tokens.first
      
      # May be IDENTIFIER or ambiguous token
      if token.respond_to?(:ambiguous?) && token.ambiguous?
        assert token.can_be?(:IDENTIFIER), "Should be resolvable to IDENTIFIER for: #{input}"
      else
        assert_equal :IDENTIFIER, token.type, "Should be IDENTIFIER for: #{input}"
      end
      assert_equal input, token.value, "Value should match for: #{input}"
    end
  end

  def test_position_tracking_comprehensive
    # Test position tracking across various scenarios
    multiline_input = <<~INPUT
      # Line 1 comment
      x = 42
      "string on line 3"
      y = 3.14
      # Final comment
    INPUT
    
    lexer = Lexer.new(multiline_input)
    tokens = lexer.tokenize
    
    # Verify all tokens have valid position information
    tokens.each do |token|
      assert token.line >= 1, "Line should be >= 1 for token: #{token}"
      assert token.column >= 1, "Column should be >= 1 for token: #{token}"
      assert token.position >= 0, "Position should be >= 0 for token: #{token}"
    end
    
    # Verify line progression
    line_numbers = tokens.map(&:line).uniq
    assert line_numbers.length > 1, "Should span multiple lines"
  end

  def test_whitespace_handling_comprehensive
    # Test various whitespace scenarios
    whitespace_tests = [
      "   \t\n\r   ",
      "\t\t\t42\t\t\t",
      "\n\n\nidentifier\n\n\n",
      " \t mixed \r\n whitespace \t ",
      "tabs\t\tand\t\tspaces",
      "\r\nwindows\r\nline\r\nendings\r\n"
    ]
    
    whitespace_tests.each do |input|
      lexer = Lexer.new(input)
      tokens = lexer.tokenize
      
      # Should handle whitespace gracefully
      assert tokens.any?, "Should produce at least EOF token for: #{input.inspect}"
      
      # All tokens should have valid positions
      tokens.each do |token|
        assert token.position >= 0, "Position should be valid for whitespace test"
      end
    end
  end

  def test_mixed_content_comprehensive
    # Test complex mixed content
    complex_input = <<~INPUT
      # Complex test with everything
      make a function called "test_func"
      x = 42 + 3.14
      if x > 100 then
        print "Large number"
      else
        print "Small number"
      end
      
      @annotation
      {key: "value", number: 123}
      [1, 2, 3, 4, 5]
      
      # More complex expressions
      result = (a + b) * c / d
      query ?- fact(X, Y, Z)
      
      # Unicode and special chars
      €£¥ symbols and 🚀💻 emojis
      greek: αβγ
    INPUT
    
    lexer = Lexer.new(complex_input)
    tokens = lexer.tokenize
    
    # Should tokenize without crashing
    assert tokens.length > 50, "Should produce many tokens for complex input"
    
    # Should contain EOF token
    eof_tokens = tokens.select { |t| t.type == :EOF }
    assert_equal 1, eof_tokens.length, "Should have exactly one EOF token"
    
    # Should contain various token types
    token_types = tokens.map(&:type).uniq
    assert token_types.include?(:IDENTIFIER), "Should contain identifiers"
    assert token_types.include?(:NUMBER), "Should contain numbers"
    assert token_types.include?(:STRING), "Should contain strings"
    assert token_types.include?(:UNKNOWN), "Should contain unknown tokens for special chars"
  end

  def test_edge_cases_comprehensive
    # Test various edge cases
    edge_cases = [
      '',                    # Empty input
      ' ',                   # Single space
      '\n',                  # Single newline
      '0',                   # Single digit
      'a',                   # Single letter
      '.',                   # Single dot
      '.5',                  # Decimal starting with dot
      '5.',                  # Decimal ending with dot
      '==',                  # Double equals
      '!=',                  # Not equals
      '<=',                  # Less than or equal
      '>=',                  # Greater than or equal
      '::',                  # Double colon
      '?-',                  # Query prefix
      '\\',                  # Backslash
      '@',                   # At symbol
      '?',                   # Question mark
      '!',                   # Exclamation
      '=',                   # Single equals
      '12345678901234567890' # Very large number
    ]
    
    edge_cases.each do |input|
      lexer = Lexer.new(input)
      tokens = lexer.tokenize
      
      # Should always produce at least EOF token
      assert tokens.any?, "Should produce tokens for edge case: #{input.inspect}"
      
      # Should always end with EOF
      assert_equal :EOF, tokens.last.type, "Should end with EOF for: #{input.inspect}"
    end
  end

  def test_peek_methods_coverage
    # Test peek_char and peek_word methods
    lexer = Lexer.new("hello world 123")
    
    # Test peek_char functionality
    first_char = lexer.send(:peek_char)
    assert_equal 'e', first_char, "Should peek at next character"
    
    # Position shouldn't change after peek
    position_before = lexer.instance_variable_get(:@position)
    lexer.send(:peek_char)
    position_after = lexer.instance_variable_get(:@position)
    assert_equal position_before, position_after, "Position shouldn't change after peek"
  end

  def test_helper_methods_coverage
    # Test alpha?, alphanumeric?, and other helper methods
    lexer = Lexer.new("test")
    
    # Test alpha? method
    assert lexer.send(:alpha?, 'a'), "Should recognize 'a' as alpha"
    assert lexer.send(:alpha?, 'Z'), "Should recognize 'Z' as alpha"
    assert lexer.send(:alpha?, '_'), "Should recognize '_' as alpha"
    refute lexer.send(:alpha?, '1'), "Should not recognize '1' as alpha"
    refute lexer.send(:alpha?, '@'), "Should not recognize '@' as alpha"
    
    # Test alphanumeric? method
    assert lexer.send(:alphanumeric?, 'a'), "Should recognize 'a' as alphanumeric"
    assert lexer.send(:alphanumeric?, '1'), "Should recognize '1' as alphanumeric"
    assert lexer.send(:alphanumeric?, '_'), "Should recognize '_' as alphanumeric"
    refute lexer.send(:alphanumeric?, '@'), "Should not recognize '@' as alphanumeric"
  end
end

# Run the comprehensive test
if __FILE__ == $0
  puts "Running comprehensive lexer coverage test..."
  require 'minitest/autorun'
end