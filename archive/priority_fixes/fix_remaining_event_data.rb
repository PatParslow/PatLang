#!/usr/bin/env ruby

# Fix remaining event_data variable references in test_object_model.rb

file_path = 'test/test_object_model.rb'
content = File.read(file_path)

puts "=== FIXING REMAINING EVENT_DATA REFERENCES IN #{file_path} ==="

# Track changes
changes_made = 0

# Fix standalone event_data variable references (not followed by [])
content.gsub!(/([^a-zA-Z_])event_data([^a-zA-Z_\[])/) do |match|
  changes_made += 1
  puts "#{changes_made}. Changed: #{match.strip} → event"
  "#{$1}event#{$2}"
end

# Fix event_data at start of line
content.gsub!(/^(\s*)event_data([^a-zA-Z_\[])/) do |match|
  changes_made += 1
  puts "#{changes_made}. Changed: #{match.strip} → event"
  "#{$1}event#{$2}"
end

# Write the updated content back
File.write(file_path, content)

puts
puts "=== SUMMARY ==="
puts "Total changes made: #{changes_made}"
puts "File updated: #{file_path}"
puts "All remaining event_data references changed to event"