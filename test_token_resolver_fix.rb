#!/usr/bin/env ruby

# Quick validation test for token resolver LocalJumpError fix
require_relative 'src/lexer'
require_relative 'src/parser/token_resolver'

puts "Testing Token Resolver LocalJumpError Fix..."

begin
  # Create a simple test case that would trigger the token resolver
  lexer = Lexer.new("make test_function() { return 42; }")
  tokens = lexer.tokenize
  
  # Create token resolver and test the problematic method
  resolver = TokenResolver.new(tokens)
  resolved_tokens = resolver.resolve_all_ambiguous_tokens
  
  puts "✅ SUCCESS: Token resolver completed without LocalJumpError"
  puts "   Resolved #{resolved_tokens.length} tokens"
  
rescue LocalJumpError => e
  puts "❌ FAILED: LocalJumpError still occurs - #{e.message}"
  puts "   Location: #{e.backtrace.first}"
rescue => e
  puts "⚠️  OTHER ERROR: #{e.class.name}: #{e.message}"
  puts "   This may be expected if other components have issues"
end

puts "Token resolver fix validation complete."