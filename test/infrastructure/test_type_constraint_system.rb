require_relative '../helpers/test_helper'
require_relative '../../src/reasoning/type_constraint_system'

class TestTypeConstraintSystem < Minitest::Test
  def setup
    @constraint_system = TypeConstraintSystem.new
    @event_log = []
    
    # Subscribe to type constraint events for testing using the PatlangObject event system
    @constraint_system.on_event(:constraint_created) { |event| @event_log << event[:data].merge(event_type: :constraint_created) }
    @constraint_system.on_event(:constraint_validated) { |event| @event_log << event[:data].merge(event_type: :constraint_validated) }
    @constraint_system.on_event(:constraint_violated) { |event| @event_log << event[:data].merge(event_type: :constraint_violated) }
    @constraint_system.on_event(:type_refined) { |event| @event_log << event[:data].merge(event_type: :type_refined) }
    @constraint_system.on_event(:propagation_started) { |event| @event_log << event[:data].merge(event_type: :propagation_started) }
    @constraint_system.on_event(:propagation_completed) { |event| @event_log << event[:data].merge(event_type: :propagation_completed) }
  end

  # === Basic Constraint Creation Tests ===

  def test_create_simple_type_constraint
    constraint = @constraint_system.create_constraint("x", :type, :Number)
    
    assert_instance_of TypeConstraint, constraint
    assert_equal "x", constraint.variable
    assert_equal :type, constraint.constraint_type
    assert_equal :Number, constraint.constraint_data
    assert_event_fired(:constraint_created, variable: "x", constraint_type: :type)
  end

  def test_create_range_constraint
    constraint = @constraint_system.create_constraint("age", :range, { min: 0, max: 150 })
    
    assert_instance_of TypeConstraint, constraint
    assert_equal "age", constraint.variable
    assert_equal :range, constraint.constraint_type
    assert_equal({ min: 0, max: 150 }, constraint.constraint_data)
    assert_event_fired(:constraint_created, variable: "age", constraint_type: :range)
  end

  def test_create_pattern_constraint
    email_pattern = /\w+@\w+\.\w+/
    constraint = @constraint_system.create_constraint("email", :pattern, email_pattern)
    
    assert_instance_of TypeConstraint, constraint
    assert_equal "email", constraint.variable
    assert_equal :pattern, constraint.constraint_type
    assert_equal email_pattern, constraint.constraint_data
  end

  def test_create_structural_constraint
    person_structure = {
      name: { type: :String, required: true },
      age: { type: :Number, range: { min: 0, max: 150 } },
      email: { type: :String, pattern: /\w+@\w+\.\w+/ }
    }
    
    constraint = @constraint_system.create_constraint("person", :structural, person_structure)
    
    assert_instance_of TypeConstraint, constraint
    assert_equal "person", constraint.variable
    assert_equal :structural, constraint.constraint_type
    assert_equal person_structure, constraint.constraint_data
  end

  def test_create_custom_constraint_with_predicate
    even_predicate = ->(value) { value.is_a?(Integer) && value.even? }
    constraint = @constraint_system.create_constraint("even_num", :custom, even_predicate)
    
    assert_instance_of TypeConstraint, constraint
    assert_equal "even_num", constraint.variable
    assert_equal :custom, constraint.constraint_type
    assert_equal even_predicate, constraint.constraint_data
  end

  # === Constraint Validation Tests ===

  def test_type_constraint_validates_correct_values
    constraint = @constraint_system.create_constraint("x", :type, :Number)
    
    assert constraint.satisfies?(42), "Integer should satisfy Number constraint"
    assert constraint.satisfies?(3.14), "Float should satisfy Number constraint"
    refute constraint.satisfies?("hello"), "String should not satisfy Number constraint"
    refute constraint.satisfies?([1, 2, 3]), "Array should not satisfy Number constraint"
    
    # Test event firing through the constraint system
    @constraint_system.satisfies_all_constraints?("x", 42)
    assert_event_fired(:constraint_validated, variable: "x", success: true)
  end

  def test_range_constraint_validates_correct_values
    constraint = @constraint_system.create_constraint("age", :range, { min: 0, max: 150 })
    
    assert constraint.satisfies?(25), "25 should satisfy age range constraint"
    assert constraint.satisfies?(0), "0 should satisfy age range constraint (boundary)"
    assert constraint.satisfies?(150), "150 should satisfy age range constraint (boundary)"
    refute constraint.satisfies?(-5), "-5 should not satisfy age range constraint"
    refute constraint.satisfies?(200), "200 should not satisfy age range constraint"
  end

  def test_pattern_constraint_validates_correct_values
    email_pattern = /\w+@\w+\.\w+/
    constraint = @constraint_system.create_constraint("email", :pattern, email_pattern)
    
    assert constraint.satisfies?("john@example.com"), "Valid email should satisfy pattern"
    assert constraint.satisfies?("test123@domain.org"), "Valid email with numbers should satisfy pattern"
    refute constraint.satisfies?("invalid-email"), "Invalid email should not satisfy pattern"
    refute constraint.satisfies?("@example.com"), "Email without username should not satisfy pattern"
  end

  def test_structural_constraint_validates_correct_values
    person_structure = {
      name: { type: :String, required: true },
      age: { type: :Number, range: { min: 0, max: 150 } },
      email: { type: :String, pattern: /\w+@\w+\.\w+/ }
    }
    constraint = @constraint_system.create_constraint("person", :structural, person_structure)
    
    valid_person = {
      name: "John Doe",
      age: 30,
      email: "john@example.com"
    }
    
    invalid_person_age = {
      name: "Jane Doe",
      age: -5,  # Invalid age
      email: "jane@example.com"
    }
    
    invalid_person_email = {
      name: "Bob Smith",
      age: 25,
      email: "invalid-email"  # Invalid email format
    }
    
    missing_required_field = {
      age: 30,
      email: "test@example.com"
      # Missing required 'name' field
    }
    
    assert constraint.satisfies?(valid_person), "Valid person should satisfy structural constraint"
    refute constraint.satisfies?(invalid_person_age), "Person with invalid age should not satisfy constraint"
    refute constraint.satisfies?(invalid_person_email), "Person with invalid email should not satisfy constraint"
    refute constraint.satisfies?(missing_required_field), "Person missing required field should not satisfy constraint"
  end

  def test_custom_constraint_validates_correct_values
    even_predicate = ->(value) { value.is_a?(Integer) && value.even? }
    constraint = @constraint_system.create_constraint("even_num", :custom, even_predicate)
    
    assert constraint.satisfies?(2), "2 should satisfy even number constraint"
    assert constraint.satisfies?(42), "42 should satisfy even number constraint"
    refute constraint.satisfies?(3), "3 should not satisfy even number constraint"
    refute constraint.satisfies?("hello"), "String should not satisfy even number constraint"
  end

  # === Constraint Violation Tests ===

  def test_constraint_violation_provides_helpful_error_message
    constraint = @constraint_system.create_constraint("x", :type, :Number)
    
    result = constraint.validate("hello")
    refute result.success?, "Validation should fail for string against Number constraint"
    assert_includes result.error_message, "expected Number", "Error message should mention expected type"
    assert_includes result.error_message, "got String", "Error message should mention actual type"
    assert_includes result.error_message, "hello", "Error message should mention actual value"
  end

  def test_range_constraint_violation_provides_helpful_error_message
    constraint = @constraint_system.create_constraint("age", :range, { min: 0, max: 150 })
    
    result = constraint.validate(-5)
    refute result.success?, "Validation should fail for -5 against age range"
    assert_includes result.error_message, "range 0..150", "Error message should mention valid range"
    assert_includes result.error_message, "-5", "Error message should mention actual value"
  end

  def test_structural_constraint_violation_provides_detailed_error_message
    person_structure = {
      name: { type: :String, required: true },
      age: { type: :Number, range: { min: 0, max: 150 } }
    }
    constraint = @constraint_system.create_constraint("person", :structural, person_structure)
    
    invalid_person = {
      name: 123,  # Should be String
      age: -5     # Should be in range
    }
    
    result = constraint.validate(invalid_person)
    refute result.success?, "Validation should fail for invalid person"
    assert_includes result.error_message, "name", "Error message should mention name field"
    assert_includes result.error_message, "age", "Error message should mention age field"
  end

  # === Multiple Constraints on Same Variable Tests ===

  def test_multiple_constraints_on_same_variable
    # Add both type and range constraints to the same variable
    type_constraint = @constraint_system.create_constraint("x", :type, :Number)
    range_constraint = @constraint_system.create_constraint("x", :range, { min: 1, max: 100 })
    
    # Value must satisfy both constraints
    assert @constraint_system.satisfies_all_constraints?("x", 50), "50 should satisfy both type and range"
    refute @constraint_system.satisfies_all_constraints?("x", "hello"), "String should fail type constraint"
    refute @constraint_system.satisfies_all_constraints?("x", 200), "200 should fail range constraint"
    refute @constraint_system.satisfies_all_constraints?("x", -5), "-5 should fail range constraint"
  end

  def test_conflicting_constraints_detected
    # Create conflicting constraints
    @constraint_system.create_constraint("x", :type, :Number)
    @constraint_system.create_constraint("x", :type, :String)
    
    conflicts = @constraint_system.detect_conflicts("x")
    refute conflicts.empty?, "Should detect conflicting type constraints"
    assert_includes conflicts.first[:description], "conflicting type constraints", "Should describe the conflict"
  end

  # === Constraint Propagation Network Tests ===

  def test_constraint_propagation_updates_related_variables
    # Create related constraints: if x = y and x :: Number, then y :: Number
    @constraint_system.create_constraint("x", :type, :Number)
    @constraint_system.add_equality_relationship("x", "y")
    
    # Propagation should infer that y is also a Number
    @constraint_system.propagate_constraints
    
    y_constraints = @constraint_system.get_constraints("y")
    assert y_constraints.any? { |c| c.constraint_type == :type && c.constraint_data == :Number },
           "y should have inferred Number type constraint"
    
    assert_event_fired(:propagation_started)
    assert_event_fired(:propagation_completed)
    assert_event_fired(:type_refined, variable: "y", new_type: :Number)
  end

  def test_constraint_propagation_with_unification
    # Create constraints and unify variables
    @constraint_system.create_constraint("x", :type, :Number)
    @constraint_system.create_constraint("y", :range, { min: 1, max: 100 })
    
    # Unify x and y
    unification_result = @constraint_system.unify_variables("x", "y")
    assert unification_result.success?, "Should be able to unify x and y"
    
    # Both variables should now have both constraints
    assert @constraint_system.satisfies_all_constraints?("x", 50), "x should satisfy both constraints"
    assert @constraint_system.satisfies_all_constraints?("y", 50), "y should satisfy both constraints"
    refute @constraint_system.satisfies_all_constraints?("x", "hello"), "x should fail type constraint"
    refute @constraint_system.satisfies_all_constraints?("y", 200), "y should fail range constraint"
  end

  def test_propagation_handles_constraint_conflicts
    # Create constraints that will conflict during propagation
    @constraint_system.create_constraint("x", :type, :Number)
    @constraint_system.create_constraint("y", :type, :String)
    
    # Try to unify x and y (should fail due to type conflict)
    unification_result = @constraint_system.unify_variables("x", "y")
    refute unification_result.success?, "Should not be able to unify Number and String variables"
    assert_includes unification_result.error_message, "type conflict", "Error should mention type conflict"
  end

  def test_propagation_performance_scales_with_network_size
    # Create a network of related variables
    100.times do |i|
      @constraint_system.create_constraint("var_#{i}", :type, :Number)
      if i > 0
        @constraint_system.add_equality_relationship("var_#{i-1}", "var_#{i}")
      end
    end
    
    start_time = Time.now
    @constraint_system.propagate_constraints
    duration = Time.now - start_time
    
    assert duration < 1.0, "Propagation of 100 variables should complete in under 1 second, took #{duration}s"
  end

  # === Integration with PatlangObject System Tests ===

  def test_constraints_integrate_with_object_system
    # Create a PatlangObject and add constraints to it
    obj = PatlangObject.create_number(42)
    constraint = @constraint_system.create_constraint(obj.object_id.to_s, :type, :Number)
    
    assert constraint.satisfies?(obj.raw_value), "Constraint should be satisfied by object's value"
    assert constraint.source_object.is_a?(PatlangObject), "Constraint should reference source object"
  end

  def test_constraints_respect_patlang_object_metadata
    obj = PatlangObject.create_string("hello")
    obj.set_metadata(:user_type, :email)
    
    # Create constraint based on metadata
    if obj.get_metadata(:user_type) == :email
      constraint = @constraint_system.create_constraint(obj.object_id.to_s, :pattern, /\w+@\w+\.\w+/)
      refute constraint.satisfies?(obj.raw_value), "String 'hello' should not satisfy email pattern"
    end
  end

  def test_constraint_cleanup_on_object_destruction
    obj = PatlangObject.create_number(42)
    constraint = @constraint_system.create_constraint(obj.object_id.to_s, :type, :Number)
    
    # Simulate object destruction by firing the destruction event
    @constraint_system.fire_event(:object_destroyed, {
      object_id: obj.object_id,
      timestamp: Time.now
    })
    
    # Constraint should be automatically cleaned up
    remaining_constraints = @constraint_system.get_constraints(obj.object_id.to_s)
    assert remaining_constraints.empty?, "Constraints should be cleaned up when object is destroyed"
  end

  # === Error Handling Tests ===

  def test_create_constraint_with_invalid_variable_name
    error = assert_raises(ArgumentError) do
      @constraint_system.create_constraint(nil, :type, :Number)
    end
    assert_includes error.message.downcase, "variable name", "Error should mention variable name"
  end

  def test_create_constraint_with_invalid_constraint_type
    error = assert_raises(ArgumentError) do
      @constraint_system.create_constraint("x", :invalid_type, :Number)
    end
    assert_includes error.message.downcase, "constraint type", "Error should mention constraint type"
  end

  def test_create_constraint_with_invalid_constraint_data
    error = assert_raises(ArgumentError) do
      @constraint_system.create_constraint("x", :range, "invalid_range_data")
    end
    assert_includes error.message.downcase, "range constraint", "Error should mention range constraint format"
  end

  # === Performance Tests ===

  def test_constraint_creation_performance
    start_time = Time.now
    
    1000.times do |i|
      @constraint_system.create_constraint("var_#{i}", :type, :Number)
    end
    
    duration = Time.now - start_time
    assert duration < 1.0, "Creating 1000 constraints should complete in under 1 second, took #{duration}s"
  end

  def test_constraint_validation_performance
    # Create constraint once
    constraint = @constraint_system.create_constraint("x", :type, :Number)
    
    start_time = Time.now
    
    # Validate many times
    1000.times do |i|
      constraint.satisfies?(i)
    end
    
    duration = Time.now - start_time
    assert duration < 0.5, "1000 constraint validations should complete in under 0.5 seconds, took #{duration}s"
  end

  def test_memory_usage_bounded_during_constraint_operations
    GC.start
    initial_objects = ObjectSpace.count_objects[:TOTAL]
    
    # Create many constraints and validate them
    500.times do |i|
      constraint = @constraint_system.create_constraint("var_#{i}", :type, :Number)
      constraint.satisfies?(i)
      constraint.satisfies?("invalid")
    end
    
    GC.start
    final_objects = ObjectSpace.count_objects[:TOTAL]
    object_increase = final_objects - initial_objects
    
    # Should not create excessive objects (reasonable bound for 500 operations)
    assert object_increase < 20000, "Memory usage increased by #{object_increase} objects, should be < 20000"
  end

  private

  def assert_event_fired(event_type, **expected_data)
    matching_events = @event_log.select { |e| e[:event_type] == event_type }
    assert !matching_events.empty?, "Expected #{event_type} event to fire"
    
    if expected_data.any?
      matching_event = matching_events.find do |event|
        expected_data.all? { |key, value| event[key] == value }
      end
      assert matching_event, "Expected #{event_type} event with data #{expected_data}"
    end
  end
end
