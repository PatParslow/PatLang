#!/usr/bin/env ruby
# Coverage Isolation Diagnostic - Check if multiple SimpleCov instances cause issues

puts "🔍 Coverage Isolation Diagnostic"
puts "=" * 50

# First, check the current SimpleCov state BEFORE any configuration
puts "\n1️⃣ Initial SimpleCov State:"
if defined?(SimpleCov)
  puts "  ✅ SimpleCov already loaded"
  if SimpleCov.result
    puts "  📊 Existing result: #{SimpleCov.result.covered_percent.round(2)}%"
  else
    puts "  🔍 No existing result"
  end
else
  puts "  ❌ SimpleCov not loaded"
end

# Load the comprehensive test runner approach
puts "\n2️⃣ Loading Comprehensive Test Runner SimpleCov Config:"
require 'simplecov'

SimpleCov.start do
  enable_coverage :branch
  add_filter '/test/'
  add_filter '/adhoc_scripts/'
  add_filter '/tools/'
  
  track_files 'src/**/*.rb'
  
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::SimpleFormatter
  ])
  
  minimum_coverage line: 80, branch: 70
end

puts "  ✅ Comprehensive runner config loaded"

# Now check if this affected the result
if SimpleCov.result
  puts "  📊 Result after config: #{SimpleCov.result.covered_percent.round(2)}%"
else
  puts "  🔍 No result after config"
end

# Now load test_helper approach
puts "\n3️⃣ Loading Test Helper SimpleCov Config:"
require_relative 'helpers/test_helper'

if SimpleCov.result
  puts "  📊 Result after test_helper: #{SimpleCov.result.covered_percent.round(2)}%"
else
  puts "  🔍 No result after test_helper"
end

# Run a simple test to generate coverage
puts "\n4️⃣ Running Simple Test to Generate Coverage:"
require_relative 'infrastructure/test_lexer'

if SimpleCov.result
  result = SimpleCov.result
  puts "  📊 Final Result:"
  puts "    Line Coverage: #{result.covered_percent.round(2)}%"
  puts "    Total Lines: #{result.total_lines}"
  puts "    Covered Lines: #{result.covered_lines}"
  puts "    Files: #{result.files.length}"
  
  # Check for branch coverage methods
  puts "  🌿 Branch Coverage Methods:"
  branch_methods = result.methods.grep(/branch/)
  if branch_methods.empty?
    puts "    ❌ No branch coverage methods found"
  else
    puts "    ✅ Branch methods: #{branch_methods}"
    branch_methods.each do |method|
      begin
        value = result.send(method)
        puts "      #{method}: #{value}"
      rescue => e
        puts "      #{method}: Error - #{e.message}"
      end
    end
  end
else
  puts "  ❌ Still no result"
end

# Check the actual HTML file location and content
puts "\n5️⃣ HTML Report Analysis:"
html_files = Dir.glob('test/coverage/index.html') + Dir.glob('coverage/index.html')
puts "  📁 HTML files found: #{html_files}"

html_files.each do |html_file|
  if File.exist?(html_file)
    content = File.read(html_file)
    if content =~ /(\d+\.\d+)%.*covered/
      puts "  📊 HTML reports: #{$1}% coverage"
    end
  end
end

puts "\n🏁 Coverage isolation diagnostic complete"