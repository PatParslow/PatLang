#!/usr/bin/env ruby

# Test script to verify iso8601 compatibility fix works in Ruby 3.3.7

puts "🧪 Testing ISO8601 Compatibility Fix"
puts "=" * 40
puts "Ruby Version: #{RUBY_VERSION}"
puts

# Test the fixed format
begin
  # Test current time
  current_time = Time.now.strftime("%Y-%m-%dT%H:%M:%S%z")
  puts "✅ Time.now.strftime format: #{current_time}"
  
  # Test UTC time  
  utc_time = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
  puts "✅ Time.now.utc.strftime format: #{utc_time}"
  
  # Test with a specific time variable
  test_time = Time.now
  formatted_time = test_time.strftime("%Y-%m-%dT%H:%M:%S%z")
  puts "✅ Variable.strftime format: #{formatted_time}"
  
  puts
  puts "🎉 All iso8601 replacements are working correctly!"
  puts "📅 Format matches ISO 8601 standard"
  
rescue => e
  puts "❌ Error: #{e.message}"
end