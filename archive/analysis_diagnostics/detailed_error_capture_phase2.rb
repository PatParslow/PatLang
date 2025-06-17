#!/usr/bin/env ruby

puts "🔍 DETAILED ERROR CAPTURE - PHASE 2"
puts "=" * 50

puts "\n🎯 Running test suite with detailed error capture..."

# Run tests and capture full output
result = `timeout 60 rake test 2>&1`

puts "\n📊 ANALYZING SPECIFIC ERROR PATTERNS..."

# Capture specific error contexts
puts "\n🔧 MISSING safe_error METHOD:"
safe_error_matches = result.scan(/.*undefined method `safe_error'.*\n.*\n.*\n/)
safe_error_matches.first(3).each_with_index do |match, i|
  puts "   #{i+1}. #{match.strip}"
  puts
end

puts "\n🔧 MISSING message_msg METHOD:"
message_msg_matches = result.scan(/.*undefined method `message_msg'.*\n.*\n.*\n/)
message_msg_matches.first(3).each_with_index do |match, i|
  puts "   #{i+1}. #{match.strip}"
  puts
end

puts "\n🔧 MISSING merge METHOD (specific objects):"
merge_matches = result.scan(/.*undefined method `merge' for (.+?):\d+/)
merge_objects = merge_matches.flatten.tally.sort_by { |obj, count| -count }
merge_objects.first(5).each do |obj, count|
  puts "   #{obj}: #{count} failures"
end

puts "\n🔧 CONSTRUCTOR ERRORS (detailed):"
constructor_matches = result.scan(/.*wrong number of arguments.*\n.*initialize.*\n.*\n/)
constructor_matches.first(3).each_with_index do |match, i|
  puts "   #{i+1}. #{match.strip}"
  puts
end

puts "\n🔧 PLUS OPERATOR ERRORS:"
plus_matches = result.scan(/.*undefined method `\+' for (.+?):\d+/)
plus_objects = plus_matches.flatten.tally.sort_by { |obj, count| -count }
plus_objects.first(3).each do |obj, count|
  puts "   #{obj}: #{count} failures"
end

# Extract file locations
puts "\n📁 ERROR LOCATIONS BY FILE:"
file_errors = {}
result.scan(/(\w+(?:\/\w+)*\.rb):\d+:.*(?:undefined method|wrong number of arguments)/) do |file_match|
  file = file_match[0]
  file_errors[file] = (file_errors[file] || 0) + 1
end

file_errors.sort_by { |file, count| -count }.first(8).each do |file, count|
  puts "   #{file}: #{count} errors"
end

puts "\n✅ DETAILED ERROR ANALYSIS COMPLETE"
puts "Next: Target the specific objects and files with highest error concentrations"