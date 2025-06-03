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