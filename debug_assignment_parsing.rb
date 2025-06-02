require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/ast_nodes'

def debug_assignment_parsing(input)
  puts "\n🔍 Debugging assignment parsing for: #{input}"
  puts '=' * 50
  
  lexer = Lexer.new(input)
  tokens = lexer.tokenize
  
  puts "Tokens:"
  tokens.each_with_index do |token, i|
    puts "  #{i}: #{token.class.name}(#{token.type}, #{token.value})"
  end
  
  parser = Parser.new(tokens)
  parser.resolve_all_ambiguous_tokens
  
  # Get the resolved tokens
  resolved_tokens = parser.instance_variable_get(:@tokens)
  current_token = parser.instance_variable_get(:@current_token)
  
  puts "\nResolved tokens:"
  resolved_tokens.each_with_index do |token, i|
    puts "  #{i}: #{token.class.name}(#{token.type}, #{token.value})"
  end
  
  puts "\nCurrent token: #{current_token&.class&.name}(#{current_token&.type}, #{current_token&.value})"
  puts "Next token (peek 1): #{parser.peek(1)&.class&.name}(#{parser.peek(1)&.type}, #{parser.peek(1)&.value})"
  
  # Test the peek logic manually
  if current_token&.type == :IDENTIFIER && parser.peek(1)&.type == :ASSIGN
    puts "✅ PEEK LOGIC: Should detect assignment!"
  else
    puts "❌ PEEK LOGIC: Assignment not detected"
    puts "  Current token type: #{current_token&.type}"
    puts "  Next token type: #{parser.peek(1)&.type}"
  end
  
  begin
    ast = parser.parse
    puts "✅ Parsed successfully: #{ast.class.name}"
  rescue => e
    puts "❌ Parse error: #{e.message}"
  end
end

debug_assignment_parsing('a = 5')
debug_assignment_parsing('x = 10')