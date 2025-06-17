#!/usr/bin/env ruby
# frozen_string_literal: true

# Test Discovery Diagnostic Tool
# This script analyzes the current test discovery patterns and identifies excluded files

require 'pathname'

class TestDiscoveryDiagnostic
  def initialize
    @base_path = File.dirname(__FILE__)
  end

  def analyze_test_discovery
    puts "=" * 80
    puts "TEST DISCOVERY DIAGNOSTIC ANALYSIS".center(80)
    puts "=" * 80
    puts

    # Find ALL test_*.rb files recursively
    all_test_files = find_all_test_files
    puts "📊 ALL TEST_*.RB FILES FOUND IN TEST DIRECTORY:"
    puts "   Total files: #{all_test_files.length}"
    puts

    # Simulate current discovery logic
    current_discovered = simulate_current_discovery
    puts "🔍 CURRENT DISCOVERY LOGIC RESULTS:"
    puts "   Total discovered: #{current_discovered.values.flatten.length}"
    puts

    # Compare and identify excluded files
    excluded_files = find_excluded_files(all_test_files, current_discovered)
    puts "❌ EXCLUDED FILES (#{excluded_files.length}):"
    excluded_files.each_with_index do |file, index|
      puts "   #{index + 1}. #{file}"
    end
    puts

    # Analyze exclusion patterns
    analyze_exclusion_patterns(excluded_files)

    # Show category breakdown
    show_category_breakdown(current_discovered)

    # Generate recommendations
    generate_recommendations(all_test_files, current_discovered, excluded_files)
  end

  private

  def find_all_test_files
    # Find all test_*.rb files recursively in the test directory
    test_pattern = File.join(@base_path, '**', 'test_*.rb')
    Dir.glob(test_pattern).map { |f| File.expand_path(f) }.sort
  end

  def simulate_current_discovery
    # Replicate the current discovery logic from comprehensive_test_suite_runner.rb
    categories = {
      'infrastructure' => File.join(@base_path, 'infrastructure'),
      'ruby_implementation' => File.join(@base_path, 'ruby_implementation'),
      'patlang_language' => File.join(@base_path, 'patlang_language'),
      'integration' => File.join(@base_path, 'integration'),
      'helpers' => File.join(@base_path, 'helpers'),
      'branch_coverage' => File.join(@base_path, 'branch_coverage'),
      'root_level' => @base_path
    }
    
    test_categories = {}
    
    categories.each do |category, path|
      if File.directory?(path) || category == 'root_level'
        test_files = if category == 'root_level'
          # For root level, only get test files directly in test/ directory
          Dir.glob(File.join(path, 'test_*.rb')).select do |f|
            # Exclude files that are in subdirectories
            File.dirname(f) == path
          end
        else
          Dir.glob(File.join(path, 'test_*.rb'))
        end
        
        # Filter out runner files and helpers - THIS IS THE EXCLUSION LOGIC
        excluded_patterns = [
          /run_.*\.rb$/,
          /runner\.rb$/,
          /helper\.rb$/,
          /coverage.*\.rb$/,
          /analysis.*\.rb$/
        ]
        
        test_files = test_files.reject do |file|
          basename = File.basename(file)
          excluded_patterns.any? { |pattern| basename =~ pattern }
        end
        
        if test_files.any?
          test_categories[category] = test_files.map { |f| File.expand_path(f) }.sort
        end
      end
    end
    
    test_categories
  end

  def find_excluded_files(all_files, discovered_files)
    discovered_set = discovered_files.values.flatten.to_set
    all_files.reject { |file| discovered_set.include?(file) }
  end

  def analyze_exclusion_patterns(excluded_files)
    puts "🔍 EXCLUSION PATTERN ANALYSIS:"
    
    # Group by exclusion reason
    exclusion_reasons = Hash.new { |h, k| h[k] = [] }
    
    excluded_files.each do |file|
      basename = File.basename(file)
      case basename
      when /run_.*\.rb$/
        exclusion_reasons['Matches run_*.rb pattern'] << file
      when /runner\.rb$/
        exclusion_reasons['Matches *runner.rb pattern'] << file
      when /helper\.rb$/
        exclusion_reasons['Matches *helper.rb pattern'] << file
      when /coverage.*\.rb$/
        exclusion_reasons['Matches coverage*.rb pattern'] << file
      when /analysis.*\.rb$/
        exclusion_reasons['Matches analysis*.rb pattern'] << file
      else
        # Check if it's in a directory not covered by current logic
        rel_path = Pathname.new(file).relative_path_from(Pathname.new(@base_path)).to_s
        if rel_path.include?('/')
          dir_name = File.dirname(rel_path)
          exclusion_reasons["In uncovered directory: #{dir_name}"] << file
        else
          exclusion_reasons['Unknown reason'] << file
        end
      end
    end
    
    exclusion_reasons.each do |reason, files|
      puts "   #{reason}: #{files.length} files"
      files.each { |file| puts "     - #{File.basename(file)}" }
    end
    puts
  end

  def show_category_breakdown(discovered_files)
    puts "📁 CURRENT CATEGORY BREAKDOWN:"
    discovered_files.each do |category, files|
      puts "   #{category}: #{files.length} files"
      files.each { |file| puts "     - #{File.basename(file)}" }
    end
    puts
  end

  def generate_recommendations(all_files, discovered_files, excluded_files)
    puts "🎯 RECOMMENDATIONS FOR ENHANCED TEST DISCOVERY:"
    puts
    
    puts "1. DYNAMIC DISCOVERY APPROACH:"
    puts "   - Replace hardcoded category directories with recursive search"
    puts "   - Use Dir.glob('test/**/test_*.rb') to find all test files"
    puts "   - Automatically categorize based on directory structure"
    puts
    
    puts "2. REFINED EXCLUSION PATTERNS:"
    puts "   - Current exclusions are too broad and eliminate legitimate tests"
    puts "   - Recommend excluding only these specific patterns:"
    puts "     * test_helper.rb (helper files)"
    puts "     * *_runner.rb (test runners, not actual tests)"
    puts "     * *_analysis.rb (analysis scripts, not tests)"
    puts "     * Files in specific utility directories"
    puts
    
    puts "3. SPECIFIC ISSUES TO FIX:"
    exclusion_reasons = Hash.new(0)
    excluded_files.each do |file|
      basename = File.basename(file)
      case basename
      when /coverage.*\.rb$/
        exclusion_reasons['coverage pattern too broad'] += 1
      when /analysis.*\.rb$/
        exclusion_reasons['analysis pattern too broad'] += 1
      else
        exclusion_reasons['directory not covered'] += 1
      end
    end
    
    exclusion_reasons.each do |issue, count|
      puts "   - Fix #{issue}: affects #{count} files"
    end
    puts
    
    puts "4. EXPECTED IMPROVEMENTS:"
    puts "   - Current discovery: #{discovered_files.values.flatten.length} files"
    puts "   - Enhanced discovery: #{all_files.length} files"
    puts "   - Additional tests: #{excluded_files.length} files (+#{((excluded_files.length.to_f / discovered_files.values.flatten.length) * 100).round(1)}%)"
    puts
  end
end

# Run the diagnostic
if __FILE__ == $0
  diagnostic = TestDiscoveryDiagnostic.new
  diagnostic.analyze_test_discovery
end