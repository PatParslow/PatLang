#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/token'

# Patch the lexer to add debug output
class Lexer
  alias_method :original_in_function_phrase_context?, :in_function_phrase_context?
  alias_method :original_check_function_phrase, :check_function_phrase
  
  def in_function_phrase_context?(position = @position)
    result = original_in_function_phrase_context?(position)
    puts "  in_function_phrase_context?(#{position}) = #{result} (current text: '#{@text[[@position-10, 0].max...@position+10]}')"
    result
  end
  
  def check_function_phrase
    result = original_check_function_phrase
    puts "  check_function_phrase() = #{result} (at position #{@position})"
    result
  end
end

def debug_context_detection
  puts "Debugging context detection..."
  
  # Test the specific phrase
  puts "\nTesting: 'make a function called test_func'"
  lexer = Lexer.new("make a function called test_func")
  tokens = lexer.tokenize
  
  puts "\nTokens:"
  tokens.each_with_index do |token, i|
    puts "#{i}: #{token.type} -> '#{token.value}'"
  end
end

if __FILE__ == $0
  debug_context_detection
end