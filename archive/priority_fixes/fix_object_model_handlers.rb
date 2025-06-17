#!/usr/bin/env ruby

# Script to revert test_object_model.rb handlers back to full event object access

file_path = 'test/test_object_model.rb'
content = File.read(file_path)

puts "=== REVERTING EVENT HANDLERS IN #{file_path} ==="
puts "Converting back from event_data parameter to event parameter with direct property access"
puts

# Track changes
changes_made = 0

# Fix handlers that I previously changed to use event_data parameter - change back to event
content.gsub!(/do \|event_data\|/) do |match|
  changes_made += 1
  puts "#{changes_made}. Changed parameter back: #{match} → do |event|"
  "do |event|"
end

# Fix handlers that I previously changed to use message_data parameter - change back to event  
content.gsub!(/do \|message_data\|/) do |match|
  changes_made += 1
  puts "#{changes_made}. Changed parameter back: #{match} → do |event|"
  "do |event|"
end

# Now these test_object_model.rb tests expect direct access to event properties
# So event_data[:old_value] should become event[:old_value] (not event[:data][:old_value])
# These are different from test_object_evaluation.rb which subscribes to global events

# Write the updated content back
File.write(file_path, content)

puts
puts "=== SUMMARY ==="
puts "Total changes made: #{changes_made}"
puts "File updated: #{file_path}"
puts "test_object_model.rb now uses event parameter with direct property access"
puts "This works because object instance events pass the data directly as the event"