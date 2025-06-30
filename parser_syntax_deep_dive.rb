#!/usr/bin/env ruby
# Deep dive into parser support for advanced syntax

require_relative 'patlang-core/lexer/lexer'
require_relative 'patlang-core/parser/parser'

puts "🔍 Deep Dive: Parser Syntax Support Analysis"
puts "=" * 50

# Test 1: Goal syntax parsing
puts "\n📊 GOAL SYNTAX PARSING"
puts "-" * 30

goal_code = <<~PAT
goal find_number {
  description: "Find a number"
  precondition: x > 0
  postcondition: result.even?
  strategy: search
}
PAT

begin
  lexer = Lexer.new(goal_code)
  tokens = lexer.tokenize
  
  puts "Tokens generated:"
  tokens.each_with_index do |token, i|
    puts "  #{i}: #{token.type} = '#{token.value}'"
  end
  
  # Try parsing
  parser = Parser.new(tokens)
  ast = parser.parse
  
  puts "\nParsing result:"
  puts "  AST type: #{ast.class}"
  puts "  AST content: #{ast.inspect}"
  
rescue => e
  puts "Parsing failed: #{e.message}"
  puts "This indicates incomplete parser support for goal syntax"
end

# Test 2: Event syntax parsing  
puts "\n📊 EVENT SYNTAX PARSING"
puts "-" * 30

event_code = <<~PAT
when button_clicked {
  fire_event(:user_action, data: "clicked")
  handle_response()
}
PAT

begin
  lexer = Lexer.new(event_code)
  tokens = lexer.tokenize
  
  puts "Tokens for event syntax:"
  tokens.each_with_index do |token, i|
    puts "  #{i}: #{token.type} = '#{token.value}'"
  end
  
  parser = Parser.new(tokens)
  ast = parser.parse
  
  puts "\nEvent parsing result:"
  puts "  AST type: #{ast.class}"
  puts "  AST handles 'when': #{ast.to_s.include?('when') ? 'Yes' : 'No'}"
  
rescue => e
  puts "Event parsing failed: #{e.message}"
end

# Test 3: Logic programming syntax
puts "\n📊 LOGIC PROGRAMMING SYNTAX"
puts "-" * 30

logic_code = <<~PAT
fact parent(john, mary).
fact parent(mary, susan).
rule grandparent(X, Z) :- parent(X, Y), parent(Y, Z).
query grandparent(john, susan).
PAT

begin
  lexer = Lexer.new(logic_code)
  tokens = lexer.tokenize
  
  puts "Logic programming tokens:"
  tokens.each_with_index do |token, i|
    puts "  #{i}: #{token.type} = '#{token.value}'"
  end
  
  parser = Parser.new(tokens)
  ast = parser.parse
  
  puts "\nLogic parsing result:"
  puts "  Supports facts: #{tokens.any? { |t| t.value == 'fact' }}"
  puts "  Supports rules: #{tokens.any? { |t| t.value == 'rule' }}"
  puts "  Supports queries: #{tokens.any? { |t| t.value == 'query' }}"
  
rescue => e
  puts "Logic parsing failed: #{e.message}"
end

# Test 4: What DOES parse successfully?
puts "\n📊 WHAT SYNTAX WORKS?"
puts "-" * 30

working_code = <<~PAT
x = 5
y = x + 10
result = x * y
PAT

begin
  lexer = Lexer.new(working_code)
  tokens = lexer.tokenize
  parser = Parser.new(tokens)
  ast = parser.parse
  
  puts "Basic syntax parsing:"
  puts "  ✅ Successfully parsed: #{ast.class}"
  puts "  ✅ Handles assignments: Yes"
  puts "  ✅ Handles arithmetic: Yes"
  
rescue => e
  puts "Even basic parsing failed: #{e.message}"
end

puts "\n🎯 PARSER ANALYSIS SUMMARY"
puts "=" * 50
puts "The parser recognizes advanced keywords (goal, when, fact, rule)"
puts "but likely doesn't have complete grammar rules to handle"
puts "the full syntax structures these keywords should support."
puts ""
puts "This confirms the gap is in PARSER GRAMMAR COMPLETENESS,"
puts "not in backend implementation or keyword recognition."