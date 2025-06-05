require_relative '../helpers/test_helper'
require_relative '../../src/lexer'
require_relative '../../src/parser'
require_relative '../../src/evaluator'
require_relative '../../src/token'
require_relative '../../src/ast_nodes'

class TestStringLiterals < Minitest::Test
  def setup
    @lexer = nil
    @parser = nil
    @evaluator = nil
  end

  def evaluate_expression(code)
    @lexer = Lexer.new(code)
    tokens = @lexer.tokenize
    @parser = Parser.new(tokens)
    ast = @parser.expression
    @evaluator = Evaluator.new
    @evaluator.evaluate(ast)
  end

  def evaluate_program(code)
    @lexer = Lexer.new(code)
    tokens = @lexer.tokenize
    @parser = Parser.new(tokens)
    ast = @parser.parse
    @evaluator = Evaluator.new
    @evaluator.evaluate(ast)
  end

  def test_basic_string_literals
    assert_equal "hello", evaluate_expression('"hello"')
    assert_equal "", evaluate_expression('""')
    assert_equal "with spaces", evaluate_expression('"with spaces"')
  end

  def test_escape_sequences
    assert_equal "hello\nworld", evaluate_expression('"hello\\nworld"')
    assert_equal 'say "hello"', evaluate_expression('"say \\"hello\\""')
    assert_equal "tab\there", evaluate_expression('"tab\\there"')
    assert_equal "backslash\\", evaluate_expression('"backslash\\\\"')
    assert_equal "carriage\rreturn", evaluate_expression('"carriage\\rreturn"')
  end

  def test_string_assignment
    result = evaluate_program('name = "Patlang"')
    assert_equal "Patlang", result
  end

  def test_string_in_variables
    code = <<~PATLANG
      greeting = "Hello"
      name = "World"
      greeting
    PATLANG
    assert_equal "Hello", evaluate_program(code)
  end

  def test_empty_string_assignment
    result = evaluate_program('empty = ""')
    assert_equal "", result
  end

  def test_string_with_numbers_and_symbols
    assert_equal "test123", evaluate_expression('"test123"')
    assert_equal "!@#$%", evaluate_expression('"!@#$%"')
    assert_equal "mixed 123 !@#", evaluate_expression('"mixed 123 !@#"')
  end

  def test_unterminated_string_error
    assert_raises(RuntimeError) do
      @lexer = Lexer.new('"unterminated string')
      @lexer.tokenize
    end
  end

  def test_incomplete_escape_sequence_error
    assert_raises(RuntimeError) do
      @lexer = Lexer.new('"incomplete escape\\')
      @lexer.tokenize
    end
  end

  def test_string_tokenization
    @lexer = Lexer.new('"hello world"')
    tokens = @lexer.tokenize
    
    assert_equal 2, tokens.length
    assert_equal Token::TOKEN_TYPES[:STRING], tokens[0].type
    assert_equal "hello world", tokens[0].value
    assert_equal Token::TOKEN_TYPES[:EOF], tokens[1].type
  end

  def test_string_with_escape_sequences_tokenization
    @lexer = Lexer.new('"hello\\nworld"')
    tokens = @lexer.tokenize
    
    assert_equal 2, tokens.length
    assert_equal Token::TOKEN_TYPES[:STRING], tokens[0].type
    assert_equal "hello\nworld", tokens[0].value
  end

  def test_multiple_strings
    code = <<~PATLANG
      first = "first string"
      second = "second string"
      second
    PATLANG
    assert_equal "second string", evaluate_program(code)
  end
end