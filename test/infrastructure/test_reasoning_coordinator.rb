# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../helpers/test_helper'
require_relative '../../src/reasoning/reasoning_coordinator'

# Comprehensive tests for the unified reasoning coordinator
class TestReasoningCoordinator < Minitest::Test
  def setup
    @evaluator = MockEvaluator.new
    @coordinator = ReasoningCoordinator.new(@evaluator)
    @event_log = []
    
    # Subscribe to coordination events
    @coordinator.on_event(:reasoning_mode_enabled) { |e| @event_log << e }
    @coordinator.on_event(:reasoning_mode_disabled) { |e| @event_log << e }
    @coordinator.on_event(:constraint_declared) { |e| @event_log << e }
    @coordinator.on_event(:goal_created) { |e| @event_log << e }
    @coordinator.on_event(:goal_pursuit_started) { |e| @event_log << e }
    @coordinator.on_event(:inference_completed) { |e| @event_log << e }
    @coordinator.on_event(:goal_pursuit_failed) { |e| @event_log << e }
    @coordinator.on_event(:fact_asserted) { |e| @event_log << e }
    @coordinator.on_event(:rule_defined) { |e| @event_log << e }
    @coordinator.on_event(:query_executed) { |e| @event_log << e }
    @coordinator.on_event(:component_registered) { |e| @event_log << e }
    @coordinator.on_event(:type_refined) { |e| @event_log << e }
    @coordinator.on_event(:unification_completed) { |e| @event_log << e }
  end

  # === Component Registration Tests ===

  def test_register_component_succeeds
    mock_component = MockTypeSystem.new
    
    @coordinator.register_component(:type_system, mock_component)
    
    assert_equal mock_component, @coordinator.get_component(:type_system)
    assert @coordinator.has_component?(:type_system)
    assert_events_fired [:component_registered]
  end

  def test_component_registration_fires_event
    mock_component = MockGoalSystem.new
    
    @coordinator.register_component(:goal_system, mock_component)
    
    registration_event = @event_log.find { |e| e[:event_type] == :component_registered }
    assert registration_event
    assert_equal :goal_system, registration_event[:name]
    assert_equal "MockGoalSystem", registration_event[:component]
  end

  def test_get_nonexistent_component_returns_nil
    assert_nil @coordinator.get_component(:nonexistent)
    refute @coordinator.has_component?(:nonexistent)
  end

  # === Reasoning Mode Management Tests ===

  def test_reasoning_mode_initially_disabled
    refute @coordinator.reasoning_mode_enabled?
  end

  def test_enable_reasoning_mode_succeeds
    result = @coordinator.enable_reasoning_mode
    
    assert @coordinator.reasoning_mode_enabled?
    assert_equal "Reasoning mode enabled", result
    assert_events_fired [:reasoning_mode_enabled]
  end

  def test_disable_reasoning_mode_succeeds
    @coordinator.enable_reasoning_mode
    result = @coordinator.disable_reasoning_mode
    
    refute @coordinator.reasoning_mode_enabled?
    assert_equal "Reasoning mode disabled", result
    assert_events_fired [:reasoning_mode_enabled, :reasoning_mode_disabled]
  end

  def test_reasoning_mode_events_include_metadata
    @coordinator.enable_reasoning_mode
    
    enable_event = @event_log.find { |e| e[:event_type] == :reasoning_mode_enabled }
    assert enable_event
    assert_instance_of Time, enable_event[:timestamp]
    assert_equal "MockEvaluator", enable_event[:evaluator]
  end

  # === Type Constraint Integration Tests ===

  def test_create_constraint_requires_reasoning_mode
    error = assert_raises(ReasoningModeError) do
      @coordinator.create_constraint(:x, :type, :Number)
    end
    
    assert_includes error.message, "Reasoning mode must be enabled"
  end

  def test_create_constraint_succeeds_with_reasoning_mode
    @coordinator.enable_reasoning_mode
    
    constraint = @coordinator.create_constraint(:x, :type, :Number)
    
    assert_instance_of TypeConstraint, constraint
    assert_equal :x, constraint.variable
    assert_equal :type, constraint.constraint_type
    assert_equal :Number, constraint.constraint_data
    assert_events_fired [:constraint_declared]
  end

  def test_create_constraint_fires_event_with_details
    @coordinator.enable_reasoning_mode
    @coordinator.create_constraint(:score, :range, 0..100)
    
    constraint_event = @event_log.find { |e| e[:event_type] == :constraint_declared }
    assert constraint_event
    assert_equal :score, constraint_event[:variable]
    assert_equal :range, constraint_event[:constraint_type]
    assert_equal 0..100, constraint_event[:constraint_data]
    assert_instance_of TypeConstraint, constraint_event[:constraint]
  end

  def test_get_constraint_returns_constraint_or_null_object
    @coordinator.enable_reasoning_mode
    @coordinator.create_constraint(:x, :type, :Number)
    
    # Should return the actual constraint
    constraint = @coordinator.get_constraint(:x)
    assert_instance_of TypeConstraint, constraint
    assert_equal :x, constraint.variable
    
    # Should return null object for missing constraint
    null_constraint = @coordinator.get_constraint(:nonexistent)
    assert_instance_of NullTypeConstraint, null_constraint
    assert_equal :nonexistent, null_constraint.variable
  end

  def test_get_constraint_handles_symbol_string_conversion
    @coordinator.enable_reasoning_mode
    @coordinator.create_constraint(:symbol_var, :type, :String)
    
    # Should find constraint with symbol lookup
    constraint_by_symbol = @coordinator.get_constraint(:symbol_var)
    assert_instance_of TypeConstraint, constraint_by_symbol
    
    # Should also find constraint with string lookup
    constraint_by_string = @coordinator.get_constraint("symbol_var")
    assert_instance_of TypeConstraint, constraint_by_string
  end

  def test_validate_assignment_without_reasoning_mode
    # Should always return true when reasoning mode disabled
    assert @coordinator.validate_assignment(:any_var, "any_value")
  end

  def test_validate_assignment_with_valid_constraint
    @coordinator.enable_reasoning_mode
    @coordinator.create_constraint(:x, :type, :Number)
    
    assert @coordinator.validate_assignment(:x, 42)
    assert @coordinator.validate_assignment(:x, 3.14)
  end

  def test_validate_assignment_with_invalid_constraint
    @coordinator.enable_reasoning_mode
    @coordinator.create_constraint(:x, :type, :Number)
    
    error = assert_raises(TypeConstraintViolation) do
      @coordinator.validate_assignment(:x, "string")
    end
    
    assert_equal :x, error.variable
    assert_equal "string", error.value
    assert_includes error.message, "Assignment violates constraint"
  end

  # === Goal System Integration Tests ===

  def test_create_goal_requires_reasoning_mode
    error = assert_raises(ReasoningModeError) do
      @coordinator.create_goal(:test_goal)
    end
    
    assert_includes error.message, "Reasoning mode must be enabled"
  end

  def test_create_goal_succeeds_with_reasoning_mode
    @coordinator.enable_reasoning_mode
    
    goal = @coordinator.create_goal(:find_answer, 
      description: "Find the answer",
      parameters: [:x, :y],
      preconditions: ["x > 0"],
      postconditions: ["result == 42"]
    )
    
    assert_instance_of Goal, goal
    assert_equal "find_answer", goal.name
    assert_equal "Find the answer", goal.description
    assert_equal [:x, :y], goal.parameters
    assert goal.has_precondition?
    assert goal.has_postcondition?
    assert_events_fired [:goal_created]
  end

  def test_create_goal_fires_detailed_event
    @coordinator.enable_reasoning_mode
    
    @coordinator.create_goal(:detailed_goal,
      parameters: [:a, :b],
      preconditions: ["a != 0"],
      postconditions: ["result > 0"]
    )
    
    goal_event = @event_log.find { |e| e[:event_type] == :goal_created }
    assert goal_event
    assert_equal :detailed_goal, goal_event[:name]
    assert_instance_of Goal, goal_event[:goal]
    assert_equal [:a, :b], goal_event[:parameters]
    assert goal_event[:has_precondition]
    assert goal_event[:has_postcondition]
  end

  def test_pursue_goal_requires_reasoning_mode
    error = assert_raises(ReasoningModeError) do
      @coordinator.pursue_goal(:any_goal)
    end
    
    assert_includes error.message, "Reasoning mode must be enabled"
  end

  def test_pursue_goal_succeeds_with_defined_goal
    @coordinator.enable_reasoning_mode
    @coordinator.create_goal(:find_even, description: "Find even number")
    
    result = @coordinator.pursue_goal(:find_even)
    
    assert_instance_of Integer, result
    assert result.even?
    assert_events_fired [:goal_pursuit_started, :inference_completed]
  end

  def test_pursue_goal_with_string_name
    @coordinator.enable_reasoning_mode
    @coordinator.create_goal(:string_goal, description: "Goal with string lookup")
    
    # Should work with string goal name
    result = @coordinator.pursue_goal("string_goal")
    assert_instance_of Integer, result
  end

  def test_pursue_undefined_goal_raises_error
    @coordinator.enable_reasoning_mode
    
    error = assert_raises(LogicError) do
      @coordinator.pursue_goal(:undefined_goal)
    end
    
    assert_includes error.message, "Goal undefined_goal not defined"
  end

  def test_pursue_goal_tracks_inference_count
    @coordinator.enable_reasoning_mode
    @coordinator.create_goal(:counted_goal, description: "Goal for counting")
    
    initial_stats = @coordinator.statistics
    initial_inferences = initial_stats[:inferences]
    
    @coordinator.pursue_goal(:counted_goal)
    
    final_stats = @coordinator.statistics
    assert_equal initial_inferences + 1, final_stats[:inferences]
  end

  def test_pursue_goal_handles_errors_gracefully
    @coordinator.enable_reasoning_mode
    
    # Create a goal that will cause an error
    error_goal = Goal.new("error_goal")
    @coordinator.instance_variable_get(:@goals)["error_goal"] = error_goal
    
    # Mock the goal resolution to raise an error
    def error_goal.resolve(**context)
      raise StandardError, "Intentional test error"
    end
    
    error = assert_raises(StandardError) do
      @coordinator.pursue_goal("error_goal")
    end
    
    assert_equal "Intentional test error", error.message
    assert_events_include :goal_pursuit_failed
  end

  # === Logic Programming Integration Tests ===

  def test_assert_fact_requires_reasoning_mode
    error = assert_raises(ReasoningModeError) do
      @coordinator.assert_fact("likes(alice, bob)")
    end
    
    assert_includes error.message, "Reasoning mode must be enabled"
  end

  def test_assert_fact_succeeds_with_reasoning_mode
    @coordinator.enable_reasoning_mode
    
    @coordinator.assert_fact("likes(alice, bob)")
    @coordinator.assert_fact("likes(bob, alice)")
    
    facts = @coordinator.get_facts
    assert_includes facts, "likes(alice, bob)"
    assert_includes facts, "likes(bob, alice)"
    assert_equal 2, facts.length
    assert_events_fired [:fact_asserted, :fact_asserted]
  end

  def test_assert_fact_fires_event_with_details
    @coordinator.enable_reasoning_mode
    
    @coordinator.assert_fact("knows(bob, charlie)")
    
    fact_event = @event_log.find { |e| e[:event_type] == :fact_asserted }
    assert fact_event
    assert_equal "knows(bob, charlie)", fact_event[:fact]
    assert_equal 1, fact_event[:total_facts]
  end

  def test_define_rule_requires_reasoning_mode
    error = assert_raises(ReasoningModeError) do
      @coordinator.define_rule("friend(X, Y) :- likes(X, Y), likes(Y, X)")
    end
    
    assert_includes error.message, "Reasoning mode must be enabled"
  end

  def test_define_rule_succeeds_with_reasoning_mode
    @coordinator.enable_reasoning_mode
    
    @coordinator.define_rule("friend(X, Y) :- likes(X, Y), likes(Y, X)")
    @coordinator.define_rule("sibling(X, Y) :- parent(Z, X), parent(Z, Y), X != Y")
    
    rules = @coordinator.get_rules
    assert_includes rules, "friend(X, Y) :- likes(X, Y), likes(Y, X)"
    assert_includes rules, "sibling(X, Y) :- parent(Z, X), parent(Z, Y), X != Y"
    assert_equal 2, rules.length
    assert_events_fired [:rule_defined, :rule_defined]
  end

  def test_define_rule_fires_event_with_details
    @coordinator.enable_reasoning_mode
    
    @coordinator.define_rule("ancestor(X, Y) :- parent(X, Y)")
    
    rule_event = @event_log.find { |e| e[:event_type] == :rule_defined }
    assert rule_event
    assert_equal "ancestor(X, Y) :- parent(X, Y)", rule_event[:rule]
    assert_equal 1, rule_event[:total_rules]
  end

  def test_query_requires_reasoning_mode
    error = assert_raises(ReasoningModeError) do
      @coordinator.query("likes(alice, X)")
    end
    
    assert_includes error.message, "Reasoning mode must be enabled"
  end

  def test_query_resolves_against_facts
    @coordinator.enable_reasoning_mode
    @coordinator.assert_fact("likes(alice, bob)")
    @coordinator.assert_fact("likes(alice, charlie)")
    
    results = @coordinator.query("likes(alice, X)")
    
    assert_instance_of Array, results
    refute_empty results
    assert_events_fired [:query_executed]
  end

  def test_query_fires_event_with_results
    @coordinator.enable_reasoning_mode
    @coordinator.assert_fact("likes(bob, music)")
    
    results = @coordinator.query("likes(bob, X)")
    
    query_event = @event_log.find { |e| e[:event_type] == :query_executed }
    assert query_event
    assert_equal "likes(bob, X)", query_event[:query]
    assert_instance_of Array, query_event[:results]
    assert_equal results.length, query_event[:result_count]
  end

  # === Cross-Paradigm Integration Tests ===

  def test_infer_type_from_facts
    @coordinator.enable_reasoning_mode
    @coordinator.assert_fact("typeof(x, number)")
    
    inferred_type = @coordinator.infer_type_from_facts(:x)
    
    assert_equal :Number, inferred_type
    
    # Should also create a constraint
    constraint = @coordinator.get_constraint(:x)
    assert_instance_of TypeConstraint, constraint
    assert_equal :type, constraint.constraint_type
    assert_equal :Number, constraint.constraint_data
  end

  def test_infer_type_from_facts_returns_nil_for_unknown_variable
    @coordinator.enable_reasoning_mode
    
    inferred_type = @coordinator.infer_type_from_facts(:unknown_var)
    
    assert_nil inferred_type
  end

  def test_propagate_constraint_to_logic
    @coordinator.enable_reasoning_mode
    constraint = @coordinator.create_constraint(:y, :type, :String)
    
    @coordinator.propagate_constraint_to_logic(:y, constraint)
    
    facts = @coordinator.get_facts
    assert_includes facts, "typeof(y, String)"
  end

  def test_propagate_range_constraint_to_logic
    @coordinator.enable_reasoning_mode
    constraint = @coordinator.create_constraint(:age, :range, 18..65)
    
    @coordinator.propagate_constraint_to_logic(:age, constraint)
    
    facts = @coordinator.get_facts
    assert_includes facts, "range(age, 18, 65)"
  end

  def test_goal_resolution_with_constraints
    @coordinator.enable_reasoning_mode
    @coordinator.create_constraint(:x, :type, :Number)
    @coordinator.create_goal(:find_valid_x, description: "Find valid x")
    
    result = @coordinator.pursue_goal(:find_valid_x)
    
    assert_instance_of Integer, result
    # The result should satisfy the constraint
    assert @coordinator.instance_variable_get(:@constraint_system).variable_satisfies?(:x, result)
  end

  # === Statistics and State Management Tests ===

  def test_statistics_provides_comprehensive_overview
    @coordinator.enable_reasoning_mode
    @coordinator.create_constraint(:stat_var, :type, :Number)
    @coordinator.create_goal(:stat_goal, description: "Statistics goal")
    @coordinator.assert_fact("test_fact")
    @coordinator.define_rule("test_rule")
    @coordinator.pursue_goal(:stat_goal)
    
    stats = @coordinator.statistics
    
    assert_instance_of Hash, stats
    assert stats[:reasoning_mode]
    assert_operator stats[:constraints], :>=, 1
    assert_operator stats[:goals], :>=, 1
    assert_operator stats[:facts], :>=, 1
    assert_operator stats[:rules], :>=, 1
    assert_operator stats[:inferences], :>=, 1
    assert_instance_of Hash, stats[:unification_stats]
  end

  def test_reset_clears_all_state
    @coordinator.enable_reasoning_mode
    @coordinator.create_constraint(:temp_var, :type, :Number)
    @coordinator.create_goal(:temp_goal, description: "Temporary goal")
    @coordinator.assert_fact("temp_fact")
    @coordinator.define_rule("temp_rule")
    @coordinator.pursue_goal(:temp_goal)
    
    @coordinator.reset!
    
    stats = @coordinator.statistics
    assert_equal 0, stats[:constraints]
    assert_equal 0, stats[:goals]
    assert_equal 0, stats[:facts]
    assert_equal 0, stats[:rules]
    assert_equal 0, stats[:inferences]
  end

  def test_reset_maintains_component_registrations
    mock_component = MockTypeSystem.new
    @coordinator.register_component(:persistent_component, mock_component)
    
    @coordinator.reset!
    
    assert_equal mock_component, @coordinator.get_component(:persistent_component)
  end

  # === Event System Integration Tests ===

  def test_cross_system_event_forwarding
    @coordinator.enable_reasoning_mode
    
    # Create constraint to trigger type system events
    @coordinator.create_constraint(:event_var, :type, :Number)
    @coordinator.instance_variable_get(:@constraint_system).set_variable_value(:event_var, 42)
    
    # Should have forwarded type_refined events
    assert_events_include :type_refined
  end

  def test_unification_event_forwarding
    @coordinator.enable_reasoning_mode
    
    # Trigger unification
    unification_engine = @coordinator.unification_engine
    unification_engine.unify(:a, :a, {})
    
    # Should have forwarded unification events
    assert_events_include :unification_completed
  end

  # === Performance Tests ===

  def test_reasoning_coordinator_initialization_performance
    start_time = Time.now
    
    10.times do
      coordinator = ReasoningCoordinator.new(@evaluator)
      coordinator.enable_reasoning_mode
    end
    
    duration = Time.now - start_time
    assert_operator duration, :<, 0.1, "10 coordinator initializations should complete in <100ms"
  end

  def test_constraint_creation_performance
    @coordinator.enable_reasoning_mode
    
    start_time = Time.now
    
    100.times do |i|
      @coordinator.create_constraint("perf_var_#{i}".to_sym, :type, :Number)
    end
    
    duration = Time.now - start_time
    assert_operator duration, :<, 0.2, "100 constraint creations should complete in <200ms"
  end

  def test_fact_assertion_performance
    @coordinator.enable_reasoning_mode
    
    start_time = Time.now
    
    200.times do |i|
      @coordinator.assert_fact("perf_fact_#{i}(test)")
    end
    
    duration = Time.now - start_time
    assert_operator duration, :<, 0.1, "200 fact assertions should complete in <100ms"
  end

  def test_integrated_reasoning_performance
    @coordinator.enable_reasoning_mode
    
    start_time = Time.now
    
    # Perform integrated reasoning operations
    20.times do |i|
      @coordinator.create_constraint("var_#{i}".to_sym, :type, :Number)
      @coordinator.create_goal("goal_#{i}".to_sym, description: "Performance goal #{i}")
      @coordinator.assert_fact("fact_#{i}(test)")
      @coordinator.pursue_goal("goal_#{i}".to_sym)
    end
    
    duration = Time.now - start_time
    assert_operator duration, :<, 1.0, "20 integrated reasoning cycles should complete in <1s"
  end

  # === Error Handling Tests ===

  def test_reasoning_mode_error_has_descriptive_message
    error = assert_raises(ReasoningModeError) do
      @coordinator.create_constraint(:test, :type, :String)
    end
    
    assert_instance_of ReasoningModeError, error
    assert_includes error.message, "Reasoning mode must be enabled"
  end

  def test_logic_error_for_undefined_goals
    @coordinator.enable_reasoning_mode
    
    error = assert_raises(LogicError) do
      @coordinator.pursue_goal(:nonexistent_goal)
    end
    
    assert_instance_of LogicError, error
    assert_includes error.message, "not defined"
  end

  def test_constraint_conflict_handling
    @coordinator.enable_reasoning_mode
    @coordinator.create_constraint(:conflict_var, :type, :Number)
    
    # This should raise a ConstraintConflictError
    error = assert_raises(ConstraintConflictError) do
      @coordinator.create_constraint(:conflict_var, :type, :String)
    end
    
    assert_instance_of ConstraintConflictError, error
    assert_equal :conflict_var, error.variable
  end

  private

  def assert_events_fired(expected_event_types)
    actual_event_types = @event_log.map { |e| e[:event_type] }
    expected_event_types.each do |expected_type|
      assert_includes actual_event_types, expected_type,
                     "Expected event #{expected_type} to be fired"
    end
  end

  def assert_events_include(event_type)
    event_types = @event_log.map { |e| e[:event_type] }
    assert_includes event_types, event_type,
                   "Expected events to include #{event_type}"
  end

  # Mock classes for testing
  class MockEvaluator
    def object_mode_enabled?
      false
    end
  end

  class MockTypeSystem
    def initialize
      @constraints = {}
    end
  end

  class MockGoalSystem
    def initialize
      @goals = {}
    end
  end
end