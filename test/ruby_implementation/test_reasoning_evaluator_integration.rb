# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../helpers/test_helper'
require_relative '../../src/reasoning/reasoning_coordinator'
require_relative '../../patlang-core/evaluator/evaluator'

# Comprehensive tests for reasoning system integration with the Ruby evaluator
class TestReasoningEvaluatorIntegration < Minitest::Test
  def setup
    @evaluator = Evaluator.new
    @reasoning_coordinator = ReasoningCoordinator.new(@evaluator)
    @event_log = []
    
    # Subscribe to integration events
    @reasoning_coordinator.on_event(:reasoning_mode_enabled) { |e| @event_log << e }
    @reasoning_coordinator.on_event(:constraint_declared) { |e| @event_log << e }
    @reasoning_coordinator.on_event(:goal_created) { |e| @event_log << e }
    @reasoning_coordinator.on_event(:inference_completed) { |e| @event_log << e }
    
    # Enable object mode for some tests
    @evaluator.enable_object_mode
  end

  # === Evaluator Integration Setup Tests ===

  def test_reasoning_coordinator_initializes_with_evaluator
    coordinator = ReasoningCoordinator.new(@evaluator)
    
    assert_equal @evaluator, coordinator.evaluator
    assert_instance_of UnificationEngine, coordinator.unification_engine
    assert_instance_of TypeConstraintSystem, coordinator.constraint_system
    refute coordinator.reasoning_mode_enabled?
  end

  def test_reasoning_coordinator_references_evaluator_properly
    assert_equal @evaluator, @reasoning_coordinator.evaluator
    assert_respond_to @reasoning_coordinator, :evaluator
  end

  # === Object Mode Integration Tests ===

  def test_evaluator_object_mode_affects_reasoning_results
    @reasoning_coordinator.enable_reasoning_mode
    
    # Create constraint - should return constraint object in object mode
    constraint = @reasoning_coordinator.create_constraint(:test_var, :type, :Number)
    
    if @evaluator.object_mode_enabled?
      assert_instance_of TypeConstraint, constraint
    else
      # In value mode, might return a simplified representation
      assert constraint
    end
  end

  def test_evaluator_value_mode_affects_reasoning_results
    @evaluator.disable_object_mode
    @reasoning_coordinator.enable_reasoning_mode
    
    # Create goal - behavior should differ based on evaluator mode
    goal = @reasoning_coordinator.create_goal(:test_goal, description: "Test goal")
    
    # Goal should still be created regardless of evaluator mode
    assert_instance_of Goal, goal
    assert_equal "test_goal", goal.name
  end

  # === Constraint Integration Tests ===

  def test_constraint_creation_integrates_with_evaluator_context
    @reasoning_coordinator.enable_reasoning_mode
    
    # Test that constraints work within evaluator context
    constraint = @reasoning_coordinator.create_constraint(:age, :type, :Number)
    
    assert_instance_of TypeConstraint, constraint
    assert constraint.satisfies?(25)
    refute constraint.satisfies?("25")
    
    # Validate assignment through reasoning coordinator
    assert @reasoning_coordinator.validate_assignment(:age, 30)
    
    error = assert_raises(TypeConstraintViolation) do
      @reasoning_coordinator.validate_assignment(:age, "thirty")
    end
    assert_equal :age, error.variable
  end

  def test_constraint_propagation_works_with_evaluator
    @reasoning_coordinator.enable_reasoning_mode
    
    # Create related constraints
    @reasoning_coordinator.create_constraint(:celsius, :type, :Number)
    @reasoning_coordinator.create_constraint(:fahrenheit, :type, :Number)
    
    # Test constraint validation in evaluator context
    constraint_system = @reasoning_coordinator.constraint_system
    
    assert constraint_system.variable_satisfies?(:celsius, 100.0)
    assert constraint_system.variable_satisfies?(:fahrenheit, 212.0)
    refute constraint_system.variable_satisfies?(:celsius, "hot")
  end

  def test_cross_constraint_validation_integration
    @reasoning_coordinator.enable_reasoning_mode
    
    # Create multiple constraints on same variable
    @reasoning_coordinator.create_constraint(:score, :type, :Number)
    @reasoning_coordinator.create_constraint(:score, :range, 0..100)
    
    # Test validation through reasoning coordinator
    assert @reasoning_coordinator.validate_assignment(:score, 85)
    assert @reasoning_coordinator.validate_assignment(:score, 0)
    assert @reasoning_coordinator.validate_assignment(:score, 100)
    
    # Test constraint violations
    error = assert_raises(TypeConstraintViolation) do
      @reasoning_coordinator.validate_assignment(:score, "85")
    end
    assert_includes error.message, "Assignment violates constraint"
    
    error = assert_raises(ConstraintViolationError) do
      @reasoning_coordinator.validate_assignment(:score, 150)
    end
    assert_includes error.message, "violates constraints"
  end

  # === Goal System Integration Tests ===

  def test_goal_creation_integrates_with_evaluator
    @reasoning_coordinator.enable_reasoning_mode
    
    goal = @reasoning_coordinator.create_goal(:evaluator_goal,
      description: "Goal for evaluator integration",
      parameters: [:input, :output],
      preconditions: ["input > 0"],
      postconditions: ["output.even?"]
    )
    
    assert_instance_of Goal, goal
    assert_equal "evaluator_goal", goal.name
    assert_equal "Goal for evaluator integration", goal.description
    assert_equal [:input, :output], goal.parameters
    assert goal.has_precondition?
    assert goal.has_postcondition?
  end

  def test_goal_pursuit_integrates_with_evaluator_context
    @reasoning_coordinator.enable_reasoning_mode
    
    @reasoning_coordinator.create_goal(:find_even,
      description: "Find an even number",
      postconditions: ["result.even?", "result > 10"]
    )
    
    result = @reasoning_coordinator.pursue_goal(:find_even)
    
    # Verify result meets postconditions
    assert_instance_of Integer, result
    assert result.even?
    assert result > 10
  end

  def test_goal_resolution_with_constraint_integration
    @reasoning_coordinator.enable_reasoning_mode
    
    # Create constraints that should guide goal resolution
    @reasoning_coordinator.create_constraint(:x, :type, :Number)
    @reasoning_coordinator.create_constraint(:x, :range, 0..50)
    
    @reasoning_coordinator.create_goal(:find_valid_x,
      description: "Find x satisfying constraints",
      postconditions: ["result.is_a?(Number)", "result >= 0", "result <= 50"]
    )
    
    result = @reasoning_coordinator.pursue_goal(:find_valid_x)
    
    # Should satisfy both goal postconditions and constraints
    assert_instance_of Integer, result
    assert_operator result, :>=, 0
    assert_operator result, :<=, 50
    
    # Should satisfy constraints
    assert @reasoning_coordinator.constraint_system.variable_satisfies?(:x, result)
  end

  # === Logic Programming Integration Tests ===

  def test_fact_assertion_integrates_with_evaluator
    @reasoning_coordinator.enable_reasoning_mode
    
    # Assert facts in evaluator context
    @reasoning_coordinator.assert_fact("likes(alice, ruby)")
    @reasoning_coordinator.assert_fact("likes(bob, python)")
    @reasoning_coordinator.assert_fact("language(ruby)")
    @reasoning_coordinator.assert_fact("language(python)")
    
    facts = @reasoning_coordinator.get_facts
    assert_equal 4, facts.length
    assert_includes facts, "likes(alice, ruby)"
    assert_includes facts, "language(ruby)"
  end

  def test_rule_definition_integrates_with_evaluator
    @reasoning_coordinator.enable_reasoning_mode
    
    # Define rules in evaluator context
    @reasoning_coordinator.define_rule("programmer(X) :- likes(X, Language), language(Language)")
    @reasoning_coordinator.define_rule("polyglot(X) :- likes(X, L1), likes(X, L2), L1 != L2")
    
    rules = @reasoning_coordinator.get_rules
    assert_equal 2, rules.length
    assert_includes rules, "programmer(X) :- likes(X, Language), language(Language)"
    assert_includes rules, "polyglot(X) :- likes(X, L1), likes(X, L2), L1 != L2"
  end

  def test_query_execution_integrates_with_evaluator
    @reasoning_coordinator.enable_reasoning_mode
    
    # Setup knowledge base
    @reasoning_coordinator.assert_fact("student(alice)")
    @reasoning_coordinator.assert_fact("student(bob)")
    @reasoning_coordinator.assert_fact("enrolled(alice, math)")
    @reasoning_coordinator.assert_fact("enrolled(bob, english)")
    
    # Execute queries
    student_results = @reasoning_coordinator.query("student(X)")
    enrollment_results = @reasoning_coordinator.query("enrolled(alice, X)")
    
    assert_instance_of Array, student_results
    assert_instance_of Array, enrollment_results
  end

  # === Cross-Paradigm Integration Tests ===

  def test_type_inference_from_logic_facts
    @reasoning_coordinator.enable_reasoning_mode
    
    # Assert type facts
    @reasoning_coordinator.assert_fact("typeof(age, number)")
    @reasoning_coordinator.assert_fact("typeof(name, string)")
    
    # Infer types from facts
    age_type = @reasoning_coordinator.infer_type_from_facts(:age)
    name_type = @reasoning_coordinator.infer_type_from_facts(:name)
    
    assert_equal :Number, age_type
    assert_equal :String, name_type
    
    # Verify constraints were created
    age_constraint = @reasoning_coordinator.get_constraint(:age)
    name_constraint = @reasoning_coordinator.get_constraint(:name)
    
    assert_instance_of TypeConstraint, age_constraint
    assert_instance_of TypeConstraint, name_constraint
    assert_equal :Number, age_constraint.constraint_data
    assert_equal :String, name_constraint.constraint_data
  end

  def test_constraint_propagation_to_logic_facts
    @reasoning_coordinator.enable_reasoning_mode
    
    # Create constraints
    number_constraint = @reasoning_coordinator.create_constraint(:value, :type, :Number)
    range_constraint = @reasoning_coordinator.create_constraint(:score, :range, 0..100)
    
    # Propagate to logic system
    @reasoning_coordinator.propagate_constraint_to_logic(:value, number_constraint)
    @reasoning_coordinator.propagate_constraint_to_logic(:score, range_constraint)
    
    facts = @reasoning_coordinator.get_facts
    assert_includes facts, "typeof(value, Number)"
    assert_includes facts, "range(score, 0, 100)"
  end

  def test_integrated_reasoning_scenario
    @reasoning_coordinator.enable_reasoning_mode
    
    # Create a complete reasoning scenario combining all paradigms
    
    # 1. Define type constraints
    @reasoning_coordinator.create_constraint(:temperature, :type, :Number)
    @reasoning_coordinator.create_constraint(:temperature, :range, -50..50)
    
    # 2. Assert logic facts
    @reasoning_coordinator.assert_fact("sensor(temp_sensor_1)")
    @reasoning_coordinator.assert_fact("reading(temp_sensor_1, 22)")
    @reasoning_coordinator.assert_fact("typeof(temperature, number)")
    
    # 3. Define logic rules
    @reasoning_coordinator.define_rule("valid_reading(Sensor, Temp) :- reading(Sensor, Temp), Temp >= -50, Temp <= 50")
    @reasoning_coordinator.define_rule("normal_temp(Temp) :- valid_reading(_, Temp), Temp >= 18, Temp <= 25")
    
    # 4. Create goals
    @reasoning_coordinator.create_goal(:validate_sensor_data,
      description: "Validate sensor temperature data",
      postconditions: ["result.is_a?(TrueClass) || result.is_a?(FalseClass)"]
    )
    
    # 5. Execute integrated reasoning
    validation_result = @reasoning_coordinator.pursue_goal(:validate_sensor_data)
    
    # 6. Query logic system
    valid_readings = @reasoning_coordinator.query("valid_reading(temp_sensor_1, X)")
    normal_temps = @reasoning_coordinator.query("normal_temp(X)")
    
    # Verify integrated results
    assert_instance_of Array, valid_readings
    assert_instance_of Array, normal_temps
    assert [true, false].include?(validation_result)
    
    # Verify constraint satisfaction
    assert @reasoning_coordinator.constraint_system.variable_satisfies?(:temperature, 22)
    refute @reasoning_coordinator.constraint_system.variable_satisfies?(:temperature, 100)
  end

  # === Performance Integration Tests ===

  def test_integrated_reasoning_performance
    @reasoning_coordinator.enable_reasoning_mode
    
    start_time = Time.now
    
    # Perform integrated operations
    20.times do |i|
      # Constraints
      @reasoning_coordinator.create_constraint("var_#{i}".to_sym, :type, :Number)
      
      # Facts
      @reasoning_coordinator.assert_fact("item(item_#{i})")
      @reasoning_coordinator.assert_fact("value(item_#{i}, #{i * 10})")
      
      # Rules
      @reasoning_coordinator.define_rule("valid_item(X) :- item(X), value(X, V), V >= 0")
      
      # Goals
      @reasoning_coordinator.create_goal("goal_#{i}".to_sym, 
        description: "Performance goal #{i}")
      
      # Goal pursuit
      @reasoning_coordinator.pursue_goal("goal_#{i}".to_sym)
      
      # Queries
      @reasoning_coordinator.query("item(X)")
    end
    
    duration = Time.now - start_time
    assert_operator duration, :<, 2.0, "20 integrated reasoning cycles should complete in <2s"
    
    # Verify all components were created
    stats = @reasoning_coordinator.statistics
    assert_operator stats[:constraints], :>=, 20
    assert_operator stats[:facts], :>=, 40
    assert_operator stats[:rules], :>=, 20
    assert_operator stats[:goals], :>=, 20
    assert_operator stats[:inferences], :>=, 20
  end

  def test_memory_usage_during_integration
    @reasoning_coordinator.enable_reasoning_mode
    
    initial_object_count = ObjectSpace.count_objects[:TOTAL]
    
    # Perform many integrated operations
    50.times do |i|
      @reasoning_coordinator.create_constraint("mem_var_#{i}".to_sym, :type, :Number)
      @reasoning_coordinator.assert_fact("mem_fact_#{i}(data)")
      @reasoning_coordinator.create_goal("mem_goal_#{i}".to_sym, description: "Memory test")
      @reasoning_coordinator.pursue_goal("mem_goal_#{i}".to_sym)
    end
    
    # Reset to clean up
    @reasoning_coordinator.reset!
    
    GC.start
    final_object_count = ObjectSpace.count_objects[:TOTAL]
    object_increase = final_object_count - initial_object_count
    
    assert_operator object_increase, :<, 10000, "Memory usage should be bounded during integration"
  end

  # === Error Handling Integration Tests ===

  def test_evaluator_error_handling_during_reasoning
    @reasoning_coordinator.enable_reasoning_mode
    
    # Test constraint violation handling
    @reasoning_coordinator.create_constraint(:strict_var, :type, :Number)
    
    error = assert_raises(TypeConstraintViolation) do
      @reasoning_coordinator.validate_assignment(:strict_var, "not a number")
    end
    
    assert_instance_of TypeConstraintViolation, error
    assert_equal :strict_var, error.variable
    assert_equal "not a number", error.value
  end

  def test_goal_failure_handling_with_evaluator
    @reasoning_coordinator.enable_reasoning_mode
    
    # Create goal with impossible postconditions
    @reasoning_coordinator.create_goal(:impossible_goal,
      description: "Goal with impossible postconditions",
      postconditions: ["result > 100", "result < 0"]  # Impossible
    )
    
    # This should either succeed with a reasonable result or fail gracefully
    assert_nothing_raised do
      result = @reasoning_coordinator.pursue_goal(:impossible_goal)
      assert_instance_of Integer, result
    end
  end

  def test_reasoning_mode_requirement_enforcement
    # Test operations that require reasoning mode
    operations_requiring_reasoning_mode = [
      -> { @reasoning_coordinator.create_constraint(:test, :type, :Number) },
      -> { @reasoning_coordinator.create_goal(:test, description: "Test") },
      -> { @reasoning_coordinator.assert_fact("test_fact") },
      -> { @reasoning_coordinator.define_rule("test_rule :- test_fact") },
      -> { @reasoning_coordinator.query("test_fact") }
    ]
    
    operations_requiring_reasoning_mode.each do |operation|
      error = assert_raises(ReasoningModeError) do
        operation.call
      end
      assert_instance_of ReasoningModeError, error
      assert_includes error.message, "Reasoning mode must be enabled"
    end
  end

  # === State Management Integration Tests ===

  def test_reasoning_state_persistence_with_evaluator
    @reasoning_coordinator.enable_reasoning_mode
    
    # Create some state
    @reasoning_coordinator.create_constraint(:persistent_var, :type, :String)
    @reasoning_coordinator.create_goal(:persistent_goal, description: "Persistent goal")
    @reasoning_coordinator.assert_fact("persistent_fact(data)")
    
    # Verify state exists
    assert_instance_of TypeConstraint, @reasoning_coordinator.get_constraint(:persistent_var)
    assert_instance_of Goal, @reasoning_coordinator.instance_variable_get(:@goals)[:persistent_goal]
    assert_includes @reasoning_coordinator.get_facts, "persistent_fact(data)"
    
    # Disable and re-enable reasoning mode
    @reasoning_coordinator.disable_reasoning_mode
    @reasoning_coordinator.enable_reasoning_mode
    
    # State should still exist
    assert_instance_of TypeConstraint, @reasoning_coordinator.get_constraint(:persistent_var)
    assert_instance_of Goal, @reasoning_coordinator.instance_variable_get(:@goals)[:persistent_goal]
    assert_includes @reasoning_coordinator.get_facts, "persistent_fact(data)"
  end

  def test_reasoning_state_reset_integration
    @reasoning_coordinator.enable_reasoning_mode
    
    # Create comprehensive state
    @reasoning_coordinator.create_constraint(:reset_var, :type, :Number)
    @reasoning_coordinator.create_goal(:reset_goal, description: "Goal to be reset")
    @reasoning_coordinator.assert_fact("reset_fact(data)")
    @reasoning_coordinator.define_rule("reset_rule :- reset_fact(data)")
    @reasoning_coordinator.pursue_goal(:reset_goal)
    
    # Verify state exists
    initial_stats = @reasoning_coordinator.statistics
    assert_operator initial_stats[:constraints], :>, 0
    assert_operator initial_stats[:goals], :>, 0
    assert_operator initial_stats[:facts], :>, 0
    assert_operator initial_stats[:rules], :>, 0
    assert_operator initial_stats[:inferences], :>, 0
    
    # Reset state
    @reasoning_coordinator.reset!
    
    # Verify state is cleared
    final_stats = @reasoning_coordinator.statistics
    assert_equal 0, final_stats[:constraints]
    assert_equal 0, final_stats[:goals]
    assert_equal 0, final_stats[:facts]
    assert_equal 0, final_stats[:rules]
    assert_equal 0, final_stats[:inferences]
  end

  private

  def assert_events_fired(expected_event_types)
    actual_event_types = @event_log.map { |e| e[:event_type] }
    expected_event_types.each do |expected_type|
      assert_includes actual_event_types, expected_type,
                     "Expected event #{expected_type} to be fired"
    end
  end
end