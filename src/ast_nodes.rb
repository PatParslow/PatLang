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