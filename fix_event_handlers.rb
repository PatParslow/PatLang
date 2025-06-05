#!/usr/bin/env ruby

# Script to fix all event handlers in test_object_evaluation.rb
# Change from event_data parameter to event parameter and update data access

file_path = 'test/test_object_evaluation.rb'
content = File.read(file_path)

puts "=== FIXING EVENT HANDLERS IN #{file_path} ==="
puts

# Track changes
changes_made = 0

# Fix all EventSystem.subscribe handlers that use event_data parameter
content.gsub!(/EventSystem\.subscribe\([^)]+\) do \|event_data\|/) do |match|
  changes_made += 1
  puts "#{changes_made}. Changed parameter: #{match}"
  match.gsub('|event_data|', '|event|')
end

# Fix all event_data[:key] references to event[:data][:key]
content.gsub!(/event_data\[([^\]]+)\]/) do |match|
  changes_made += 1
  puts "#{changes_made}. Changed data access: #{match} → event[:data][#{$1}]"
  "event[:data][#{$1}]"
end

# Write the updated content back
File.write(file_path, content)

puts
puts "=== SUMMARY ==="
puts "Total changes made: #{changes_made}"
puts "File updated: #{file_path}"
puts "All event handlers now use event parameter and event[:data][:key] access pattern"