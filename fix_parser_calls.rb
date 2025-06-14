#!/usr/bin/env ruby

# Script to fix all @parser.parse(code) calls to use create_parser(code).parse

file_path = 'test/infrastructure/test_type_constraint_parser.rb'
content = File.read(file_path)

# Replace all instances of @parser.parse(code) with parser = create_parser(code); result = parser.parse
content.gsub!(/@parser\.parse\(([^)]+)\)/) do |match|
  code_param = $1
  "parser = create_parser(#{code_param})\n    result = parser.parse"
end

# Also replace standalone "result = @parser.parse" with "parser = create_parser(code)\n    result = parser.parse"
content.gsub!(/result = @parser\.parse/) do |match|
  "parser = create_parser(code)\n    result = parser.parse"
end

# Replace error assertions that use @parser.parse
content.gsub!(/@parser\.parse\(([^)]+)\)/) do |match|
  code_param = $1
  "create_parser(#{code_param}).parse"
end

# Write the updated content back
File.write(file_path, content)

puts "Fixed all parser calls in #{file_path}"