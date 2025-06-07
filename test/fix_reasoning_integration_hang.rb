#!/usr/bin/env ruby

# Fix for test_reasoning_integration.rb hanging issues
# Applies EmergencyTimeout protection to problematic test methods

require_relative '../src/emergency_timeout'

puts "🔧 APPLYING TIMEOUT PROTECTION TO REASONING INTEGRATION TESTS"
puts "=" * 70

# Read the original file
original_file = 'test/patlang_language/test_reasoning_integration.rb'
puts "📖 Reading #{original_file}..."

content = File.read(original_file)

# Methods that are known to potentially hang based on our analysis
hanging_methods = [
  'test_malformed_goal_syntax_reports_location',
  'test_undefined_predicate_in_query',
  'test_reasoning_mode_required_for_constraints',
  'test_invalid_constraint_syntax_reports_error'
]

puts "🎯 Applying timeout protection to #{hanging_methods.length} methods:"
hanging_methods.each { |method| puts "   - #{method}" }

# Apply timeout protection to each hanging method
hanging_methods.each do |method_name|
  # Find the method definition
  method_regex = /^(\s*def #{method_name}\s*\n)(.*?)(^(\s*)end\s*$)/m
  
  if content.match(method_regex)
    puts "   ✅ Found method: #{method_name}"
    
    # Replace with timeout-protected version
    content.gsub!(method_regex) do |match|
      indentation = $1.match(/^(\s*)/)[1]
      method_header = $1
      method_body = $2
      method_end = $3
      end_indentation = $4
      
      # Create timeout-protected version
      <<~RUBY
#{method_header}#{indentation}  # TIMEOUT PROTECTION: Prevent hanging on malformed syntax
#{indentation}  EmergencyTimeout.protect(10, error_message: "#{method_name} exceeded 10s timeout") do
#{method_body.gsub(/^/, "#{indentation}    ")}#{indentation}  end
#{method_end}
      RUBY
    end
    
  else
    puts "   ⚠️  Method not found: #{method_name}"
  end
end

# Add EmergencyTimeout require at the top
unless content.include?("require_relative '../../src/emergency_timeout'")
  # Find the line after the existing requires
  require_section = content.lines.take_while { |line| line.start_with?('require') || line.strip.empty? || line.start_with?('#') }
  insert_line = require_section.length
  
  lines = content.lines
  lines.insert(insert_line, "require_relative '../../src/emergency_timeout'\n")
  content = lines.join
  
  puts "✅ Added EmergencyTimeout require"
end

# Write the updated file
backup_file = "#{original_file}.backup.#{Time.now.to_i}"
puts "💾 Creating backup: #{backup_file}"
File.write(backup_file, File.read(original_file))

puts "✍️  Writing updated file: #{original_file}"
File.write(original_file, content)

puts "🎉 TIMEOUT PROTECTION APPLIED SUCCESSFULLY!"
puts
puts "📊 SUMMARY:"
puts "   - Applied timeout protection to #{hanging_methods.length} methods"
puts "   - Each method now has a 10-second timeout limit"
puts "   - Added EmergencyTimeout require"
puts "   - Created backup file: #{File.basename(backup_file)}"
puts
puts "✅ The test file should now run without hanging!"