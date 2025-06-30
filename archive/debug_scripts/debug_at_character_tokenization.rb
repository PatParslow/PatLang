#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'src/lexer'
require_relative 'src/token'

def debug_tokenization(input)
  puts "Input: '#{input}'"
  lexer = Lexer.new(input)
  tokens = lexer.tokenize
  
  puts "Tokens (#{tokens.length}):"
  tokens.each_with_index do |token, i|
    puts "  #{i}: #{token.type} = '#{token.value}'"
  end
  puts
end

# Debug the failing test cases
puts "🔍 Debugging '@' Character Tokenization"
puts "=" * 40

debug_tokenization('user @ domain.com')
debug_tokenization('test@example.com')
debug_tokenization('"email: " + user@domain.com')