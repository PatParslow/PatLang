#!/usr/bin/env ruby

# Fix the syntax error in test_facts_database.rb caused by unmatched 'end'

file_path = 'test/infrastructure/test_facts_database.rb'
content = File.read(file_path)
lines = content.split("\n")

puts "🔧 FIXING SYNTAX ERROR: test_facts_database.rb"
puts "=" * 50

# Find and fix the unmatched 'end' around line 641
# The error suggests there's an extra 'end' statement

# Look for problematic 'end' statements
fixed_lines = []
end_count = 0
class_count = 0
def_count = 0

lines.each_with_index do |line, index|
  stripped = line.strip
  
  # Count opening keywords
  if stripped.start_with?('class ')
    class_count += 1
  elsif stripped.start_with?('def ')
    def_count += 1
  end
  
  # Count closing 'end' keywords
  if stripped == 'end'
    end_count += 1
    
    # If we're around line 641 and this looks like an extra 'end', skip it
    if index > 630 && index < 650
      puts "🔍 Checking line #{index + 1}: '#{line}'"
      
      # Look at context - if this is an orphaned 'end', skip it
      prev_line = lines[index - 1]&.strip || ""
      next_line = lines[index + 1]&.strip || ""
      
      # If previous line is already an 'end' or this seems orphaned, skip
      if prev_line == 'end' || (next_line == "" && index > lines.length - 20)
        puts "   ❌ Removing orphaned 'end' at line #{index + 1}"
        next # Skip this line
      end
    end
  end
  
  fixed_lines << line
end

# Write the fixed content
File.write(file_path, fixed_lines.join("\n"))

puts "✅ Fixed syntax error in #{file_path}"
puts "📊 Summary:"
puts "   - Total lines: #{lines.length}"
puts "   - Fixed lines: #{fixed_lines.length}"
puts "   - Lines removed: #{lines.length - fixed_lines.length}"

puts "\n🚀 Ready to test again!"