require_relative '../object_model/patlang_object'
require_relative 'unification_engine'

# Type Constraint System for Patlang's Type Inference
# Provides constraint creation, validation, and propagation for unified reasoning
class TypeConstraintSystem < PatlangObject
  def initialize
    super("type_constraint_system", :type_constraint_system)
    initialize_event_system
    
    @constraints = Hash.new { |h, k| h[k] = [] }
    @relationships = Hash.new { |h, k| h[k] = [] }
    @unification_engine = UnificationEngine.new
    
    # Subscribe to object destruction events for cleanup
    on_all_events do |event_data|
      if event_data[:type] == :object_destroyed
        cleanup_constraints_for_object(event_data[:data][:object_id].to_s)
      end
    end
    
    set_metadata(:type, :type_constraint_system)
    set_metadata(:created_at, Time.now)
  end
  
  # Get total number of constraints across all variables
  def constraint_count
    @constraints.values.map(&:length).sum
  end
  
  # Create a new type constraint for a variable
  def create_constraint(variable, constraint_type, constraint_data, **options)
    validate_constraint_inputs(variable, constraint_type, constraint_data)
    
    constraint = TypeConstraint.new(variable, constraint_type, constraint_data, **options)
    @constraints[variable] << constraint
    
    fire_event(:constraint_created, {
      variable: variable,
      constraint_type: constraint_type,
      constraint_data: constraint_data,
      timestamp: Time.now
    })
    
    constraint
  end
  
  # Check if a value satisfies all constraints for a variable
  def satisfies_all_constraints?(variable, value)
    constraints = @constraints[variable]
    return true if constraints.empty?
    
    constraints.all? do |constraint|
      result = constraint.satisfies?(value)
      
      # Fire validation event for each constraint check
      fire_event(:constraint_validated, {
        variable: variable,
        constraint_type: constraint.constraint_type,
        value: value,
        success: result,
        timestamp: Time.now
      })
      
      if !result
        fire_event(:constraint_violated, {
          variable: variable,
          constraint_type: constraint.constraint_type,
          value: value,
          timestamp: Time.now
        })
      end
      
      result
    end
  end
  
  # Alias for compatibility with reasoning_coordinator
  alias variable_satisfies? satisfies_all_constraints?
  
  # Set a variable's value - for tracking constraint validation
  def set_variable_value(variable, value)
    # Store the value for constraint validation
    @variable_values ||= {}
    @variable_values[variable] = value
    
    # Fire event for variable assignment
    fire_event(:variable_assigned, {
      variable: variable,
      value: value,
      timestamp: Time.now
    })
  end
  
  # Detect conflicts between constraints on a variable
  def detect_conflicts(variable)
    constraints = @constraints[variable]
    conflicts = []
    
    # Check for conflicting type constraints
    type_constraints = constraints.select { |c| c.constraint_type == :type }
    if type_constraints.length > 1
      types = type_constraints.map(&:constraint_data).uniq
      if types.length > 1
        conflicts << {
          type: :conflicting_types,
          description: "conflicting type constraints: #{types.join(', ')}",
          constraints: type_constraints
        }
      end
    end
    
    # Check for conflicting range constraints
    range_constraints = constraints.select { |c| c.constraint_type == :range }
    if range_constraints.length > 1
      # Check if ranges overlap
      ranges = range_constraints.map(&:constraint_data)
      if ranges_conflict?(ranges)
        conflicts << {
          type: :conflicting_ranges,
          description: "conflicting range constraints",
          constraints: range_constraints
        }
      end
    end
    
    conflicts
  end
  
  # Propagate constraints through the variable relationship network
  def propagate_constraints
    fire_event(:propagation_started, {
      variable_count: @constraints.keys.length,
      relationship_count: @relationships.values.flatten.length,
      timestamp: Time.now
    })
    
    changed = true
    iterations = 0
    max_iterations = 100  # Prevent infinite loops
    
    while changed && iterations < max_iterations
      changed = false
      iterations += 1
      
      @relationships.each do |var1, related_vars|
        related_vars.each do |var2|
          if propagate_between_variables(var1, var2)
            changed = true
          end
        end
      end
    end
    
    fire_event(:propagation_completed, {
      iterations: iterations,
      converged: !changed,
      timestamp: Time.now
    })
    
    !changed  # Return true if converged
  end
  
  # Add an equality relationship between two variables
  def add_equality_relationship(var1, var2)
    @relationships[var1] << var2 unless @relationships[var1].include?(var2)
    @relationships[var2] << var1 unless @relationships[var2].include?(var1)
  end
  
  # Attempt to unify two variables (merging their constraints)
  def unify_variables(var1, var2)
    # Check for type conflicts before unifying
    var1_types = @constraints[var1].select { |c| c.constraint_type == :type }
    var2_types = @constraints[var2].select { |c| c.constraint_type == :type }
    
    if !var1_types.empty? && !var2_types.empty?
      var1_type = var1_types.first.constraint_data
      var2_type = var2_types.first.constraint_data
      
      if var1_type != var2_type
        return UnificationResult.new(false, "type conflict: cannot unify #{var1_type} with #{var2_type}")
      end
    end
    
    # Merge constraints from both variables
    add_equality_relationship(var1, var2)
    
    # Copy constraints from var2 to var1
    @constraints[var2].each do |constraint|
      unless @constraints[var1].any? { |c| equivalent_constraint?(c, constraint) }
        new_constraint = TypeConstraint.new(var1, constraint.constraint_type, constraint.constraint_data, self)
        @constraints[var1] << new_constraint
      end
    end
    
    # Copy constraints from var1 to var2
    @constraints[var1].each do |constraint|
      unless @constraints[var2].any? { |c| equivalent_constraint?(c, constraint) }
        new_constraint = TypeConstraint.new(var2, constraint.constraint_type, constraint.constraint_data, self)
        @constraints[var2] << new_constraint
      end
    end
    
    UnificationResult.new(true)
  end
  
  # Get all constraints for a variable
  def get_constraints(variable)
    @constraints[variable].dup
  end
  
  # Cleanup constraints when an object is destroyed
  def cleanup_constraints_for_object(object_id)
    remove_constraints(object_id)
  end
  
  # Remove all constraints for a variable (for cleanup)
  def remove_constraints(variable)
    @constraints.delete(variable)
    @relationships.delete(variable)
    @relationships.each_value { |vars| vars.delete(variable) }
  end
  
  # Public fire_event method for test compatibility
  def fire_event(event_type, event_data = {})
    # Delegate to parent class fire_event method
    super
  end
  
  private
  
  def validate_constraint_inputs(variable, constraint_type, constraint_data)
    raise ArgumentError, "Variable name cannot be nil" if variable.nil?
    raise ArgumentError, "Variable name must be a string" unless variable.is_a?(String) || variable.is_a?(Symbol)
    
    valid_types = [:type, :range, :pattern, :structural, :custom]
    unless valid_types.include?(constraint_type)
      raise ArgumentError, "Invalid constraint type: #{constraint_type}. Must be one of #{valid_types.join(', ')}"
    end
    
    case constraint_type
    when :range
      unless constraint_data.is_a?(Hash) && constraint_data.key?(:min) && constraint_data.key?(:max)
        raise ArgumentError, "Range constraint data must be a hash with :min and :max keys"
      end
    when :pattern
      unless constraint_data.is_a?(Regexp)
        raise ArgumentError, "Pattern constraint data must be a Regexp"
      end
    when :structural
      unless constraint_data.is_a?(Hash)
        raise ArgumentError, "Structural constraint data must be a Hash"
      end
    when :custom
      unless constraint_data.respond_to?(:call)
        raise ArgumentError, "Custom constraint data must be callable (proc/lambda)"
      end
    end
  end
  
  def ranges_conflict?(ranges)
    # Simple conflict detection: check if any ranges don't overlap
    return false if ranges.length < 2
    
    ranges.combination(2).any? do |range1, range2|
      range1[:max] < range2[:min] || range2[:max] < range1[:min]
    end
  end
  
  def propagate_between_variables(var1, var2)
    changed = false
    
    # Propagate type constraints
    var1_types = @constraints[var1].select { |c| c.constraint_type == :type }
    var2_types = @constraints[var2].select { |c| c.constraint_type == :type }
    
    if !var1_types.empty? && var2_types.empty?
      type_constraint = TypeConstraint.new(var2, :type, var1_types.first.constraint_data, self)
      @constraints[var2] << type_constraint
      
      fire_event(:type_refined, {
        variable: var2,
        old_type: nil,
        new_type: var1_types.first.constraint_data,
        source_variable: var1,
        timestamp: Time.now
      })
      
      changed = true
    elsif var1_types.empty? && !var2_types.empty?
      type_constraint = TypeConstraint.new(var1, :type, var2_types.first.constraint_data, self)
      @constraints[var1] << type_constraint
      
      fire_event(:type_refined, {
        variable: var1,
        old_type: nil,
        new_type: var2_types.first.constraint_data,
        source_variable: var2,
        timestamp: Time.now
      })
      
      changed = true
    end
    
    changed
  end
  
  def equivalent_constraint?(c1, c2)
    c1.constraint_type == c2.constraint_type && 
    c1.constraint_data == c2.constraint_data
  end
end

# Individual type constraint representation
class TypeConstraint
  attr_reader :variable, :constraint_type, :constraint_data, :source_object
  
  def initialize(variable, constraint_type, constraint_data, system = nil)
    @variable = variable
    @constraint_type = constraint_type
    @constraint_data = constraint_data
    @system = system
    @source_object = system  # Reference to the constraint system
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
    when :custom
      satisfies_custom_constraint?(value)
    else
      false
    end
  end
  
  # Validate a value and return detailed result
  def validate(value)
    if satisfies?(value)
      ValidationResult.new(valid: true)
    else
      error_message = generate_error_message(value)
      ValidationResult.new(valid: false, errors: [error_message])
    end
  end
  
  private
  
  def satisfies_type_constraint?(value)
    case @constraint_data
    when :Number
      value.is_a?(Numeric)
    when :String
      value.is_a?(String)
    when :Array
      value.is_a?(Array)
    when :Hash
      value.is_a?(Hash)
    when :Boolean
      value.is_a?(TrueClass) || value.is_a?(FalseClass)
    else
      value.class.name.to_sym == @constraint_data
    end
  end
  
  def satisfies_range_constraint?(value)
    return false unless value.is_a?(Numeric)
    
    min = @constraint_data[:min]
    max = @constraint_data[:max]
    
    value >= min && value <= max
  end
  
  def satisfies_pattern_constraint?(value)
    return false unless value.is_a?(String)
    
    @constraint_data.match?(value)
  end
  
  def satisfies_structural_constraint?(value)
    return false unless value.is_a?(Hash)
    
    @constraint_data.each do |field_name, field_spec|
      # Check if required field is present
      if field_spec[:required] && !value.key?(field_name)
        return false
      end
      
      # If field is present, validate it
      if value.key?(field_name)
        field_value = value[field_name]
        
        # Check type
        if field_spec[:type]
          type_constraint = TypeConstraint.new("#{@variable}.#{field_name}", :type, field_spec[:type])
          return false unless type_constraint.satisfies?(field_value)
        end
        
        # Check range
        if field_spec[:range]
          range_constraint = TypeConstraint.new("#{@variable}.#{field_name}", :range, field_spec[:range])
          return false unless range_constraint.satisfies?(field_value)
        end
        
        # Check pattern
        if field_spec[:pattern]
          pattern_constraint = TypeConstraint.new("#{@variable}.#{field_name}", :pattern, field_spec[:pattern])
          return false unless pattern_constraint.satisfies?(field_value)
        end
      end
    end
    
    true
    
    true
  end
  
  def satisfies_custom_constraint?(value)
    begin
      @constraint_data.call(value)
    rescue
      false
    end
  end
  
  def generate_error_message(value)
    case @constraint_type
    when :type
      "Variable '#{@variable}' expected #{@constraint_data}, got #{value.class} (#{value.inspect})"
    when :range
      "Variable '#{@variable}' value #{value.inspect} not in range #{@constraint_data[:min]}..#{@constraint_data[:max]}"
    when :pattern
      "Variable '#{@variable}' value #{value.inspect} does not match pattern #{@constraint_data.inspect}"
    when :structural
      errors = []
      @constraint_data.each do |field_name, field_spec|
        if field_spec[:required] && !value.key?(field_name)
          errors << "missing required field '#{field_name}'"
        elsif value.key?(field_name)
          field_value = value[field_name]
          if field_spec[:type]
            type_constraint = TypeConstraint.new("#{@variable}.#{field_name}", :type, field_spec[:type])
            unless type_constraint.satisfies?(field_value)
              errors << "field '#{field_name}' type error"
            end
          end
          if field_spec[:range]
            range_constraint = TypeConstraint.new("#{@variable}.#{field_name}", :range, field_spec[:range])
            unless range_constraint.satisfies?(field_value)
              errors << "field '#{field_name}' range error"
            end
          end
        end
      end
      "Structural constraint violation for '#{@variable}': #{errors.join(', ')}"
    when :custom
      "Variable '#{@variable}' value #{value.inspect} does not satisfy custom constraint"
    else
      "Variable '#{@variable}' constraint violation"
    end
  end
end

# Result classes for validation and unification
class ValidationResult
  attr_reader :success, :error_message
  
  def initialize(success, error_message = nil, *additional_args)
    @success = success
    @error_message = error_message
  end
  
  def success?
    @success
  end
end

class UnificationResult
  attr_reader :success, :error_message
  
  def initialize(success, error_message = nil, *additional_args)
    @success = success
    @error_message = error_message
  end
  
  def success?
    @success
  end
end