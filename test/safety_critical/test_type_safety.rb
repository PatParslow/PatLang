# frozen_string_literal: true

require_relative '../helpers/test_helper'

class TestTypeSafety < Minitest::Test
  def setup
    @type_system = MockTypeSystem.new
    @mock_evaluator = MockEvaluator.new
  end

  # Test TypeConstraint creation and basic functionality
  def test_type_constraint_creation
    # Test basic type constraint creation
    constraint = TypeConstraint.new(:x, :type, :number)
    
    assert_equal :x, constraint.variable
    assert_equal :type, constraint.constraint_type
    assert_equal :number, constraint.constraint_data
    assert_equal [], constraint.conditions
  end

  def test_type_constraint_with_conditions
    conditions = [:positive, :integer]
    constraint = TypeConstraint.new(:x, :type, :number, conditions)
    
    assert_equal :x, constraint.variable
    assert_equal :type, constraint.constraint_type
    assert_equal :number, constraint.constraint_data
    assert_equal conditions, constraint.conditions
  end

  def test_type_constraint_with_options
    options = { metadata: { strict: true } }
    constraint = TypeConstraint.new(:x, :type, :number, **options)
    
    assert_equal :x, constraint.variable
    assert_equal :type, constraint.constraint_type
    assert_equal :number, constraint.constraint_data
  end

  # Test type constraint validation
  def test_type_constraint_validation_numbers
    constraint = TypeConstraint.new(:x, :type, :number)
    
    # Should satisfy numeric values
    assert constraint.satisfies?(42)
    assert constraint.satisfies?(3.14)
    assert constraint.satisfies?(0)
    assert constraint.satisfies?(-5)
    
    # Should not satisfy non-numeric values
    assert_not constraint.satisfies?("string")
    assert_not constraint.satisfies?(true)
    assert_not constraint.satisfies?(nil)
    assert_not constraint.satisfies?([])
    assert_not constraint.satisfies?({})
  end

  def test_type_constraint_validation_strings
    constraint = TypeConstraint.new(:x, :type, :string)
    
    # Should satisfy string values
    assert constraint.satisfies?("hello")
    assert constraint.satisfies?("")
    assert constraint.satisfies?("123")
    
    # Should not satisfy non-string values
    assert_not constraint.satisfies?(42)
    assert_not constraint.satisfies?(true)
    assert_not constraint.satisfies?(nil)
    assert_not constraint.satisfies?([])
  end

  def test_range_constraint_validation
    constraint = TypeConstraint.new(:x, :range, 1..10)
    
    # Should satisfy values in range
    assert constraint.satisfies?(1)
    assert constraint.satisfies?(5)
    assert constraint.satisfies?(10)
    
    # Should not satisfy values outside range
    assert_not constraint.satisfies?(0)
    assert_not constraint.satisfies?(11)
    assert_not constraint.satisfies?(-1)
    assert_not constraint.satisfies?("5")
  end

  def test_pattern_constraint_validation
    constraint = TypeConstraint.new(:x, :pattern, /^[a-z]+$/)
    
    # Should satisfy matching patterns
    assert constraint.satisfies?("hello")
    assert constraint.satisfies?("world")
    assert constraint.satisfies?("abc")
    
    # Should not satisfy non-matching patterns
    assert_not constraint.satisfies?("Hello")  # Capital letter
    assert_not constraint.satisfies?("hello123")  # Numbers
    assert_not constraint.satisfies?("hello!")  # Special chars
    assert_not constraint.satisfies?(123)  # Not a string
  end

  def test_structural_constraint_validation
    # Test structural constraints for object-like structures
    constraint_data = { required_keys: [:name, :age], optional_keys: [:email] }
    constraint = TypeConstraint.new(:x, :structural, constraint_data)
    
    # Should satisfy objects with required keys
    valid_obj = { name: "John", age: 30 }
    assert constraint.satisfies?(valid_obj)
    
    valid_obj_with_optional = { name: "John", age: 30, email: "john@example.com" }
    assert constraint.satisfies?(valid_obj_with_optional)
    
    # Should not satisfy objects missing required keys
    invalid_obj = { name: "John" }  # Missing age
    assert_not constraint.satisfies?(invalid_obj)
    
    empty_obj = {}
    assert_not constraint.satisfies?(empty_obj)
  end

  def test_composite_constraint_validation
    # Test composite constraints (AND/OR logic)
    constraint_data = {
      type: :and,
      constraints: [
        { type: :type, data: :number },
        { type: :range, data: 1..100 }
      ]
    }
    constraint = TypeConstraint.new(:x, :composite, constraint_data)
    
    # Should satisfy values that meet all constraints
    assert constraint.satisfies?(50)
    assert constraint.satisfies?(1)
    assert constraint.satisfies?(100)
    
    # Should not satisfy values that fail any constraint
    assert_not constraint.satisfies?(0)      # Outside range
    assert_not constraint.satisfies?(101)    # Outside range
    assert_not constraint.satisfies?("50")   # Wrong type
  end

  def test_custom_constraint_validation
    # Test custom constraint with lambda
    constraint_data = lambda { |value| value.is_a?(Integer) && value.even? }
    constraint = TypeConstraint.new(:x, :custom, constraint_data)
    
    # Should satisfy even integers
    assert constraint.satisfies?(2)
    assert constraint.satisfies?(4)
    assert constraint.satisfies?(0)
    assert constraint.satisfies?(-2)
    
    # Should not satisfy odd integers or non-integers
    assert_not constraint.satisfies?(1)
    assert_not constraint.satisfies?(3)
    assert_not constraint.satisfies?(2.5)
    assert_not constraint.satisfies?("2")
  end

  # Test constraint validation with exceptions
  def test_constraint_validation_with_exceptions
    constraint = TypeConstraint.new(:x, :type, :number)
    
    # Should pass validation for valid values
    assert constraint.validate!(42)
    assert constraint.validate!(3.14)
    
    # Should raise TypeConstraintViolation for invalid values
    assert_raises(TypeConstraintViolation) do
      constraint.validate!("string")
    end
    
    assert_raises(TypeConstraintViolation) do
      constraint.validate!(nil)
    end
  end

  def test_type_constraint_violation_details
    constraint = TypeConstraint.new(:x, :type, :number)
    
    begin
      constraint.validate!("invalid")
      assert false, "Expected TypeConstraintViolation"
    rescue TypeConstraintViolation => e
      assert_equal :x, e.variable
      assert_equal "invalid", e.value
      assert_includes e.message, "Variable x"
    end
  end

  # Test TypeConstraintSystem functionality
  def test_type_constraint_system_creation
    # Test that we can create a constraint system
    # Using mock since we may not have the actual implementation loaded
    system = @type_system
    
    assert_respond_to system, :create_constraint
    assert_respond_to system, :validate
  end

  def test_constraint_system_constraint_creation
    system = @type_system
    
    # Should be able to create constraints
    constraint = system.create_constraint(:type, { variable: :x, type: :number })
    assert_not_nil constraint
  end

  def test_constraint_system_validation
    system = @type_system
    
    # Create a constraint
    system.create_constraint(:type, { variable: :x, type: :number })
    
    # Should validate values against constraints
    assert system.validate(42, :type)
    assert system.validate(3.14, :type)
  end

  # Test constraint conditions
  def test_constraint_has_condition
    # Constraint without conditions
    constraint = TypeConstraint.new(:x, :type, :number)
    assert_not constraint.has_condition?
    
    # Constraint with array conditions
    constraint_with_conditions = TypeConstraint.new(:x, :type, :number, [:positive])
    assert constraint_with_conditions.has_condition?
    
    # Constraint with string condition
    constraint_with_string = TypeConstraint.new(:x, :type, :number, "must be positive")
    assert constraint_with_string.has_condition?
  end

  def test_constraint_metadata_respect
    # Test constraint respects object metadata
    constraint = TypeConstraint.new(:x, :type, :number)
    
    # Mock object with metadata
    mock_object = Object.new
    def mock_object.respond_to?(method)
      method == :get_metadata || super
    end
    def mock_object.get_metadata(key)
      key == :type_hint ? :number : nil
    end
    
    assert constraint.respects_metadata?(mock_object)
    
    # Mock object with conflicting metadata
    mock_object_conflict = Object.new
    def mock_object_conflict.respond_to?(method)
      method == :get_metadata || super
    end
    def mock_object_conflict.get_metadata(key)
      key == :type_hint ? :string : nil
    end
    
    assert_not constraint.respects_metadata?(mock_object_conflict)
  end

  # Test constraint string representation
  def test_constraint_string_representation
    type_constraint = TypeConstraint.new(:x, :type, :number)
    assert_equal "x :: number", type_constraint.to_s
    
    range_constraint = TypeConstraint.new(:y, :range, 1..10)
    assert_equal "y in 1..10", range_constraint.to_s
    
    pattern_constraint = TypeConstraint.new(:z, :pattern, /\d+/)
    assert_includes pattern_constraint.to_s, "z matches"
  end

  # Test edge cases and boundary conditions
  def test_constraint_edge_cases
    # Test nil values
    constraint = TypeConstraint.new(:x, :type, :number)
    assert_not constraint.satisfies?(nil)
    
    # Test boundary values for ranges
    range_constraint = TypeConstraint.new(:x, :range, 1..10)
    assert range_constraint.satisfies?(1)   # Lower bound
    assert range_constraint.satisfies?(10)  # Upper bound
    assert_not range_constraint.satisfies?(0.99)  # Just below
    assert_not range_constraint.satisfies?(10.01)  # Just above
  end

  def test_constraint_with_complex_data_structures
    # Test constraints with complex data structures
    constraint_data = {
      required_keys: [:name, :age],
      optional_keys: [:email, :phone],
      type_constraints: {
        name: :string,
        age: :number,
        email: :string
      }
    }
    
    constraint = TypeConstraint.new(:user, :structural, constraint_data)
    
    # Valid complex structure
    valid_user = {
      name: "John Doe",
      age: 30,
      email: "john@example.com"
    }
    assert constraint.satisfies?(valid_user)
    
    # Invalid complex structure
    invalid_user = {
      name: "John Doe",
      age: "thirty"  # Wrong type
    }
    assert_not constraint.satisfies?(invalid_user)
  end

  # Test type coercion scenarios
  def test_type_coercion_handling
    # Test scenarios where type coercion might be attempted
    number_constraint = TypeConstraint.new(:x, :type, :number)
    
    # These should not satisfy without explicit coercion
    assert_not number_constraint.satisfies?("42")
    assert_not number_constraint.satisfies?("3.14")
    assert_not number_constraint.satisfies?(true)  # In some languages, true -> 1
    assert_not number_constraint.satisfies?(false) # In some languages, false -> 0
  end

  def test_constraint_validation_performance
    # Test that constraint validation doesn't have performance issues
    constraint = TypeConstraint.new(:x, :type, :number)
    
    # Validate many values quickly
    start_time = Time.now
    
    1000.times do |i|
      constraint.satisfies?(i)
      constraint.satisfies?("string#{i}")
    end
    
    elapsed = Time.now - start_time
    assert_operator elapsed, :<, 1.0, "Constraint validation should be fast"
  end

  # Test constraint system integration
  def test_constraint_system_integration
    # Test integration between different constraint types
    system = @type_system
    
    # Create multiple constraints for the same variable
    system.create_constraint(:type, { variable: :x, type: :number })
    system.create_constraint(:range, { variable: :x, range: 1..100 })
    
    # Should validate against all constraints
    assert system.validate(50, :type)
    assert system.validate(50, :range)
  end

  def test_constraint_error_messages
    # Test that constraint violations provide helpful error messages
    constraint = TypeConstraint.new(:username, :pattern, /^[a-zA-Z0-9_]+$/)
    
    begin
      constraint.validate!("invalid-username!")
      assert false, "Expected validation to fail"
    rescue TypeConstraintViolation => e
      assert_includes e.message, "username"
      assert_includes e.message, "Variable username"
    end
  end

  # Test constraint system with complex scenarios
  def test_complex_constraint_scenario
    # Simulate a complex type checking scenario
    user_constraint = TypeConstraint.new(:user, :structural, {
      required_keys: [:id, :name, :email],
      type_constraints: {
        id: :number,
        name: :string,
        email: :string
      }
    })
    
    # Valid user
    valid_user = {
      id: 1,
      name: "John Doe",
      email: "john@example.com"
    }
    assert user_constraint.satisfies?(valid_user)
    
    # Invalid user - missing required key
    invalid_user_missing = {
      id: 1,
      name: "John Doe"
      # Missing email
    }
    assert_not user_constraint.satisfies?(invalid_user_missing)
    
    # Invalid user - wrong type
    invalid_user_type = {
      id: "1",  # Should be number
      name: "John Doe",
      email: "john@example.com"
    }
    assert_not user_constraint.satisfies?(invalid_user_type)
  end

  def test_constraint_system_error_handling
    # Test error handling in constraint system
    system = @type_system
    
    # Should handle invalid constraint types gracefully
    assert_nothing_raised do
      system.create_constraint(:invalid_type, { variable: :x })
    end
    
    # Should handle validation of invalid values
    assert_nothing_raised do
      system.validate(nil, :invalid_type)
    end
  end
end