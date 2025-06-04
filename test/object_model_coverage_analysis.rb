#!/usr/bin/env ruby

require 'simplecov'
require 'simplecov-console'

# Configure SimpleCov to track only object model files
SimpleCov.start do
  add_filter '/test/'
  add_filter '/adhoc_scripts/'
  add_filter '/docs/'
  add_filter '/examples/'
  add_filter '/tools/'
  
  # Only track the object model files we care about
  add_group 'Object Model', 'src/object_model'
  
  # Track specific files
  track_files 'src/object_model/*.rb'
  
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::Console
  ])
end

require_relative 'test_helper'
require_relative '../src/object_model/patlang_object'
require_relative '../src/object_model/event_system'
require_relative '../src/object_model/object_integration'

# Run the object model tests to get coverage
require_relative 'test_object_model'

puts "\n" + "="*80
puts "OBJECT MODEL COVERAGE ANALYSIS"
puts "="*80

# Get coverage data
coverage_data = SimpleCov.result

if coverage_data.nil?
  puts "No coverage data available"
  exit 1
end

puts "\nOverall Coverage:"
puts "- Line Coverage: #{coverage_data.covered_percent.round(2)}%"

coverage_data.groups.each do |name, files|
  next unless name == 'Object Model'
  
  puts "\n#{name} Files:"
  files.each do |file|
    filename = File.basename(file.filename)
    puts "  #{filename}: #{file.covered_percent.round(2)}% (#{file.covered_lines.size}/#{file.lines.size} lines)"
    
    # Show uncovered lines
    uncovered = file.missed_lines
    if uncovered.any?
      puts "    Uncovered lines: #{uncovered.join(', ')}"
    end
  end
end

puts "\n" + "="*80
puts "DETAILED COVERAGE GAPS"
puts "="*80

# Analyze each object model file for specific gaps
object_model_files = [
  '../src/object_model/patlang_object.rb',
  '../src/object_model/event_system.rb', 
  '../src/object_model/object_integration.rb'
]

object_model_files.each do |file_path|
  relative_path = file_path.gsub('../', '')
  puts "\n#{relative_path}:"
  
  # Find the file in coverage results
  covered_file = coverage_data.files.find { |f| f.filename.include?(relative_path) }
  
  if covered_file
    missed_lines = covered_file.missed_lines
    if missed_lines.any?
      puts "  Missed lines: #{missed_lines.join(', ')}"
      
      # Read the file to show what's not covered
      File.readlines(file_path).each_with_index do |line, idx|
        line_num = idx + 1
        if missed_lines.include?(line_num)
          puts "    #{line_num}: #{line.strip}"
        end
      end
    else
      puts "  All lines covered!"
    end
  else
    puts "  File not found in coverage report"
  end
end