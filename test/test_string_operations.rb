require_relative 'test_helper'
require_relative '../src/lexer'
require_relative '../src/parser'
require_relative '../src/evaluator'
require_relative '../src/token'
require_relative '../src/ast_nodes'

class TestStringOperations < Minitest::Test
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

  # String Concatenation Tests
  def test_string_plus_string
    assert_equal "helloworld", evaluate_expression('"hello" + "world"')
    assert_equal "abc", evaluate_expression('"a" + "b" + "c"')
    assert_equal "", evaluate_expression('"" + ""')
  end

  def test_string_plus_number
    assert_equal "hello123", evaluate_expression('"hello" + 123')
    assert_equal "42world", evaluate_expression('42 + "world"')
    assert_equal "3.14159", evaluate_expression('3.14 + "159"')
  end

  def test_string_concatenation_with_variables
    code = <<~PATLANG
      greeting = "Hello"
      name = "World"
      greeting + " " + name
    PATLANG
    assert_equal "Hello World", evaluate_program(code)
  end

  def test_mixed_concatenation_chain
    assert_equal "Result: 42!", evaluate_expression('"Result: " + 42 + "!"')
    assert_equal "123abc456", evaluate_expression('123 + "abc" + 456')
  end

  # String Comparison Tests
  def test_string_equality
    assert_equal true, evaluate_expression('"hello" == "hello"')
    assert_equal false, evaluate_expression('"hello" == "world"')
    assert_equal false, evaluate_expression('"hello" != "hello"')
    assert_equal true, evaluate_expression('"hello" != "world"')
  end

  def test_string_ordering
    assert_equal true, evaluate_expression('"apple" < "banana"')
    assert_equal false, evaluate_expression('"banana" < "apple"')
    assert_equal true, evaluate_expression('"zebra" > "apple"')
    assert_equal false, evaluate_expression('"apple" > "zebra"')
    assert_equal true, evaluate_expression('"hello" <= "hello"')
    assert_equal true, evaluate_expression('"apple" <= "banana"')
    assert_equal true, evaluate_expression('"hello" >= "hello"')
    assert_equal true, evaluate_expression('"zebra" >= "apple"')
  end

  def test_string_comparison_in_control_flow
    code = <<~PATLANG
      name = "Alice"
      if name == "Alice" then
        "Found Alice"
      else
        "Not Alice"
      end
    PATLANG
    assert_equal "Found Alice", evaluate_program(code)

    code = <<~PATLANG
      word1 = "apple"
      word2 = "banana"
      if word1 < word2 then
        "apple comes first"
      else
        "banana comes first"
      end
    PATLANG
    assert_equal "apple comes first", evaluate_program(code)
  end

  # String Indexing Tests (1-based indexing)
  def test_string_indexing_basic
    assert_equal "h", evaluate_expression('"hello"[1]')
    assert_equal "e", evaluate_expression('"hello"[2]')
    assert_equal "o", evaluate_expression('"hello"[5]')
  end

  def test_string_negative_indexing
    assert_equal "o", evaluate_expression('"hello"[-1]')
    assert_equal "l", evaluate_expression('"hello"[-2]')
    assert_equal "h", evaluate_expression('"hello"[-5]')
  end

  def test_string_indexing_with_variables
    code = <<~PATLANG
      text = "world"
      index = 2
      text[index]
    PATLANG
    assert_equal "o", evaluate_program(code)
  end

  def test_string_indexing_bounds_checking
    assert_raises(RuntimeError, "String index 6 out of bounds") do
      evaluate_expression('"hello"[6]')
    end

    assert_raises(RuntimeError, "String index 0 out of bounds") do
      evaluate_expression('"hello"[0]')
    end

    assert_raises(RuntimeError, "String index -6 out of bounds") do
      evaluate_expression('"hello"[-6]')
    end
  end

  def test_string_indexing_non_integer_error
    assert_raises(RuntimeError, "String index must be an integer") do
      evaluate_expression('"hello"["bad"]')
    end
  end

  def test_indexing_non_string_error
    assert_raises(RuntimeError, "Index access is only supported for strings") do
      evaluate_expression('123[1]')
    end
  end

  # String Method Tests
  def test_string_length_method
    assert_equal 5, evaluate_expression('"hello".length')
    assert_equal 0, evaluate_expression('"".length')
    assert_equal 13, evaluate_expression('"Hello, World!".length')
  end

  def test_string_length_with_variables
    code = <<~PATLANG
      message = "Patlang"
      message.length
    PATLANG
    assert_equal 7, evaluate_program(code)
  end

  def test_method_call_non_string_error
    # Numbers now support length method, so test with an invalid method instead
    assert_raises(RuntimeError, "Unknown number method") do
      evaluate_expression('123.invalid_method')
    end
  end

  def test_unknown_string_method_error
    assert_raises(RuntimeError, "Unknown string method: unknown") do
      evaluate_expression('"hello".unknown')
    end
  end

  # Integration Tests
  def test_complex_string_operations
    code = <<~PATLANG
      first = "Hello"
      second = "World"
      combined = first + " " + second
      combined[7]
    PATLANG
    assert_equal "W", evaluate_program(code)
  end

  def test_string_operations_in_loops
    code = <<~PATLANG
      text = "abc"
      i = 1
      result = ""
      while i <= text.length do
        result = result + text[i]
        i = i + 1
      end
      result
    PATLANG
    assert_equal "abc", evaluate_program(code)
  end

  def test_chained_operations
    assert_equal 10, evaluate_expression('("hello" + "world").length')
    assert_equal "d", evaluate_expression('("hello" + "world")[-1]')
  end

  def test_string_comparison_with_concatenation
    code = <<~PATLANG
      if "a" + "b" == "ab" then
        "concatenation works"
      else
        "concatenation failed"
      end
    PATLANG
    assert_equal "concatenation works", evaluate_program(code)
  end
end