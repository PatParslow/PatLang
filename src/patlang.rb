#!/usr/bin/env ruby

require_relative 'lexer'
require_relative 'token'
require_relative 'parser'
require_relative 'ast_nodes'
require_relative 'evaluator'

# Main Patlang interpreter entry point
class Patlang
  def self.process_expression(expression, show_details: false)
    puts "Processing: #{expression}" if show_details
    puts "=" * 50 if show_details
    
    begin
      # Tokenization
      if show_details
        puts "TOKENS:"
        puts "-" * 20
      end
      lexer = Lexer.new(expression)
      tokens = lexer.tokenize
      
      if show_details
        tokens.each_with_index do |token, index|
          puts "#{index + 1}. #{token}"
        end
        puts "Total tokens: #{tokens.length}"
        puts
      end
      
      # Parsing
      if show_details
        puts "AST:"
        puts "-" * 20
      end
      parser = Parser.new(tokens)
      ast = parser.parse
      
      if show_details
        puts "#{ast}"
        puts
      end
      
      # Evaluation
      if show_details
        puts "EVALUATION:"
        puts "-" * 20
      end
      evaluator = Evaluator.new
      result = evaluator.evaluate(ast)
      
      if show_details
        puts "Result: #{result}"
        puts
      end
      
      result
    rescue => e
      if show_details
        puts "Error: #{e.message}"
        puts
      end
      raise e
    end
  end

  def self.evaluate(expression)
    process_expression(expression, show_details: false)
  end

  def self.demo
    puts "Patlang Minimal Lexer & Parser Demo"
    puts "=" * 50
    puts
    
    # Demo expressions
    expressions = [
      "42",
      "2 + 3",
      "2 + 3 * 4",
      "(2 + 3) * 4",
      "10 - 5 / 2",
      "1 + 2 - 3 * 4 / 5"
    ]
    
    expressions.each do |expr|
      process_expression(expr, show_details: true)
    end
    
    # Interactive REPL mode
    puts "Interactive REPL (type 'exit' to quit):"
    puts "-" * 40
    
    loop do
      print "> "
      input = gets
      break if input.nil? || input.chomp.downcase == 'exit'
      
      input = input.chomp
      next if input.strip.empty?
      
      begin
        result = evaluate(input)
        puts result
      rescue => e
        puts "Error: #{e.message}"
      end
    end
    
    puts "Goodbye!"
  end

  def self.repl
    puts "Patlang Arithmetic Interpreter REPL"
    puts "=" * 40
    puts "Enter arithmetic expressions to evaluate."
    puts "Type 'exit' to quit."
    puts
    
    loop do
      print "> "
      input = gets
      break if input.nil? || input.chomp.downcase == 'exit'
      
      input = input.chomp
      next if input.strip.empty?
      
      begin
        result = evaluate(input)
        puts result
      rescue => e
        puts "Error: #{e.message}"
      end
    end
    
    puts "Goodbye!"
  end
end

# Run demo if this file is executed directly
if __FILE__ == $0
  Patlang.demo
end