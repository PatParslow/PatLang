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
    
    evaluator = Evaluator.new  # Persistent evaluator for REPL
    
    loop do
      print "> "
      input = STDIN.gets
      break if input.nil? || input.chomp.downcase == 'exit'
      
      input = input.chomp
      next if input.strip.empty?
      
      begin
        result = process_expression_with_evaluator(input, evaluator, show_details: false)
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
    
    evaluator = Evaluator.new  # Persistent evaluator for REPL
    
    loop do
      print "> "
      input = gets
      break if input.nil? || input.chomp.downcase == 'exit'
      
      input = input.chomp
      next if input.strip.empty?
      
      begin
        result = process_expression_with_evaluator(input, evaluator, show_details: false)
        puts result
      rescue => e
        puts "Error: #{e.message}"
      end
    end
    
    puts "Goodbye!"
  end

  def self.process_expression_with_evaluator(expression, evaluator, show_details: false)
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
      
      # Evaluation with provided evaluator
      if show_details
        puts "EVALUATION:"
        puts "-" * 20
      end
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
end

# Run demo if this file is executed directly
if __FILE__ == $0
  if ARGV.include?('--demo') || ARGV.empty?
    Patlang.demo
  elsif ARGV.include?('--help') || ARGV.include?('-h')
    puts "Patlang v0.2.0 - Variables and Assignment"
    puts "Usage:"
    puts "  ruby #{$0}         # Run demo mode"
    puts "  ruby #{$0} --demo  # Run demo mode"
    puts "  ruby #{$0} --help  # Show this help"
    puts ""
    puts "Demo mode shows lexer, parser, and evaluator output for sample expressions,"
    puts "then enters an interactive REPL for testing variable assignments and arithmetic."
  else
    puts "Unknown argument: #{ARGV.join(' ')}"
    puts "Use --help for usage information."
    exit 1
  end
end