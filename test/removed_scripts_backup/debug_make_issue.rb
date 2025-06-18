#!/usr/bin/env ruby

require_relative '../patlang-core/lexer/lexer'
require_relative '../patlang-core/parser/parser'

# Debug the MAKE token issue
test_code = "make z 25"

puts "🔍 DEBUGGING MAKE TOKEN ISSUE"
puts "Code: #{test_code}"
puts

# Step 1: Lexer output
puts "1. LEXER TOKENS:"
lexer = Lexer.new(test_code)
tokens = lexer.tokenize
tokens.each_with_index do |token, i|
  puts "  #{i}: #{token.type} -> '#{token.value}'"
end
puts

# Step 2: Parser AST
puts "2. PARSER AST:"
parser = Parser.new(tokens)
ast = parser.parse

def print_ast(node, indent = 0)
  spaces = "  " * indent
  case node
  when AssignmentNode
    puts "#{spaces}AssignmentNode:"
    puts "#{spaces}  name: '#{node.name}'"
    puts "#{spaces}  expression:"
    print_ast(node.expression, indent + 2)
  when NumberNode
    puts "#{spaces}NumberNode: #{node.value}"
  when VariableNode
    puts "#{spaces}VariableNode: '#{node.name}'"
  when BlockNode
    puts "#{spaces}BlockNode:"
    node.statements.each { |stmt| print_ast(stmt, indent + 1) }
  else
    puts "#{spaces}#{node.class}: #{node}"
  end
end

print_ast(ast)