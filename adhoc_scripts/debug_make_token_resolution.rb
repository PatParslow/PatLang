#!/usr/bin/env ruby
require_relative 'src/lexer'
require_relative 'src/parser/token_resolver'

# Test the token resolution for "make a function called factorial"
code = "make a function called factorial takes: n { return 42 }"
lexer = Lexer.new(code)
tokens = lexer.tokenize

puts "=== LEXER OUTPUT ==="
tokens.each_with_index do |token, i|
  if token.is_a?(AmbiguousToken)
    puts "#{i}: AmbiguousToken - possibilities: #{token.possibilities.map{|p| p[:type]}}"
  else
    puts "#{i}: #{token.type} (#{token.value})"
  end
end

puts "\n=== TOKEN RESOLVER OUTPUT ==="
resolver = ParserModules::TokenResolver.new(tokens)

tokens.each_with_index do |token, i|
  if token.is_a?(AmbiguousToken)
    resolved = resolver.resolve_ambiguous_token(token, i)
    puts "#{i}: AmbiguousToken resolved to: #{resolved.type} (#{resolved.value})"
  else
    puts "#{i}: #{token.type} (#{token.value})"
  end
end