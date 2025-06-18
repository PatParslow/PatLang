# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../patlang-core/lexer/lexer'
require_relative '../../patlang-core/lexer/token'

class TestLexer < Minitest::Test
  def test_empty_input
    lexer = Lexer.new('')
    tokens = lexer.tokenize
    assert_equal 1, tokens.length
    assert_equal :EOF, tokens[0].type
  end

  def test_whitespace_handling
    lexer = Lexer.new("   \t\n  ")
    tokens = lexer.tokenize
    assert_equal 1, tokens.length
    assert_equal :EOF, tokens[0].type
  end

  def test_single_character_tokens
    test_cases = [
      ['+', :PLUS],
      ['-', :MINUS],
      ['*', :STAR],
      ['/', :SLASH],
      ['%', :PERCENT],
      ['(', :LPAREN],
      [')', :RPAREN],
      ['{', :LBRACE],
      ['}', :RBRACE],
      [':', :COLON],
      [',', :COMMA],
      ['@', :AT]
    ]

    test_cases.each do |input, expected_type|
      lexer = Lexer.new(input)
      tokens = lexer.tokenize
      assert_equal 2, tokens.length
      assert_equal expected_type, tokens[0].type
      assert_equal :EOF, tokens[1].type
    end
  end

  def test_two_character_tokens
    test_cases = [
      ['==', :EQUAL],
      ['!=', :NOT_EQUAL],
      ['<=', :LESS_EQUAL],
      ['>=', :GREATER_EQUAL]
    ]

    test_cases.each do |input, expected_type|
      lexer = Lexer.new(input)
      tokens = lexer.tokenize
      assert_equal 2, tokens.length
      assert_equal expected_type, tokens[0].type
      assert_equal :EOF, tokens[1].type
    end
  end

  def test_single_vs_double_character_disambiguation
    # Test that single characters work when not part of double character tokens
    test_cases = [
      ['<', :LESS],
      ['>', :GREATER],
      ['=', :ASSIGN],
      ['!', :NOT]
    ]

    test_cases.each do |input, expected_type|
      lexer = Lexer.new(input)
      tokens = lexer.tokenize
      assert_equal 2, tokens.length
      assert_equal expected_type, tokens[0].type
      assert_equal :EOF, tokens[1].type
    end
  end

  def test_numbers
    test_cases = [
      ['42', 42],
      ['0', 0],
      ['123', 123],
      ['3.14', 3.14],
      ['0.5', 0.5],
      ['100.0', 100.0]
    ]

    test_cases.each do |input, expected_value|
      lexer = Lexer.new(input)
      tokens = lexer.tokenize
      assert_equal 2, tokens.length
      assert_equal :NUMBER, tokens[0].type
      assert_equal expected_value, tokens[0].value
      assert_equal :EOF, tokens[1].type
    end
  end

  def test_strings
    test_cases = [
      ['"hello"', 'hello'],
      ['"world"', 'world'],
      ['""', ''],
      ['"Hello, World!"', 'Hello, World!'],
      ['"123"', '123']
    ]

    test_cases.each do |input, expected_value|
      lexer = Lexer.new(input)
      tokens = lexer.tokenize
      assert_equal 2, tokens.length
      assert_equal :STRING, tokens[0].type
      assert_equal expected_value, tokens[0].value
      assert_equal :EOF, tokens[1].type
    end
  end

  def test_identifiers_and_keywords
    keyword_tests = [
      ['if', :IF],
      ['then', :THEN],
      ['else', :ELSE],
      ['end', :END],
      ['true', :TRUE],
      ['false', :FALSE],
      ['print', :PRINT],
      ['make', :MAKE],
      ['a', :A],
      ['function', :FUNCTION],
      ['called', :CALLED],
      ['takes', :TAKES],
      ['returns', :RETURNS],
      ['return', :RETURN],
      ['call', :CALL],
      ['with', :WITH]
    ]

    keyword_tests.each do |input, expected_type|
      lexer = Lexer.new(input)
      tokens = lexer.tokenize
      assert_equal 2, tokens.length
      assert_equal expected_type, tokens[0].type
      assert_equal :EOF, tokens[1].type
    end

    # Test regular identifiers
    identifier_tests = [
      ['variable', 'variable'],
      ['x', 'x'],
      ['myVar', 'myVar'],
      ['test123', 'test123'],
      ['_underscore', '_underscore']
    ]

    identifier_tests.each do |input, expected_value|
      lexer = Lexer.new(input)
      tokens = lexer.tokenize
      assert_equal 2, tokens.length
      assert_equal :IDENTIFIER, tokens[0].type
      assert_equal expected_value, tokens[0].value
      assert_equal :EOF, tokens[1].type
    end
  end

  def test_complex_expressions
    lexer = Lexer.new('x + 5 * (y - 2)')
    tokens = lexer.tokenize

    expected_types = [:IDENTIFIER, :PLUS, :NUMBER, :STAR, :LPAREN, :IDENTIFIER, :MINUS, :NUMBER, :RPAREN, :EOF]
    expected_values = ['x', nil, 5, nil, nil, 'y', nil, 2, nil, nil]

    assert_equal expected_types.length, tokens.length

    expected_types.each_with_index do |expected_type, index|
      assert_equal expected_type, tokens[index].type
    end

    expected_values.each_with_index do |expected_value, index|
      next if expected_value.nil?
      assert_equal expected_value, tokens[index].value
    end
  end

  def test_if_statement_tokenization
    lexer = Lexer.new('if x > 5 then print "big" else print "small" end')
    tokens = lexer.tokenize

    expected_types = [
      :IF, :IDENTIFIER, :GREATER, :NUMBER, :THEN, :PRINT, :STRING,
      :ELSE, :PRINT, :STRING, :END, :EOF
    ]

    assert_equal expected_types.length, tokens.length
    expected_types.each_with_index do |expected_type, index|
      assert_equal expected_type, tokens[index].type
    end
  end

  def test_assignment_and_comparison
    lexer = Lexer.new('result = x == y')
    tokens = lexer.tokenize

    expected_types = [:IDENTIFIER, :ASSIGN, :IDENTIFIER, :EQUAL, :IDENTIFIER, :EOF]
    assert_equal expected_types.length, tokens.length
    expected_types.each_with_index do |expected_type, index|
      assert_equal expected_type, tokens[index].type
    end
  end

  def test_string_escaping
    test_cases = [
      ['"hello\\"world"', 'hello"world'],
      ['"\\\\"', '\\'],
      ['"\\n"', "\n"],
      ['"\\t"', "\t"]
    ]

    test_cases.each do |input, expected_value|
      lexer = Lexer.new(input)
      tokens = lexer.tokenize
      assert_equal 2, tokens.length
      assert_equal :STRING, tokens[0].type
      assert_equal expected_value, tokens[0].value
    end
  end

  def test_position_tracking
    lexer = Lexer.new("hello\nworld")
    tokens = lexer.tokenize

    assert_equal 1, tokens[0].line
    assert_equal 1, tokens[0].column
    assert_equal 2, tokens[1].line
    assert_equal 1, tokens[1].column
  end

  def test_error_handling
    # Test unclosed string - lexer follows "Never Fail, Always Token" principle
    lexer = Lexer.new('"unclosed string')
    tokens = lexer.tokenize
    
    # Should return UNTERMINATED_STRING token, not raise error
    assert_equal 2, tokens.length
    assert_equal :UNTERMINATED_STRING, tokens[0].type
    assert_equal 'unclosed string', tokens[0].value
    assert_equal :EOF, tokens[1].type

    # Improved parsing: '3.14.159' now parses as separate tokens instead of erroring
    lexer = Lexer.new('3.14.159')
    tokens = lexer.tokenize
    assert_equal 3, tokens.length  # Two numbers and EOF
    assert_equal :NUMBER, tokens[0].type
    assert_equal :NUMBER, tokens[1].type
    assert_equal :EOF, tokens[2].type
  end

  def test_function_tokenization
    lexer = Lexer.new('make a function called test')
    tokens = lexer.tokenize

    expected_types = [:MAKE, :A, :FUNCTION, :CALLED, :IDENTIFIER, :EOF]
    assert_equal expected_types.length, tokens.length
    expected_types.each_with_index do |expected_type, index|
      assert_equal expected_type, tokens[index].type
    end
  end

  def test_function_call_tokenization
    lexer = Lexer.new('call test with 5, 10')
    tokens = lexer.tokenize

    expected_types = [:CALL, :IDENTIFIER, :WITH, :NUMBER, :COMMA, :NUMBER, :EOF]
    assert_equal expected_types.length, tokens.length
    expected_types.each_with_index do |expected_type, index|
      assert_equal expected_type, tokens[index].type
    end
  end

  def test_function_definition_complete
    input = 'make a function called add takes: x, y { return x + y }'
    lexer = Lexer.new(input)
    tokens = lexer.tokenize

    expected_types = [
      :MAKE, :A, :FUNCTION, :CALLED, :IDENTIFIER, :TAKES, :COLON,
      :IDENTIFIER, :COMMA, :IDENTIFIER, :LBRACE, :RETURN,
      :IDENTIFIER, :PLUS, :IDENTIFIER, :RBRACE, :EOF
    ]

    assert_equal expected_types.length, tokens.length
    expected_types.each_with_index do |expected_type, index|
      assert_equal expected_type, tokens[index].type, "Token #{index} should be #{expected_type}, got #{tokens[index].type}"
    end
  end

  def test_boolean_and_comparison_operators
    lexer = Lexer.new('true == false != x <= y >= z < a > b')
    tokens = lexer.tokenize

    expected_types = [
      :TRUE, :EQUAL, :FALSE, :NOT_EQUAL, :IDENTIFIER,
      :LESS_EQUAL, :IDENTIFIER, :GREATER_EQUAL, :IDENTIFIER,
      :LESS, :A, :GREATER, :IDENTIFIER, :EOF
    ]

    assert_equal expected_types.length, tokens.length
    expected_types.each_with_index do |expected_type, index|
      assert_equal expected_type, tokens[index].type
    end
  end

  def test_arithmetic_expressions
    lexer = Lexer.new('result = (a + b) * c / d - e % f')
    tokens = lexer.tokenize

    expected_types = [
      :IDENTIFIER, :ASSIGN, :LPAREN, :A, :PLUS, :IDENTIFIER,
      :RPAREN, :STAR, :IDENTIFIER, :SLASH, :IDENTIFIER, :MINUS,
      :IDENTIFIER, :PERCENT, :IDENTIFIER, :EOF
    ]

    assert_equal expected_types.length, tokens.length
    expected_types.each_with_index do |expected_type, index|
      assert_equal expected_type, tokens[index].type
    end
  end

  def test_mixed_content_tokenization
    input = <<~CODE
      if x > 0 then
        make a function called double takes: n {
          return n * 2
        }
        call double with x
      end
    CODE

    lexer = Lexer.new(input)
    tokens = lexer.tokenize

    # Verify we get sensible tokens without counting exact positions
    assert_includes tokens.map(&:type), :IF
    assert_includes tokens.map(&:type), :MAKE
    assert_includes tokens.map(&:type), :FUNCTION
    assert_includes tokens.map(&:type), :CALLED
    assert_includes tokens.map(&:type), :TAKES
    assert_includes tokens.map(&:type), :RETURN
    assert_includes tokens.map(&:type), :CALL
    assert_includes tokens.map(&:type), :WITH
    assert_includes tokens.map(&:type), :END
    assert_equal :EOF, tokens.last.type
  end

  def test_edge_case_tokenization
    # Test adjacent operators
    lexer = Lexer.new('x==y!=z<=a>=b')
    tokens = lexer.tokenize

    expected_types = [
      :IDENTIFIER, :EQUAL, :IDENTIFIER, :NOT_EQUAL,
      :IDENTIFIER, :LESS_EQUAL, :A, :GREATER_EQUAL,
      :IDENTIFIER, :EOF
    ]

    assert_equal expected_types.length, tokens.length
    expected_types.each_with_index do |expected_type, index|
      assert_equal expected_type, tokens[index].type
    end
  end

  def test_number_edge_cases
    test_cases = [
      ['0.0', 0.0],
      ['42.', 42.0],
      ['.5', 0.5],
      ['1000', 1000],
      ['0001', 1]  # Leading zeros
    ]

    test_cases.each do |input, expected_value|
      lexer = Lexer.new(input)
      tokens = lexer.tokenize
      assert_equal :NUMBER, tokens[0].type
      assert_equal expected_value, tokens[0].value
    end
  end

  def test_identifier_edge_cases
    # Test cases with expected token types (updated for AmbiguousToken architecture)
    test_cases = [
      ['a', :A],              # AmbiguousToken - could be article or identifier
      ['_', :IDENTIFIER],
      ['_var', :IDENTIFIER],
      ['var_', :IDENTIFIER],
      ['var123', :IDENTIFIER],
      ['CamelCase', :IDENTIFIER],
      ['snake_case', :IDENTIFIER],
      ['mixedCase_123', :IDENTIFIER]
    ]

    test_cases.each do |input, expected_type|
      lexer = Lexer.new(input)
      tokens = lexer.tokenize
      assert_equal expected_type, tokens[0].type
      assert_equal input, tokens[0].value
    end
  end

  def test_keyword_case_sensitivity
    # Keywords should be case sensitive
    test_cases = [
      ['IF', :IDENTIFIER],      # Should be identifier, not keyword
      ['True', :IDENTIFIER],    # Should be identifier, not keyword
      ['PRINT', :IDENTIFIER],   # Should be identifier, not keyword
      ['if', :IF],             # Should be keyword
      ['true', :TRUE],         # Should be keyword
      ['print', :PRINT]        # Should be keyword
    ]

    test_cases.each do |input, expected_type|
      lexer = Lexer.new(input)
      tokens = lexer.tokenize
      assert_equal expected_type, tokens[0].type
    end
  end

  def test_complex_string_content
    test_cases = [
      ['"Hello, World!"', 'Hello, World!'],
      ['"Numbers: 123 and symbols: @#$"', 'Numbers: 123 and symbols: @#$'],
      ['"Mixed \\"quotes\\" content"', 'Mixed "quotes" content'],
      ['"Newline\\nand tab\\there"', "Newline\nand tab\there"]
    ]

    test_cases.each do |input, expected_value|
      lexer = Lexer.new(input)
      tokens = lexer.tokenize
      assert_equal :STRING, tokens[0].type
      assert_equal expected_value, tokens[0].value
    end
  end

  def test_whitespace_variations
    inputs = [
      "   token   ",      # Spaces
      "\t\ttoken\t\t",   # Tabs
      "\n\ntoken\n\n",   # Newlines
      " \t\n token \n\t " # Mixed
    ]

    inputs.each do |input|
      lexer = Lexer.new(input)
      tokens = lexer.tokenize
      assert_equal 2, tokens.length
      assert_equal :IDENTIFIER, tokens[0].type
      assert_equal 'token', tokens[0].value
      assert_equal :EOF, tokens[1].type
    end
  end

  def test_comprehensive_function_syntax
    input = <<~CODE
      make a function called calculate takes: x, y returns: number {
        if x > y then
          return x + y
        else
          return x - y
        end
      }
      
      result = call calculate with 10, 5
    CODE

    lexer = Lexer.new(input)
    tokens = lexer.tokenize

    # Verify essential function tokens are present
    token_types = tokens.map(&:type)

    assert_includes token_types, :MAKE
    assert_includes token_types, :A
    assert_includes token_types, :FUNCTION
    assert_includes token_types, :CALLED
    assert_includes token_types, :TAKES
    assert_includes token_types, :RETURNS
    assert_includes token_types, :RETURN
    assert_includes token_types, :CALL
    assert_includes token_types, :WITH
    assert_includes token_types, :LBRACE
    assert_includes token_types, :RBRACE
    assert_includes token_types, :COLON
    assert_includes token_types, :COMMA

    # Check we have identifiers for function and variable names
    identifier_tokens = tokens.select { |t| t.type == :IDENTIFIER }
    assert_operator identifier_tokens.length, :>, 0

    # Check we have numbers
    number_tokens = tokens.select { |t| t.type == :NUMBER }
    assert_operator number_tokens.length, :>, 0

    assert_equal :EOF, tokens.last.type
  end

  def test_comment_handling
    test_cases = [
      ['# This is a comment', []],
      ["# Comment\ntrue", [:TRUE]],
      ["x = 5 # inline comment", [:IDENTIFIER, :ASSIGN, :NUMBER]],
      ["# First line\n# Second line\nx = 1", [:IDENTIFIER, :ASSIGN, :NUMBER]]
    ]

    test_cases.each do |input, expected_types|
      lexer = Lexer.new(input)
      tokens = lexer.tokenize
      
      # Remove EOF token for comparison
      actual_types = tokens[0..-2].map(&:type)
      assert_equal expected_types, actual_types, "Failed for input: #{input.inspect}"
    end
  end

  def test_numeric_precision
    test_cases = [
      ['3.141592653589793', 3.141592653589793],
      ['0.000001', 0.000001],
      ['1234567890', 1234567890],
      ['99.99', 99.99]
    ]

    test_cases.each do |input, expected_value|
      lexer = Lexer.new(input)
      tokens = lexer.tokenize
      assert_equal :NUMBER, tokens[0].type
      assert_equal expected_value, tokens[0].value
    end
  end

  def test_comprehensive_token_values
    input = 'test_var = 42.5 + "hello world"'
    lexer = Lexer.new(input)
    tokens = lexer.tokenize

    expected_tokens = [
      [:IDENTIFIER, 'test_var'],
      [:ASSIGN, nil],
      [:NUMBER, 42.5],
      [:PLUS, "+"],
      [:STRING, 'hello world'],
      [:EOF, nil]
    ]

    assert_equal expected_tokens.length, tokens.length

    expected_tokens.each_with_index do |(expected_type, expected_value), index|
      assert_equal expected_type, tokens[index].type
      if expected_value.nil?
        assert_nil tokens[index].value
      else
        assert_equal expected_value, tokens[index].value
      end
    end
  end

  def test_error_handling_comprehensive
    # Test various invalid character combinations - lexer follows "Never Fail, Always Token" principle
    invalid_inputs = ['$', '&', '~', '`']
    
    invalid_inputs.each do |invalid_char|
      lexer = Lexer.new(invalid_char)
      tokens = lexer.tokenize
      
      # Should return UNKNOWN token, not raise error
      assert_equal 2, tokens.length
      assert_equal Token::TOKEN_TYPES[:UNKNOWN], tokens[0].type
      assert_equal invalid_char, tokens[0].value
      assert_equal Token::TOKEN_TYPES[:EOF], tokens[1].type
    end
    
    # Test that % is now valid (modulo operator)
    lexer = Lexer.new('%')
    tokens = lexer.tokenize
    assert_equal :PERCENT, tokens[0].type
    
    # Test that @ is now valid (AT token)
    lexer = Lexer.new('@')
    tokens = lexer.tokenize
    assert_equal :AT, tokens[0].type
  end

  def test_position_tracking_for_new_tokens
    lexer = Lexer.new('true == false')
    tokens = lexer.tokenize
    
    # Check that positions are correctly tracked
    assert_equal 1, tokens[0].line
    assert_equal 1, tokens[0].column
    assert_equal 1, tokens[1].line
    assert_equal 6, tokens[1].column  # After 'true '
    assert_equal 1, tokens[2].line
    assert_equal 9, tokens[2].column  # After 'true == '
  end

  def test_function_phrase_tokenization
    # Test natural language function phrases
    test_cases = [
      ['make a function', [:MAKE, :A, :FUNCTION]],
      ['function called', [:FUNCTION, :CALLED]],
      ['takes:', [:TAKES, :COLON]],
      ['returns:', [:RETURNS, :COLON]],
      ['call test with', [:CALL, :IDENTIFIER, :WITH]]
    ]

    test_cases.each do |input, expected_types|
      lexer = Lexer.new(input)
      tokens = lexer.tokenize
      
      # Remove EOF for comparison
      actual_types = tokens[0..-2].map(&:type)
      assert_equal expected_types, actual_types, "Failed for input: #{input}"
    end
  end

  def test_nested_braces_and_complex_structure
    input = <<~CODE
      make a function called nested {
        if true then {
          return call other with { x: 1, y: 2 }
        }
      }
    CODE

    lexer = Lexer.new(input)
    tokens = lexer.tokenize
    
    # Count braces
    lbrace_count = tokens.count { |t| t.type == :LBRACE }
    rbrace_count = tokens.count { |t| t.type == :RBRACE }
    
    assert_equal 3, lbrace_count
    assert_equal 3, rbrace_count
    assert_equal :EOF, tokens.last.type
  end
end