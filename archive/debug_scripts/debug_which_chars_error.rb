#!/usr/bin/env ruby

require_relative 'src/lexer'
require_relative 'src/token'

puts "=== Testing which characters actually raise lexer errors ==="
puts

# Test the characters that were in the original invalid_inputs
test_chars = [
  "#", "$", "%",  # Individual chars from "#$%"
  "~", "!",       # From "~!"
  "€", "£", "¥",  # Currency symbols
  "∞", "∑", "∏",  # Mathematical symbols
  "α", "β", "γ",  # Greek letters
  "中", "文",      # Chinese characters
  "🚀", "💻",     # Emojis
]

test_chars.each do |char|
  print "Testing '#{char}' (#{char.ord}): "
  
  begin
    lexer = Lexer.new(char)
    tokens = lexer.tokenize
    puts "✓ SUCCESS - produces tokens: #{tokens.map { |t| "#{t.type}:#{t.value}" }.join(', ')}"
  rescue RuntimeError => e
    puts "✗ ERROR - #{e.message}"
  rescue => e
    puts "? UNEXPECTED - #{e.class}: #{e.message}"
  end
end

puts
puts "=== Testing full strings ==="

test_strings = [
  "#$%",
  "~!",
  "€£¥",
  "∞∑∏",
  "αβγ",
  "中文",
  "🚀💻",
]

test_strings.each do |string|
  print "Testing '#{string}': "
  
  begin
    lexer = Lexer.new(string)
    tokens = lexer.tokenize
    puts "✓ SUCCESS - produces tokens: #{tokens.map { |t| "#{t.type}:#{t.value}" }.join(', ')}"
  rescue RuntimeError => e
    puts "✗ ERROR - #{e.message}"
  rescue => e
    puts "? UNEXPECTED - #{e.class}: #{e.message}"
  end
end