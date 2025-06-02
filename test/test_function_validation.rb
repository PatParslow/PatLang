require_relative 'test_helper'
require_relative '../src/patlang'

class TestFunctionValidation < Minitest::Test
  def test_basic_function_definition_and_call
    # Test the exact scenario from the issue report
    code = '
make a function called greet {
  return "Hello, World!"
}
call greet
'
    
    result = Patlang.evaluate(code)
    assert_equal "Hello, World!", result, "Function should return the expected string value"
  end
  
  def test_function_with_parameters
    code = '
make a function called add takes: x, y {
  return x + y
}
call add with 5, 3
'
    
    result = Patlang.evaluate(code)
    assert_equal 8, result, "Function should correctly add parameters"
  end
  
  def test_function_with_string_concatenation
    code = '
make a function called greet_person takes: name {
  return "Hello, " + name + "!"
}
call greet_person with "Alice"
'
    
    result = Patlang.evaluate(code)
    assert_equal "Hello, Alice!", result, "Function should correctly concatenate strings"
  end
  
  def test_function_with_control_flow
    code = '
make a function called classify_number takes: x {
  if x > 0 then
    return "positive"
  else
    if x < 0 then
      return "negative"
    else
      return "zero"
    end
  end
}
call classify_number with 5
'
    
    result = Patlang.evaluate(code)
    assert_equal "positive", result, "Function should correctly classify positive numbers"
  end
  
  def test_nested_function_calls
    code = '
make a function called double takes: x {
  return x * 2
}

make a function called quadruple takes: x {
  return call double with (call double with x)
}

call quadruple with 3
'
    
    result = Patlang.evaluate(code)
    assert_equal 12, result, "Nested function calls should work correctly"
  end
  
  def test_function_definition_returns_function_object
    code = 'make a function called test { return 42 }'
    
    result = Patlang.evaluate(code)
    assert_instance_of FunctionDefinitionNode, result, "Function definition should return FunctionDefinitionNode"
    assert_equal "test", result.name, "Function name should be preserved"
  end
  
  def test_recursive_function
    code = '
make a function called factorial takes: n {
  if n <= 1 then
    return 1
  else
    return n * (call factorial with n - 1)
  end
}
call factorial with 5
'
    
    result = Patlang.evaluate(code)
    assert_equal 120, result, "Recursive factorial function should work correctly"
  end
  
  def test_function_with_no_parameters
    code = '
make a function called get_pi {
  return 3.14159
}
call get_pi
'
    
    result = Patlang.evaluate(code)
    assert_equal 3.14159, result, "Function with no parameters should work correctly"
  end
  
  def test_multiple_function_definitions
    code = '
make a function called add takes: x, y {
  return x + y
}

make a function called multiply takes: x, y {
  return x * y
}

call multiply with (call add with 2, 3), 4
'
    
    result = Patlang.evaluate(code)
    assert_equal 20, result, "Multiple functions should coexist and work together"
  end
  
  def test_function_with_comments
    code = '
# Define a greeting function
make a function called greet {
  return "Hello"  # Return greeting
}
# Call the function
call greet
'
    
    result = Patlang.evaluate(code)
    assert_equal "Hello", result, "Functions should work correctly with comments"
  end
end