# frozen_string_literal: true

require_relative 'unification_engine'

# Type constraint system for unified reasoning
# This is a minimal stub implementation for Phase 1 TDD
class TypeConstraintSystem
  def initialize
    @constraints = {}
    @variables = {}
    @relationships = {}
    @event_handlers = {}
    @constraint_count = 0
  end

  # Register event handlers for constraint events
  def on_event(event_type, &block)
    @event_handlers[event_type] ||= []
    @event_handlers[event_type] << block
  end

  # Create a new type constraint
  def create_constraint(variable, constraint_type, constraint_data, **options)
    @constraint_count += 1
    
    # Check for conflicts with existing constraints
    existing_constraints = @constraints[variable] || []
    check_constraint_conflicts!(variable, constraint_type, constraint_data, existing_constraints)
    
    constraint = TypeConstraint.new(variable, constraint_type, constraint_data, **options)
    @constraints[variable] ||= []
    @constraints[variable] << constraint
    
    fire_event(:constraint_created, {
      variable: variable,
      constraint: constraint,
      constraint_id: @constraint_count
    })
    
    constraint
  end

  # Get all constraints for a variable
  def get_constraints(variable)
    @constraints[variable] || []
  end

  # Check if a variable satisfies all its constraints
  def variable_satisfies?(variable, value)
    constraints = get_constraints(variable)
    return true if constraints.empty?
    
    constraints.all? do |constraint|
      result = constraint.satisfies?(value)
      fire_event(:constraint_validated, {
        variable: variable,
        value: value,
        constraint: constraint,
        result: result
      })
      result
    end
  end

  # Set a variable's value and trigger propagation
  def set_variable_value(variable, value)
    unless variable_satisfies?(variable, value)
      violated_constraints = get_constraints(variable).reject { |c| c.satisfies?(value) }
      raise ConstraintViolationError.new(
        "Value #{value} violates constraints for #{variable}",
        variable: variable,
        value: value,
        constraints: violated_constraints
      )
    end
    
    @variables[variable] = value
    propagate_from(variable)
  end

  # Get a variable's current value
  def get_variable_value(variable)
    @variables[variable]
  end

  # Add a relationship between variables for propagation
  def add_relationship(from_var, to_var, transform)
    @relationships[from_var] ||= []
    @relationships[from_var] << {
      target: to_var,
      transform: transform
    }
  end

  # Get total number of constraints in the system
  def constraint_count
    @constraints.values.flatten.length
  end

  # Remove all constraints for a variable (for cleanup)
  def remove_constraints(variable)
    removed = @constraints.delete(variable) || []
    @variables.delete(variable)
    
    removed.each do |constraint|
      fire_event(:constraint_removed, {
        variable: variable,
        constraint: constraint
      })
    end
    
    removed.length
  end

  private

  def check_constraint_conflicts!(variable, new_type, new_data, existing_constraints)
    case new_type
    when :range
      existing_range = existing_constraints.find { |c| c.constraint_type == :range }
      if existing_range && !ranges_compatible?(existing_range.constraint_data, new_data)
        raise ConstraintConflictError.new(
          "Range constraint conflict for variable :#{variable}",
          variable: variable,
          existing_constraint: existing_range,
          new_constraint_type: new_type,
          new_constraint_data: new_data
        )
      end
    when :type
      existing_type = existing_constraints.find { |c| c.constraint_type == :type }
      if existing_type && existing_type.constraint_data != new_data
        raise ConstraintConflictError.new(
          "Type constraint conflict for variable :#{variable}",
          variable: variable,
          existing_constraint: existing_type,
          new_constraint_type: new_type,
          new_constraint_data: new_data
        )
      end
    end
  end

  def ranges_compatible?(range1, range2)
    # Two ranges are compatible if they overlap
    return false if range1.max < range2.min || range2.max < range1.min
    true
  end

  def propagate_from(variable)
    relationships = @relationships[variable] || []
    source_value = @variables[variable]
    
    relationships.each do |rel|
      begin
        new_value = rel[:transform].call(source_value)
        target_var = rel[:target]
        
        # Check if new value satisfies target constraints
        unless variable_satisfies?(target_var, new_value)
          raise ConstraintViolationError.new(
            "Propagation conflict: #{new_value} violates constraints for #{target_var}",
            variable: target_var,
            value: new_value,
            source_variable: variable,
            source_value: source_value
          )
        end
        
        @variables[target_var] = new_value
        fire_event(:type_refined, {
          variable: target_var,
          new_value: new_value,
          source: variable,
          source_value: source_value
        })
        
        # Continue propagation from target variable
        propagate_from(target_var)
        
      rescue => e
        fire_event(:propagation_failed, {
          source_variable: variable,
          target_variable: rel[:target],
          error: e.message
        })
        raise
      end
    end
  end

  def fire_event(event_type, data)
    handlers = @event_handlers[event_type]
    return unless handlers
    
    handlers.each do |handler|
      begin
        handler.call(data.merge(event_type: event_type, timestamp: Time.now))
      rescue => e
        warn "Event handler error for #{event_type}: #{e.message}"
      end
    end
  end
end

# Individual type constraint
class TypeConstraint
  attr_reader :variable, :constraint_type, :constraint_data, :conditions

  def initialize(variable, constraint_type, constraint_data, **options)
    @variable = variable.to_sym
    @constraint_type = constraint_type.to_sym
    @constraint_data = constraint_data
    @conditions = options[:conditions] || []
    @metadata = options[:metadata] || {}
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
    !@conditions.empty?
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
    when Proc
      @constraint_data.call(value)
    when Method
      @constraint_data.call(value)
    else
      false
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

# Exception classes
class TypeConstraintViolation < StandardError
  attr_reader :variable, :value

  def initialize(variable, value, message)
    @variable = variable
    @value = value
    super("Variable #{variable}: #{message}")
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