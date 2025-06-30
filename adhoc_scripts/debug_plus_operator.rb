#!/usr/bin/env ruby

require_relative 'src/patlang'

puts "🔍 DEBUGGING PLUS OPERATOR FOR '5 + 3'"
puts "=" * 50

code = "5 + 3"
puts "Code: #{code.inspect}"

# Debug lexing
puts "\n📝 LEXING PHASE:"
puts "-" * 20
lexer = Lexer.new(code)
tokens = lexer.tokenize
tokens.each_with_index do |token, i|
  puts "#{i}: #{token.type.inspect} = #{token.value.inspect}"
end

# Debug parsing
puts "\n🔧 PARSING PHASE:"
puts "-" * 20
parser = Parser.new(tokens)
begin
  ast = parser.parse
  puts "AST created successfully"
  
  # Let's examine the AST structure
  def inspect_node(node, indent = 0)
    prefix = "  " * indent
    case node
    when BinaryOpNode
      puts "#{prefix}BinaryOpNode:"
      puts "#{prefix}  operator: #{node.operator.inspect}"
      puts "#{prefix}  left:"
      inspect_node(node.left, indent + 2)
      puts "#{prefix}  right:"
      inspect_node(node.right, indent + 2)
    when NumberNode
      puts "#{prefix}NumberNode: #{node.value}"
    else
      puts "#{prefix}#{node.class}: #{node.inspect}"
    end
  end
  
  puts "\nAST Structure:"
  inspect_node(ast)
  
rescue => e
  puts "❌ Parse error: #{e.message}"
  puts "Backtrace: #{e.backtrace.first(3).join('\n')}"
end

# Debug evaluation if parsing succeeded
if defined?(ast) && ast
  puts "\n⚡ EVALUATION PHASE:"
  puts "-" * 20
  evaluator = Evaluator.new
  
  begin
    result = evaluator.evaluate(ast)
    puts "✅ Result: #{result.inspect}"
  rescue => e
    puts "❌ Evaluation error: #{e.message}"
    puts "Backtrace: #{e.backtrace.first(5).join('\n')}"
  end
end