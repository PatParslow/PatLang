#!/usr/bin/env ruby
# frozen_string_literal: true

require 'test/unit'
require_relative '../patlang-core/evaluator/evaluator'
require_relative '../patlang-core/ast/ast_nodes'

# Comprehensive test suite for Phase 1 Goal System Integration
class GoalIntegrationTest < Test::Unit::TestCase
  def setup
    @evaluator = Evaluator.new
    @evaluator.enable_reasoning_mode
  end

  def test_goal_integration_initialization
    # Test that goal integration is properly initialized
    assert_respond_to @evaluator, :goal_integration_enabled?
    assert_respond_to @evaluator, :goal_integration_stats
    
    # Initially not enabled until first use
    refute @evaluator.goal_integration_enabled?
  end

  def test_goal_declaration_integration
    # Create a mock goal node
    goal_node = create_mock_goal_node(
      description: "find_even_number",
      preconditions: ["input > 0"],
      postconditions: ["result.even?", "result > 10"],
      strategies: ["systematic_search"]
    )
    
    # Test goal declaration through AST
    result = @evaluator.visit_goal_node(goal_node)
    
    assert_not_nil result
    assert @evaluator.goal_integration_enabled?
    
    # Check integration stats
    stats = @evaluator.goal_integration_stats
    assert_equal 1, stats[:goals_declared]
    assert_equal 'active', stats[:components][:goal_system]
  end

  def test_goal_pursuit_integration
    # Declare a goal first
    goal_node = create_mock_goal_node(description: "find_even")
    @evaluator.visit_goal_node(goal_node)
    
    # Create pursue node
    pursue_node = create_mock_pursue_node("find_even")
    
    # Test goal pursuit
    result = @evaluator.visit_pursue_node(pursue_node)
    
    assert_not_nil result
    assert result.is_a?(Integer), "Expected numeric result for find_even goal"
    assert result.even?, "Result should be even"
    assert result > 10, "Result should be greater than 10"
    
    # Check stats updated
    stats = @evaluator.goal_integration_stats
    assert_equal 1, stats[:goals_pursued]
  end

  def test_fact_assertion_integration
    # Create assert node
    assert_node = create_mock_assert_node("user(alice)")
    
    # Test fact assertion
    result = @evaluator.visit_assert_node(assert_node)
    
    assert_equal "user(alice)", result
    assert @evaluator.goal_integration_enabled?
    
    # Verify facts database is active
    stats = @evaluator.goal_integration_stats
    assert_equal 'active', stats[:components][:facts_database]
  end

  def test_query_execution_integration
    # Assert some facts first
    @evaluator.visit_assert_node(create_mock_assert_node("user(alice)"))
    @evaluator.visit_assert_node(create_mock_assert_node("user(bob)"))
    
    # Create query node
    query_node = create_mock_query_node("user(X)")
    
    # Test query execution
    results = @evaluator.visit_query_node(query_node)
    
    assert_not_nil results
    assert results.is_a?(Array), "Query should return array of results"
  end

  def test_direct_goal_system_access
    # Test direct access methods
    goal = @evaluator.declare_goal("test_goal", {
      preconditions: ["x > 0"],
      postconditions: ["result > x"]
    })
    
    assert_not_nil goal
    assert_equal "test_goal", goal.name
    
    # Test goal pursuit
    result = @evaluator.pursue_goal("test_goal", x: 5)
    assert_not_nil result
  end

  def test_facts_database_integration
    # Test fact assertion
    fact_result = @evaluator.assert_fact("parent(john, mary)")
    assert_equal "parent(john, mary)", fact_result
    
    # Test query
    query_results = @evaluator.query_facts("parent(john, X)")
    assert_not_nil query_results
    assert query_results.is_a?(Array)
  end

  def test_cross_system_communication
    # Test that goals can trigger events that affect facts
    goal_node = create_mock_goal_node(
      description: "record_achievement", 
      postconditions: ["achievement_recorded == true"]
    )
    
    # Declare and pursue goal
    @evaluator.visit_goal_node(goal_node)
    result = @evaluator.visit_pursue_node(create_mock_pursue_node("record_achievement"))
    
    assert_not_nil result
    
    # Verify integration stats show activity
    stats = @evaluator.goal_integration_stats
    assert stats[:goals_declared] >= 1
    assert stats[:goals_pursued] >= 1
  end

  def test_build_tool_compatibility
    # Test that existing build tool functionality still works
    # This ensures backward compatibility
    
    # Create a goal similar to what build tool uses
    build_goal_node = create_mock_goal_node(
      description: "compile_project",
      preconditions: ["source_files.exist?"],
      postconditions: ["output_files.exist?", "compilation.success?"],
      strategies: ["incremental_build", "full_rebuild"]
    )
    
    result = @evaluator.visit_goal_node(build_goal_node)
    assert_not_nil result
    
    # Pursue the build goal
    pursue_result = @evaluator.visit_pursue_node(create_mock_pursue_node("compile_project"))
    assert_not_nil pursue_result
  end

  def test_performance_monitoring
    # Perform several operations to test performance tracking
    5.times do |i|
      goal_node = create_mock_goal_node(description: "test_goal_#{i}")
      @evaluator.visit_goal_node(goal_node)
      @evaluator.visit_pursue_node(create_mock_pursue_node("test_goal_#{i}"))
    end
    
    stats = @evaluator.goal_integration_stats
    assert_equal 5, stats[:goals_declared]
    assert_equal 5, stats[:goals_pursued]
    assert stats[:runtime_seconds] > 0
    assert stats[:success_rate] >= 0
  end

  def test_error_handling_and_fallbacks
    # Test pursuit of non-existent goal
    pursue_node = create_mock_pursue_node("non_existent_goal")
    
    # Should not raise error but return fallback result
    result = @evaluator.visit_pursue_node(pursue_node)
    assert_not_nil result
    assert_equal "non_existent_goal_resolved", result
  end

  def test_reasoning_mode_requirement
    # Test with reasoning mode disabled
    @evaluator.disable_reasoning_mode
    
    goal_node = create_mock_goal_node(description: "test_goal")
    
    # Should still work because goal integration manages its own reasoning
    result = @evaluator.visit_goal_node(goal_node)
    assert_not_nil result
  end

  private

  def create_mock_goal_node(description:, preconditions: [], postconditions: [], strategies: [], parameters: [])
    OpenStruct.new(
      description: description,
      preconditions: preconditions,
      postconditions: postconditions,
      strategies: strategies,
      parameters: parameters
    )
  end

  def create_mock_pursue_node(goal_name, context: {}, parameters: [])
    OpenStruct.new(
      goal_name: goal_name,
      context: context,
      parameters: parameters
    )
  end

  def create_mock_assert_node(fact)
    OpenStruct.new(
      fact: fact
    )
  end

  def create_mock_query_node(goal_term, variables: [])
    OpenStruct.new(
      goal_term: goal_term,
      variables: variables
    )
  end
end

# Integration validation test
class GoalIntegrationValidationTest < Test::Unit::TestCase
  def setup
    @evaluator = Evaluator.new
    @evaluator.enable_reasoning_mode
  end

  def test_complete_goal_lifecycle
    puts "\n=== Testing Complete Goal Lifecycle ==="
    
    # 1. Declare goal
    goal_node = OpenStruct.new(
      description: "find_optimal_value",
      preconditions: ["range.valid?"],
      postconditions: ["result.optimal?", "result.in_range?"],
      strategies: ["binary_search", "gradient_descent"]
    )
    
    declared_goal = @evaluator.declare_goal(goal_node.description, {
      preconditions: goal_node.preconditions,
      postconditions: goal_node.postconditions,
      strategies: goal_node.strategies
    })
    puts "✓ Goal declared: #{declared_goal.inspect}"
    
    # 2. Pursue goal
    pursue_node = OpenStruct.new(
      goal_name: "find_optimal_value",
      context: { range: (1..100), target: 42 }
    )
    
    result = @evaluator.pursue_goal(pursue_node.goal_name, pursue_node.context)
    puts "✓ Goal pursued with result: #{result}"
    
    # 3. Assert facts about the result
    fact_node = OpenStruct.new(fact: "optimal_value(#{result})")
    @evaluator.assert_fact(fact_node.fact)
    puts "✓ Fact asserted: optimal_value(#{result})"
    
    # 4. Query the facts
    query_node = OpenStruct.new(goal_term: "optimal_value(X)")
    query_results = @evaluator.query_facts(query_node.goal_term)
    puts "✓ Query executed with results: #{query_results.inspect}"
    
    # 5. Check integration stats
    stats = @evaluator.goal_integration_stats
    puts "✓ Integration Stats: #{stats.inspect}"
    
    assert stats[:goals_declared] >= 1
    assert stats[:goals_pursued] >= 1
    assert stats[:success_rate] > 0
    
    puts "=== Goal Integration Test PASSED ==="
  end
end

if __FILE__ == $0
  puts "Running Goal Integration Tests..."
  puts "=" * 50
  
  # Run individual test methods if needed
  test = GoalIntegrationValidationTest.new(:test_complete_goal_lifecycle)
  test.setup
  test.test_complete_goal_lifecycle
  
  puts "\nRunning full test suite..."
  # This will run all tests
end