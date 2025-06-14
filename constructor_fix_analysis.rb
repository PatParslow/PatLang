#!/usr/bin/env ruby

puts "🔧 CONSTRUCTOR SIGNATURE FIX ANALYSIS"
puts "=" * 40

puts "\n🎯 Target: Fix 'Given 4, Expected 3' constructor issues (12 failures)"

# Get detailed constructor error output
result = `timeout 30 rake test 2>&1`

puts "\n🔍 EXTRACTING CONSTRUCTOR ERROR DETAILS..."

# Find specific constructor errors with file locations
constructor_details = result.scan(/(.*?\.rb):\d+:in `initialize'.*?wrong number of arguments \(given (\d+), expected (\d+)\)/)

puts "\n📋 CONSTRUCTOR ERROR BREAKDOWN:"
constructor_details.each_with_index do |details, i|
  file, given, expected = details
  puts "   #{i+1}. File: #{file}"
  puts "      Given: #{given}, Expected: #{expected}"
  puts
end

# Group by signature mismatch
signature_groups = constructor_details.group_by { |details| [details[1], details[2]] }

puts "\n📊 SIGNATURE MISMATCH FREQUENCY:"
signature_groups.each do |signature, occurrences|
  given, expected = signature
  puts "   Given #{given}, Expected #{expected}: #{occurrences.length} occurrences"
  
  # Show affected files
  files = occurrences.map { |occ| occ[0] }.uniq
  puts "     Files: #{files.join(', ')}"
  puts
end

puts "\n🎯 PRIORITY FIX TARGETS:"
puts "   1. Most frequent: Given 4, Expected 3 (likely type constraint constructors)"
puts "   2. Secondary: Given 2, Expected 1 and Given 0, Expected 1"

puts "\n✅ CONSTRUCTOR ANALYSIS COMPLETE"
puts "Next: Fix the specific constructor signatures identified"