# Base AST Node class
# All AST nodes inherit from this base class

class Node
  attr_reader :type, :position, :line, :column
  
  def initialize(type, position = nil, line = nil, column = nil)
    @type = type
    @position = position
    @line = line
    @column = column
  end
  
  # String representation for debugging
  def to_s
    "#<#{self.class}:#{object_id} type=#{@type} position=#{@position}>"
  end
  
  # Check if this node is of a specific type
  def type?(expected_type)
    @type == expected_type
  end
  
  # Accept visitor pattern for AST traversal
  def accept(visitor)
    visitor.visit(self)
  end
  
  # Get all child nodes (override in subclasses)
  def children
    []
  end
  
  # Deep clone support
  def deep_clone
    clone
  end
end