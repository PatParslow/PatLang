#!/usr/bin/env ruby

require_relative 'lexer'
require_relative 'token'

# Main Patlang interpreter entry point
class Patlang
  def self.tokenize_and_print(expression)
    puts "Tokenizing: #{expression}"
    puts "-" * 40
    
    begin
      lexer = Lexer.new(expression)
      tokens = lexer.tokenize
      
      tokens.each_with_index do |token, index|
        puts "#{index + 1}. #{token}"
      end
      
      puts "-" * 40
      puts "Total tokens: #{tokens.length}"
      puts
    rescue => e
      puts "Error: #{e.message}"
      puts
    end
  end

  def self.demo
    puts "Patlang Minimal Lexer Demo"
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
      tokenize_and_print(expr)
    end
    
    # Interactive mode
    puts "Interactive mode (type 'exit' to quit):"
    puts "-" * 40
    
    loop do
      print "> "
      input = gets
      break if input.nil? || input.chomp.downcase == 'exit'
      
      input = input.chomp
      next if input.strip.empty?
      
      tokenize_and_print(input)
    end
    
    puts "Goodbye!"
  end
end

# Run demo if this file is executed directly
if __FILE__ == $0
  Patlang.demo
end