#!/usr/bin/env ruby

# Priority 3B-5: Exception Type Mismatch Analysis
# Identify tests expecting NoMethodError but getting TypeError/ArgumentError

require_relative 'test/test_helper'

class Priority3B5Analysis
  def initialize
    @mismatch_results = []
  end

  def analyze_exception_mismatches
    puts "=== Priority 3B-5: Exception Type Mismatch Analysis ==="
    puts "Target: assert_raises(NoMethodError) getting TypeError/ArgumentError"
    puts

    # Test files with assert_raises(NoMethodError) patterns
    test_files = [
      'test/ruby_implementation/test_goal_system.rb',
      'test/infrastructure/test_facts_database.rb'
    ]

    test_files.each do |file|
      analyze_file(file)
    end

    report_findings
  end

  private

  def analyze_file(file_path)
    puts "Analyzing: #{file_path}"
    
    return unless File.exist?(file_path)
    
    content = File.read(file_path)
    
    # Find assert_raises(NoMethodError) patterns
    content.scan(/assert_raises\(NoMethodError\) do\s*\n(.*?)\n\s*end/m) do |block_content|
      test_context = $`[-100..-1] || ""  # Get context before match
      
      # Extract test method name
      if test_context =~ /def\s+(test_\w+)/
        test_method = $1
        puts "  Found test: #{test_method}"
        
        # Try to execute the block and catch actual exception
        begin
          eval(block_content[0])
          puts "    Expected: NoMethodError, Got: No exception (test may be broken)"
        rescue NoMethodError => e
          puts "    ✓ Correct: NoMethodError - #{e.message[0..80]}..."
        rescue TypeError => e
          puts "    ❌ MISMATCH: Expected NoMethodError, Got TypeError - #{e.message[0..80]}..."
          @mismatch_results << {
            file: file_path,
            test: test_method,
            expected: 'NoMethodError',
            actual: 'TypeError',
            message: e.message
          }
        rescue ArgumentError => e
          puts "    ❌ MISMATCH: Expected NoMethodError, Got ArgumentError - #{e.message[0..80]}..."
          @mismatch_results << {
            file: file_path,
            test: test_method,
            expected: 'NoMethodError',
            actual: 'ArgumentError',
            message: e.message
          }
        rescue => e
          puts "    ? Other: Expected NoMethodError, Got #{e.class} - #{e.message[0..80]}..."
        end
      end
    end
    puts
  end

  def report_findings
    puts "=== MISMATCH SUMMARY ==="
    if @mismatch_results.empty?
      puts "No exception type mismatches found."
      puts "Tests may need to be run in proper context."
    else
      puts "Found #{@mismatch_results.length} exception type mismatches:"
      
      @mismatch_results.each_with_index do |result, i|
        puts "\n#{i+1}. #{result[:file]}::#{result[:test]}"
        puts "   Expected: #{result[:expected]}"
        puts "   Actual: #{result[:actual]}"
        puts "   Message: #{result[:message][0..100]}..."
      end
      
      # Group by actual exception type
      type_groups = @mismatch_results.group_by { |r| r[:actual] }
      puts "\n=== BY EXCEPTION TYPE ==="
      type_groups.each do |type, results|
        puts "#{type}: #{results.length} instances"
        results.each { |r| puts "  - #{r[:file]}::#{r[:test]}" }
      end
    end
  end
end

# Run analysis
analyzer = Priority3B5Analysis.new
analyzer.analyze_exception_mismatches