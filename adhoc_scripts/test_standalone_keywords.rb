#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/token'

def test_standalone_keywords
  test_cases = [
    'make',
    'a', 
    'function',
    'called'
  ]
  
  test_cases.each do |keyword|
    puts "Testing standalone: '#{keyword}'"
    lexer = Lexer.new(keyword)
    tokens = lexer.tokenize
    
    puts "  Result: #{tokens[0].type}"
    puts
  end
end

if __FILE__ == $0
  test_standalone_keywords
end