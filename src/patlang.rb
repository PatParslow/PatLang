#!/usr/bin/env ruby

require_relative 'lexer'
require_relative 'token'
require_relative 'parser'
require_relative 'ast_nodes'
require_relative 'evaluator'
require_relative 'reasoning/reasoning_coordinator'
require_relative 'reasoning/form_validator'
require_relative 'reasoning/goal_system'
require_relative 'reasoning/facts_database'

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
    # Enhanced evaluate method with reasoning integration
    if expression.is_a?(String) && (expression.include?('form') || expression.include?('goal') || expression.include?('fact'))
      # Use reasoning-enhanced evaluation
      evaluate_with_reasoning(expression)
    else
      # Use standard evaluation
      process_expression(expression, show_details: false)
    end
  end

  def self.evaluate_with_reasoning(code)
    # Initialize reasoning coordinator
    coordinator = ReasoningCoordinator.new
    
    # Register reasoning components
    coordinator.register_component(:form_validator, FormValidator.new)
    coordinator.register_component(:goal_system, GoalSystem.new)
    coordinator.register_component(:facts_database, FactsDatabase.new)
    
    begin
      # Process through reasoning coordinator
      coordinator.process_expression(code)
    rescue => e
      # Fallback to standard evaluation if reasoning fails
      process_expression(code, show_details: false)
    end
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

  def self.run_file(filename)
    unless File.exist?(filename)
      puts "Error: File '#{filename}' not found."
      exit 1
    end
    
    begin
      content = File.read(filename)
      puts "Running #{filename}..."
      puts "=" * 40
      
      evaluator = Evaluator.new
      result = process_expression_with_evaluator(content, evaluator, show_details: false)
      puts "Final result: #{result}" if result
    rescue => e
      puts "Error executing #{filename}: #{e.message}"
      exit 1
    end
  end
end

# Run demo if this file is executed directly
if __FILE__ == $0
  if ARGV.include?('--demo')
    Patlang.demo
  elsif ARGV.include?('--repl')
    Patlang.repl
  elsif ARGV.include?('--help') || ARGV.include?('-h')
    puts "Patlang v0.4.0 - String Operations"
    puts "Usage:"
    puts "  ruby #{$0}              # Run demo mode"
    puts "  ruby #{$0} --demo       # Run demo mode"
    puts "  ruby #{$0} --repl       # Run REPL mode"
    puts "  ruby #{$0} <filename>   # Execute a .pat file"
    puts "  ruby #{$0} --help       # Show this help"
    puts ""
    puts "Demo mode shows lexer, parser, and evaluator output for sample expressions."
    puts "REPL mode provides an interactive shell for testing expressions."
    puts "File mode executes Patlang programs from .pat files."
  elsif ARGV.length == 1 && !ARGV[0].start_with?('--')
    # Single argument that doesn't start with -- is treated as a filename
    Patlang.run_file(ARGV[0])
  elsif ARGV.empty?
    Patlang.demo
  else
    puts "Unknown argument: #{ARGV.join(' ')}"
    puts "Use --help for usage information."
    exit 1
  end
end