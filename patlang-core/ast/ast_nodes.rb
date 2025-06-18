# Abstract Syntax Tree node classes for Patlang

# Base class for all AST nodes
class ASTNode
  def to_s
    self.class.name
  end
end

# Node representing a number literal
class NumberNode < ASTNode
  attr_reader :value

  def initialize(value)
    @value = value
  end

  def to_s
    "NumberNode(#{@value})"
  end
end

# Node representing a binary operation
class BinaryOpNode < ASTNode
  attr_reader :left, :operator, :right

  def initialize(left, operator, right)
    @left = left
    @operator = operator
    @right = right
  end

  def to_s
    "BinaryOpNode(#{@left}, #{@operator}, #{@right})"
  end
end

# Node representing a unary operation (e.g., -x, !x)
class UnaryOpNode < ASTNode
  attr_reader :operator, :operand

  def initialize(operator, operand)
    @operator = operator
    @operand = operand
  end

  def to_s
    "UnaryOpNode(#{@operator}, #{@operand})"
  end
end

# Node representing a variable reference/lookup
class VariableNode < ASTNode
  attr_reader :name

  def initialize(name)
    @name = name
  end

  # Alias for compatibility with test expectations
  def value
    @name
  end

  def to_s
    "VariableNode(#{@name})"
  end
end

# Node representing a variable assignment
class AssignmentNode < ASTNode
  attr_reader :name, :expression

  def initialize(name, expression)
    @name = name
    @expression = expression
  end

  def to_s
    "AssignmentNode(#{@name}, #{@expression})"
  end
end

# Node representing a property assignment (obj.prop = value)
class PropertyAssignmentNode < ASTNode
  attr_reader :object_name, :property_name, :expression

  def initialize(object_name, property_name, expression)
    @object_name = object_name
    @property_name = property_name
    @expression = expression
  end

  def to_s
    "PropertyAssignmentNode(#{@object_name}.#{@property_name}, #{@expression})"
  end
end

# Node representing a boolean literal (true/false)
class BooleanNode < ASTNode
  attr_reader :value

  def initialize(value)
    @value = value
  end

  def to_s
    "BooleanNode(#{@value})"
  end
end

# Node representing a comparison operation
class ComparisonNode < ASTNode
  attr_reader :left, :operator, :right

  def initialize(left, operator, right)
    @left = left
    @operator = operator
    @right = right
  end

  def to_s
    "ComparisonNode(#{@left}, #{@operator}, #{@right})"
  end
end

# Node representing an if/then/else conditional statement
class IfNode < ASTNode
  attr_reader :condition, :then_body, :else_body

  def initialize(condition, then_body, else_body = nil)
    @condition = condition
    @then_body = then_body
    @else_body = else_body
  end

  def to_s
    if @else_body
      "IfNode(#{@condition}, #{@then_body}, #{@else_body})"
    else
      "IfNode(#{@condition}, #{@then_body})"
    end
  end
end

# Node representing a while loop statement
class WhileNode < ASTNode
  attr_reader :condition, :body

  def initialize(condition, body)
    @condition = condition
    @body = body
  end

  def to_s
    "WhileNode(#{@condition}, #{@body})"
  end
end

# Node representing a block of statements
class BlockNode < ASTNode
  attr_reader :statements

  def initialize(statements = [])
    @statements = statements
  end

  def to_s
    "BlockNode([#{@statements.map(&:to_s).join(', ')}])"
  end
end

# Node representing a string literal
class StringNode < ASTNode
  attr_reader :value

  def initialize(value)
    @value = value
  end

  def to_s
    "StringNode(#{@value.inspect})"
  end
end

# Node representing index access (e.g., string[index])
class IndexAccessNode < ASTNode
  attr_reader :object, :index

  def initialize(object, index)
    @object = object
    @index = index
  end

  def to_s
    "IndexAccessNode(#{@object}, #{@index})"
  end
end

# Node representing method call (e.g., string.length)
class MethodCallNode < ASTNode
  attr_reader :object, :method_name, :arguments

  def initialize(object, method_name, arguments = [])
    @object = object
    @method_name = method_name
    @arguments = arguments
  end

  def to_s
    "MethodCallNode(#{@object}, #{@method_name}, #{@arguments})"
  end
end
# Node representing a function definition
class FunctionDefinitionNode < ASTNode
  attr_reader :name, :parameters, :body, :return_type

  def initialize(name, parameters, body, return_type = nil)
    @name = name
    @parameters = parameters
    @body = body
    @return_type = return_type
  end

  def to_s
    "FunctionDefinitionNode(#{@name}, #{@parameters}, #{@body})"
  end
end

# Node representing a function call
class FunctionCallNode < ASTNode
  attr_reader :function_name, :arguments

  def initialize(function_name, arguments = [])
    @function_name = function_name
    @arguments = arguments
  end

  def to_s
    "FunctionCallNode(#{@function_name}, #{@arguments})"
  end
end

# Node representing a function parameter
class ParameterNode < ASTNode
  attr_reader :name, :type, :default_value

  def initialize(name, type = nil, default_value = nil)
    @name = name
    @type = type
    @default_value = default_value
  end

  def to_s
    if @default_value
      "ParameterNode(#{@name}, #{@type}, #{@default_value})"
    else
      "ParameterNode(#{@name}, #{@type})"
    end
  end
end

# Node representing a return statement
class ReturnNode < ASTNode
  attr_reader :expression

  def initialize(expression = nil)
    @expression = expression
  end

  def to_s
    if @expression
      "ReturnNode(#{@expression})"
    else
      "ReturnNode()"
    end
  end
end

# Node representing an expression that should automatically output to console
class AutoOutputNode < ASTNode
  attr_reader :expression

  def initialize(expression)
    @expression = expression
  end

  def to_s
    "AutoOutputNode(#{@expression})"
  end
end

# Node representing a print statement (e.g., print "text")
class PrintNode < ASTNode
  attr_reader :expression

  def initialize(expression)
    @expression = expression
  end

  def to_s
    "PrintNode(#{@expression})"
  end
end

# Node representing a type constraint declaration for unified reasoning
class TypeConstraintNode < ASTNode
  attr_reader :variable, :constraint_type, :constraint_data, :conditions

  def initialize(variable, constraint_type, constraint_data = nil, conditions = nil)
    @variable = variable
    @constraint_type = constraint_type
    @constraint_data = constraint_data
    @conditions = conditions
  end

  def satisfies?(value)
    # Method stub - evaluation logic to be implemented later
    raise NotImplementedError, "satisfies? method not yet implemented"
  end

  def validate
    # Method stub - validation logic to be implemented later
    raise NotImplementedError, "validate method not yet implemented"
  end

  def error_message
    # Method stub - error message generation to be implemented later
    raise NotImplementedError, "error_message method not yet implemented"
  end

  def to_s
    if @conditions
      "TypeConstraintNode(#{@variable} :: #{@constraint_type} where #{@conditions})"
    else
      "TypeConstraintNode(#{@variable} :: #{@constraint_type})"
    end
  end
end

# Node representing a goal declaration for goal-oriented programming
class GoalNode < ASTNode
  attr_reader :description, :preconditions, :postconditions, :strategies

  def initialize(description, preconditions = [], postconditions = [], strategies = [])
    @description = description
    @preconditions = preconditions
    @postconditions = postconditions
    @strategies = strategies
  end

  def can_pursue?
    # Method stub - pursuit validation logic to be implemented later
    raise NotImplementedError, "can_pursue? method not yet implemented"
  end

  def success_criteria
    # Method stub - success criteria evaluation to be implemented later
    raise NotImplementedError, "success_criteria method not yet implemented"
  end

  def to_s
    "GoalNode(#{@description})"
  end
end

# Node representing a fact assertion (e.g., assert fact(likes(alice, bob)))
class AssertNode < ASTNode
  attr_reader :fact

  def initialize(fact)
    @fact = fact
  end

  def to_s
    "AssertNode(#{@fact})"
  end
end

# Node representing a logic programming rule
class LogicRuleNode < ASTNode
  attr_reader :head, :body, :rule_type

  def initialize(head, body, rule_type = :standard)
    @head = head
    @body = body
    @rule_type = rule_type
  end

  def matches?(query)
    # Method stub - pattern matching logic to be implemented later
    raise NotImplementedError, "matches? method not yet implemented"
  end

  def apply(bindings = {})
    # Method stub - rule application logic to be implemented later
    raise NotImplementedError, "apply method not yet implemented"
  end

  def to_s
    "LogicRuleNode(#{@head} :- #{@body}, type: #{@rule_type})"
  end
end

# Node representing a logic programming query
class QueryNode < ASTNode
  attr_reader :goal_term, :variables, :query_type

  def initialize(goal_term, variables = [], query_type = :standard)
    @goal_term = goal_term
    @variables = variables
    @query_type = query_type
  end

  def bind_variables(bindings = {})
    # Method stub - variable binding logic to be implemented later
    raise NotImplementedError, "bind_variables method not yet implemented"
  end

  def result_format
    # Method stub - result formatting logic to be implemented later
    raise NotImplementedError, "result_format method not yet implemented"
  end

  def to_s
    "QueryNode(#{@goal_term}, vars: #{@variables}, type: #{@query_type})"
  end
end

# Node representing goal pursuit (e.g., pursue find_answer)
class PursueNode < ASTNode
  attr_reader :goal_name, :arguments

  def initialize(goal_name, arguments = [])
    @goal_name = goal_name
    @arguments = arguments
  end

  def to_s
    "PursueNode(#{@goal_name})"
  end
end

# Node representing reasoning mode control (e.g., reasoning mode on)
class ReasoningModeNode < ASTNode
  attr_reader :enabled

  def initialize(enabled)
    @enabled = enabled
  end

  def to_s
    "ReasoningModeNode(#{@enabled ? 'on' : 'off'})"
  end
end

# Node representing a parser error with recovery
class ErrorNode < ASTNode
  attr_reader :message, :recovered_value
  
  def initialize(message, recovered_value = nil)
    @message = message
    @recovered_value = recovered_value
  end
  
  def to_s
    "ErrorNode(#{@message.inspect})"
  end
end

# === Type Constraint AST Nodes ===

# Node representing a type annotation (e.g., x :: Number)
class TypeAnnotationNode < ASTNode
  attr_reader :variable_name, :type_constraint

  def initialize(variable_name, type_constraint)
    @variable_name = variable_name
    @type_constraint = type_constraint
  end

  def to_s
    "TypeAnnotationNode(#{@variable_name} :: #{@type_constraint})"
  end
end

# Node representing a generic type constraint (e.g., Array[Number])
class GenericTypeConstraint < ASTNode
  attr_reader :base_type, :type_parameters

  def initialize(base_type, type_parameters)
    @base_type = base_type
    @type_parameters = type_parameters
  end

  def to_s
    params = @type_parameters.map(&:to_s).join(', ')
    "GenericTypeConstraint(#{@base_type}[#{params}])"
  end
end

# Node representing a range constraint (e.g., Number(0..100))
class RangeConstraint < ASTNode
  attr_reader :base_type, :min_value, :max_value, :exclusive_max

  def initialize(base_type, min_value, max_value, exclusive_max = false)
    @base_type = base_type
    @min_value = min_value
    @max_value = max_value
    @exclusive_max = exclusive_max
  end

  def exclusive_max?
    @exclusive_max
  end

  def to_s
    range_op = @exclusive_max ? '...' : '..'
    "RangeConstraint(#{@base_type}(#{@min_value}#{range_op}#{@max_value}))"
  end
end

# Node representing a pattern constraint (e.g., String(/regex/))
class PatternConstraint < ASTNode
  attr_reader :base_type, :pattern

  def initialize(base_type, pattern)
    @base_type = base_type
    @pattern = pattern
  end

  def to_s
    "PatternConstraint(#{@base_type}(#{@pattern.inspect}))"
  end
end

# Node representing a structural constraint (e.g., {name: String, age: Number})
class StructuralConstraint < ASTNode
  attr_reader :field_constraints

  def initialize(field_constraints)
    @field_constraints = field_constraints
  end

  def to_s
    fields = @field_constraints.map { |name, constraint| "#{name}: #{constraint}" }.join(', ')
    "StructuralConstraint({#{fields}})"
  end
end

# Node representing a union type constraint (e.g., Number | String)
class UnionTypeConstraint < ASTNode
  attr_reader :allowed_types

  def initialize(allowed_types)
    @allowed_types = allowed_types
  end

  def to_s
    types = @allowed_types.map(&:to_s).join(' | ')
    "UnionTypeConstraint(#{types})"
  end
end

# Node representing a field constraint within a structural constraint
class FieldConstraint < ASTNode
  attr_reader :type_constraint, :required

  def initialize(type_constraint, required = true)
    @type_constraint = type_constraint
    @required = required
  end

  def required?
    @required
  end

  def to_s
    req_marker = @required ? '!' : '?'
    "FieldConstraint(#{@type_constraint}#{req_marker})"
  end
end

# Enhanced AssignmentNode to support type constraints
class TypedAssignmentNode < AssignmentNode
  attr_reader :type_constraint

  def initialize(name, type_constraint, expression)
    super(name, expression)
    @type_constraint = type_constraint
  end

  alias_method :variable_name, :name
  alias_method :value, :expression

  def to_s
    "TypedAssignmentNode(#{@name}: #{@type_constraint} = #{@expression})"
  end
end

# Enhanced FunctionDefinitionNode to support parameter and return type constraints
class TypedFunctionDefinitionNode < ASTNode
  attr_reader :function_name, :parameters, :return_type_constraint, :body

  def initialize(function_name, parameters, return_type_constraint, body = nil)
    @function_name = function_name
    @parameters = parameters
    @return_type_constraint = return_type_constraint
    @body = body
  end

  def to_s
    params = @parameters.map(&:to_s).join(', ')
    "TypedFunctionDefinitionNode(#{@function_name}(#{params}) -> #{@return_type_constraint})"
  end
end

# Node representing a function parameter with type constraint
class ParameterNode < ASTNode
  attr_reader :name, :type, :default_value, :required

  def initialize(name, type = nil, default_value = nil, required = true)
    @name = name
    @type = type
    @default_value = default_value
    @required = required
  end

  def required?
    @required
  end

  # Backward compatibility
  def type_constraint
    @type
  end

  def to_s
    req_marker = @required ? '' : '?'
    default_part = @default_value ? " = #{@default_value}" : ""
    "ParameterNode(#{@name}#{req_marker}: #{@type}#{default_part})"
  end
end

# Node representing a program with multiple statements
class ProgramNode < ASTNode
  attr_reader :statements

  def initialize(statements)
    @statements = statements
  end

  def to_s
    "ProgramNode(#{@statements.length} statements)"
  end
end

# Load enhanced reasoning nodes after base classes are defined
require_relative 'enhanced_reasoning_nodes'