#!/usr/bin/env ruby

# Phase 1 Error Analysis - Capture specific error details
puts "🔍 PHASE 1 ERROR ANALYSIS - Capturing 36 Errors"
puts "=" * 60

# Run tests and capture only errors (not failures)
test_output = `ruby test/run_all_tests.rb 2>&1`

# Parse for errors specifically
error_sections = []
current_error = nil
in_error_section = false

test_output.each_line do |line|
  # Look for error markers
  if line =~ /^\s*\d+\)\s+Error:/
    # Save previous error if exists
    error_sections << current_error if current_error
    
    # Start new error
    current_error = {
      header: line.strip,
      details: [],
      test_class: nil,
      test_method: nil,
      error_type: nil,
      error_message: nil
    }
    in_error_section = true
    
    # Extract test info from header
    if line =~ /Error:\s+(.+?)#(.+?):/
      current_error[:test_class] = $1
      current_error[:test_method] = $2
    end
    
  elsif in_error_section && line.strip.empty?
    # End of error section
    in_error_section = false
    
  elsif in_error_section && current_error
    # Collect error details
    current_error[:details] << line.strip
    
    # Extract error type and message
    if line =~ /^\s*([A-Z]\w+Error|[A-Z]\w+Exception):\s*(.+)/
      current_error[:error_type] = $1
      current_error[:error_message] = $2
    end
  end
end

# Save last error
error_sections << current_error if current_error

puts "📊 FOUND #{error_sections.size} ERRORS"
puts ""

# Categorize errors
error_categories = {
  'LoadError' => [],
  'NameError' => [],
  'NoMethodError' => [],
  'ArgumentError' => [],
  'TypeError' => [],
  'RuntimeError' => [],
  'Other' => []
}

error_sections.each do |error|
  category = error[:error_type] || 'Other'
  category = 'Other' unless error_categories.key?(category)
  error_categories[category] << error
end

# Report by category
error_categories.each do |category, errors|
  next if errors.empty?
  
  puts "🔴 #{category.upcase} (#{errors.size} errors)"
  puts "-" * 40
  
  errors.each_with_index do |error, index|
    puts "#{index + 1}. #{error[:test_class]}##{error[:test_method]}"
    puts "   Error: #{error[:error_message]}" if error[:error_message]
    
    # Show first few lines of stack trace
    stack_lines = error[:details].select { |line| line.include?('.rb:') }
    if stack_lines.any?
      puts "   Location: #{stack_lines.first}"
    end
    puts ""
  end
end

# Summary and recommendations
puts "📋 ERROR SUMMARY & NEXT STEPS"
puts "=" * 40

total_errors = error_sections.size
puts "Total Errors: #{total_errors}"

error_categories.each do |category, errors|
  next if errors.empty?
  percentage = (errors.size.to_f / total_errors * 100).round(1)
  puts "• #{category}: #{errors.size} (#{percentage}%)"
end

puts ""
puts "🎯 PRIORITY RECOMMENDATIONS:"

# Priority 1: LoadError and NameError (blocking)
critical_errors = error_categories['LoadError'] + error_categories['NameError']
if critical_errors.any?
  puts "1. CRITICAL: Fix #{critical_errors.size} LoadError/NameError issues (blocking dependencies)"
end

# Priority 2: NoMethodError (API issues)  
if error_categories['NoMethodError'].any?
  puts "2. HIGH: Fix #{error_categories['NoMethodError'].size} NoMethodError issues (missing methods)"
end

# Priority 3: ArgumentError/TypeError (parameter issues)
param_errors = error_categories['ArgumentError'] + error_categories['TypeError']
if param_errors.any?
  puts "3. MEDIUM: Fix #{param_errors.size} parameter/type issues"
end

puts ""
puts "💾 Detailed error data saved for analysis"