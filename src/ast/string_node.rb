# String Node for AST - Compatibility wrapper
# This file provides backward compatibility for tests that expect individual AST node files
# The actual implementation is in src/ast_nodes.rb

require_relative '../ast_nodes'

# StringNode is already defined in ast_nodes.rb as inheriting from ASTNode
# This file just ensures the require path works for tests
