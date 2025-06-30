#!/usr/bin/env ruby
# Fix script to remove @ character handling from lexer

require 'fileutils'

puts "=== Fixing Lexer @ Character Handling ==="
puts

# Read the current lexer file
lexer_file = 'src/lexer.rb'
content = File.read(lexer_file)

puts "1. Creating backup of lexer.rb..."
FileUtils.cp(lexer_file, "#{lexer_file}.backup")

puts "2. Current @ handling code (lines 200-203):"
lines = content.split("\n")
puts "   Line 200: #{lines[199]}"
puts "   Line 201: #{lines[200]}"
puts "   Line 202: #{lines[201]}"
puts "   Line 203: #{lines[202]}"

puts "\n3. Removing @ character handling..."

# Remove the '@' case block (lines 200-203)
# This regex matches the entire when '@' case block
updated_content = content.gsub(/^      when '@'\n        start_line, start_column = @line, @column\n        advance\n        return Token\.new\(Token::TOKEN_TYPES\[:AT\], '@', @position - 1, start_line, start_column\)\n/, '')

# Write the updated content
File.write(lexer_file, updated_content)

puts "4. Successfully removed @ character handling from lexer"
puts "5. The @ character will now fall through to the error case at line 242"

puts "\n=== Fix Applied Successfully ==="