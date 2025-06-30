# frozen_string_literal: true

require_relative 'unification_engine'
require_relative '../exceptions'

# Type constraint classes for unified reasoning
# TypeConstraintSystem is defined in type_constraint_system.rb to avoid conflicts

# Individual type constraint
class TypeConstraint
  attr_reader :variable, :constraint_type, :constraint_data, :conditions

  def initialize(variable, constraint_type, constraint_data = nil, conditions_or_options = nil, **options)
  @variable = variable.to_sym
  @constraint_type = constraint_type.to_sym
  @constraint_data = constraint_data
  
  # Handle both old 4-argument style and new flexible style
  if conditions_or_options.is_a?(Array) || conditions_or_options.is_a?(Hash)
    if conditions_or_options.is_a?(Array)
      @conditions = conditions_or_options
      @metadata = options[:metadata] || {}
    else
      @conditions = conditions_or_options[:conditions] || []
      @metadata = conditions_or_options[:metadata] || {}
    end
  else
    @conditions = options[:conditions] || []
    @metadata = options[:metadata] || {}
  end
end

  # Check if a value satisfies this constraint
  def satisfies?(value)
    case @constraint_type
    when :type
      satisfies_type_constraint?(value)
    when :range
      satisfies_range_constraint?(value)
    when :pattern
      satisfies_pattern_constraint?(value)
    when :structural
      satisfies_structural_constraint?(value)
    when :composite
      satisfies_composite_constraint?(value)
    when :custom
      satisfies_custom_constraint?(value)
    else
      false
    end
  end

  # Validate a value, raising an exception if it doesn't satisfy
  def validate!(value)
    return true if satisfies?(value)
    
    raise TypeConstraintViolation.new(@variable, value, generate_error_message(value))
  end

  # Check if this constraint has additional conditions
  def has_condition?
    return false unless @conditions
    
    # Handle different condition types
    case @conditions
    when Array
      @conditions.any?
    when String
      !@conditions.empty?
    else
      # For AST nodes like BinaryOpNode or other objects
      !@conditions.nil?
    end
  end

  # Check if this constraint respects object metadata
  def respects_metadata?(object)
    return true unless object.respond_to?(:get_metadata)
    
    type_hint = object.get_metadata(:type_hint)
    return true unless type_hint
    
    case @constraint_type
    when :type
      @constraint_data == type_hint
    else
      true
    end
  end

  def to_s
    case @constraint_type
    when :type
      "#{@variable} :: #{@constraint_data}"
    when :range
      "#{@variable} in #{@constraint_data}"
    when :pattern
      "#{@variable} matches #{@constraint_data}"
    when :structural
      "#{@variable} :: Object{...}"
    else
      "#{@variable} :: #{@constraint_type}(#{@constraint_data})"
    end
  end

  def inspect
    "#<TypeConstraint:#{to_s}>"
  end

  private

  def satisfies_type_constraint?(value)
    case @constraint_data
    when :Number, :Numeric
      value.is_a?(Numeric)
    when :String
      value.is_a?(String)
    when :Boolean
      value.is_a?(TrueClass) || value.is_a?(FalseClass)
    when :Array
      value.is_a?(Array)
    when :Hash, :Object
      value.is_a?(Hash)
    when :Symbol
      value.is_a?(Symbol)
    when Class
      value.is_a?(@constraint_data)
    else
      false
    end
  end

  def satisfies_range_constraint?(value)
    @constraint_data.cover?(value)
  rescue
    false
  end

  def satisfies_pattern_constraint?(value)
    return false unless value.is_a?(String)
    @constraint_data.match?(value)
  rescue
    false
  end

  def satisfies_structural_constraint?(value)
    return false unless value.is_a?(Hash)
    
    @constraint_data.all? do |field, field_constraints|
      field_value = value[field]
      
      # Check required fields
      if field_constraints[:required] && field_value.nil?
        return false
      end
      
      # Skip validation for nil values on optional fields
      next true if field_value.nil? && !field_constraints[:required]
      
      # Validate field constraints
      validate_field_constraints(field_value, field_constraints)
    end
  end

  def validate_field_constraints(value, constraints)
    # Type constraint
    if constraints[:type]
      temp_constraint = TypeConstraint.new(:temp, :type, constraints[:type])
      return false unless temp_constraint.satisfies?(value)
    end
    
    # Range constraint
    if constraints[:range]
      temp_constraint = TypeConstraint.new(:temp, :range, constraints[:range])
      return false unless temp_constraint.satisfies?(value)
    end
    
    # Pattern constraint
    if constraints[:pattern]
      temp_constraint = TypeConstraint.new(:temp, :pattern, constraints[:pattern])
      return false unless temp_constraint.satisfies?(value)
    end
    
    # Nested structural constraints
    if constraints[:elements] && value.is_a?(Array)
      return false unless value.all? { |elem| validate_field_constraints(elem, constraints[:elements]) }
    end
    
    true
  end

  def satisfies_composite_constraint?(value)
    @constraint_data.all? do |sub_constraint|
      temp_constraint = TypeConstraint.new(
        @variable, 
        sub_constraint[:type], 
        sub_constraint[:data]
      )
      temp_constraint.satisfies?(value)
    end
  end

  def satisfies_custom_constraint?(value)
    case @constraint_data
    when Proc, Method
      @constraint_data.call(value)
    when TrueClass, FalseClass
      @constraint_data  # Return the boolean value directly
    else
      # For other types, assume it's a callable if it responds to call
      @constraint_data.respond_to?(:call) ? @constraint_data.call(value) : false
    end
  rescue
    false
  end

  def generate_error_message(value)
    case @constraint_type
    when :type
      "Expected #{@constraint_data}, got #{value.class.name}"
    when :range
      "Expected value in range #{@constraint_data}, got #{value}"
    when :pattern
      "Expected value matching pattern #{@constraint_data}, got #{value.inspect}"
    when :structural
      "Expected object with required structure, got #{value.inspect}"
    when :composite
      "Expected value satisfying all composite constraints, got #{value.inspect}"
    when :custom
      "Expected value satisfying custom constraint, got #{value.inspect}"
    else
      "Constraint violation for #{@variable}"
    end
  end
end


class ConstraintConflictError < StandardError
  attr_reader :variable, :existing_constraint, :new_constraint_type, :new_constraint_data

  def initialize(message, variable: nil, existing_constraint: nil, new_constraint_type: nil, new_constraint_data: nil)
    super(message)
    @variable = variable
    @existing_constraint = existing_constraint
    @new_constraint_type = new_constraint_type
    @new_constraint_data = new_constraint_data
  end
end

class ConstraintViolationError < StandardError
  attr_reader :variable, :value, :constraints, :source_variable, :source_value

  def initialize(message, variable: nil, value: nil, constraints: nil, source_variable: nil, source_value: nil)
    super(message)
    @variable = variable
    @value = value
    @constraints = constraints
    @source_variable = source_variable
    @source_value = source_value
  end
end

# Null object pattern for missing constraints to prevent NoMethodError
class NullTypeConstraint
attr_reader :variable

def initialize(variable)
  @variable = variable
end

def satisfies?(value)
  # A null constraint accepts nothing - this ensures tests fail properly
  # rather than crashing with NoMethodError
  false
end

def validate!(value)
  false
end

def has_condition?
  false
end

def constraint_type
  :null
end

def constraint_data
  nil
end

def to_s
  "#{@variable} :: <missing constraint>"
end

def inspect
  "#<NullTypeConstraint:#{@variable}>"
end
end