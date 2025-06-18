# Enhanced AST nodes for advanced reasoning syntax support

# Enhanced structural constraint node for complex object type definitions
class StructuralConstraintNode < ASTNode
  attr_reader :variable, :field_constraints, :conditions

  def initialize(variable, field_constraints, conditions = nil)
    @variable = variable
    @field_constraints = field_constraints
    @conditions = conditions
  end

  def validate_structure(value)
    return false unless value.is_a?(Hash)
    
    @field_constraints.each do |field_name, field_spec|
      # Check required fields
      if field_spec[:required] != false && !value.key?(field_name)
        return false
      end
      
      # Validate field types if present
      if value.key?(field_name)
        field_value = value[field_name]
        unless validate_field_type(field_value, field_spec)
          return false
        end
      end
    end
    
    true
  end

  def to_s
    fields_str = @field_constraints.map do |name, spec|
      "#{name} :: #{spec[:type] || spec}"
    end.join(', ')
    
    base = "#{@variable} :: Object { #{fields_str} }"
    @conditions ? "#{base} where #{@conditions}" : base
  end

  private

  def validate_field_type(value, field_spec)
    expected_type = field_spec[:type] || field_spec
    case expected_type
    when :String
      value.is_a?(String)
    when :Number
      value.is_a?(Numeric)
    when :Boolean
      value.is_a?(TrueClass) || value.is_a?(FalseClass)
    when :Array
      value.is_a?(Array)
    when :Hash, :Object
      value.is_a?(Hash)
    else
      true  # Unknown types pass validation
    end
  end
end

# Enhanced goal node with rich metadata and parameter support
class EnhancedGoalNode < GoalNode
  attr_reader :parameters, :metadata

  def initialize(description, parameters = [], preconditions = [], postconditions = [], strategies = [], metadata = {})
    super(description, preconditions, postconditions, strategies)
    @parameters = parameters
    @metadata = metadata
  end

  def has_parameters?
    !@parameters.empty?
  end

  def parameter_count
    @parameters.length
  end

  def get_parameter(name)
    @parameters.find { |p| p[:name] == name.to_sym }
  end

  def timeout
    @metadata[:timeout]
  end

  def priority
    @metadata[:priority] || 0
  end

  def to_s
    param_str = @parameters.map do |p|
      p[:type] ? "#{p[:name]} :: #{p[:type]}" : p[:name].to_s
    end.join(', ')
    
    base = @parameters.empty? ? "#{@description}" : "#{@description}(#{param_str})"
    
    if @metadata.any?
      meta_str = @metadata.map { |k, v| "#{k}: #{v}" }.join(', ')
      "EnhancedGoalNode(#{base}) { #{meta_str} }"
    else
      "EnhancedGoalNode(#{base})"
    end
  end
end

# Enhanced logic rule node with better body composition support
class EnhancedLogicRuleNode < LogicRuleNode
  attr_reader :variables, :rule_metadata

  def initialize(head, body, rule_type = :standard, metadata = {})
    super(head, body, rule_type)
    @variables = extract_variables
    @rule_metadata = metadata
  end

  def has_variables?
    !@variables.empty?
  end

  def variable_count
    @variables.length
  end

  def is_fact?
    @body.nil?
  end

  def is_recursive?
    return false unless @body
    head_functor = extract_functor(@head)
    contains_functor?(@body, head_functor)
  end

  def to_s
    rule_indicator = @rule_type == :prolog ? " :- " : " if "
    base = @body ? "#{@head}#{rule_indicator}#{@body}" : @head.to_s
    "EnhancedLogicRuleNode(#{base}, vars: #{@variables}, type: #{@rule_type})"
  end

  private

  def extract_variables
    vars = []
    extract_vars_from_node(@head, vars)
    extract_vars_from_node(@body, vars) if @body
    vars.uniq
  end

  def extract_vars_from_node(node, vars)
    case node
    when VariableNode
      vars << node.name if node.name =~ /^[A-Z]/  # Prolog variable convention
    when FunctionCallNode
      node.arguments.each { |arg| extract_vars_from_node(arg, vars) }
    when ConjunctionNode
      node.terms.each { |term| extract_vars_from_node(term, vars) }
    when BinaryOpNode
      extract_vars_from_node(node.left, vars)
      extract_vars_from_node(node.right, vars)
    end
  end

  def extract_functor(node)
    case node
    when FunctionCallNode
      node.function_name
    else
      nil
    end
  end

  def contains_functor?(node, functor)
    case node
    when FunctionCallNode
      node.function_name == functor
    when ConjunctionNode
      node.terms.any? { |term| contains_functor?(term, functor) }
    when BinaryOpNode
      contains_functor?(node.left, functor) || contains_functor?(node.right, functor)
    else
      false
    end
  end
end

# Conjunction node for representing compound rule bodies
class ConjunctionNode < ASTNode
  attr_reader :terms

  def initialize(terms)
    @terms = terms
  end

  def term_count
    @terms.length
  end

  def add_term(term)
    @terms << term
  end

  def to_s
    terms_str = @terms.map(&:to_s).join(', ')
    "ConjunctionNode([#{terms_str}])"
  end
end

# Enhanced query node with better variable tracking and result handling
class EnhancedQueryNode < QueryNode
  attr_reader :query_options, :expected_result_count

  def initialize(goal_term, variables = [], query_type = :standard, options = {})
    super(goal_term, variables, query_type)
    @query_options = options
    @expected_result_count = options[:limit] || :unlimited
  end

  def has_limit?
    @expected_result_count != :unlimited
  end

  def has_ordering?
    @query_options.key?(:order_by)
  end

  def lazy_evaluation?
    @query_options[:lazy] == true
  end

  def to_s
    options_str = @query_options.empty? ? "" : " with #{@query_options}"
    "EnhancedQueryNode(#{@goal_term}, vars: #{@variables}#{options_str})"
  end
end

# Array constraint node for typed array specifications
class ArrayConstraintNode < ASTNode
  attr_reader :variable, :element_type, :size_constraints

  def initialize(variable, element_type = nil, size_constraints = nil)
    @variable = variable
    @element_type = element_type
    @size_constraints = size_constraints
  end

  def validate_array(value)
    return false unless value.is_a?(Array)
    
    # Check size constraints
    if @size_constraints
      return false unless validate_size(value.length)
    end
    
    # Check element types
    if @element_type
      return false unless value.all? { |elem| validate_element_type(elem) }
    end
    
    true
  end

  def to_s
    type_str = @element_type ? "[#{@element_type}]" : ""
    size_str = @size_constraints ? " size #{@size_constraints}" : ""
    "#{@variable} :: Array#{type_str}#{size_str}"
  end

  private

  def validate_size(length)
    case @size_constraints
    when Range
      @size_constraints.include?(length)
    when Numeric
      length == @size_constraints
    when Hash
      min = @size_constraints[:min] || 0
      max = @size_constraints[:max] || Float::INFINITY
      length >= min && length <= max
    else
      true
    end
  end

  def validate_element_type(element)
    case @element_type
    when :String
      element.is_a?(String)
    when :Number
      element.is_a?(Numeric)
    when :Boolean
      element.is_a?(TrueClass) || element.is_a?(FalseClass)
    else
      true
    end
  end
end

# Pattern constraint node for regex and custom pattern matching
class PatternConstraintNode < ASTNode
  attr_reader :variable, :pattern, :pattern_type

  def initialize(variable, pattern, pattern_type = :regex)
    @variable = variable
    @pattern = pattern
    @pattern_type = pattern_type
  end

  def matches?(value)
    case @pattern_type
    when :regex
      @pattern.is_a?(Regexp) && @pattern.match?(value.to_s)
    when :custom
      @pattern.respond_to?(:call) && @pattern.call(value)
    else
      false
    end
  end

  def to_s
    pattern_str = @pattern_type == :regex ? @pattern.inspect : @pattern.to_s
    "#{@variable} matches #{pattern_str}"
  end
end

# Composite constraint node for combining multiple constraint types
class CompositeConstraintNode < ASTNode
  attr_reader :variable, :sub_constraints, :composition_type

  def initialize(variable, sub_constraints, composition_type = :all)
    @variable = variable
    @sub_constraints = sub_constraints
    @composition_type = composition_type  # :all, :any, :none
  end

  def satisfies?(value)
    case @composition_type
    when :all
      @sub_constraints.all? { |constraint| constraint.satisfies?(value) }
    when :any
      @sub_constraints.any? { |constraint| constraint.satisfies?(value) }
    when :none
      @sub_constraints.none? { |constraint| constraint.satisfies?(value) }
    else
      false
    end
  end

  def constraint_count
    @sub_constraints.length
  end

  def to_s
    op = case @composition_type
         when :all then " AND "
         when :any then " OR "
         when :none then " NOT "
         else " ? "
         end
    
    constraints_str = @sub_constraints.map(&:to_s).join(op)
    "#{@variable} :: (#{constraints_str})"
  end
end