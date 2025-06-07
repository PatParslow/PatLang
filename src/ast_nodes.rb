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
# Node representing a type constraint declaration (e.g., constrain x :: Number where x > 0)
class ConstraintNode < ASTNode
  attr_reader :variable, :type, :conditions

  def initialize(variable, type, conditions = nil)
    @variable = variable
    @type = type
    @conditions = conditions
  end

  def to_s
    if @conditions
      "ConstraintNode(#{@variable} :: #{@type} where #{@conditions})"
    else
      "ConstraintNode(#{@variable} :: #{@type})"
    end
  end
end

# Node representing a goal declaration (e.g., goal find_answer { postcondition: answer > 0 })
class GoalNode < ASTNode
  attr_reader :name, :parameters, :precondition, :postcondition, :strategy,
              :description, :strategies, :subgoals, :context

  def initialize(name, parameters = [], precondition = nil, postcondition = nil, strategy = nil,
                 description = nil, strategies = [], subgoals = [], context = {})
    @name = name
    @parameters = parameters
    @precondition = precondition
    @postcondition = postcondition
    @strategy = strategy
    @description = description
    @strategies = strategies
    @subgoals = subgoals
    @context = context
  end

  def to_s
    "GoalNode(#{@name})"
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

# Node representing a query (e.g., query likes(X, bob))
class QueryNode < ASTNode
  attr_reader :pattern

  def initialize(pattern)
    @pattern = pattern
  end

  def to_s
    "QueryNode(#{@pattern})"
  end
end

# Node representing a rule definition (e.g., rule ancestor(X, Y) :- parent(X, Y))
class RuleNode < ASTNode
  attr_reader :head, :body

  def initialize(head, body)
    @head = head
    @body = body
  end

  def to_s
    "RuleNode(#{@head} :- #{@body})"
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