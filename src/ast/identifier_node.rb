# Identifier Node for AST - Compatibility wrapper
# This file provides backward compatibility for tests that expect individual AST node files
# The actual implementation is in src/ast_nodes.rb

require_relative '../ast_nodes'

# Create IdentifierNode as an alias to VariableNode since that's what's used in ast_nodes.rb
# This maintains compatibility while using the existing comprehensive AST implementation
class IdentifierNode < VariableNode
  alias_method :name, :value
  
  def initialize(name, value = nil)
    super(name)
    @value = value || name
  end
end
