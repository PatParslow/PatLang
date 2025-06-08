# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../helpers/test_helper'
require_relative '../../src/reasoning/type_constraint'
require_relative '../../src/reasoning/reasoning_coordinator'

# Comprehensive tests for type constraint syntax and semantics in the Patlang language
class TestTypeConstraintSyntax < Minitest::Test
  def setup
    @evaluator = MockEvaluator.new
    @coordinator = ReasoningCoordinator.new(@evaluator)
    @coordinator.enable_reasoning_mode
    @event_log = []
    
    # Subscribe to constraint events
    @coordinator.on_event(:constraint_declared) { |e| @event_log << e }
    @coordinator.on_event(:type_refined) { |e| @event_log << e }
  end

  # === Basic Type Constraint Syntax Tests ===

  def test_numeric_type_constraint_syntax
    # Test: variable :: Number
    constraint = @coordinator.create_constraint(:age, :type, :Number)
    
    assert_equal :age, constraint.variable
    assert_equal :type, constraint.constraint_type
    assert_equal :Number, constraint.constraint_data
    
    # Validate constraint behavior
    assert constraint.satisfies?(25)
    assert constraint.satisfies?(3.14)
    refute constraint.satisfies?("25")
    refute constraint.satisfies?(true)
  end

  def test_string_type_constraint_syntax
    # Test: name :: String
    constraint = @coordinator.create_constraint(:name, :type, :String)
    
    assert constraint.satisfies?("Alice")
    assert constraint.satisfies?("")
    refute constraint.satisfies?(123)
    refute constraint.satisfies?(nil)
  end

  def test_boolean_type_constraint_syntax
    # Test: flag :: Boolean
    constraint = @coordinator.create_constraint(:flag, :type, :Boolean)
    
    assert constraint.satisfies?(true)
    assert constraint.satisfies?(false)
    refute constraint.satisfies?("true")
    refute constraint.satisfies?(1)
    refute constraint.satisfies?(0)
  end

  def test_array_type_constraint_syntax
    # Test: items :: Array
    constraint = @coordinator.create_constraint(:items, :type, :Array)
    
    assert constraint.satisfies?([1, 2, 3])
    assert constraint.satisfies?([])
    assert constraint.satisfies?(["a", "b", "c"])
    refute constraint.satisfies?("not an array")
    refute constraint.satisfies?({a: 1, b: 2})
  end

  def test_hash_type_constraint_syntax
    # Test: data :: Hash / data :: Object
    constraint = @coordinator.create_constraint(:data, :type, :Hash)
    
    assert constraint.satisfies?({name: "Alice", age: 30})
    assert constraint.satisfies?({})
    refute constraint.satisfies?([1, 2, 3])
    refute constraint.satisfies?("not a hash")
  end

  def test_symbol_type_constraint_syntax
    # Test: status :: Symbol
    constraint = @coordinator.create_constraint(:status, :type, :Symbol)
    
    assert constraint.satisfies?(:active)
    assert constraint.satisfies?(:inactive)
    refute constraint.satisfies?("active")
    refute constraint.satisfies?(123)
  end

  # === Range Constraint Syntax Tests ===

  def test_numeric_range_constraint_syntax
    # Test: age in 0..120
    constraint = @coordinator.create_constraint(:age, :range, 0..120)
    
    assert_equal :age, constraint.variable
    assert_equal :range, constraint.constraint_type
    assert_equal 0..120, constraint.constraint_data
    
    # Validate range behavior
    assert constraint.satisfies?(0)
    assert constraint.satisfies?(25)
    assert constraint.satisfies?(120)
    refute constraint.satisfies?(-1)
    refute constraint.satisfies?(121)
  end

  def test_exclusive_range_constraint_syntax
    # Test: score in 0...100
    constraint = @coordinator.create_constraint(:score, :range, 0...100)
    
    assert constraint.satisfies?(0)
    assert constraint.satisfies?(50)
    assert constraint.satisfies?(99)
    refute constraint.satisfies?(100)
    refute constraint.satisfies?(-1)
  end

  def test_floating_point_range_constraint_syntax
    # Test: temperature in -273.15..1000.0
    constraint = @coordinator.create_constraint(:temperature, :range, -273.15..1000.0)
    
    assert constraint.satisfies?(-273.15)
    assert constraint.satisfies?(0.0)
    assert constraint.satisfies?(100.5)
    assert constraint.satisfies?(1000.0)
    refute constraint.satisfies?(-300.0)
    refute constraint.satisfies?(1500.0)
  end

  # === Pattern Constraint Syntax Tests ===

  def test_email_pattern_constraint_syntax
    # Test: email matches /regex/
    email_pattern = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
    constraint = @coordinator.create_constraint(:email, :pattern, email_pattern)
    
    assert_equal :email, constraint.variable
    assert_equal :pattern, constraint.constraint_type
    assert_equal email_pattern, constraint.constraint_data
    
    # Validate pattern behavior
    assert constraint.satisfies?("user@example.com")
    assert constraint.satisfies?("test.email@domain.co.uk")
    refute constraint.satisfies?("invalid-email")
    refute constraint.satisfies?("user@")
    refute constraint.satisfies?("@domain.com")
  end

  def test_phone_pattern_constraint_syntax
    # Test: phone matches /phone regex/
    phone_pattern = /\A\+?[\d\s\-\(\)]{10,15}\z/
    constraint = @coordinator.create_constraint(:phone, :pattern, phone_pattern)
    
    assert constraint.satisfies?("+1 (555) 123-4567")
    assert constraint.satisfies?("555-123-4567")
    assert constraint.satisfies?("+44 20 7946 0958")
    refute constraint.satisfies?("123")
    refute constraint.satisfies?("not-a-phone")
  end

  def test_alphanumeric_pattern_constraint_syntax
    # Test: username matches /^[a-zA-Z0-9_]+$/
    username_pattern = /\A[a-zA-Z0-9_]+\z/
    constraint = @coordinator.create_constraint(:username, :pattern, username_pattern)
    
    assert constraint.satisfies?("user123")
    assert constraint.satisfies?("alice_bob")
    assert constraint.satisfies?("USER_NAME_2024")
    refute constraint.satisfies?("user-name")
    refute constraint.satisfies?("user name")
    refute constraint.satisfies?("user@domain")
  end

  # === Structural Constraint Syntax Tests ===

  def test_simple_object_structure_constraint_syntax
    # Test: person :: { name: String, age: Number }
    structure = {
      name: { type: :String, required: true },
      age: { type: :Number, required: true }
    }
    constraint = @coordinator.create_constraint(:person, :structural, structure)
    
    assert_equal :person, constraint.variable
    assert_equal :structural, constraint.constraint_type
    assert_equal structure, constraint.constraint_data
    
    # Validate structural behavior
    valid_person = { name: "Alice", age: 30 }
    invalid_missing_field = { name: "Bob" }
    invalid_wrong_type = { name: "Charlie", age: "thirty" }
    
    assert constraint.satisfies?(valid_person)
    refute constraint.satisfies?(invalid_missing_field)
    refute constraint.satisfies?(invalid_wrong_type)
  end

  def test_optional_fields_structure_constraint_syntax
    # Test: user :: { name: String!, email: String?, age: Number! }
    structure = {
      name: { type: :String, required: true },
      email: { type: :String, required: false },
      age: { type: :Number, required: true }
    }
    constraint = @coordinator.create_constraint(:user, :structural, structure)
    
    # Valid with all fields
    valid_complete = { name: "Alice", email: "alice@example.com", age: 25 }
    assert constraint.satisfies?(valid_complete)
    
    # Valid without optional field
    valid_partial = { name: "Bob", age: 30 }
    assert constraint.satisfies?(valid_partial)
    
    # Invalid missing required field
    invalid_missing_required = { email: "charlie@example.com", age: 35 }
    refute constraint.satisfies?(invalid_missing_required)
  end

  def test_nested_structure_constraint_syntax
    # Test: address :: { street: String, city: String, country: { name: String, code: String } }
    structure = {
      street: { type: :String, required: true },
      city: { type: :String, required: true },
      country: {
        type: :Hash,
        required: true,
        elements: {
          name: { type: :String, required: true },
          code: { type: :String, required: true }
        }
      }
    }
    constraint = @coordinator.create_constraint(:address, :structural, structure)
    
    valid_address = {
      street: "123 Main St",
      city: "Anytown",
      country: { name: "United States", code: "US" }
    }
    
    invalid_address = {
      street: "456 Oak Ave",
      city: "Somewhere",
      country: { name: "Canada" }  # Missing code
    }
    
    assert constraint.satisfies?(valid_address)
    refute constraint.satisfies?(invalid_address)
  end

  def test_array_elements_structure_constraint_syntax
    # Test: tags :: Array[String]
    structure = {
      tags: {
        type: :Array,
        required: true,
        elements: { type: :String }
      }
    }
    constraint = @coordinator.create_constraint(:document, :structural, structure)
    
    valid_doc = { tags: ["ruby", "programming", "testing"] }
    invalid_doc_mixed_types = { tags: ["ruby", 123, "testing"] }
    invalid_doc_wrong_type = { tags: "not an array" }
    
    assert constraint.satisfies?(valid_doc)
    refute constraint.satisfies?(invalid_doc_mixed_types)
    refute constraint.satisfies?(invalid_doc_wrong_type)
  end

  # === Composite Constraint Syntax Tests ===

  def test_multiple_type_constraints_syntax
    # Test: value :: Number in 0..100
    @coordinator.create_constraint(:value, :type, :Number)
    @coordinator.create_constraint(:value, :range, 0..100)
    
    constraint_system = @coordinator.instance_variable_get(:@constraint_system)
    
    # Should satisfy both constraints
    assert constraint_system.variable_satisfies?(:value, 50)
    assert constraint_system.variable_satisfies?(:value, 0)
    assert constraint_system.variable_satisfies?(:value, 100)
    
    # Should fail type constraint
    refute constraint_system.variable_satisfies?(:value, "50")
    
    # Should fail range constraint
    refute constraint_system.variable_satisfies?(:value, -10)
    refute constraint_system.variable_satisfies?(:value, 150)
  end

  def test_composite_constraint_syntax
    # Test: password :: String matches /regex/ length > 8
    sub_constraints = [
      { type: :type, data: :String },
      { type: :pattern, data: /\A(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[a-zA-Z\d]{8,}\z/ },
      { type: :custom, data: proc { |value| value.length >= 8 } }
    ]
    constraint = @coordinator.create_constraint(:password, :composite, sub_constraints)
    
    assert_equal :password, constraint.variable
    assert_equal :composite, constraint.constraint_data
    
    # Strong password that meets all criteria
    assert constraint.satisfies?("StrongPass123")
    
    # Fails pattern (no uppercase)
    refute constraint.satisfies?("weakpass123")
    
    # Fails length
    refute constraint.satisfies?("Short1")
    
    # Fails type
    refute constraint.satisfies?(12345678)
  end

  # === Custom Constraint Syntax Tests ===

  def test_proc_custom_constraint_syntax
    # Test: custom constraint with Proc
    validator = proc do |value|
      value.is_a?(String) && 
      value.length >= 6 && 
      value.length <= 20 &&
      /\A[a-zA-Z0-9_]+\z/.match?(value)
    end
    
    constraint = @coordinator.create_constraint(:username, :custom, validator)
    
    assert_equal :username, constraint.variable
    assert_equal :custom, constraint.constraint_type
    assert_equal validator, constraint.constraint_data
    
    # Valid usernames
    assert constraint.satisfies?("user123")
    assert constraint.satisfies?("alice_bob")
    assert constraint.satisfies?("valid_user_name_123")
    
    # Invalid usernames
    refute constraint.satisfies?("short")  # Too short
    refute constraint.satisfies?("this_username_is_way_too_long_to_be_valid")  # Too long
    refute constraint.satisfies?("user-name")  # Invalid characters
    refute constraint.satisfies?(123456)  # Wrong type
  end

  def test_method_custom_constraint_syntax
    # Test: custom constraint with Method
    def valid_percentage?(value)
      value.is_a?(Numeric) && value >= 0 && value <= 100
    end
    
    constraint = @coordinator.create_constraint(:percentage, :custom, method(:valid_percentage?))
    
    assert constraint.satisfies?(0)
    assert constraint.satisfies?(50.5)
    assert constraint.satisfies?(100)
    refute constraint.satisfies?(-10)
    refute constraint.satisfies?(150)
    refute constraint.satisfies?("50%")
  end

  # === Constraint Combination and Conflict Tests ===

  def test_compatible_constraint_combination
    # Test: age :: Number in 0..120
    @coordinator.create_constraint(:age, :type, :Number)
    @coordinator.create_constraint(:age, :range, 0..120)
    
    constraint_system = @coordinator.instance_variable_get(:@constraint_system)
    
    # Should work with valid values
    assert_nothing_raised do
      constraint_system.set_variable_value(:age, 25)
    end
    
    assert_equal 25, constraint_system.get_variable_value(:age)
  end

  def test_incompatible_constraint_conflict_detection
    # Test: conflicting type constraints
    @coordinator.create_constraint(:conflict_var, :type, :Number)
    
    error = assert_raises(ConstraintConflictError) do
      @coordinator.create_constraint(:conflict_var, :type, :String)
    end
    
    assert_includes error.message, "Type constraint conflict"
    assert_equal :conflict_var, error.variable
  end

  def test_incompatible_range_conflict_detection
    # Test: conflicting range constraints
    @coordinator.create_constraint(:range_var, :range, 0..50)
    
    error = assert_raises(ConstraintConflictError) do
      @coordinator.create_constraint(:range_var, :range, 100..200)
    end
    
    assert_includes error.message, "Range constraint conflict"
    assert_equal :range_var, error.variable
  end

  def test_overlapping_range_compatibility
    # Test: overlapping ranges should be compatible
    @coordinator.create_constraint(:overlap_var, :range, 0..100)
    
    assert_nothing_raised do
      @coordinator.create_constraint(:overlap_var, :range, 50..150)
    end
    
    constraints = @coordinator.instance_variable_get(:@constraint_system).get_constraints(:overlap_var)
    assert_equal 2, constraints.length
  end

  # === Constraint Validation and Error Messages Tests ===

  def test_type_constraint_violation_message
    constraint = @coordinator.create_constraint(:typed_var, :type, :Number)
    
    error = assert_raises(TypeConstraintViolation) do
      constraint.validate!("not a number")
    end
    
    assert_includes error.message, "Expected Number, got String"
    assert_equal :typed_var, error.variable
    assert_equal "not a number", error.value
  end

  def test_range_constraint_violation_message
    constraint = @coordinator.create_constraint(:ranged_var, :range, 1..10)
    
    error = assert_raises(TypeConstraintViolation) do
      constraint.validate!(15)
    end
    
    assert_includes error.message, "Expected value in range 1..10, got 15"
  end

  def test_pattern_constraint_violation_message
    pattern = /\A[a-z]+\z/
    constraint = @coordinator.create_constraint(:pattern_var, :pattern, pattern)
    
    error = assert_raises(TypeConstraintViolation) do
      constraint.validate!("UPPERCASE")
    end
    
    assert_includes error.message, "Expected value matching pattern"
    assert_includes error.message, "UPPERCASE"
  end

  def test_structural_constraint_violation_message
    structure = { name: { type: :String, required: true } }
    constraint = @coordinator.create_constraint(:struct_var, :structural, structure)
    
    error = assert_raises(TypeConstraintViolation) do
      constraint.validate!({ age: 30 })  # Missing required name field
    end
    
    assert_includes error.message, "Expected object with required structure"
  end

  # === Constraint String Representation Tests ===

  def test_type_constraint_string_representation
    constraint = @coordinator.create_constraint(:x, :type, :Number)
    
    assert_equal "x :: Number", constraint.to_s
    assert_includes constraint.inspect, "TypeConstraint"
    assert_includes constraint.inspect, "x :: Number"
  end

  def test_range_constraint_string_representation
    constraint = @coordinator.create_constraint(:age, :range, 18..65)
    
    assert_equal "age in 18..65", constraint.to_s
  end

  def test_pattern_constraint_string_representation
    pattern = /\A[a-z]+\z/
    constraint = @coordinator.create_constraint(:word, :pattern, pattern)
    
    expected = "word matches #{pattern}"
    assert_equal expected, constraint.to_s
  end

  def test_structural_constraint_string_representation
    structure = { name: { type: :String, required: true } }
    constraint = @coordinator.create_constraint(:person, :structural, structure)
    
    assert_equal "person :: Object{...}", constraint.to_s
  end

  # === Performance Tests for Constraint Syntax ===

  def test_constraint_creation_syntax_performance
    start_time = Time.now
    
    100.times do |i|
      @coordinator.create_constraint("perf_var_#{i}".to_sym, :type, :Number)
    end
    
    duration = Time.now - start_time
    assert_operator duration, :<, 0.1, "100 type constraint creations should complete in <100ms"
  end

  def test_constraint_validation_syntax_performance
    # Create various constraint types
    @coordinator.create_constraint(:num_var, :type, :Number)
    @coordinator.create_constraint(:range_var, :range, 0..1000)
    @coordinator.create_constraint(:pattern_var, :pattern, /\A[a-z]+\z/)
    
    constraint_system = @coordinator.instance_variable_get(:@constraint_system)
    
    start_time = Time.now
    
    1000.times do |i|
      constraint_system.variable_satisfies?(:num_var, i)
      constraint_system.variable_satisfies?(:range_var, i % 100)
      constraint_system.variable_satisfies?(:pattern_var, "test")
    end
    
    duration = Time.now - start_time
    assert_operator duration, :<, 0.2, "3000 constraint validations should complete in <200ms"
  end

  # === Integration with Language Semantics Tests ===

  def test_constraint_metadata_integration
    constraint = @coordinator.create_constraint(:meta_var, :type, :String, 
      metadata: { source: "user_input", validation_level: "strict" }
    )
    
    # Metadata should be preserved
    metadata = constraint.instance_variable_get(:@metadata)
    assert_equal "user_input", metadata[:source]
    assert_equal "strict", metadata[:validation_level]
  end

  def test_constraint_conditions_integration
    constraint = @coordinator.create_constraint(:cond_var, :type, :Number,
      conditions: ["value > 0", "value % 2 == 0"]
    )
    
    assert constraint.has_condition?
    conditions = constraint.instance_variable_get(:@conditions)
    assert_includes conditions, "value > 0"
    assert_includes conditions, "value % 2 == 0"
  end

  private

  # Mock evaluator for testing
  class MockEvaluator
    def object_mode_enabled?
      false
    end
  end
end