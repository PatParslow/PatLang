#!/usr/bin/env ruby

# Find where NotImplementedError messages are actually generated
require 'open3'

puts "🔍 TRACING NotImplementedError SOURCES"
puts "=" * 50

# Search for test files that might be throwing NotImplementedError
puts "\n📊 Searching test files for NotImplementedError patterns..."

begin
  # Search test files for NotImplementedError
  test_files = Dir.glob("test/**/*.rb")
  
  test_files.each do |test_file|
    content = File.read(test_file)
    
    # Look for patterns that raise NotImplementedError
    patterns = [
      /raise.*NotImplementedError/,
      /NotImplementedError.*RED phase/,
      /skip.*NotImplementedError/,
      /pending.*NotImplementedError/
    ]
    
    patterns.each_with_index do |pattern, index|
      if content.match(pattern)
        puts "\n📁 #{test_file} - Pattern #{index + 1}:"
        
        content.split("\n").each_with_index do |line, line_num|
          if line.match(pattern)
            puts "   Line #{line_num + 1}: #{line.strip}"
            
            # Show context
            if line_num > 0
              puts "   Context before: #{content.split("\n")[line_num - 1].strip}"
            end
            if line_num < content.split("\n").length - 1
              puts "   Context after: #{content.split("\n")[line_num + 1].strip}"
            end
            puts "   ---"
          end
        end
      end
    end
  end
  
  # Search source files for methods that might conditionally raise NotImplementedError
  puts "\n🔍 Searching source files for conditional NotImplementedError..."
  
  source_files = Dir.glob("src/**/*.rb")
  
  source_files.each do |source_file|
    content = File.read(source_file)
    
    # Look for methods that conditionally raise NotImplementedError
    conditional_patterns = [
      /if.*RED.*phase.*raise.*NotImplementedError/,
      /unless.*implemented.*raise.*NotImplementedError/,
      /def.*\n.*raise.*NotImplementedError.*RED.*phase/m
    ]
    
    conditional_patterns.each_with_index do |pattern, index|
      if content.match(pattern)
        puts "\n📁 #{source_file} - Conditional Pattern #{index + 1}:"
        puts "   Found conditional NotImplementedError"
      end
    end
    
    # Look for methods that might be calling other methods that raise NotImplementedError
    if content.include?("RED phase") && content.include?("NotImplementedError")
      puts "\n📁 #{source_file}:"
      content.split("\n").each_with_index do |line, line_num|
        if line.include?("RED phase") || line.include?("NotImplementedError")
          puts "   Line #{line_num + 1}: #{line.strip}"
        end
      end
    end
  end
  
  # Try to find actual method calls that are failing
  puts "\n🚀 Running a single test to capture stack trace..."
  
  # Run a specific test that should fail with NotImplementedError
  stdout, stderr, status = Open3.capture3("cd test && ruby -I.. test_ruby_implementation/test_advanced_goal_strategies.rb 2>&1")
  
  output = stdout + stderr
  
  puts "\n📋 Sample test output:"
  puts output.split("\n").select { |line| 
    line.include?("NotImplementedError") || 
    line.include?("ERROR") ||
    line.include?("FAIL") ||
    line.include?("RED phase")
  }.first(10).join("\n")
  
rescue => e
  puts "❌ Error in analysis: #{e.message}"
  puts "Backtrace: #{e.backtrace.first(3).join("\n")}"
end

puts "\n📋 SUMMARY"
puts "=" * 50
puts "Analysis complete. Check above for actual NotImplementedError sources."