#!/usr/bin/env ruby

require_relative 'src/parser'
require_relative 'src/lexer'

# Chain of Drafts: Test parser event method existence
puts "=== Diagnostic: Parser Event System ==="

# Check if Parser has on_event method
lexer = Lexer.new("x :: Number")
tokens = lexer.tokenize
parser = Parser.new(tokens)

puts "Parser class: #{parser.class}"
puts "Parser responds to on_event?: #{parser.respond_to?(:on_event)}"
puts "Parser methods containing 'event': #{parser.methods.select { |m| m.to_s.include?('event') }}"

# Check what the test is trying to do
puts "\n=== Issue Analysis ==="
puts "The test expects parser.on_event(:type_annotation_parsed) to work"
puts "But Parser class has no event system"
puts "Solution: Add event system to Parser class"

puts "\n=== Proposed Fix ==="
puts "1. Add EventCapable mixin to Parser class"
puts "2. Add event firing when parsing type annotations"
puts "3. Ensure TypeConstraintParser fires events"