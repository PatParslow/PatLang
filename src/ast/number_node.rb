# Number Node for AST - Compatibility wrapper
# This file provides backward compatibility for tests that expect individual AST node files
# The actual implementation is in src/ast_nodes.rb

require_relative '../ast_nodes'

# NumberNode is already defined in ast_nodes.rb as inheriting from ASTNode
# This file just ensures the require path works for tests
