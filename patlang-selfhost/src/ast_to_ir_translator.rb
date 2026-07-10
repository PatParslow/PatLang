# AST → IR Translator for Patlang
# Contract-driven: Converts AST nodes to IR instructions as per IR schema.

require_relative '../../patlang-core/ast/ast_nodes'

module Patlang
  module IR
    # IR instruction types (mirroring rust-runtime/src/ir/types.rs)
    Instr = Struct.new(:op, :args)

    class Translator
      # Entry point: translate an AST node to a list of IR instructions
      def self.translate(ast)
        new.translate_node(ast)
      end

      def translate_node(node)
        case node
        when NumberNode
          [Instr.new(:Const, [node.value])]
        when VariableNode
          [Instr.new(:LoadLocal, [node.name])]
        when AssignmentNode
          expr_code = translate_node(node.expression)
          expr_code + [Instr.new(:StoreLocal, [node.name])]
        when BinaryOpNode
          left_code = translate_node(node.left)
          right_code = translate_node(node.right)
          op = binop_to_ir(node.operator)
          left_code + right_code + [Instr.new(:BinOp, [op])]
        when UnaryOpNode
          operand_code = translate_node(node.operand)
          op = unop_to_ir(node.operator)
          operand_code + [Instr.new(:UnOp, [op])]
        else
          raise NotImplementedError, "Unknown AST node: #{node.class}"
        end
      end

      private

      def binop_to_ir(op)
        # Map AST operator string to IR BinOpKind symbol
        {
          '+' => :Add,
          '-' => :Sub,
          '*' => :Mul,
          '/' => :Div,
          '%' => :Mod,
          '==' => :Eq,
          '!=' => :Ne,
          '<' => :Lt,
          '<=' => :Le,
          '>' => :Gt,
          '>=' => :Ge,
          '&&' => :And,
          '||' => :Or
        }.fetch(op) { raise ArgumentError, "Unknown binary operator: #{op}" }
      end

      def unop_to_ir(op)
        {
          '-' => :Neg,
          '!' => :Not
        }.fetch(op) { raise ArgumentError, "Unknown unary operator: #{op}" }
      end
    end
  end
end