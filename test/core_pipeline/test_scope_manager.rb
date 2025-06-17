# frozen_string_literal: true

require_relative '../helpers/test_helper'

class TestScopeManager < Minitest::Test
  def setup
    @scope_manager = EvaluatorModules::ScopeManager.new
  end

  # Test basic scope operations
  def test_scope_manager_initialization
    assert_not_nil @scope_manager.variables
    assert_not_nil @scope_manager.scope_stack
    assert_equal({}, @scope_manager.variables)
    assert_equal([], @scope_manager.scope_stack)
  end

  def test_push_and_pop_scope
    # Set a variable in current scope
    @scope_manager.set_variable("x", 42)
    assert_equal 42, @scope_manager.get_variable("x")
    
    # Push new scope
    @scope_manager.push_scope
    assert_equal 1, @scope_manager.scope_stack.length
    
    # Variable should still be accessible
    assert_equal 42, @scope_manager.get_variable("x")
    
    # Set variable in new scope
    @scope_manager.set_variable("y", 24)
    assert_equal 24, @scope_manager.get_variable("y")
    assert_equal 42, @scope_manager.get_variable("x")
    
    # Pop scope
    @scope_manager.pop_scope
    assert_equal 0, @scope_manager.scope_stack.length
    
    # Should have original scope back
    assert_equal 42, @scope_manager.get_variable("x")
    
    # Variable from inner scope should be gone
    assert_raises(RuntimeError) do
      @scope_manager.get_variable("y")
    end
  end

  def test_pop_scope_when_empty
    # Should raise error when trying to pop empty scope stack
    error = assert_raises(RuntimeError) do
      @scope_manager.pop_scope
    end
    
    assert_includes error.message, "scope stack is empty"
  end

  # Test variable setting and getting
  def test_set_and_get_variable_basic
    @scope_manager.set_variable("test_var", "test_value")
    assert_equal "test_value", @scope_manager.get_variable("test_var")
    
    @scope_manager.set_variable("number", 123)
    assert_equal 123, @scope_manager.get_variable("number")
    
    @scope_manager.set_variable("boolean", true)
    assert_equal true, @scope_manager.get_variable("boolean")
  end

  def test_set_variable_with_nil_name
    # Should handle nil name gracefully
    assert_nothing_raised do
      @scope_manager.set_variable(nil, "value")
    end
    
    # Should not create a variable
    assert_raises(RuntimeError) do
      @scope_manager.get_variable(nil)
    end
  end

  def test_set_variable_with_empty_name
    # Should handle empty name gracefully
    assert_nothing_raised do
      @scope_manager.set_variable("", "value")
      @scope_manager.set_variable("   ", "value")
    end
    
    # Should not create variables for empty names
    assert_raises(RuntimeError) do
      @scope_manager.get_variable("")
    end
  end

  def test_get_variable_with_nil_name
    # Should return nil for nil name
    assert_nil @scope_manager.get_variable(nil)
  end

  def test_get_variable_with_empty_name
    # Should return nil for empty names
    assert_nil @scope_manager.get_variable("")
    assert_nil @scope_manager.get_variable("   ")
    assert_nil @scope_manager.get_variable(",")
  end

  def test_get_variable_with_punctuation
    # Should return nil for single character punctuation
    assert_nil @scope_manager.get_variable("!")
    assert_nil @scope_manager.get_variable("@")
    assert_nil @scope_manager.get_variable("#")
    assert_nil @scope_manager.get_variable("$")
    
    # But should work for valid variable names
    @scope_manager.set_variable("_valid", "value")
    assert_equal "value", @scope_manager.get_variable("_valid")
  end

  def test_variable_name_conversion
    # Should handle symbol and string conversion consistently
    @scope_manager.set_variable(:symbol_var, "symbol_value")
    assert_equal "symbol_value", @scope_manager.get_variable("symbol_var")
    assert_equal "symbol_value", @scope_manager.get_variable(:symbol_var)
    
    @scope_manager.set_variable("string_var", "string_value")
    assert_equal "string_value", @scope_manager.get_variable("string_var")
    assert_equal "string_value", @scope_manager.get_variable(:string_var)
  end

  def test_undefined_variable_error
    # Should raise error for undefined variables
    error = assert_raises(RuntimeError) do
      @scope_manager.get_variable("undefined_variable")
    end
    
    assert_includes error.message, "Undefined variable: undefined_variable"
  end

  # Test scope hierarchy and variable resolution
  def test_variable_resolution_hierarchy
    # Set variable in outer scope
    @scope_manager.set_variable("outer", "outer_value")
    
    # Push inner scope
    @scope_manager.push_scope
    
    # Should access outer variable
    assert_equal "outer_value", @scope_manager.get_variable("outer")
    
    # Set variable in inner scope
    @scope_manager.set_variable("inner", "inner_value")
    assert_equal "inner_value", @scope_manager.get_variable("inner")
    
    # Override outer variable in inner scope
    @scope_manager.set_variable("outer", "inner_override")
    assert_equal "inner_override", @scope_manager.get_variable("outer")
    
    # Pop back to outer scope
    @scope_manager.pop_scope
    
    # Should have original outer value back
    assert_equal "outer_value", @scope_manager.get_variable("outer")
    
    # Inner variable should be gone
    assert_raises(RuntimeError) do
      @scope_manager.get_variable("inner")
    end
  end

  def test_multiple_scope_levels
    # Create multiple scope levels
    @scope_manager.set_variable("level0", "value0")
    
    @scope_manager.push_scope
    @scope_manager.set_variable("level1", "value1")
    
    @scope_manager.push_scope
    @scope_manager.set_variable("level2", "value2")
    
    @scope_manager.push_scope
    @scope_manager.set_variable("level3", "value3")
    
    # Should access variables from all levels
    assert_equal "value0", @scope_manager.get_variable("level0")
    assert_equal "value1", @scope_manager.get_variable("level1")
    assert_equal "value2", @scope_manager.get_variable("level2")
    assert_equal "value3", @scope_manager.get_variable("level3")
    
    # Pop one level
    @scope_manager.pop_scope
    assert_raises(RuntimeError) { @scope_manager.get_variable("level3") }
    assert_equal "value2", @scope_manager.get_variable("level2")
    assert_equal "value1", @scope_manager.get_variable("level1")
    assert_equal "value0", @scope_manager.get_variable("level0")
    
    # Pop another level
    @scope_manager.pop_scope
    assert_raises(RuntimeError) { @scope_manager.get_variable("level2") }
    assert_equal "value1", @scope_manager.get_variable("level1")
    assert_equal "value0", @scope_manager.get_variable("level0")
  end

  # Test goal variable functionality
  def test_goal_variable_detection
    # Test various goal variable patterns
    assert @scope_manager.goal_variable?("complex_search")
    assert @scope_manager.goal_variable?("discover_relationships")
    assert @scope_manager.goal_variable?("find_even")
    assert @scope_manager.goal_variable?("find_valid_x")
    assert @scope_manager.goal_variable?("solve_equation")
    assert @scope_manager.goal_variable?("optimize")
    assert @scope_manager.goal_variable?("find_answer")
    
    # Test pattern-based detection
    assert @scope_manager.goal_variable?("custom_goal")
    assert @scope_manager.goal_variable?("data_search")
    assert @scope_manager.goal_variable?("find_relationships")
    
    # Test non-goal variables
    assert_not @scope_manager.goal_variable?("regular_variable")
    assert_not @scope_manager.goal_variable?("x")
    assert_not @scope_manager.goal_variable?("count")
  end

  def test_goal_variable_registration
    # Test automatic registration of goal variables
    assert_equal :complex_search_goal, @scope_manager.get_variable("complex_search")
    assert_equal :discover_relationships_goal, @scope_manager.get_variable("discover_relationships")
    assert_equal :find_even_goal, @scope_manager.get_variable("find_even")
    assert_equal :find_valid_x_goal, @scope_manager.get_variable("find_valid_x")
    assert_equal :solve_equation_goal, @scope_manager.get_variable("solve_equation")
    assert_equal :optimize_goal, @scope_manager.get_variable("optimize")
    assert_equal :find_answer_goal, @scope_manager.get_variable("find_answer")
  end

  def test_custom_goal_variable_registration
    # Test custom goal variables get registered with pattern
    custom_goal = @scope_manager.get_variable("custom_goal")
    assert_equal :custom_goal_goal, custom_goal
    
    search_goal = @scope_manager.get_variable("data_search")
    assert_equal :data_search_goal, search_goal
    
    relationships_goal = @scope_manager.get_variable("find_relationships")
    assert_equal :find_relationships_goal, relationships_goal
  end

  def test_goal_variable_registration_in_scopes
    # Test goal variable registration works in nested scopes
    @scope_manager.push_scope
    
    goal_value = @scope_manager.get_variable("complex_search")
    assert_equal :complex_search_goal, goal_value
    
    @scope_manager.pop_scope
    
    # Should still be available in outer scope after registration
    assert_equal :complex_search_goal, @scope_manager.get_variable("complex_search")
  end

  # Test performance and memory characteristics
  def test_scope_manager_performance_with_many_variables
    # Test performance with many variables
    start_time = Time.now
    
    1000.times do |i|
      @scope_manager.set_variable("var#{i}", "value#{i}")
    end
    
    1000.times do |i|
      value = @scope_manager.get_variable("var#{i}")
      assert_equal "value#{i}", value
    end
    
    elapsed = Time.now - start_time
    assert_operator elapsed, :<, 1.0, "Scope manager should be fast with many variables"
  end

  def test_scope_manager_memory_efficiency
    # Test memory efficiency with many scopes
    original_var_count = @scope_manager.variables.length
    
    # Create many nested scopes
    50.times do |i|
      @scope_manager.push_scope
      @scope_manager.set_variable("scope#{i}", "value#{i}")
    end
    
    assert_equal 50, @scope_manager.scope_stack.length
    
    # Pop all scopes
    50.times do
      @scope_manager.pop_scope
    end
    
    assert_equal 0, @scope_manager.scope_stack.length
    assert_equal original_var_count, @scope_manager.variables.length
  end

  def test_scope_manager_deep_nesting
    # Test very deep nesting doesn't cause issues
    depth = 100
    
    # Create deep nesting
    depth.times do |i|
      @scope_manager.push_scope
      @scope_manager.set_variable("depth#{i}", i)
    end
    
    # Should still access all variables
    depth.times do |i|
      assert_equal i, @scope_manager.get_variable("depth#{i}")
    end
    
    # Pop all scopes
    depth.times do
      @scope_manager.pop_scope
    end
    
    assert_equal 0, @scope_manager.scope_stack.length
  end

  # Test edge cases and error conditions
  def test_variable_override_behavior
    # Test variable override behavior in same scope
    @scope_manager.set_variable("override_test", "original")
    assert_equal "original", @scope_manager.get_variable("override_test")
    
    @scope_manager.set_variable("override_test", "updated")
    assert_equal "updated", @scope_manager.get_variable("override_test")
  end

  def test_scope_isolation
    # Test that scope changes are properly isolated
    @scope_manager.set_variable("isolation_test", "outer")
    
    @scope_manager.push_scope
    @scope_manager.set_variable("isolation_test", "inner")
    
    # Inner scope should have inner value
    assert_equal "inner", @scope_manager.get_variable("isolation_test")
    
    @scope_manager.pop_scope
    
    # Outer scope should have original value
    assert_equal "outer", @scope_manager.get_variable("isolation_test")
  end

  def test_complex_variable_names
    # Test various complex but valid variable names
    complex_names = [
      "var_with_underscores",
      "VarWithCamelCase",
      "var123",
      "_leading_underscore",
      "trailing_underscore_",
      "multiple___underscores"
    ]
    
    complex_names.each do |name|
      @scope_manager.set_variable(name, "value_for_#{name}")
      assert_equal "value_for_#{name}", @scope_manager.get_variable(name)
    end
  end

  def test_variable_value_types
    # Test various value types
    test_values = [
      ["string", "string_value"],
      ["integer", 42],
      ["float", 3.14],
      ["boolean_true", true],
      ["boolean_false", false],
      ["nil_value", nil],
      ["array", [1, 2, 3]],
      ["hash", { key: "value" }],
      ["symbol", :symbol_value]
    ]
    
    test_values.each do |name, value|
      @scope_manager.set_variable(name, value)
      assert_equal value, @scope_manager.get_variable(name)
    end
  end

  def test_scope_stack_integrity
    # Test that scope stack maintains integrity under various operations
    original_stack_size = @scope_manager.scope_stack.length
    
    # Perform various operations
    @scope_manager.set_variable("test1", "value1")
    assert_equal original_stack_size, @scope_manager.scope_stack.length
    
    @scope_manager.push_scope
    assert_equal original_stack_size + 1, @scope_manager.scope_stack.length
    
    @scope_manager.set_variable("test2", "value2")
    assert_equal original_stack_size + 1, @scope_manager.scope_stack.length
    
    @scope_manager.pop_scope
    assert_equal original_stack_size, @scope_manager.scope_stack.length
  end

  def test_concurrent_access_safety
    # Test thread safety simulation (basic test)
    results = []
    
    # Simulate concurrent variable setting
    threads = []
    10.times do |i|
      threads << Thread.new do
        @scope_manager.set_variable("thread_var_#{i}", "thread_value_#{i}")
        results << @scope_manager.get_variable("thread_var_#{i}")
      end
    end
    
    threads.each(&:join)
    
    # All results should be correct (note: basic test, not comprehensive thread safety)
    assert_equal 10, results.length
    results.each_with_index do |result, i|
      assert_equal "thread_value_#{i}", result
    end
  end

  def test_scope_manager_state_consistency
    # Test that scope manager maintains consistent state
    initial_state = {
      variables: @scope_manager.variables.dup,
      scope_stack_size: @scope_manager.scope_stack.length
    }
    
    # Perform operations that should return to initial state
    @scope_manager.push_scope
    @scope_manager.set_variable("temp", "temp_value")
    @scope_manager.push_scope
    @scope_manager.set_variable("temp2", "temp_value2")
    @scope_manager.pop_scope
    @scope_manager.pop_scope
    
    # Should be back to initial state
    assert_equal initial_state[:variables], @scope_manager.variables
    assert_equal initial_state[:scope_stack_size], @scope_manager.scope_stack.length
  end
end