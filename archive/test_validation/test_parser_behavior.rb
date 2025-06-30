require_relative 'src/lexer'
require_relative 'src/parser'

# Test the exact failing case
code = 'goal malformed { postcondition missing colon }'

lexer = Lexer.new(code)
tokens = lexer.tokenize
parser = Parser.new(tokens)

puts "Testing: #{code}"
puts "Tokens: #{tokens.map { |t| "#{t.type}:#{t.value}" }.join(', ')}"

result = parser.parse
puts "Result class: #{result.class}"

if result.respond_to?(:statements) && result.statements.any?
  goal_stmt = result.statements.first
  puts "First statement: #{goal_stmt.class}"
  
  if goal_stmt.is_a?(ErrorNode)
    puts "✓ ERROR DETECTED: #{goal_stmt.message}"
  else
    puts "❌ NO ERROR: Parser succeeded when it should have failed"
    
    # Let's examine what was actually parsed
    if goal_stmt.respond_to?(:name)
      puts "  Goal name: #{goal_stmt.name}"
    end
    if goal_stmt.respond_to?(:postconditions)
      puts "  Postconditions: #{goal_stmt.postconditions.inspect}"
    end
  end
end
