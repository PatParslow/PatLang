require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/ast_nodes'

def debug_statement_method(input)
  puts "\n🔍 Testing statement method directly for: #{input}"
  puts '=' * 50
  
  lexer = Lexer.new(input)
  tokens = lexer.tokenize
  parser = Parser.new(tokens)
  parser.resolve_all_ambiguous_tokens
  
  # Test the statement method directly
  current_token = parser.instance_variable_get(:@current_token)
  puts "Current token: #{current_token&.class&.name}(#{current_token&.type}, #{current_token&.value})"
  puts "Next token (peek 1): #{parser.peek(1)&.class&.name}(#{parser.peek(1)&.type}, #{parser.peek(1)&.value})"
  
  # Check the assignment detection logic manually
  if current_token&.type == Token::TOKEN_TYPES[:IDENTIFIER] && parser.peek(1)&.type == Token::TOKEN_TYPES[:ASSIGN]
    puts "✅ Should take assignment path!"
  else
    puts "❌ Will not take assignment path"
  end
  
  begin
    stmt = parser.send(:statement)  # Call statement method directly
    puts "✅ Statement parsed successfully: #{stmt.class.name}"
  rescue => e
    puts "❌ Statement parsing failed: #{e.message}"
    puts "Backtrace: #{e.backtrace.first}"
  end
end

debug_statement_method('a = 5')