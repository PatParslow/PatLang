#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/parser'
require_relative 'src/parser/token_resolver'

# Test token resolution specifically
test_code = "make a function called sum_range takes: start, end {"

puts "Testing token resolution for parameter context..."
puts "Code: #{test_code}"
puts "\n" + "="*50

begin
  lexer = Lexer.new(test_code)
  raw_tokens = lexer.tokenize
  
  puts "Raw tokens (before resolution):"
  raw_tokens.each_with_index do |token, i|
    if token.is_a?(AmbiguousToken)
      puts "#{i}: AMBIGUOUS [#{token.possibilities.map{|p| "#{p[:type]}:#{p[:value]}"}.join(', ')}]"
    else
      puts "#{i}: #{token.type} = '#{token.value}'"
    end
  end
  puts "\n" + "="*30
  
  resolver = ParserModules::TokenResolver.new(raw_tokens)
  resolved_tokens = resolver.resolve_all_ambiguous_tokens
  
  puts "Resolved tokens (after resolution):"
  resolved_tokens.each_with_index do |token, i|
    puts "#{i}: #{token.type} = '#{token.value}'"
  end
  
rescue => e
  puts "Error: #{e.message}"
  puts "Backtrace:"
  puts e.backtrace[0..5].join("\n")
end