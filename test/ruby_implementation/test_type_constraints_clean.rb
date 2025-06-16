# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../helpers/test_helper'
require_relative '../../src/reasoning/type_constraint_system'

# Test the type constraint system for unified reasoning
class TestTypeConstraints < Minitest::Test
  def setup
    @constraint_system = TypeConstraintSystem.new
    @event_log = []
    
    # Subscribe to constraint events for testing
    @constraint_system.on_event(:constraint_created) { |e| @event_log << e }
    @constraint_system.on_event(:constraint_validated) { |e| @event_log << e }
    @constraint_system.on_event(:constraint_failed) { |e| @event_log << e }
    @constraint_system.on_event(:type_refined) { |e| @event_log << e }
  end

  # === Core Constraint Creation Tests ===

  def test_create_type_constraint_basic
    constraint = @constraint_system.create_constraint(:x, :type, :Number)
    
    assert_instance_of TypeConstraint, constraint
    assert_equal :x, constraint.variable
    assert_equal :type, constraint.constraint_type
    assert_equal :Number, constraint.constraint_data
    assert_events_fired [:constraint_created]
  end

  def test_create_range_constraint
    constraint = @constraint_system.create_constraint(:age, :range, 0..150)
    
    assert_instance_of TypeConstraint, constraint
    assert_equal :age, constraint.variable
    assert_equal :range, constraint.constraint_type
    assert_equal 0..150, constraint.constraint_data
    assert_events_fired [:constraint_created]
  end

  def test_create_pattern_constraint
    constraint = @constraint_system.create_constraint(:name, :pattern, /\A[A-Z][a-z]+\z/)
    
    assert_instance_of TypeConstraint, constraint
    assert_equal :name, constraint.variable
    assert_equal :pattern, constraint.constraint_type
    assert_equal(/\A[A-Z][a-z]+\z/, constraint.constraint_data)
    assert_events_fired [:constraint_created]
  end

  def test_multiple_constraints_same_variable
    constraint1 = @constraint_system.create_constraint(:x, :type, :Number)
    constraint2 = @constraint_system.create_constraint(:x, :range, 0..100)
    
    constraints = @constraint_system.get_constraints(:x)
    assert_equal 2, constraints.length
    assert_includes constraints, constraint1
    assert_includes constraints, constraint2
  end

  # === Constraint Validation Tests ===

  def test_type_constraint_validates_correct_values
    @constraint_system.create_constraint(:x, :type, :Number)
    
    assert @constraint_system.variable_satisfies?(:x, 42)
    assert @constraint_system.variable_satisfies?(:x, 3.14)
    refute @constraint_system.variable_satisfies?(:x, "not a number")
    refute @constraint_system.variable_satisfies?(:x, true)
    
    assert_events_fired [:constraint_created, :constraint_validated, :constraint_validated,
                         :constraint_validated, :constraint_validated]
  end

  def test_range_constraint_validates_correct_values
    @constraint_system.create_constraint(:age, :range, 0..150)
    
    assert @constraint_system.variable_satisfies?(:age, 25)
    assert @constraint_system.variable_satisfies?(:age, 0)
    assert @constraint_system.variable_satisfies?(:age, 150)
    refute @constraint_system.variable_satisfies?(:age, -1)
    refute @constraint_system.variable_satisfies?(:age, 151)
  end

  def test_pattern_constraint_validates_correct_values
    @constraint_system.create_constraint(:name, :pattern, /\A[A-Z][a-z]+\z/)
    
    assert @constraint_system.variable_satisfies?(:name, "Alice")
    assert @constraint_system.variable_satisfies?(:name, "Bob")
    refute @constraint_system.variable_satisfies?(:name, "alice")
    refute @constraint_system.variable_satisfies?(:name, "123")
    refute @constraint_system.variable_satisfies?(:name, "")
  end

  def test_multiple_constraints_all_must_satisfy
    @constraint_system.create_constraint(:x, :type, :Number)
    @constraint_system.create_constraint(:x, :range, 0..100)
    
    assert @constraint_system.variable_satisfies?(:x, 50)
    refute @constraint_system.variable_satisfies?(:x, 150)  # violates range
    refute @constraint_system.variable_satisfies?(:x, "50") # violates type
  end

  # === Error Handling Tests ===

  def test_constraint_provides_helpful_error_messages
    constraint = @constraint_system.create_constraint(:age, :range, 0..150)
    
    error = assert_raises(TypeConstraintViolation) do
      constraint.validate!(200)
    end
    
    assert_includes error.message, "age"
    assert_includes error.message, "0..150"
  end

  def test_range_constraint_error_includes_range_info
    @constraint_system.create_constraint(:age, :range, 0..150)
    
    error = assert_raises(ConstraintViolationError) do
      @constraint_system.set_variable_value(:age, 200)
    end
    
    assert_includes error.message, "200"
  end

  private

  def assert_events_fired(expected_event_types)
    actual_event_types = @event_log.map { |e| e[:event_type] }
    assert_equal expected_event_types, actual_event_types,
                 "Expected events #{expected_event_types}, got #{actual_event_types}"
  end
end