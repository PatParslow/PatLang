#!/usr/bin/env ruby

# Test Dependency Mapper for PATLANG
# Maps dependencies between source files and test files for intelligent test selection

require 'json'
require 'set'

class TestDependencyMapper
  def initialize
    @base_path = File.dirname(__FILE__)
    @project_root = File.dirname(@base_path)
    @dependencies = {}
    @reverse_dependencies = {}
    @test_files = []
    @source_files = []
  end

  def build_dependency_map
    puts "🔍 Building test dependency map for PATLANG"
    puts "=" * 50
    
    scan_project_files
    analyze_static_dependencies
    analyze_test_patterns
    analyze_coverage_relationships
    build_reverse_map
    save_dependency_data
    
    generate_dependency_report
  end

  def find_affected_tests(changed_files)
    puts "🎯 Finding tests affected by changes:"
    changed_files.each { |f| puts "   - #{f}" }
    puts
    
    affected_tests = Set.new
    
    changed_files.each do |file|
      # Direct test file changes
      if file.start_with?('test/')
        affected_tests.add(file) if @test_files.include?(file)
      end
      
      # Source file changes affecting tests
      if @dependencies[file]
        @dependencies[file].each { |test| affected_tests.add(test) }
      end
      
      # Pattern-based matching
      pattern_matches = find_pattern_based_tests(file)
      pattern_matches.each { |test| affected_tests.add(test) }
    end
    
    # Convert to structured format
    structured_tests = affected_tests.map do |test_path|
      {
        file: test_path,
        category: extract_category(test_path),
        reason: determine_dependency_reason(test_path, changed_files),
        priority: calculate_test_priority(test_path, changed_files)
      }
    end
    
    # Sort by priority
    structured_tests.sort_by { |t| t[:priority] }
  end

  private

  def scan_project_files
    puts "📂 Scanning project files..."
    
    # Scan test files
    test_patterns = [
      'test/infrastructure/test_*.rb',
      'test/ruby_implementation/test_*.rb', 
      'test/patlang_language/test_*.rb'
    ]
    
    test_patterns.each do |pattern|
      Dir.glob(File.join(@project_root, pattern)).each do |file|
        relative_path = file.sub(@project_root + '/', '')
        @test_files << relative_path
      end
    end
    
    # Scan source files
    source_patterns = [
      'src/**/*.rb'
    ]
    
    source_patterns.each do |pattern|
      Dir.glob(File.join(@project_root, pattern)).each do |file|
        relative_path = file.sub(@project_root + '/', '')
        @source_files << relative_path
      end
    end
    
    puts "   Found #{@test_files.length} test files"
    puts "   Found #{@source_files.length} source files"
    puts
  end

  def analyze_static_dependencies
    puts "🔗 Analyzing static dependencies..."
    
    @test_files.each do |test_file|
      analyze_test_file_dependencies(test_file)
    end
    
    puts "   Analyzed dependencies for #{@test_files.length} test files"
    puts
  end

  def analyze_test_file_dependencies(test_file)
    full_path = File.join(@project_root, test_file)
    return unless File.exist?(full_path)
    
    content = File.read(full_path)
    dependencies = Set.new
    
    # Explicit requires
    content.scan(/require_relative\s+['"](.*?)['"]/) do |match|
      required_file = normalize_require_path(match[0], test_file)
      if required_file && @source_files.include?(required_file)
        dependencies.add(required_file)
      end
    end
    
    content.scan(/require\s+['"](.*?)['"]/) do |match|
      # Handle absolute requires that might map to source files
      required_file = map_absolute_require(match[0])
      if required_file && @source_files.include?(required_file)
        dependencies.add(required_file)
      end
    end
    
    # Class/module instantiations that might indicate dependencies
    content.scan(/(\w+)\.new/) do |match|
      potential_file = find_source_file_for_class(match[0])
      if potential_file
        dependencies.add(potential_file)
      end
    end
    
    # Method calls that indicate component usage
    content.scan(/(\w+)\.(\w+)/) do |class_name, method_name|
      potential_file = find_source_file_for_class(class_name)
      if potential_file
        dependencies.add(potential_file)
      end
    end
    
    # Store dependencies
    dependencies.each do |source_file|
      @dependencies[source_file] ||= []
      @dependencies[source_file] << test_file unless @dependencies[source_file].include?(test_file)
    end
  end

  def normalize_require_path(require_path, from_file)
    # Handle relative paths from test files
    if require_path.start_with?('../')
      # Go up from test file to project root, then follow path
      base_dir = File.dirname(from_file)
      normalized = File.expand_path(require_path, base_dir)
      
      # Make it relative to project root
      if normalized.start_with?('/')
        normalized = normalized[1..-1]
      end
      
      # Add .rb extension if missing
      normalized += '.rb' unless normalized.end_with?('.rb')
      
      return normalized if @source_files.include?(normalized)
    end
    
    # Handle direct paths
    potential_paths = [
      "#{require_path}.rb",
      "src/#{require_path}.rb",
      "src/#{require_path}/#{File.basename(require_path)}.rb"
    ]
    
    potential_paths.find { |path| @source_files.include?(path) }
  end

  def map_absolute_require(require_name)
    # Map common require patterns to source files
    mappings = {
      'patlang' => 'src/patlang.rb',
      'token' => 'src/token.rb',
      'parser' => 'src/parser.rb',
      'lexer' => 'src/lexer.rb',
      'evaluator' => 'src/evaluator.rb',
      'ast_nodes' => 'src/ast_nodes.rb'
    }
    
    mappings[require_name]
  end

  def find_source_file_for_class(class_name)
    # Common class to file mappings
    class_mappings = {
      'Patlang' => 'src/patlang.rb',
      'Token' => 'src/token.rb',
      'Parser' => 'src/parser.rb',
      'Lexer' => 'src/lexer.rb',
      'Evaluator' => 'src/evaluator.rb',
      'ASTNode' => 'src/ast_nodes.rb',
      'ASTNodes' => 'src/ast_nodes.rb',
      'FactsDatabase' => 'src/reasoning/facts_database.rb',
      'GoalSystem' => 'src/reasoning/goal_system.rb',
      'UnificationEngine' => 'src/reasoning/unification_engine.rb',
      'TypeConstraint' => 'src/reasoning/type_constraint.rb',
      'ReasoningCoordinator' => 'src/reasoning/reasoning_coordinator.rb',
      'CrossParadigmCoordinator' => 'src/reasoning/cross_paradigm_coordinator.rb'
    }
    
    # Try exact match
    return class_mappings[class_name] if class_mappings[class_name]
    
    # Try snake_case conversion
    snake_case = class_name.gsub(/([A-Z])/, '_\1').downcase.sub(/^_/, '')
    potential_files = [
      "src/#{snake_case}.rb",
      "src/reasoning/#{snake_case}.rb",
      "src/parser/#{snake_case}.rb"
    ]
    
    potential_files.find { |file| @source_files.include?(file) }
  end

  def analyze_test_patterns
    puts "🔍 Analyzing test file patterns..."
    
    # Pattern-based dependency analysis
    pattern_rules = [
      {
        pattern: /test.*lexer/i,
        dependencies: ['src/lexer.rb', 'src/token.rb']
      },
      {
        pattern: /test.*parser/i,
        dependencies: ['src/parser.rb', 'src/lexer.rb', 'src/token.rb', 'src/ast_nodes.rb']
      },
      {
        pattern: /test.*evaluator/i,
        dependencies: ['src/evaluator.rb', 'src/parser.rb', 'src/lexer.rb']
      },
      {
        pattern: /test.*reasoning/i,
        dependencies: ['src/reasoning/']
      },
      {
        pattern: /test.*object.*model/i,
        dependencies: ['src/object_model/', 'src/evaluator.rb']
      },
      {
        pattern: /test.*integration/i,
        dependencies: ['src/patlang.rb', 'src/parser.rb', 'src/evaluator.rb']
      }
    ]
    
    @test_files.each do |test_file|
      pattern_rules.each do |rule|
        if test_file.match(rule[:pattern])
          rule[:dependencies].each do |dep|
            if dep.end_with?('/')
              # Directory dependency - find all files in directory
              dir_files = @source_files.select { |f| f.start_with?(dep) }
              dir_files.each do |source_file|
                @dependencies[source_file] ||= []
                @dependencies[source_file] << test_file unless @dependencies[source_file].include?(test_file)
              end
            else
              # Single file dependency
              if @source_files.include?(dep)
                @dependencies[dep] ||= []
                @dependencies[dep] << test_file unless @dependencies[dep].include?(test_file)
              end
            end
          end
        end
      end
    end
    
    puts "   Applied pattern-based dependency rules"
    puts
  end

  def analyze_coverage_relationships
    puts "📊 Analyzing coverage relationships..."
    
    # If coverage data exists, use it to infer dependencies
    coverage_files = Dir.glob(File.join(@base_path, 'coverage/**/coverage.json'))
    
    coverage_files.each do |coverage_file|
      analyze_coverage_file(coverage_file)
    end
    
    puts "   Analyzed #{coverage_files.length} coverage files"
    puts
  end

  def analyze_coverage_file(coverage_file)
    return unless File.exist?(coverage_file)
    
    begin
      coverage_data = JSON.parse(File.read(coverage_file))
      
      # Extract file coverage information
      coverage_data.each do |file_path, coverage_info|
        next unless coverage_info.is_a?(Hash)
        
        # If a source file has coverage, it was likely executed by recent tests
        relative_path = file_path.sub(@project_root + '/', '')
        if @source_files.include?(relative_path) && coverage_info['lines']
          # Mark as potentially related to all recently run tests
          # This is a heuristic that could be improved with more detailed coverage data
        end
      end
    rescue JSON::ParserError
      # Skip malformed coverage files
    end
  end

  def find_pattern_based_tests(changed_file)
    tests = []
    
    # Direct naming conventions
    base_name = File.basename(changed_file, '.rb')
    
    # Look for tests that match the base name
    @test_files.each do |test_file|
      test_base = File.basename(test_file, '.rb')
      
      # Direct name match (e.g., lexer.rb -> test_lexer.rb)
      if test_base == "test_#{base_name}"
        tests << test_file
      end
      
      # Partial name match (e.g., unification_engine.rb -> test_unification_engine.rb)
      if test_base.include?(base_name) || base_name.include?(test_base.sub('test_', ''))
        tests << test_file
      end
      
      # Directory-based matching
      if changed_file.include?('/reasoning/') && test_file.include?('reasoning')
        tests << test_file
      end
      
      if changed_file.include?('/parser/') && test_file.include?('parser')
        tests << test_file
      end
    end
    
    tests.uniq
  end

  def build_reverse_map
    puts "🔄 Building reverse dependency map..."
    
    @dependencies.each do |source_file, test_files|
      test_files.each do |test_file|
        @reverse_dependencies[test_file] ||= []
        @reverse_dependencies[test_file] << source_file
      end
    end
    
    puts "   Built reverse dependencies for #{@reverse_dependencies.length} test files"
    puts
  end

  def extract_category(test_path)
    if test_path.include?('infrastructure/')
      'infrastructure'
    elsif test_path.include?('ruby_implementation/')
      'ruby_implementation'
    elsif test_path.include?('patlang_language/')
      'patlang_language'
    else
      'other'
    end
  end

  def determine_dependency_reason(test_path, changed_files)
    reasons = []
    
    changed_files.each do |changed_file|
      # Direct test file change
      if test_path == changed_file
        reasons << "direct change"
      end
      
      # Source dependency
      if @reverse_dependencies[test_path]&.include?(changed_file)
        reasons << "depends on #{File.basename(changed_file)}"
      end
      
      # Pattern match
      if find_pattern_based_tests(changed_file).include?(test_path)
        reasons << "pattern match with #{File.basename(changed_file)}"
      end
    end
    
    reasons.join(', ')
  end

  def calculate_test_priority(test_path, changed_files)
    priority = 5  # Default priority
    
    changed_files.each do |changed_file|
      # Direct test file change - highest priority
      if test_path == changed_file
        priority = 0
        break
      end
      
      # Core component changes
      if changed_file.include?('lexer') || changed_file.include?('parser')
        priority = [priority, 1].min
      end
      
      # Evaluator changes
      if changed_file.include?('evaluator')
        priority = [priority, 2].min
      end
      
      # Infrastructure tests have higher priority
      if test_path.include?('infrastructure/')
        priority = [priority, 2].min
      end
    end
    
    priority
  end

  def save_dependency_data
    puts "💾 Saving dependency data..."
    
    dependency_data = {
      timestamp: Time.now.to_i,
      source_files: @source_files,
      test_files: @test_files,
      dependencies: @dependencies,
      reverse_dependencies: @reverse_dependencies,
      statistics: {
        total_source_files: @source_files.length,
        total_test_files: @test_files.length,
        total_dependencies: @dependencies.values.flatten.length,
        coverage_percentage: calculate_coverage_percentage
      }
    }
    
    # Save main dependency file
    deps_file = File.join(@base_path, 'test_dependencies.json')
    File.write(deps_file, JSON.pretty_generate(dependency_data))
    
    # Save simplified version for scheduler
    simplified_deps = {}
    @dependencies.each do |source_file, test_files|
      simplified_deps[source_file] = test_files.uniq
    end
    
    simple_file = File.join(@base_path, 'test_dependencies_simple.json')
    File.write(simple_file, JSON.pretty_generate(simplified_deps))
    
    puts "   Main dependency data: #{deps_file}"
    puts "   Simplified data: #{simple_file}"
    puts
  end

  def calculate_coverage_percentage
    covered_files = @dependencies.keys.length
    total_files = @source_files.length
    
    return 0 if total_files == 0
    
    (covered_files.to_f / total_files * 100).round(1)
  end

  def generate_dependency_report
    puts "📊 DEPENDENCY ANALYSIS REPORT"
    puts "=" * 50
    
    puts "📂 PROJECT OVERVIEW:"
    puts "   Source files: #{@source_files.length}"
    puts "   Test files: #{@test_files.length}"
    puts "   Dependencies mapped: #{@dependencies.length}"
    puts "   Coverage: #{calculate_coverage_percentage}%"
    puts
    
    puts "🔗 DEPENDENCY BREAKDOWN:"
    @dependencies.each do |source_file, test_files|
      puts "   #{source_file}:"
      test_files.each { |test| puts "     → #{test}" }
    end
    puts
    
    puts "📈 STATISTICS:"
    most_tested = @dependencies.max_by { |_, tests| tests.length }
    if most_tested
      puts "   Most tested file: #{most_tested[0]} (#{most_tested[1].length} tests)"
    end
    
    least_tested = @source_files.select { |f| !@dependencies.key?(f) }
    if least_tested.any?
      puts "   Untested files: #{least_tested.length}"
      least_tested.first(5).each { |f| puts "     - #{f}" }
    end
    
    puts
    puts "💡 RECOMMENDATIONS:"
    
    if least_tested.any?
      puts "   - Add test coverage for #{least_tested.length} untested files"
    end
    
    if calculate_coverage_percentage < 80
      puts "   - Improve dependency mapping (current coverage: #{calculate_coverage_percentage}%)"
    end
    
    orphaned_tests = @test_files.select { |t| !@reverse_dependencies.key?(t) }
    if orphaned_tests.any?
      puts "   - Review #{orphaned_tests.length} tests with unclear dependencies"
    end
    
    puts
  end
end

# CLI Interface
if __FILE__ == $0
  mapper = TestDependencyMapper.new
  
  if ARGV[0] == 'map'
    mapper.build_dependency_map
  elsif ARGV[0] == 'affected' && ARGV[1]
    # Find affected tests for specific files
    changed_files = ARGV[1..-1]
    affected = mapper.find_affected_tests(changed_files)
    
    puts "🎯 Affected tests:"
    affected.each do |test|
      puts "   - #{test[:file]} (#{test[:reason]}) [priority: #{test[:priority]}]"
    end
  else
    puts "USAGE:"
    puts "  ruby test/test_dependency_mapper.rb map"
    puts "  ruby test/test_dependency_mapper.rb affected src/lexer.rb src/parser.rb"
    exit(1)
  end
end