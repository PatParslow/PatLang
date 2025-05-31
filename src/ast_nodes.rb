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