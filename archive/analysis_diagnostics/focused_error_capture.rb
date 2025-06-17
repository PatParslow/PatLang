#!/usr/bin/env ruby

puts "🔍 FOCUSED ERROR CAPTURE"
puts "=" * 30

puts "\n🧪 Running targeted test to capture specific error details..."

# Run a focused test with more detailed output
result = `timeout 20 rake test 2>&1 | grep -A5 -B5 "wrong number of arguments"`

puts "\n📋 CONSTRUCTOR ERROR DETAILS:"
puts result

# Also capture merge method errors
puts "\n📋 MERGE METHOD ERROR DETAILS:"
merge_result = `timeout 20 rake test 2>&1 | grep -A3 -B3 "undefined method.*merge"`
puts merge_result

# And + operator errors
puts "\n📋 PLUS OPERATOR ERROR DETAILS:"
plus_result = `timeout 20 rake test 2>&1 | grep -A3 -B3 "undefined method.*\+"`
puts plus_result

puts "\n✅ FOCUSED CAPTURE COMPLETE"