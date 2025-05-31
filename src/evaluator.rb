require_relative 'ast_nodes'

# Evaluator class for traversing AST and computing arithmetic results
class Evaluator
  def initialize
    @variables = {}
  end

  def evaluate(node)
    case node
    when NumberNode
      visit_number_node(node)
    when BinaryOpNode
      visit_binary_op_node(node)
    when AssignmentNode
      visit_assignment_node(node)
    when VariableNode
      visit_variable_node(node)
    else
      raise "Unknown node type: #{node.class}"
    end
  end

  private

  def visit_number_node(node)
    node.value
  end

  def visit_binary_op_node(node)
    left_value = evaluate(node.left)
    right_value = evaluate(node.right)

    case node.operator
    when '+'
      left_value + right_value
    when '-'
      left_value - right_value
    when '*'
      left_value * right_value
    when '/'
      if right_value == 0
        raise "Division by zero"
      end
      left_value.to_f / right_value
    else
      raise "Unknown operator: #{node.operator}"
    end
  end

  def visit_assignment_node(node)
    value = evaluate(node.expression)
    @variables[node.name] = value
    value
  end

  def visit_variable_node(node)
    unless @variables.key?(node.name)
      raise "Undefined variable: #{node.name}"
    end
    @variables[node.name]
  end
end