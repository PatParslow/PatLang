require_relative 'ast_nodes'

# Evaluator class for traversing AST and computing arithmetic results
class Evaluator
  def evaluate(node)
    case node
    when NumberNode
      visit_number_node(node)
    when BinaryOpNode
      visit_binary_op_node(node)
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
end