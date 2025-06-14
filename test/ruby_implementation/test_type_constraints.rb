# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../helpers/test_helper'
require_relative '../../src/reasoning/type_constraint'

# Test the type constraint system for unified reasoning
class TestTypeConstraints < Minitest::Test
  def setup
    @constraint_system = TypeConstraintSystem.new
    @event_log = []
    
    # Subscribe to constraint events for testing
    @constraint_system.on_event(:constraint_created) { |e| @event_log << e }
    @constraint_system.on_event(:constraint_validated) { |e| @event_log << e }
    @constraint_system.on_event(:constraint_violated) { |e| @event_log << e }
    @constraint_system.on_event(:type_refined) { |e| @event_log << e }
  end

  # === Basic Constraint Creation Tests ===

  def test_create_simple_type_constraint
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
    assert_equal (0..150), constraint.constraint_data
  end

  def test_create_pattern_constraint
    pattern = /\A\w+@\w+\.\w+\z/
    constraint = @constraint_system.create_constraint(:email, :pattern, pattern)
    
    assert_instance_of TypeConstraint, constraint
    assert_equal :email, constraint.variable
    assert_equal :pattern, constraint.constraint_type
    assert_equal pattern, constraint.constraint_data
  end

  def test_create_structural_constraint
    structure = {
      name: { type: :String, required: true },
      age: { type: :Number, range: 0..150 },
      email: { type: :String, pattern: /\A\w+@\w+\.\w+\z/ }
    }
    
    constraint = @constraint_system.create_constraint(:person, :structural, structure)
    
    assert_instance_of TypeConstraint, constraint
    assert_equal :person, constraint.variable
    assert_equal :structural, constraint.constraint_type
    assert_equal structure, constraint.constraint_data
  end

  def test_create_composite_constraint
    constraints = [
      { type: :type, data: :Number },
      { type: :range, data: 1..100 },
      { type: :custom, data: ->(x) { x.even? } }
    ]
    
    constraint = @constraint_system.create_constraint(:even_number, :composite, constraints)
    
    assert_instance_of TypeConstraint, constraint
    assert_equal :even_number, constraint.variable
    assert_equal :composite, constraint.constraint_type
    assert_equal constraints, constraint.constraint_data
  end

  # === Constraint Validation Tests ===

  def test_type_constraint_validates_correct_values
    constraint = @constraint_system.create_constraint(:x, :type, :Number)
    
    assert constraint.satisfies?(42), "Integer should satisfy Number constraint"
    assert constraint.satisfies?(3.14), "Float should satisfy Number constraint"
    assert constraint.satisfies?(0), "Zero should satisfy Number constraint"
    assert constraint.satisfies?(-5), "Negative number should satisfy Number constraint"
    
    assert_events_fired [:constraint_created, :constraint_validated, :constraint_validated, 
                         :constraint_validated, :constraint_validated]
  end

  def test_type_constraint_rejects_incorrect_values
    constraint = @constraint_system.create_constraint(:x, :type, :Number)
    
    refute constraint.satisfies?("42"), "String should not satisfy Number constraint"
    refute constraint.satisfies?(true), "Boolean should not satisfy Number constraint"
    refute constraint.satisfies?(nil), "Nil should not satisfy Number constraint"
    refute constraint.satisfies?([]), "Array should not satisfy Number constraint"
  end

  def test_range_constraint_validates_boundaries
    constraint = @constraint_system.create_constraint(:score, :range, 0..100)
    
    assert constraint.satisfies?(0), "Lower boundary should be valid"
    assert constraint.satisfies?(100), "Upper boundary should be valid"
    assert constraint.satisfies?(50), "Middle value should be valid"
    
    refute constraint.satisfies?(-1), "Below range should be invalid"
    refute constraint.satisfies?(101), "Above range should be invalid"
  end

  def test_pattern_constraint_validates_strings
    constraint = @constraint_system.create_constraint(:email, :pattern, /\A\w+@\w+\.\w+\z/)
    
    assert constraint.satisfies?("user@example.com"), "Valid email should satisfy pattern"
    assert constraint.satisfies?("test@domain.org"), "Valid email should satisfy pattern"
    
    refute constraint.satisfies?("invalid-email"), "Invalid format should not satisfy"
    refute constraint.satisfies?("@example.com"), "Missing username should not satisfy"
    refute constraint.satisfies?("user@"), "Missing domain should not satisfy"
  end

  def test_structural_constraint_validates_objects
    structure = {
      name: { type: :String, required: true },
      age: { type: :Number, range: 0..150 }
    }
    constraint = @constraint_system.create_constraint(:person, :structural, structure)
    
    valid_person = { name: "John Doe", age: 30 }
    assert constraint.satisfies?(valid_person), "Valid structure should satisfy constraint"
    
    missing_required = { age: 30 }
    refute constraint.satisfies?(missing_required), "Missing required field should not satisfy"
    
    wrong_type = { name: "John", age: "thirty" }
    refute constraint.satisfies?(wrong_type), "Wrong field type should not satisfy"
    
    out_of_range = { name: "John", age: 200 }
    refute constraint.satisfies?(out_of_range), "Out of range value should not satisfy"
  end

  def test_composite_constraint_validates_all_parts
    constraints = [
      { type: :type, data: :Number },
      { type: :range, data: 2..100 },
      { type: :custom, data: ->(x) { x.even? } }
    ]
    constraint = @constraint_system.create_constraint(:even_num, :composite, constraints)
    
    assert constraint.satisfies?(4), "Even number in range should satisfy"
    assert constraint.satisfies?(50), "Even number in range should satisfy"
    
    refute constraint.satisfies?(3), "Odd number should not satisfy"
    refute constraint.satisfies?(1), "Number below range should not satisfy"
    refute constraint.satisfies?(102), "Number above range should not satisfy"
    refute constraint.satisfies?("4"), "Wrong type should not satisfy"
  end

  def test_constraint_provides_helpful_error_messages
    constraint = @constraint_system.create_constraint(:x, :type, :Number)
    
    begin
      constraint.validate!("not a number")
      flunk "Should have raised TypeConstraintViolation"
    rescue TypeConstraintViolation => e
      assert_equal :x, e.variable
      assert_includes e.message, "Number"
      assert_includes e.message, "String"
      assert_equal "not a number", e.value
    end
  end

  def test_range_constraint_error_includes_range_info
    constraint = @constraint_system.create_constraint(:age, :range, 0..150)
    
    begin
      constraint.validate!(200)
      flunk "Should have raised TypeConstraintViolation"
    rescue TypeConstraintViolation => e
      assert_includes e.message, "0..150"
      assert_includes e.message, "200"
    end
  end

  # === Multiple Constraints on Same Variable ===

  def test_multiple_constraints_on_same_variable
    @constraint_system.create_constraint(:x, :type, :Number)
    @constraint_system.create_constraint(:x, :range, 0..100)
    
    constraints = @constraint_system.get_constraints(:x)
    assert_equal 2, constraints.length
    
    # All constraints must be satisfied
    assert @constraint_system.variable_satisfies?(:x, 50), "Value satisfying all constraints should pass"
    refute @constraint_system.variable_satisfies?(:x, -5), "Value violating range should fail"
    refute @constraint_system.variable_satisfies?(:x, "50"), "Value violating type should fail"
  end

  def test_conflicting_constraints_detected
    @constraint_system.create_constraint(:x, :range, 0..50)
    
    error = assert_raises(ConstraintConflictError) do
      @constraint_system.create_constraint(:x, :range, 60..100)
    end
    
    assert_includes error.message, "conflict"
    assert_includes error.message, ":x"
  end

  def test_compatible_constraints_merge_correctly
    @constraint_system.create_constraint(:x, :type, :Number)
    @constraint_system.create_constraint(:x, :range, 0..100)
    @constraint_system.create_constraint(:x, :custom, ->(n) { n.even? })
    
    # Should accept values that satisfy all constraints
    assert @constraint_system.variable_satisfies?(:x, 50)
    refute @constraint_system.variable_satisfies?(:x, 51) # odd
    refute @constraint_system.variable_satisfies?(:x, -2) # out of range but even
  end

  # === Constraint Propagation Network Tests ===

  def test_constraint_propagation_updates_related_variables
    @constraint_system.create_constraint(:x, :type, :Number)
    @constraint_system.create_constraint(:y, :type, :Number)
    @constraint_system.add_relationship(:x, :y, ->(x_val) { x_val * 2 })
    
    @constraint_system.set_variable_value(:x, 5)
    
    # Propagation should update y to 10
    assert_equal 10, @constraint_system.get_variable_value(:y)
    assert_events_include :type_refined
  end

  def test_propagation_fires_type_refined_events
    @constraint_system.create_constraint(:width, :range, 1..100)
    @constraint_system.create_constraint(:area, :type, :Number)
    @constraint_system.add_relationship(:width, :area, ->(w) { w * w })
    
    @constraint_system.set_variable_value(:width, 5)
    
    refined_events = @event_log.select { |e| e[:event_type] == :type_refined }
    assert_operator refined_events.length, :>, 0, "Should fire type_refined events"
    
    area_event = refined_events.find { |e| e[:variable] == :area }
    assert area_event, "Should fire type_refined event for area"
    assert_equal 25, area_event[:new_value]
  end

  def test_propagation_handles_constraint_conflicts
    @constraint_system.create_constraint(:x, :range, 1..10)
    @constraint_system.create_constraint(:y, :range, 1..5)
    @constraint_system.add_relationship(:x, :y, ->(x_val) { x_val * 2 })
    
    error = assert_raises(ConstraintViolationError) do
      @constraint_system.set_variable_value(:x, 5) # Would make y = 10, violating y's range
    end
    
    assert_includes error.message, "propagation"
    assert_includes error.message, "conflict"
  end

  def test_propagation_performance_scales_with_network_size
    # Create a constraint network
    100.times do |i|
      @constraint_system.create_constraint("var#{i}".to_sym, :type, :Number)
      if i > 0
        @constraint_system.add_relationship("var#{i-1}".to_sym, "var#{i}".to_sym, ->(val) { val + 1 })
      end
    end
    
    start_time = Time.now
    @constraint_system.set_variable_value(:var0, 1)
    duration = Time.now - start_time
    
    assert_operator duration, :<, 0.1, "Propagation through 100 variables should complete quickly"
    assert_equal 100, @constraint_system.get_variable_value(:var99)
  end

  # === Integration Tests ===

  def test_constraints_integrate_with_object_system
    skip "Object system integration not yet implemented"
    
    obj = PatlangObject.new
    constraint = @constraint_system.create_constraint(obj, :type, :Number)
    
    assert constraint.satisfies?(obj) if obj.value.is_a?(Numeric)
  end

  def test_constraints_respect_patlang_object_metadata
    skip "Object system integration not yet implemented"
    
    obj = PatlangObject.new
    obj.set_metadata(:type_hint, :String)
    
    constraint = @constraint_system.create_constraint(obj, :type, :String)
    assert constraint.respects_metadata?(obj)
  end

  def test_constraint_cleanup_on_object_destruction
    skip "Object system integration not yet implemented"
    
    obj = PatlangObject.new
    @constraint_system.create_constraint(obj, :type, :Number)
    
    initial_count = @constraint_system.constraint_count
    obj = nil
    GC.start
    
    final_count = @constraint_system.constraint_count
    assert_operator final_count, :<, initial_count, "Constraints should be cleaned up"
  end

  # === Performance Tests ===

  def test_constraint_validation_performance
    constraint = @constraint_system.create_constraint(:x, :type, :Number)
    
    start_time = Time.now
    10000.times { constraint.satisfies?(42) }
    duration = Time.now - start_time
    
    assert_operator duration, :<, 0.1, "10000 validations should complete quickly"
  end

  def test_complex_constraint_performance
    structure = {
      field1: { type: :String, pattern: /\A\w+\z/ },
      field2: { type: :Number, range: 1..1000 },
      field3: { type: :Array, elements: { type: :Number } }
    }
    constraint = @constraint_system.create_constraint(:complex, :structural, structure)
    
    test_object = {
      field1: "valid",
      field2: 500,
      field3: [1, 2, 3, 4, 5]
    }
    
    start_time = Time.now
    1000.times { constraint.satisfies?(test_object) }
    duration = Time.now - start_time
    
    assert_operator duration, :<, 0.5, "1000 complex validations should complete reasonably quickly"
  end

  private

  def assert_events_fired(expected_event_types)
    actual_event_types = @event_log.map { |e| e[:event_type] }
    assert_equal expected_event_types, actual_event_types,
                 "Expected events #{expected_event_types}, got #{actual_event_types}"
  end

  def assert_events_include(event_type)
    event_types = @event_log.map { |e| e[:event_type] }
    assert_includes event_types, event_type, "Expected #{event_type} event to be fired"
  end
end

# === Supporting Classes for Tests ===

class TypeConstraintSystem
  def initialize
    @constraints = {}
    @variables = {}
    @relationships = {}
    @event_handlers = {}
  end

  def on_event(event_type, &block)
    @event_handlers[event_type] ||= []
    @event_handlers[event_type] << block
  end

  def create_constraint(variable, type, data, **options)
    # Check for conflicts
    existing = @constraints[variable] || []
    if type == :range && existing.any? { |c| c.constraint_type == :range }
      raise ConstraintConflictError, "Range constraint conflict for variable :#{variable}"
    end

    constraint = TypeConstraint.new(variable, type, data)
    @constraints[variable] ||= []
    @constraints[variable] << constraint
    
    fire_event(:constraint_created, variable: variable, constraint: constraint)
    constraint
  end

  def get_constraints(variable)
    @constraints[variable] || []
  end

  def variable_satisfies?(variable, value)
    constraints = get_constraints(variable)
    return true if constraints.empty?
    
    constraints.all? do |constraint|
      result = constraint.satisfies?(value)
      fire_event(:constraint_validated, variable: variable, value: value, result: result)
      result
    end
  end

  def set_variable_value(variable, value)
    # Validate against constraints
    unless variable_satisfies?(variable, value)
      raise ConstraintViolationError, "Value #{value} violates constraints for #{variable}"
    end
    
    @variables[variable] = value
    propagate_from(variable)
  end

  def get_variable_value(variable)
    @variables[variable]
  end

  def add_relationship(from_var, to_var, transform)
    @relationships[from_var] ||= []
    @relationships[from_var] << { target: to_var, transform: transform }
  end

  def constraint_count
    @constraints.values.flatten.length
  end

  private

  def propagate_from(variable)
    relationships = @relationships[variable] || []
    source_value = @variables[variable]
    
    relationships.each do |rel|
      new_value = rel[:transform].call(source_value)
      target_var = rel[:target]
      
      # Check if new value satisfies target constraints
      unless variable_satisfies?(target_var, new_value)
        raise ConstraintViolationError, "Propagation conflict: #{new_value} violates constraints for #{target_var}"
      end
      
      @variables[target_var] = new_value
      fire_event(:type_refined, variable: target_var, new_value: new_value, source: variable)
    end
  end

  def fire_event(event_type, data)
    @event_handlers[event_type]&.each { |handler| handler.call(data.merge(event_type: event_type)) }
  end
end

class TypeConstraint
  attr_reader :variable, :constraint_type, :constraint_data

  def initialize(variable, type, data)
    @variable = variable
    @constraint_type = type
    @constraint_data = data
  end

  def satisfies?(value)
    case @constraint_type
    when :type
      satisfies_type?(value)
    when :range
      satisfies_range?(value)
    when :pattern
      satisfies_pattern?(value)
    when :structural
      satisfies_structure?(value)
    when :composite
      satisfies_composite?(value)
    when :custom
      @constraint_data.call(value)
    else
      false
    end
  end

  def validate!(value)
    return true if satisfies?(value)
    
    raise TypeConstraintViolation.new(@variable, value, constraint_message)
  end

  private

  def satisfies_type?(value)
    case @constraint_data
    when :Number
      value.is_a?(Numeric)
    when :String
      value.is_a?(String)
    when :Boolean
      value.is_a?(TrueClass) || value.is_a?(FalseClass)
    when :Array
      value.is_a?(Array)
    when :Hash
      value.is_a?(Hash)
    else
      false
    end
  end

  def satisfies_range?(value)
    @constraint_data.cover?(value)
  end

  def satisfies_pattern?(value)
    value.is_a?(String) && @constraint_data.match?(value)
  end

  def satisfies_structure?(value)
    return false unless value.is_a?(Hash)
    
    @constraint_data.all? do |field, field_constraints|
      field_value = value[field]
      
      if field_constraints[:required] && field_value.nil?
        return false
      end
      
      next true if field_value.nil? && !field_constraints[:required]
      
      # Check type
      if field_constraints[:type]
        temp_constraint = TypeConstraint.new(field, :type, field_constraints[:type])
        return false unless temp_constraint.satisfies?(field_value)
      end
      
      # Check range
      if field_constraints[:range]
        temp_constraint = TypeConstraint.new(field, :range, field_constraints[:range])
        return false unless temp_constraint.satisfies?(field_value)
      end
      
      # Check pattern
      if field_constraints[:pattern]
        temp_constraint = TypeConstraint.new(field, :pattern, field_constraints[:pattern])
        return false unless temp_constraint.satisfies?(field_value)
      end
      
      true
    end
  end

  def satisfies_composite?(value)
    @constraint_data.all? do |sub_constraint|
      temp_constraint = TypeConstraint.new(@variable, sub_constraint[:type], sub_constraint[:data])
      temp_constraint.satisfies?(value)
    end
  end

  def constraint_message
    case @constraint_type
    when :type
      "Expected #{@constraint_data}, got #{value.class.name}"
    when :range
      "Expected value in range #{@constraint_data}"
    when :pattern
      "Expected value matching pattern #{@constraint_data}"
    else
      "Constraint violation"
    end
  end
end


class ConstraintConflictError < StandardError; end
class ConstraintViolationError < StandardError; end