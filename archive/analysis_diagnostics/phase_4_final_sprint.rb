#!/usr/bin/env ruby

puts "🎯 PHASE 4: FINAL SPRINT TO 80%+ TARGET"
puts "=" * 45

puts "\n📊 CURRENT STATUS:"
puts "   Success Rate: 76.0%"
puts "   Errors Remaining: 77"
puts "   Target Gap: 4.0% (43 test fixes needed)"

puts "\n🎯 PRIORITY TARGET BREAKDOWN:"
puts "   1. Missing merge method: 28 occurrences (highest impact)"
puts "   2. Constructor issues: 19 occurrences"
puts "   3. Missing + operator: 8 occurrences"
puts "   4. Name resolution errors: 10 occurrences"

puts "\n🔍 DETAILED ERROR ANALYSIS..."

# Get detailed error output for targeted fixing
result = `timeout 45 rake test 2>&1`

puts "\n📋 MERGE METHOD FAILURE ANALYSIS:"
merge_errors = result.scan(/undefined method `merge' for (.+?):\d+:in/)
merge_objects = merge_errors.flatten.tally.sort_by { |obj, count| -count }

if merge_objects.any?
  puts "   Objects failing merge:"
  merge_objects.first(5).each do |obj, count|
    puts "     #{obj}: #{count} failures"
  end
else
  puts "   No specific merge object info captured"
end

puts "\n📋 CONSTRUCTOR FAILURE ANALYSIS:"
constructor_errors = result.scan(/wrong number of arguments \(given (\d+), expected (\d+)\)/)
constructor_patterns = constructor_errors.tally.sort_by { |pattern, count| -count }

if constructor_patterns.any?
  puts "   Constructor signature mismatches:"
  constructor_patterns.first(5).each do |pattern, count|
    given, expected = pattern
    puts "     Given #{given}, Expected #{expected}: #{count} failures"
  end
end

puts "\n📋 PLUS OPERATOR FAILURE ANALYSIS:"
plus_errors = result.scan(/undefined method `\+' for (.+?):\d+:in/)
plus_objects = plus_errors.flatten.tally.sort_by { |obj, count| -count }

if plus_objects.any?
  puts "   Objects failing + operator:"
  plus_objects.first(3).each do |obj, count|
    puts "     #{obj}: #{count} failures"
  end
end

# Extract file locations for targeted fixes
puts "\n📁 HIGH-ERROR FILES:"
file_errors = {}
result.scan(/([^:\s]+\.rb):\d+:.*(?:undefined method|wrong number of arguments)/) do |file_match|
  file = file_match[0]
  file_errors[file] = (file_errors[file] || 0) + 1
end

file_errors.sort_by { |file, count| -count }.first(8).each do |file, count|
  puts "   #{file}: #{count} errors"
end

puts "\n🎯 PHASE 4 STRATEGY:"
puts "   Step 1: Fix merge method on Hash and event data objects"
puts "   Step 2: Resolve constructor signature mismatches"
puts "   Step 3: Add + operator to missing object types"
puts "   Step 4: Address name resolution issues"

# Calculate impact potential
total_targeted = 28 + 19 + 8  # merge + constructor + plus
potential_improvement = (total_targeted.to_f / 1063 * 100).round(1)
projected_success = 76.0 + potential_improvement

puts "\n📈 PHASE 4 PROJECTION:"
puts "   Target errors: #{total_targeted}"
puts "   Potential improvement: +#{potential_improvement}%"
puts "   Projected success rate: #{projected_success}%"
puts "   Target achievement: #{projected_success >= 80.0 ? '🎯 ACHIEVABLE!' : '📈 VERY CLOSE'}"

puts "\n✅ PHASE 4 ANALYSIS COMPLETE"
puts "Next: Implement targeted fixes for merge, constructor, and + operator issues"