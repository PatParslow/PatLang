#!/usr/bin/env ruby

# Unknown Error Epidemic Diagnostic Tool
# Systematically tests the 17 files with unknown_error status

require 'timeout'

class UnknownErrorDiagnostic
  def initialize
    @results = []
    @patterns = {
      require_failures: [],
      missing_classes: [],
      infinite_loops: [],
      method_errors: [],
      constant_warnings: []
    }
  end

  def diagnose_all
    puts "🚨 DIAGNOSING UNKNOWN ERROR EPIDEMIC"
    puts "=" * 50
    
    # Test representative files from each category
    test_files = [
      # Infrastructure
      "test/infrastructure/test_reasoning_coordinator.rb",
      "test/infrastructure/test_type_constraint_parser.rb",
      
      # Ruby Implementation  
      "test/ruby_implementation/test_string_operations.rb",
      "test/ruby_implementation/test_function_evaluator.rb",
      "test/ruby_implementation/test_evaluator_edge_cases.rb",
      
      # Patlang Language
      "test/patlang_language/test_evaluator_error_handling.rb",
      "test/patlang_language/test_evaluator.rb",
      
      # Helpers
      "test/helpers/test_constants.rb"
    ]
    
    test_files.each do |file|
      diagnose_file(file)
    end
    
    analyze_patterns
    generate_report
  end

  private

  def diagnose_file(file)
    puts "\n🔍 Diagnosing: #{file}"
    
    begin
      # Test require loading with timeout
      Timeout::timeout(5) do
        result = test_require_loading(file)
        @results << result
        categorize_error(result)
      end
    rescue Timeout::Error
      result = {
        file: file,
        status: "timeout",
        error: "File loading hangs (timeout after 5s)",
        category: "infinite_loop"
      }
      @results << result
      @patterns[:infinite_loops] << result
      puts "  ❌ TIMEOUT: File hangs during loading"
    rescue => e
      result = {
        file: file,
        status: "error",
        error: e.message,
        backtrace: e.backtrace[0..2],
        category: classify_error(e)
      }
      @results << result
      categorize_error(result)
      puts "  ❌ ERROR: #{e.class}: #{e.message}"
    end
  end

  def test_require_loading(file)
    puts "  📝 Testing require loading..."
    
    # Create isolated test environment
    test_code = <<~RUBY
      begin
        # Change to test directory
        Dir.chdir('#{File.dirname(file)}')
        
        # Try to require the file
        require_relative '#{File.basename(file, '.rb')}'
        
        puts "  ✅ File loads successfully"
        { status: "success", file: "#{file}" }
      rescue LoadError => e
        puts "  ❌ LoadError: \#{e.message}"
        { status: "load_error", file: "#{file}", error: e.message }
      rescue NameError => e
        puts "  ❌ NameError: \#{e.message}"
        { status: "name_error", file: "#{file}", error: e.message }
      rescue => e
        puts "  ❌ \#{e.class}: \#{e.message}"
        { status: "other_error", file: "#{file}", error: e.message, class: e.class }
      end
    RUBY
    
    # Execute in subprocess to avoid contaminating current environment
    result = `cd "#{Dir.pwd}" && ruby -e "#{test_code}" 2>&1`
    
    if result.include?("✅")
      { file: file, status: "success" }
    elsif result.include?("LoadError")
      { file: file, status: "load_error", error: extract_error(result) }
    elsif result.include?("NameError")
      { file: file, status: "name_error", error: extract_error(result) }
    else
      { file: file, status: "unknown", error: result.strip }
    end
  end

  def extract_error(output)
    output.lines.find { |line| line.include?("❌") }&.strip || output.strip
  end

  def classify_error(error)
    case error.class.to_s
    when "LoadError"
      "require_failure"
    when "NameError"
      "missing_class"
    when "NoMethodError"
      "method_error"
    else
      "other"
    end
  end

  def categorize_error(result)
    case result[:status]
    when "load_error"
      @patterns[:require_failures] << result
    when "name_error"
      @patterns[:missing_classes] << result
    when "timeout"
      @patterns[:infinite_loops] << result
    end
  end

  def analyze_patterns
    puts "\n🧩 PATTERN ANALYSIS"
    puts "=" * 30
    
    @patterns.each do |pattern, results|
      next if results.empty?
      
      puts "\n📊 #{pattern.to_s.upcase.gsub('_', ' ')} (#{results.length} files):"
      results.each do |result|
        puts "   • #{File.basename(result[:file])}: #{result[:error]}"
      end
    end
  end

  def generate_report
    puts "\n🎯 ROOT CAUSE ANALYSIS"
    puts "=" * 40
    
    total_files = @results.length
    
    puts "\n📈 SUMMARY:"
    puts "   Total files tested: #{total_files}"
    puts "   Require failures: #{@patterns[:require_failures].length}"
    puts "   Missing classes: #{@patterns[:missing_classes].length}"  
    puts "   Infinite loops: #{@patterns[:infinite_loops].length}"
    
    puts "\n🔧 LIKELY ROOT CAUSES:"
    
    if @patterns[:require_failures].length > 0
      puts "   1. REQUIRE PATH ISSUES:"
      puts "      - Relative paths pointing to wrong locations"
      puts "      - Missing source files in expected locations"
      puts "      - Similar to the TypeConstraintSystem fix needed"
    end
    
    if @patterns[:missing_classes].length > 0
      puts "   2. MISSING CLASS DEFINITIONS:"
      puts "      - Classes referenced but not defined"
      puts "      - Mock classes not implemented"
      puts "      - Constants not properly initialized"
    end
    
    if @patterns[:infinite_loops].length > 0
      puts "   3. INFINITE LOOPS/HANGS:"
      puts "      - Circular requires"
      puts "      - Initialization loops"
      puts "      - Test setup hanging"
    end

    puts "\n💡 RECOMMENDED FIXES:"
    puts "   1. Fix require paths (similar to TypeConstraintSystem)"
    puts "   2. Add missing mock classes and constants"
    puts "   3. Add timeout protection to test setup"
    puts "   4. Break circular dependencies"
  end
end

# Run the diagnostic
if __FILE__ == $0
  diagnostic = UnknownErrorDiagnostic.new
  diagnostic.diagnose_all
end