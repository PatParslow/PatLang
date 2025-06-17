#!/usr/bin/env ruby

# Find NotImplementedError issues by running tests and analyzing the output
require 'open3'

puts "🔍 SEARCHING FOR NotImplementedError ISSUES"
puts "=" * 50

# Run tests to capture NotImplementedError messages
puts "\n📊 Running test suite to capture NotImplementedError patterns..."

begin
  # Run ruby tests and capture output
  stdout, stderr, status = Open3.capture3("ruby -I. test/run_all_tests.rb 2>&1")
  
  combined_output = stdout + stderr
  
  # Find NotImplementedError patterns
  not_implemented_lines = combined_output.split("\n").select do |line|
    line.downcase.include?("notimplementederror") || 
    line.include?("not implemented") ||
    line.include?("NotImplemented")
  end
  
  puts "\n🎯 Found NotImplementedError patterns:"
  if not_implemented_lines.empty?
    puts "❌ No direct NotImplementedError patterns found in test output"
  else
    not_implemented_lines.each_with_index do |line, index|
      puts "#{index + 1}. #{line.strip}"
    end
  end
  
  # Look for method stubs or TODO comments
  puts "\n🔍 Looking for potential stub methods..."
  
  # Search source files for potential stubs
  Dir.glob("src/**/*.rb").each do |file|
    content = File.read(file)
    
    # Look for various stub patterns
    stub_patterns = [
      /def\s+\w+.*\n\s*#.*TODO/,
      /def\s+\w+.*\n\s*#.*stub/i,
      /def\s+\w+.*\n\s*#.*not.*implement/i,
      /def\s+\w+.*\n\s*raise.*NotImplementedError/,
      /def\s+\w+.*\n\s*nil\s*$/,
      /def\s+\w+.*\n\s*\{\}\s*$/,
      /def\s+\w+.*\n\s*\[\]\s*$/,
      /def\s+\w+.*\n\s*false\s*$/
    ]
    
    stub_patterns.each_with_index do |pattern, pattern_index|
      matches = content.scan(pattern)
      if matches.any?
        puts "📁 #{file} - Pattern #{pattern_index + 1}: #{matches.length} potential stubs"
        
        # Show context for first few matches
        content.split("\n").each_with_index do |line, line_num|
          if pattern.match(line + "\n" + (content.split("\n")[line_num + 1] || ""))
            puts "   Line #{line_num + 1}: #{line.strip}"
            next_line = content.split("\n")[line_num + 1]
            puts "   Line #{line_num + 2}: #{next_line.strip}" if next_line
            puts "   ---"
          end
        end
      end
    end
  end
  
rescue => e
  puts "❌ Error running analysis: #{e.message}"
  puts "Backtrace: #{e.backtrace.first(3).join("\n")}"
end

puts "\n📋 SUMMARY"
puts "=" * 50
puts "Analysis complete. Check above for potential NotImplementedError sources."