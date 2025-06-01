require_relative 'test_helper'
require_relative '../src/lexer'
require_relative '../src/parser'
require_relative '../src/evaluator'
require_relative '../src/token'
require_relative '../src/ast_nodes'

class TestExtendedStringMethods < Minitest::Test
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

  # Substring method tests (1-based indexing)
  def test_substring_basic
    assert_equal "ell", evaluate_expression('"hello".substring(2, 3)')
    assert_equal "wor", evaluate_expression('"world".substring(1, 3)')
    assert_equal "d", evaluate_expression('"world".substring(5, 1)')
  end

  def test_substring_edge_cases
    assert_equal "", evaluate_expression('"hello".substring(1, 0)')
    assert_equal "hello", evaluate_expression('"hello".substring(1, 5)')
    assert_equal "o", evaluate_expression('"hello".substring(5, 10)')  # Length beyond string
  end

  def test_substring_negative_start
    assert_equal "lo", evaluate_expression('"hello".substring(-2, 2)')
    assert_equal "o", evaluate_expression('"hello".substring(-1, 1)')
    assert_equal "ello", evaluate_expression('"hello".substring(-4, 4)')
  end

  def test_substring_error_cases
    assert_raises(RuntimeError, "String.substring method takes 2 arguments") do
      evaluate_expression('"hello".substring(1)')
    end

    assert_raises(RuntimeError, "String.substring start must be an integer") do
      evaluate_expression('"hello".substring("bad", 2)')
    end

    assert_raises(RuntimeError, "String.substring length must be an integer") do
      evaluate_expression('"hello".substring(1, "bad")')
    end

    assert_raises(RuntimeError, "String.substring start index 10 out of bounds") do
      evaluate_expression('"hello".substring(10, 2)')
    end

    assert_raises(RuntimeError, "String.substring length must be non-negative") do
      evaluate_expression('"hello".substring(1, -1)')
    end
  end

  # starts_with method tests
  def test_starts_with_basic
    assert_equal true, evaluate_expression('"hello".starts_with("h")')
    assert_equal true, evaluate_expression('"hello".starts_with("hel")')
    assert_equal true, evaluate_expression('"hello".starts_with("hello")')
    assert_equal false, evaluate_expression('"hello".starts_with("x")')
    assert_equal false, evaluate_expression('"hello".starts_with("ell")')
  end

  def test_starts_with_empty_string
    assert_equal true, evaluate_expression('"hello".starts_with("")')
    assert_equal true, evaluate_expression('"".starts_with("")')
  end

  def test_starts_with_error_cases
    assert_raises(RuntimeError, "String.starts_with method takes 1 argument") do
      evaluate_expression('"hello".starts_with("h", "extra")')
    end

    assert_raises(RuntimeError, "String.starts_with prefix must be a string") do
      evaluate_expression('"hello".starts_with(123)')
    end
  end

  # ends_with method tests
  def test_ends_with_basic
    assert_equal true, evaluate_expression('"hello".ends_with("o")')
    assert_equal true, evaluate_expression('"hello".ends_with("llo")')
    assert_equal true, evaluate_expression('"hello".ends_with("hello")')
    assert_equal false, evaluate_expression('"hello".ends_with("x")')
    assert_equal false, evaluate_expression('"hello".ends_with("hel")')
  end

  def test_ends_with_empty_string
    assert_equal true, evaluate_expression('"hello".ends_with("")')
    assert_equal true, evaluate_expression('"".ends_with("")')
  end

  def test_ends_with_error_cases
    assert_raises(RuntimeError, "String.ends_with method takes 1 argument") do
      evaluate_expression('"hello".ends_with("o", "extra")')
    end

    assert_raises(RuntimeError, "String.ends_with suffix must be a string") do
      evaluate_expression('"hello".ends_with(123)')
    end
  end

  # uppercase method tests
  def test_uppercase_basic
    assert_equal "HELLO", evaluate_expression('"hello".uppercase()')
    assert_equal "WORLD", evaluate_expression('"WoRlD".uppercase()')
    assert_equal "123ABC", evaluate_expression('"123abc".uppercase()')
    assert_equal "", evaluate_expression('"".uppercase()')
  end

  def test_uppercase_error_cases
    assert_raises(RuntimeError, "String.uppercase method takes no arguments") do
      evaluate_expression('"hello".uppercase("extra")')
    end
  end

  # lowercase method tests
  def test_lowercase_basic
    assert_equal "hello", evaluate_expression('"HELLO".lowercase()')
    assert_equal "world", evaluate_expression('"WoRlD".lowercase()')
    assert_equal "123abc", evaluate_expression('"123ABC".lowercase()')
    assert_equal "", evaluate_expression('"".lowercase()')
  end

  def test_lowercase_error_cases
    assert_raises(RuntimeError, "String.lowercase method takes no arguments") do
      evaluate_expression('"HELLO".lowercase("extra")')
    end
  end

  # trim method tests
  def test_trim_basic
    assert_equal "hello", evaluate_expression('"  hello  ".trim()')
    assert_equal "world", evaluate_expression('" world ".trim()')
    assert_equal "test", evaluate_expression('"test".trim()')
    assert_equal "", evaluate_expression('"   ".trim()')
    assert_equal "", evaluate_expression('"".trim()')
  end

  def test_trim_whitespace_types
    assert_equal "hello", evaluate_expression('"\t hello \n".trim()')
    assert_equal "multi line", evaluate_expression('"\r\n  multi line  \t\r".trim()')
  end

  def test_trim_error_cases
    assert_raises(RuntimeError, "String.trim method takes no arguments") do
      evaluate_expression('"  hello  ".trim("extra")')
    end
  end

  # Integration tests with variables
  def test_methods_with_variables
    code = <<~PATLANG
      text = "Hello World"
      part = text.substring(1, 5)
      part.lowercase()
    PATLANG
    assert_equal "hello", evaluate_program(code)

    code = <<~PATLANG
      greeting = "  Hello  "
      clean = greeting.trim()
      clean.starts_with("Hello")
    PATLANG
    assert_equal true, evaluate_program(code)
  end

  # Chained method calls
  def test_chained_methods
    assert_equal "HELLO", evaluate_expression('"  hello  ".trim().uppercase()')
    assert_equal "wor", evaluate_expression('"Hello World".lowercase().substring(7, 3)')
    assert_equal true, evaluate_expression('"TESTING".lowercase().starts_with("test")')
  end

  # Complex integration scenarios
  def test_string_methods_in_control_flow
    code = <<~PATLANG
      filename = "document.txt"
      if filename.ends_with(".txt") then
        filename.substring(1, filename.length - 4).uppercase()
      else
        "Unknown file type"
      end
    PATLANG
    assert_equal "DOCUMENT", evaluate_program(code)

    code = <<~PATLANG
      user_input = "  Admin  "
      clean_input = user_input.trim().lowercase()
      if clean_input == "admin" then
        "Access granted"
      else
        "Access denied"
      end
    PATLANG
    assert_equal "Access granted", evaluate_program(code)
  end

  def test_string_methods_in_loops
    code = <<~PATLANG
      words = "hello world test"
      i = 1
      result = ""
      while i <= words.length do
        char = words[i]
        if char != " " then
          result = result + char.uppercase()
        end
        i = i + 1
      end
      result
    PATLANG
    assert_equal "HELLOWORLDTEST", evaluate_program(code)
  end

  # Edge case testing
  def test_methods_on_empty_strings
    assert_equal "", evaluate_expression('"".substring(1, 0)')
    assert_equal true, evaluate_expression('"".starts_with("")')
    assert_equal true, evaluate_expression('"".ends_with("")')
    assert_equal "", evaluate_expression('"".uppercase()')
    assert_equal "", evaluate_expression('"".lowercase()')
    assert_equal "", evaluate_expression('"".trim()')
  end

  def test_methods_with_special_characters
    assert_equal "HELLO\nWORLD", evaluate_expression('"hello\nworld".uppercase()')
    assert_equal true, evaluate_expression('"hello\tworld".starts_with("hello")')
    assert_equal "tab ", evaluate_expression('"\ttab and spaces\t ".trim().substring(1, 4)')
  end

  # Number method tests
  def test_number_length_method
    assert_equal 1, evaluate_expression('1.length()')
    assert_equal 2, evaluate_expression('42.length()')
    assert_equal 3, evaluate_expression('123.length()')
    assert_equal 4, evaluate_expression('3.14.length()')
    assert_equal 6, evaluate_expression('123.45.length()')
  end

  def test_number_method_with_variables
    code = <<~PATLANG
      num = 12345
      num.length()
    PATLANG
    assert_equal 5, evaluate_program(code)
  end

  def test_number_method_error_cases
    assert_raises(RuntimeError, "Number.length method takes no arguments") do
      evaluate_expression('123.length("extra")')
    end

    assert_raises(RuntimeError, "Unknown number method: unknown") do
      evaluate_expression('123.unknown()')
    end
  end
end