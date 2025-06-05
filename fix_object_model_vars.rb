#!/usr/bin/env ruby

# Fix variable references in test_object_model.rb handlers

file_path = 'test/test_object_model.rb'
content = File.read(file_path)

puts "=== FIXING VARIABLE REFERENCES IN #{file_path} ==="

# Track changes
changes_made = 0

# Fix event_data variable references to just access event properties directly
content.gsub!(/event_data\[([^\]]+)\]/) do |match|
  changes_made += 1
  puts "#{changes_made}. Changed: #{match} → event[#{$1}]"
  "event[#{$1}]"
end

# Fix message_data variable references  
content.gsub!(/message_data\[([^\]]+)\]/) do |match|
  changes_made += 1
  puts "#{changes_made}. Changed: #{match} → event[#{$1}]"
  "event[#{$1}]"
end

# Write the updated content back
File.write(file_path, content)

puts
puts "=== SUMMARY ==="
puts "Total changes made: #{changes_made}"
puts "File updated: #{file_path}"
puts "All variable references now use event[key] pattern"