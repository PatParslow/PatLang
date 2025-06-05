require_relative 'test_helper'
require_relative '../src/lexer'
require_relative '../src/parser'
require_relative '../src/evaluator'
require_relative '../src/object_model/patlang_object'
require_relative '../src/object_model/number_object'
require_relative '../src/object_model/string_object'
require_relative '../src/object_model/event_system'

class TestObjectEvaluation < Minitest::Test
  def setup
    @evaluator = Evaluator.new
    
    # Clear object registry before each test
    PatlangObject.clear_registry
    
    # Clear global event handlers before each test
    EventSystem.clear_global_handlers
  end
  
  def teardown
    # Clean up object registry after each test
    PatlangObject.clear_registry
    
    # Clear global event handlers after each test
    EventSystem.clear_global_handlers
  end
  
  def parse_and_evaluate(code)
    lexer = Lexer.new(code)
    tokens = lexer.tokenize
    parser = Parser.new(tokens)
    ast = parser.parse
    @evaluator.evaluate(ast)
  end
  
  def test_backward_compatibility_mode_disabled_by_default
    assert_equal false, @evaluator.object_mode_enabled?
    
    # Test that legacy evaluation still works
    result = parse_and_evaluate("42")
    
    assert_equal 42, result
    assert result.is_a?(Numeric)
    refute result.is_a?(PatlangObject)
  end
  
  def test_enable_object_mode
    @evaluator.enable_object_mode
    assert_equal true, @evaluator.object_mode_enabled?
    
    # Test that object evaluation works
    result = parse_and_evaluate("42")
    
    assert result.is_a?(NumberObject)
    assert_equal 42, result.value
    assert_equal :number, result.object_type
  end
  
  def test_disable_object_mode_returns_to_legacy
    @evaluator.enable_object_mode
    @evaluator.disable_object_mode
    
    assert_equal false, @evaluator.object_mode_enabled?
    
    result = parse_and_evaluate("42")
    
    assert_equal 42, result
    assert result.is_a?(Numeric)
    refute result.is_a?(PatlangObject)
  end
  
  def test_number_object_creation_with_events
    @evaluator.enable_object_mode
    
    event_fired = false
    EventSystem.subscribe(:object_created) do |event|
      event_fired = true
      assert_equal :number, event[:data][:type]
      assert_equal 42, event[:data][:value]
    end
    
    result = parse_and_evaluate("42")
    
    assert event_fired, "Object creation event should have been fired"
    assert result.is_a?(NumberObject)
    assert_equal 42, result.value
  end
  
  def test_string_object_creation_with_events
    @evaluator.enable_object_mode
    
    event_fired = false
    EventSystem.subscribe(:object_created) do |event|
      event_fired = true
      assert_equal :string, event[:data][:type]
      assert_equal "hello", event[:data][:value]
    end
    
    result = parse_and_evaluate('"hello"')
    
    assert event_fired, "Object creation event should have been fired"
    assert result.is_a?(StringObject)
    assert_equal "hello", result.value
  end
  
  def test_arithmetic_operations_with_events
    @evaluator.enable_object_mode
    
    addition_event_fired = false
    EventSystem.subscribe(:arithmetic_operation) do |event|
      if event[:data][:operation] == :add
        addition_event_fired = true
        assert_equal 10, event[:data][:left_operand]
        assert_equal 5, event[:data][:right_operand]
        assert_equal 15, event[:data][:result]
      end
    end
    
    result = parse_and_evaluate("10 + 5")
    
    assert addition_event_fired, "Arithmetic operation event should have been fired"
    assert result.is_a?(NumberObject)
    assert_equal 15, result.value
  end
  
  def test_string_concatenation_with_events
    @evaluator.enable_object_mode
    
    string_event_fired = false
    EventSystem.subscribe(:string_operation) do |event|
      if event[:data][:operation] == :concatenate
        string_event_fired = true
        assert_equal "hello", event[:data][:left_operand]
        assert_equal " world", event[:data][:right_operand]
        assert_equal "hello world", event[:data][:result]
      end
    end
    
    result = parse_and_evaluate('"hello" + " world"')
    
    assert string_event_fired, "String operation event should have been fired"
    assert result.is_a?(StringObject)
    assert_equal "hello world", result.value
  end
  
  def test_number_string_concatenation
    @evaluator.enable_object_mode
    
    result = parse_and_evaluate('42 + " items"')
    
    assert result.is_a?(StringObject)
    assert_equal "42 items", result.value
  end
  
  def test_string_repetition_with_events
    @evaluator.enable_object_mode
    
    repeat_event_fired = false
    EventSystem.subscribe(:string_operation) do |event|
      if event[:data][:operation] == :repeat
        repeat_event_fired = true
        assert_equal "hello", event[:data][:operand]
        assert_equal 3, event[:data][:times]
        assert_equal "hellohellohello", event[:data][:result]
      end
    end
    
    result = parse_and_evaluate('"hello" * 3')
    
    assert repeat_event_fired, "String repeat operation event should have been fired"
    assert result.is_a?(StringObject)
    assert_equal "hellohellohello", result.value
  end
  
  def test_comparison_operations_with_events
    @evaluator.enable_object_mode
    
    comparison_event_fired = false
    EventSystem.subscribe(:comparison_operation) do |event|
      if event[:data][:operation] == :less_than
        comparison_event_fired = true
        assert_equal 5, event[:data][:left_operand]
        assert_equal 10, event[:data][:right_operand]
        assert_equal true, event[:data][:result]
      end
    end
    
    result = parse_and_evaluate("5 < 10")
    
    assert comparison_event_fired, "Comparison operation event should have been fired"
    assert result.is_a?(PatlangObject)
    assert_equal true, result.value
    assert_equal :boolean, result.object_type
  end
  
  def test_unary_operations_with_events
    @evaluator.enable_object_mode
    
    unary_event_fired = false
    EventSystem.subscribe(:unary_operation) do |event|
      if event[:data][:operation] == :negate
        unary_event_fired = true
        assert_equal 42, event[:data][:operand]
        assert_equal -42, event[:data][:result]
      end
    end
    
    result = parse_and_evaluate("-42")
    
    assert unary_event_fired, "Unary operation event should have been fired"
    assert result.is_a?(NumberObject)
    assert_equal -42, result.value
  end
  
  def test_division_by_zero_error_with_events
    @evaluator.enable_object_mode
    
    error_event_fired = false
    EventSystem.subscribe(:arithmetic_error) do |event|
      if event[:data][:error] == :division_by_zero
        error_event_fired = true
        assert_equal :divide, event[:data][:operation]
        assert_equal 42, event[:data][:left_operand]
        assert_equal 0, event[:data][:right_operand]
      end
    end
    
    assert_raises(RuntimeError, "Division by zero") do
      parse_and_evaluate("42 / 0")
    end
    
    assert error_event_fired, "Arithmetic error event should have been fired"
  end
  
  def test_complex_expression_with_object_evaluation
    @evaluator.enable_object_mode
    
    # Test: (10 + 5) * 2 - 3
    result = parse_and_evaluate("(10 + 5) * 2 - 3")
    
    assert result.is_a?(NumberObject)
    assert_equal 27, result.value
  end
  
  def test_mixed_arithmetic_and_string_operations
    @evaluator.enable_object_mode
    
    # Test: "Result: " + (10 + 5)
    result = parse_and_evaluate('"Result: " + (10 + 5)')
    
    assert result.is_a?(StringObject)
    assert_equal "Result: 15", result.value
  end
  
  def test_object_registry_tracking
    @evaluator.enable_object_mode
    
    initial_count = PatlangObject.object_count
    
    result = parse_and_evaluate("42 + 13")
    
    # Should have created at least 3 objects: 42, 13, and the result 55
    assert PatlangObject.object_count >= initial_count + 3
    assert PatlangObject.objects_of_type(:number).length >= 3
  end
  
  def test_boolean_object_creation
    @evaluator.enable_object_mode
    
    result = parse_and_evaluate("true")
    
    assert result.is_a?(PatlangObject)
    assert_equal true, result.value
    assert_equal :boolean, result.object_type
  end
  
  def test_object_equality_comparison
    @evaluator.enable_object_mode
    
    result = parse_and_evaluate("42 == 42")
    
    assert result.is_a?(PatlangObject)
    assert_equal true, result.value
    assert_equal :boolean, result.object_type
  end
  
  def test_string_comparison_operations
    @evaluator.enable_object_mode
    
    result = parse_and_evaluate('"hello" == "hello"')
    
    assert result.is_a?(PatlangObject)
    assert_equal true, result.value
    assert_equal :boolean, result.object_type
  end
  
  def test_power_operation_with_events
    @evaluator.enable_object_mode
    
    power_event_fired = false
    EventSystem.subscribe(:arithmetic_operation) do |event|
      if event[:data][:operation] == :power
        power_event_fired = true
        assert_equal 2, event[:data][:left_operand]
        assert_equal 3, event[:data][:right_operand]
        assert_equal 8, event[:data][:result]
      end
    end
    
    # Test the object method directly since power operator may not be in parser
    num_obj = NumberObject.new(2)
    result = num_obj.power(3)
    
    assert power_event_fired, "Power operation event should have been fired"
    assert result.is_a?(NumberObject)
    assert_equal 8, result.value
  end
  
  def test_modulo_operation_with_events
    @evaluator.enable_object_mode
    
    modulo_event_fired = false
    EventSystem.subscribe(:arithmetic_operation) do |event|
      if event[:data][:operation] == :modulo
        modulo_event_fired = true
        assert_equal 10, event[:data][:left_operand]
        assert_equal 3, event[:data][:right_operand]
        assert_equal 1, event[:data][:result]
      end
    end
    
    result = parse_and_evaluate("10 % 3")
    
    assert modulo_event_fired, "Modulo operation event should have been fired"
    assert result.is_a?(NumberObject)
    assert_equal 1, result.value
  end
  
  def test_coverage_enhancement_paths
    @evaluator.enable_object_mode
    
    # Test various operator combinations to enhance coverage
    test_cases = [
      ["5 + 3", 8],
      ["10 - 4", 6],
      ["6 * 7", 42],
      ["15 / 3", 5],
      ["17 % 5", 2],
      ["2 + 3 * 4", 14],  # Test operator precedence
      ["-5 + 10", 5],     # Test unary with binary
      ["(2 + 3) * 4", 20] # Test parentheses
    ]
    
    test_cases.each do |expression, expected|
      result = parse_and_evaluate(expression)
      
      assert result.is_a?(NumberObject), "Expression '#{expression}' should return NumberObject"
      assert_equal expected, result.value, "Expression '#{expression}' should equal #{expected}"
    end
  end
  
  def test_string_operation_coverage_paths
    @evaluator.enable_object_mode
    
    # Test various string operations to enhance coverage
    string_cases = [
      ['"hello" + " world"', "hello world"],
      ['"test" * 2', "testtest"],
      ['"ABC" + "123"', "ABC123"]
    ]
    
    string_cases.each do |expression, expected|
      result = parse_and_evaluate(expression)
      
      assert result.is_a?(StringObject), "Expression '#{expression}' should return StringObject"
      assert_equal expected, result.value, "Expression '#{expression}' should equal '#{expected}'"
    end
  end
  
  def test_comparison_operation_coverage_paths
    @evaluator.enable_object_mode
    
    # Test various comparison operations to enhance coverage
    comparison_cases = [
      ["5 < 10", true],
      ["10 > 5", true],
      ["5 <= 5", true],
      ["10 >= 10", true],
      ["5 == 5", true],
      ["5 != 10", true]
    ]
    
    comparison_cases.each do |expression, expected|
      result = parse_and_evaluate(expression)
      
      assert result.is_a?(PatlangObject), "Expression '#{expression}' should return PatlangObject"
      assert_equal expected, result.value, "Expression '#{expression}' should equal #{expected}"
      assert_equal :boolean, result.object_type, "Expression '#{expression}' should return boolean type"
    end
  end
end