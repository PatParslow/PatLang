#!/usr/bin/env ruby

# Patlang Bootstrap Entry Point
# This file loads the core Patlang language implementation through the Ruby host

puts "🚀 Patlang Bootstrap - Ruby Host Implementation"
puts "=============================================="

# Add the project root to the load path
project_root = File.expand_path('../../', __FILE__)
$LOAD_PATH.unshift(project_root)

begin
  # Load Ruby host bootstrap components
  puts "📚 Loading Ruby host bootstrap..."
  require_relative 'hash_extensions'
  require_relative 'emergency_timeout'
  
  # Load core language components from patlang-core
  puts "🔧 Loading Patlang core language components..."
  require_relative '../../patlang-core/exceptions'
  require_relative '../../patlang-core/lexer/token'
  require_relative '../../patlang-core/lexer/ambiguous_token'
  require_relative '../../patlang-core/lexer/lexer'
  require_relative '../../patlang-core/ast/ast_nodes'
  require_relative '../../patlang-core/parser/parser'
  require_relative '../../patlang-core/evaluator/evaluator'
  
  puts "✅ All core components loaded successfully!"
  
  # Test basic functionality
  puts "\n🧪 Testing basic functionality..."
  
  # Test lexer
  lexer = Lexer.new("x = 42")
  tokens = lexer.tokenize
  puts "  Lexer test: #{tokens.length} tokens generated ✓"
  
  # Test parser
  parser = Parser.new(tokens)
  ast = parser.parse
  puts "  Parser test: AST generated ✓"
  
  # Test evaluator
  evaluator = Evaluator.new
  result = evaluator.evaluate(ast)
  puts "  Evaluator test: Result = #{result} ✓"
  
  puts "\n🎉 Bootstrap Complete - Patlang is ready!"
  
rescue => e
  puts "\n❌ Bootstrap Failed: #{e.message}"
  puts "Stack trace:"
  puts e.backtrace[0..5].map { |line| "  #{line}" }
  exit 1
end

# If this file is run directly, start the REPL
if __FILE__ == $PROGRAM_NAME
  puts "\n💬 Starting Patlang REPL..."
  puts "Type 'exit' to quit"
  
  evaluator = Evaluator.new
  
  loop do
    print "patlang> "
    input = gets.chomp
    
    break if input == 'exit'
    next if input.empty?
    
    begin
      lexer = Lexer.new(input)
      tokens = lexer.tokenize
      parser = Parser.new(tokens)
      ast = parser.parse
      result = evaluator.evaluate(ast)
      puts "=> #{result}"
    rescue => e
      puts "Error: #{e.message}"
    end
  end
  
  puts "Goodbye!"
end