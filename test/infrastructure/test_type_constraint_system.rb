# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../helpers/test_helper'
require_relative '../../src/reasoning/type_constraint'

# Comprehensive tests for the type constraint system
class TestTypeConstraintSystem < Minitest::Test
  def setup
    @system = TypeConstraintSystem.new
    @event_log = []
    
    # Subscribe to constraint events for testing
    @system.on_event(:constraint_created) { |e| @event_log << e }
    @system.on_event(:constraint_validated) { |e| @event_log << e }
    @system.on_event(:constraint_removed) { |e| @event_log << e }
    @system.on_event(:type_refined) { |e| @event_log << e }
    @system.on_event(:propagation_failed) { |e| @event_log << e }
  end

  # === Basic Constraint Creation Tests ===

  def test_create_type_constraint_succeeds
    constraint = @system.create_constraint(:x, :type, :Number)
    
    assert_instance_of TypeConstraint, constraint
    assert_equal :x, constraint.variable
    assert_equal :type, constraint.constraint_type
    assert_equal :Number, constraint.constraint_data
    assert_events_fired [:constraint_created]
  end

  def test_create_range_constraint_succeeds
    constraint = @system.create_constraint(:age, :range, 0..120)
    
    assert_instance_of TypeConstraint, constraint
    assert_equal :age, constraint.variable
    assert_equal :range, constraint.constraint_type
    assert_equal 0..120, constraint.constraint_data
  end

  def test_create_pattern_constraint_succeeds
    email_pattern = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
    constraint = @system.create_constraint(:email, :pattern, email_pattern)
    
    assert_instance_of TypeConstraint, constraint
    assert_equal :email, constraint.variable
    assert_equal :pattern, constraint.constraint_type
    assert_equal email_pattern, constraint.constraint_data
  end

  def test_create_structural_constraint_succeeds
    structure = {
      name: { type: :String, required: true },
      age: { type: :Number, range: 0..120, required: true },
      email: { type: :String, pattern: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i, required: false }
    }
    constraint = @system.create_constraint(:person, :structural, structure)
    
    assert_instance_of TypeConstraint, constraint
    assert_equal :person, constraint.variable
    assert_equal :structural, constraint.constraint_type
    assert_equal structure, constraint.constraint_data
  end

  def test_create_custom_constraint_with_proc
    validator = proc { |value| value.is_a?(String) && value.length > 5 }
    constraint = @system.create_constraint(:password, :custom, validator)
    
    assert_instance_of TypeConstraint, constraint
    assert_equal :password, constraint.variable
    assert_equal :custom, constraint.constraint_type
    assert_equal validator, constraint.constraint_data
  end

  # === Constraint Conflict Detection Tests ===

  def test_conflicting_type_constraints_raise_error
    @system.create_constraint(:x, :type, :Number)
    
    error = assert_raises(ConstraintConflictError) do
      @system.create_constraint(:x, :type, :String)
    end
    
    assert_includes error.message, "Type constraint conflict"
    assert_equal :x, error.variable
  end

  def test_conflicting_range_constraints_raise_error
    @system.create_constraint(:score, :range, 0..100)
    
    error = assert_raises(ConstraintConflictError) do
      @system.create_constraint(:score, :range, 200..300)
    end
    
    assert_includes error.message, "Range constraint conflict"
    assert_equal :score, error.variable
  end

  def test_compatible_range_constraints_allowed
    @system.create_constraint(:value, :range, 0..100)
    
    # Overlapping range should be allowed
    assert_nothing_raised do
      @system.create_constraint(:value, :range, 50..150)
    end
  end

  # === Variable Satisfaction Tests ===

  def test_variable_satisfies_type_constraint
    @system.create_constraint(:x, :type, :Number)
    
    assert @system.variable_satisfies?(:x, 42)
    assert @system.variable_satisfies?(:x, 3.14)
    refute @system.variable_satisfies?(:x, "string")
    refute @system.variable_satisfies?(:x, true)
  end

  def test_variable_satisfies_range_constraint
    @system.create_constraint(:age, :range, 0..120)
    
    assert @system.variable_satisfies?(:age, 25)
    assert @system.variable_satisfies?(:age, 0)
    assert @system.variable_satisfies?(:age, 120)
    refute @system.variable_satisfies?(:age, -1)
    refute @system.variable_satisfies?(:age, 121)
  end

  def test_variable_satisfies_pattern_constraint
    email_pattern = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
    @system.create_constraint(:email, :pattern, email_pattern)
    
    assert @system.variable_satisfies?(:email, "user@example.com")
    assert @system.variable_satisfies?(:email, "test.email@domain.org")
    refute @system.variable_satisfies?(:email, "invalid-email")
    refute @system.variable_satisfies?(:email, "user@")
  end

  def test_variable_satisfies_structural_constraint
    structure = {
      name: { type: :String, required: true },
      age: { type: :Number, required: true }
    }
    @system.create_constraint(:person, :structural, structure)
    
    valid_person = { name: "Alice", age: 30 }
    invalid_person_missing_field = { name: "Bob" }
    invalid_person_wrong_type = { name: "Charlie", age: "thirty" }
    
    assert @system.variable_satisfies?(:person, valid_person)
    refute @system.variable_satisfies?(:person, invalid_person_missing_field)
    refute @system.variable_satisfies?(:person, invalid_person_wrong_type)
  end

  def test_variable_satisfies_custom_constraint
    validator = proc { |value| value.is_a?(String) && value.length > 5 }
    @system.create_constraint(:password, :custom, validator)
    
    assert @system.variable_satisfies?(:password, "secret123")
    refute @system.variable_satisfies?(:password, "short")
    refute @system.variable_satisfies?(:password, 123456)
  end

  def test_variable_satisfies_multiple_constraints
    @system.create_constraint(:score, :type, :Number)
    @system.create_constraint(:score, :range, 0..100)
    
    assert @system.variable_satisfies?(:score, 85)
    assert @system.variable_satisfies?(:score, 0)
    assert @system.variable_satisfies?(:score, 100)
    refute @system.variable_satisfies?(:score, -10)
    refute @system.variable_satisfies?(:score, 150)
    refute @system.variable_satisfies?(:score, "85")
  end

  # === Variable Assignment and Validation Tests ===

  def test_set_valid_variable_value_succeeds
    @system.create_constraint(:x, :type, :Number)
    
    assert_nothing_raised do
      @system.set_variable_value(:x, 42)
    end
    
    assert_equal 42, @system.get_variable_value(:x)
  end

  def test_set_invalid_variable_value_raises_error
    @system.create_constraint(:x, :type, :Number)
    
    error = assert_raises(ConstraintViolationError) do
      @system.set_variable_value(:x, "string")
    end
    
    assert_includes error.message, "violates constraints"
    assert_equal :x, error.variable
    assert_equal "string", error.value
  end

  def test_constraint_violation_includes_constraint_details
    @system.create_constraint(:age, :range, 0..120)
    
    error = assert_raises(ConstraintViolationError) do
      @system.set_variable_value(:age, 150)
    end
    
    assert_equal :age, error.variable
    assert_equal 150, error.value
    assert_instance_of Array, error.constraints
    refute_empty error.constraints
  end

  # === Constraint Propagation Tests ===

  def test_add_relationship_creates_propagation
    @system.create_constraint(:fahrenheit, :type, :Number)
    @system.create_constraint(:celsius, :type, :Number)
    
    # Add relationship: celsius = (fahrenheit - 32) * 5/9
    @system.add_relationship(:fahrenheit, :celsius, proc { |f| (f - 32) * 5.0 / 9.0 })
    
    @system.set_variable_value(:fahrenheit, 212)
    
    assert_equal 100.0, @system.get_variable_value(:celsius)
    assert_events_include :type_refined
  end

  def test_propagation_respects_target_constraints
    @system.create_constraint(:input, :range, -100..100)
    @system.create_constraint(:output, :range, 0..50)
    
    # Transform that doubles the input
    @system.add_relationship(:input, :output, proc { |x| x * 2 })
    
    # This should work (25 * 2 = 50, within output range)
    assert_nothing_raised do
      @system.set_variable_value(:input, 25)
    end
    
    # This should fail (60 * 2 = 120, exceeds output range)
    error = assert_raises(ConstraintViolationError) do
      @system.set_variable_value(:input, 60)
    end
    
    assert_includes error.message, "propagation conflict"
  end

  # === Constraint Management Tests ===

  def test_get_constraints_returns_array
    @system.create_constraint(:x, :type, :Number)
    @system.create_constraint(:x, :range, 0..100)
    
    constraints = @system.get_constraints(:x)
    
    assert_instance_of Array, constraints
    assert_equal 2, constraints.length
    assert constraints.all? { |c| c.is_a?(TypeConstraint) }
  end

  def test_get_constraints_empty_for_unconstrained_variable
    constraints = @system.get_constraints(:undefined_var)
    
    assert_instance_of Array, constraints
    assert_empty constraints
  end

  def test_constraint_count_tracks_total_constraints
    initial_count = @system.constraint_count
    
    @system.create_constraint(:x, :type, :Number)
    assert_equal initial_count + 1, @system.constraint_count
    
    @system.create_constraint(:y, :range, 0..100)
    assert_equal initial_count + 2, @system.constraint_count
    
    @system.create_constraint(:x, :range, -10..10)
    assert_equal initial_count + 3, @system.constraint_count
  end

  def test_remove_constraints_cleans_up_variable
    @system.create_constraint(:temp_var, :type, :Number)
    @system.create_constraint(:temp_var, :range, 0..100)
    @system.set_variable_value(:temp_var, 50)
    
    removed_count = @system.remove_constraints(:temp_var)
    
    assert_equal 2, removed_count
    assert_empty @system.get_constraints(:temp_var)
    assert_nil @system.get_variable_value(:temp_var)
    assert_events_include :constraint_removed
  end

  # === Event System Tests ===

  def test_constraint_creation_fires_events
    @system.create_constraint(:test_var, :type, :String)
    
    creation_event = @event_log.find { |e| e[:event_type] == :constraint_created }
    assert creation_event
    assert_equal :test_var, creation_event[:variable]
    assert_instance_of TypeConstraint, creation_event[:constraint]
  end

  def test_validation_fires_events
    @system.create_constraint(:x, :type, :Number)
    @system.variable_satisfies?(:x, 42)
    
    validation_events = @event_log.select { |e| e[:event_type] == :constraint_validated }
    assert validation_events.any?
    
    validation_event = validation_events.first
    assert_equal :x, validation_event[:variable]
    assert_equal 42, validation_event[:value]
    assert validation_event[:result]
  end

  def test_propagation_fires_events
    @system.create_constraint(:source, :type, :Number)
    @system.create_constraint(:target, :type, :Number)
    @system.add_relationship(:source, :target, proc { |x| x * 2 })
    
    @system.set_variable_value(:source, 21)
    
    refinement_events = @event_log.select { |e| e[:event_type] == :type_refined }
    assert refinement_events.any?
    
    refinement_event = refinement_events.first
    assert_equal :target, refinement_event[:variable]
    assert_equal 42, refinement_event[:new_value]
    assert_equal :source, refinement_event[:source]
  end

  # === Edge Cases and Error Handling Tests ===

  def test_null_constraint_pattern_for_missing_constraints
    # This tests the NullTypeConstraint pattern
    null_constraint = NullTypeConstraint.new(:missing_var)
    
    assert_equal :missing_var, null_constraint.variable
    refute null_constraint.satisfies?("any_value")
    refute null_constraint.validate!("any_value")
    refute null_constraint.has_condition?
    assert_equal :null, null_constraint.constraint_type
    assert_nil null_constraint.constraint_data
  end

  def test_constraint_handles_malformed_values_gracefully
    @system.create_constraint(:safe_var, :range, 0..100)
    
    # These should not crash but return false
    refute @system.variable_satisfies?(:safe_var, Object.new)
    refute @system.variable_satisfies?(:safe_var, nil)
    refute @system.variable_satisfies?(:safe_var, [1, 2, 3])
  end

  def test_structural_constraint_with_nested_arrays
    structure = {
      tags: { 
        type: :Array, 
        elements: { type: :String },
        required: true 
      }
    }
    @system.create_constraint(:document, :structural, structure)
    
    valid_doc = { tags: ["ruby", "programming", "test"] }
    invalid_doc = { tags: ["ruby", 123, "test"] }
    
    assert @system.variable_satisfies?(:document, valid_doc)
    refute @system.variable_satisfies?(:document, invalid_doc)
  end

  # === Performance Tests ===

  def test_constraint_creation_performance
    start_time = Time.now
    
    100.times do |i|
      @system.create_constraint("var_#{i}".to_sym, :type, :Number)
    end
    
    duration = Time.now - start_time
    assert_operator duration, :<, 0.1, "100 constraint creations should complete in <100ms"
  end

  def test_constraint_validation_performance
    # Create constraints
    50.times do |i|
      @system.create_constraint("var_#{i}".to_sym, :range, 0..1000)
    end
    
    start_time = Time.now
    
    # Validate many values
    1000.times do |i|
      var_name = "var_#{i % 50}".to_sym
      @system.variable_satisfies?(var_name, i)
    end
    
    duration = Time.now - start_time
    assert_operator duration, :<, 0.2, "1000 validations should complete in <200ms"
  end

  def test_memory_usage_bounded_during_constraint_operations
    initial_object_count = ObjectSpace.count_objects[:TOTAL]
    
    # Create and remove many constraints
    100.times do |i|
      var_name = "temp_#{i}".to_sym
      @system.create_constraint(var_name, :type, :Number)
      @system.set_variable_value(var_name, i)
      @system.remove_constraints(var_name)
    end
    
    GC.start
    final_object_count = ObjectSpace.count_objects[:TOTAL]
    object_increase = final_object_count - initial_object_count
    
    assert_operator object_increase, :<, 2000, "Memory usage should be bounded"
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
end