#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/parser'

def debug_goal_parsing
  puts "=== Debugging Goal Parsing ==="
  
  code = 'goal validate_data { precondition: data :: Object, postcondition: data.valid }'
  puts "Testing: #{code}"
  
  begin
    lexer = Lexer.new(code)
    tokens = lexer.tokenize
    puts "Tokens:"
    tokens.each_with_index do |token, i|
      puts "  #{i}: #{token}"
    end
    
    puts "\nParsing..."
    parser = Parser.new(tokens)
    ast = parser.parse
    puts "Success: #{ast.class}"
    puts "AST: #{ast.inspect}"
  rescue => e
    puts "ERROR: #{e.message}"
    puts "Error class: #{e.class}"
    puts "Backtrace:"
    e.backtrace[0..5].each { |line| puts "  #{line}" }
  end
end

if __FILE__ == $0
  debug_goal_parsing
end