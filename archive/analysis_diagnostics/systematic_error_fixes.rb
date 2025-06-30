#!/usr/bin/env ruby

puts "🔧 SYSTEMATIC ERROR FIXES - TOP 3 PATTERNS"
puts "=" * 50

# Focus on the top 3 error patterns:
# 1. LocalJumpError: 86 occurrences
# 2. NoMethodError: 63 occurrences  
# 3. Missing Methods: 57 occurrences

puts "\n🎯 PHASE 1: FIXING LOCAL JUMP ERRORS (86 occurrences)"

# Run a focused test to identify LocalJumpError sources
puts "   Analyzing LocalJumpError patterns..."

result = `timeout 30 rake test 2>&1`

# Extract LocalJumpError patterns
local_jump_errors = result.scan(/LocalJumpError[^:]*:.*?\n.*?\n.*?\n/)
puts "   Found #{local_jump_errors.size} LocalJumpError instances"

# Show sample errors for analysis
if local_jump_errors.any?
  puts "\n   📋 Sample LocalJumpError patterns:"
  local_jump_errors.first(3).each_with_index do |error, i|
    puts "      #{i+1}. #{error.strip}"
  end
end

# Extract file locations with LocalJumpError
local_jump_files = result.scan(/([^:\s]+\.rb):\d+:.*LocalJumpError/)
unique_files = local_jump_files.flatten.uniq

puts "\n   📁 Files with LocalJumpError:"
unique_files.first(5).each do |file|
  count = local_jump_files.flatten.count(file)
  puts "      - #{file} (#{count} occurrences)"
end

puts "\n🎯 PHASE 2: FIXING NOMETHOD ERRORS (63 occurrences)"

# Extract NoMethodError patterns
nomethod_errors = result.scan(/NoMethodError[^:]*:.*?\n/)
puts "   Found #{nomethod_errors.size} NoMethodError instances"

# Extract missing method names
missing_methods = result.scan(/undefined method `([^']+)'/)
method_counts = missing_methods.flatten.tally.sort_by { |method, count| -count }

puts "\n   🔧 Most critical missing methods:"
method_counts.first(8).each do |method, count|
  puts "      - `#{method}`: #{count} failures"
end

puts "\n🎯 PHASE 3: CONSTRUCTOR SIGNATURE ISSUES (25 occurrences)"

# Extract constructor errors
constructor_errors = result.scan(/wrong number of arguments.*?\n.*?initialize.*?\n/)
puts "   Found #{constructor_errors.size} constructor signature issues"

# Extract class names with constructor issues
constructor_classes = result.scan(/([A-Z]\w+).*?wrong number of arguments.*?initialize/)
class_counts = constructor_classes.flatten.tally.sort_by { |cls, count| -count }

puts "\n   🏗️  Classes with constructor issues:"
class_counts.first(5).each do |cls, count|
  puts "      - #{cls}: #{count} issues"
end

puts "\n✅ ANALYSIS COMPLETE"
puts "\n🚀 RECOMMENDED FIX PRIORITY:"
puts "   1. Fix LocalJumpError in #{unique_files.first(2).join(', ')}"
puts "   2. Add missing methods: #{method_counts.first(3).map(&:first).join(', ')}"
puts "   3. Fix constructors for: #{class_counts.first(2).map(&:first).join(', ')}"

puts "\n📊 EXPECTED IMPACT:"
total_fixes = 86 + 63 + 25  # Top 3 error patterns
puts "   Potential fixes: #{total_fixes} errors"
puts "   Projected success rate: ~#{(67.4 + (total_fixes * 100.0 / 1063)).round(1)}%"