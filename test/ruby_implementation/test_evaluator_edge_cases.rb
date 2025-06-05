require_relative '../helpers/test_helper'
require_relative '../../src/evaluator'
require_relative '../../src/lexer'
require_relative '../../src/parser'
require_relative '../../src/ast_nodes'

class TestEvaluatorEdgeCases < Minitest::Test
  def setup
    @evaluator = Evaluator.new
  end

  def evaluate_code(code)
    lexer = Lexer.new(code)
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    @evaluator.evaluate(ast)
  end

  def evaluate_expression(code)
    lexer = Lexer.new(code)
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.expression
    @evaluator.evaluate(ast)
  end

  # Test all conditional branches in visit_binary_op_node
  def test_binary_op_string_concatenation_branches
    # String + String (left is string)
    result = evaluate_expression('"hello" + "world"')
    assert_equal "helloworld", result
    
    # Number + String (right is string, left is not)
    result = evaluate_expression('42 + "test"')
    assert_equal "42test", result
    
    # String + Number (left is string, right is not)
    result = evaluate_expression('"test" + 42')
    assert_equal "test42", result
    
    # Neither is string - normal arithmetic
    result = evaluate_expression('2 + 3')
    assert_equal 5, result
  end

  # Test all operators in binary_op_node
  def test_all_binary_operators
    # Addition
    assert_equal 7, evaluate_expression('3 + 4')
    
    # Subtraction  
    assert_equal 1, evaluate_expression('5 - 4')
    
    # Multiplication
    assert_equal 12, evaluate_expression('3 * 4')
    
    # Division (normal)
    assert_equal 2.5, evaluate_expression('5 / 2')
    
    # Division by zero error
    error = assert_raises(StandardError) do
      evaluate_expression('5 / 0')
    end
    assert_match(/Division by zero/, error.message)
    
    # Unknown operator error (this tests the else clause)
    # We can't easily test this without modifying the parser, but it's there for completeness
  end

  # Test all comparison operators
  def test_all_comparison_operators
    # Equal
    assert_equal true, evaluate_expression('5 == 5')
    assert_equal false, evaluate_expression('5 == 3')
    
    # Not equal
    assert_equal false, evaluate_expression('5 != 5')
    assert_equal true, evaluate_expression('5 != 3')
    
    # Less than
    assert_equal true, evaluate_expression('3 < 5')
    assert_equal false, evaluate_expression('5 < 3')
    
    # Greater than
    assert_equal false, evaluate_expression('3 > 5')
    assert_equal true, evaluate_expression('5 > 3')
    
    # Less than or equal
    assert_equal true, evaluate_expression('3 <= 5')
    assert_equal true, evaluate_expression('5 <= 5')
    assert_equal false, evaluate_expression('7 <= 5')
    
    # Greater than or equal
    assert_equal false, evaluate_expression('3 >= 5')
    assert_equal true, evaluate_expression('5 >= 5')
    assert_equal true, evaluate_expression('7 >= 5')
  end

  # Test if-node conditional branches
  def test_if_node_branches
    # Truthy condition, no else
    result = evaluate_code('if true then "yes" end')
    assert_equal "yes", result
    
    # Falsy condition, no else (returns nil)
    result = evaluate_code('if false then "yes" end')
    assert_nil result
    
    # Truthy condition with else
    result = evaluate_code('if true then "yes" else "no" end')
    assert_equal "yes", result
    
    # Falsy condition with else
    result = evaluate_code('if false then "yes" else "no" end')
    assert_equal "no", result
    
    # Test is_truthy method with various values
    # Note: nil is not a variable in Patlang, it's just false/empty behavior
    # We'll test with undefined variables or false values instead
    
    result = evaluate_code('if 0 then "yes" else "no" end')
    assert_equal "yes", result  # 0 is truthy in Patlang
    
    result = evaluate_code('if "" then "yes" else "no" end')
    assert_equal "yes", result  # empty string is truthy in Patlang
  end

  # Test visit_index_access_node branches
  def test_index_access_branches
    # Valid positive index
    result = evaluate_expression('"hello"[2]')
    assert_equal "e", result
    
    # Valid negative index  
    result = evaluate_expression('"hello"[-1]')
    assert_equal "o", result
    
    # Negative index conversion branch
    result = evaluate_expression('"hello"[-2]')
    assert_equal "l", result
    
    # Index 0 error (tests the bounds checking)
    error = assert_raises(StandardError) do
      evaluate_expression('"hello"[0]')
    end
    assert_match(/String index 0 out of bounds/, error.message)
    
    # Negative index out of bounds
    error = assert_raises(StandardError) do
      evaluate_expression('"hello"[-10]')
    end
    assert_match(/String index -10 out of bounds/, error.message)
    
    # Positive index out of bounds
    error = assert_raises(StandardError) do
      evaluate_expression('"hello"[10]')
    end
    assert_match(/String index 10 out of bounds/, error.message)
  end

  # Test visit_method_call_node branches
  def test_method_call_branches
    # String object
    result = evaluate_expression('"hello".length()')
    assert_equal 5, result
    
    # Number object
    result = evaluate_expression('123.length()')
    assert_equal 3, result
    
    # Unsupported object type
    error = assert_raises(StandardError) do
      evaluate_code(<<~CODE)
        x = true
        x.length()
      CODE
    end
    assert_match(/Method calls are only supported for strings and numbers/, error.message)
  end

  # Test handle_string_method branches
  def test_string_method_branches
    # All string methods
    assert_equal 5, evaluate_expression('"hello".length()')
    assert_equal "ell", evaluate_expression('"hello".substring(2, 3)')
    assert_equal true, evaluate_expression('"hello".starts_with("hel")')
    assert_equal true, evaluate_expression('"hello".ends_with("llo")')
    assert_equal "HELLO", evaluate_expression('"hello".uppercase()')
    assert_equal "hello", evaluate_expression('"HELLO".lowercase()')
    assert_equal "hello", evaluate_expression('"  hello  ".trim()')
    
    # Unknown string method (tests else clause)
    error = assert_raises(StandardError) do
      evaluate_expression('"hello".unknown()')
    end
    assert_match(/Unknown string method: unknown/, error.message)
  end

  # Test substring method branches thoroughly
  def test_substring_method_branches
    # Empty string case with valid parameters
    result = evaluate_expression('"".substring(1, 0)')
    assert_equal "", result
    
    # Empty string case with invalid start
    error = assert_raises(StandardError) do
      evaluate_expression('"".substring(2, 1)')
    end
    assert_match(/String.substring start index 2 out of bounds/, error.message)
    
    # Normal case - positive start index
    result = evaluate_expression('"hello".substring(2, 3)')
    assert_equal "ell", result
    
    # Negative start index (tests the conversion branch)
    result = evaluate_expression('"hello".substring(-3, 2)')
    assert_equal "ll", result
    
    # Length extends beyond string (tests end_index clamping)
    result = evaluate_expression('"hello".substring(3, 10)')
    assert_equal "llo", result
    
    # Start index out of bounds
    error = assert_raises(StandardError) do
      evaluate_expression('"hello".substring(10, 2)')
    end
    assert_match(/String.substring start index 10 out of bounds/, error.message)
    
    # Zero start index
    error = assert_raises(StandardError) do
      evaluate_expression('"hello".substring(0, 2)')
    end
    assert_match(/String.substring start index 0 out of bounds/, error.message)
  end

  # Test while loop branches and infinite loop protection
  def test_while_loop_branches
    # Normal while loop
    result = evaluate_code(<<~CODE)
      i = 1
      sum = 0
      while i <= 3 do
        sum = sum + i
        i = i + 1
      end
      sum
    CODE
    assert_equal 6, result
    
    # While loop that never executes
    result = evaluate_code(<<~CODE)
      i = 5
      sum = 0
      while i < 3 do
        sum = sum + i
        i = i + 1
      end
      sum
    CODE
    assert_equal 0, result
    
    # Test infinite loop protection
    # Note: This is tricky to test without actually creating an infinite loop
    # The protection kicks in at 10000 iterations
    error = assert_raises(StandardError) do
      evaluate_code(<<~CODE)
        i = 1
        while true do
          i = i + 1
          if i > 10001 then
            break
          end
        end
      CODE
    end
    assert_match(/Maximum loop iterations exceeded/, error.message)
  end

  # Test block node (multiple statements)
  def test_block_node_branches
    # Single statement
    result = evaluate_code('42')
    assert_equal 42, result
    
    # Multiple statements
    result = evaluate_code(<<~CODE)
      x = 1
      y = 2
      x + y
    CODE
    assert_equal 3, result
    
    # Empty block would return nil, but parser might not allow this
  end

  # Test error conditions comprehensive
  def test_comprehensive_error_conditions
    # Undefined variable
    error = assert_raises(StandardError) do
      evaluate_code('undefined_var')
    end
    assert_match(/Undefined variable: undefined_var/, error.message)
    
    # Invalid index type
    error = assert_raises(StandardError) do
      evaluate_code(<<~CODE)
        x = "not_integer"
        "hello"[x]
      CODE
    end
    assert_match(/String index must be an integer/, error.message)
    
    # Index on non-string
    error = assert_raises(StandardError) do
      evaluate_code(<<~CODE)
        x = 123
        x[1]
      CODE
    end
    assert_match(/Index access is only supported for strings/, error.message)
  end

  # Test type coercion in string concatenation
  def test_string_concatenation_type_coercion
    # Boolean to string
    result = evaluate_expression('"Result: " + true')
    assert_equal "Result: true", result
    
    result = evaluate_expression('"Result: " + false')
    assert_equal "Result: false", result
    
    # Float to string
    result = evaluate_expression('"Pi: " + 3.14')
    assert_equal "Pi: 3.14", result
    
    # Variable containing different types
    result = evaluate_code(<<~CODE)
      bool_var = true
      num_var = 42
      "Bool: " + bool_var + ", Num: " + num_var
    CODE
    assert_equal "Bool: true, Num: 42", result
  end
end