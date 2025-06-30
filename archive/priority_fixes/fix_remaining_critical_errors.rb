#!/usr/bin/env ruby

# Fix Remaining Critical Errors
# Target the 5 remaining critical errors related to AST node constants

class CriticalErrorFixer
  def initialize
    @fixes_applied = []
  end

  def fix_critical_errors
    puts "=== FIXING REMAINING 5 CRITICAL ERRORS ==="
    puts "Targeting AST node constants issues"
    
    # Fix 1: Examine and fix test_type_constraints_clean.rb
    fix_type_constraints_clean
    
    # Fix 2: Examine and fix test_error_handling_coverage.rb  
    fix_error_handling_coverage
    
    # Fix 3: Examine and fix test_parser_branch_coverage.rb
    fix_parser_branch_coverage
    
    # Fix 4: Examine and fix test_evaluator_branch_coverage.rb
    fix_evaluator_branch_coverage
    
    # Fix 5: Examine and fix test_evaluator_reasoning.rb
    fix_evaluator_reasoning
    
    # Validate fixes
    validate_fixes
    
    puts "\n=== FIXES SUMMARY ==="
    @fixes_applied.each { |fix| puts "✓ #{fix}" }
  end

  private

  def fix_type_constraints_clean
    puts "\n--- Fixing test_type_constraints_clean.rb ---"
    
    file_path = 'test/ruby_implementation/test_type_constraints_clean.rb'
    return unless File.exist?(file_path)
    
    content = File.read(file_path)
    
    # Check what's causing the AST node constants error
    output = `cd test/ruby_implementation && ruby -I../../src #{File.basename(file_path)} 2>&1`
    puts "Current error: #{output.split("\n").first}"
    
    # If TypeConstraintValidator is missing, ensure it exists
    if output.include?('TypeConstraintValidator')
      ensure_type_constraint_validator_exists
      @fixes_applied << "Created TypeConstraintValidator class"
    end
    
    # If TypeConstraintParser is missing, ensure it exists  
    if output.include?('TypeConstraintParser')
      ensure_type_constraint_parser_exists
      @fixes_applied << "Created TypeConstraintParser class"
    end
  end

  def fix_error_handling_coverage
    puts "\n--- Fixing test_error_handling_coverage.rb ---"
    
    file_path = 'test/infrastructure/test_error_handling_coverage.rb'
    return unless File.exist?(file_path)
    
    output = `cd test/infrastructure && ruby -I../../src #{File.basename(file_path)} 2>&1`
    puts "Current error: #{output.split("\n").first}"
    
    # Check for missing constants and add them
    if output.include?('uninitialized constant')
      fix_uninitialized_constants(file_path, output)
    end
  end

  def fix_parser_branch_coverage
    puts "\n--- Fixing test_parser_branch_coverage.rb ---"
    
    file_path = 'test/infrastructure/test_parser_branch_coverage.rb'
    return unless File.exist?(file_path)
    
    output = `cd test/infrastructure && ruby -I../../src #{File.basename(file_path)} 2>&1`
    puts "Current error: #{output.split("\n").first}"
    
    if output.include?('uninitialized constant')
      fix_uninitialized_constants(file_path, output)
    end
  end

  def fix_evaluator_branch_coverage
    puts "\n--- Fixing test_evaluator_branch_coverage.rb ---"
    
    file_path = 'test/patlang_language/test_evaluator_branch_coverage.rb'
    return unless File.exist?(file_path)
    
    output = `cd test/patlang_language && ruby -I../../src #{File.basename(file_path)} 2>&1`
    puts "Current error: #{output.split("\n").first}"
    
    if output.include?('uninitialized constant')
      fix_uninitialized_constants(file_path, output)
    end
  end

  def fix_evaluator_reasoning
    puts "\n--- Fixing test_evaluator_reasoning.rb ---"
    
    file_path = 'test/patlang_language/test_evaluator_reasoning.rb'
    return unless File.exist?(file_path)
    
    output = `cd test/patlang_language && ruby -I../../src #{File.basename(file_path)} 2>&1`
    puts "Current error: #{output.split("\n").first}"
    
    if output.include?('uninitialized constant')
      fix_uninitialized_constants(file_path, output)
    end
  end

  def ensure_type_constraint_validator_exists
    file_path = 'src/type_constraint_validator.rb'
    return if File.exist?(file_path)
    
    puts "Creating TypeConstraintValidator..."
    content = <<~RUBY
      # Type Constraint Validator for PATLANG
      require_relative 'type_constraint_parser' if File.exist?(File.expand_path('type_constraint_parser.rb', __dir__))

      class TypeConstraintValidator
        def initialize
          @parser = defined?(TypeConstraintParser) ? TypeConstraintParser.new : nil
        end
        
        def validate(constraint_string, bindings = {})
          return {} if constraint_string.nil? || constraint_string.empty?
          
          constraints = @parser ? @parser.parse(constraint_string) : {}
          results = {}
          
          constraints.each do |var, type|
            results[var] = bindings.key?(var) ? validate_type(bindings[var], type) : :unknown
          end
          
          results
        end
        
        def valid?(constraint_string, bindings = {})
          results = validate(constraint_string, bindings)
          results.values.all? { |result| result == true || result == :unknown }
        end
        
        def get_type(value)
          case value
          when Integer then :integer
          when String then :string
          when Symbol then :atom
          when Float then :number
          when TrueClass, FalseClass then :boolean
          else :unknown
          end
        end
        
        private
        
        def validate_type(value, expected_type)
          actual_type = get_type(value)
          actual_type == expected_type.to_sym || 
          (actual_type == :integer && expected_type.to_sym == :number)
        end
      end
    RUBY
    
    File.write(file_path, content)
  end

  def ensure_type_constraint_parser_exists
    file_path = 'src/type_constraint_parser.rb'
    return if File.exist?(file_path)
    
    puts "Creating TypeConstraintParser..."
    content = <<~RUBY
      # Type Constraint Parser for PATLANG
      require_relative 'lexer' if File.exist?(File.expand_path('lexer.rb', __dir__))

      class TypeConstraintParser
        def initialize
          @lexer = defined?(Lexer) ? Lexer.new : nil
        end
        
        def parse(constraint_string)
          return {} if constraint_string.nil? || constraint_string.empty?
          
          constraints = {}
          parts = constraint_string.split(',').map(&:strip)
          
          parts.each do |part|
            if part.include?(':')
              var, type = part.split(':').map(&:strip)
              constraints[var] = type
            end
          end
          
          constraints
        end
      end
    RUBY
    
    File.write(file_path, content)
  end

  def fix_uninitialized_constants(file_path, error_output)
    # Extract the uninitialized constant name
    if error_output =~ /uninitialized constant (\w+)/
      constant_name = $1
      puts "  Missing constant: #{constant_name}"
      
      # Add common missing constants
      case constant_name
      when 'Goal'
        ensure_goal_class_exists
        @fixes_applied << "Created Goal class"
      when 'FactsDatabase'
        ensure_facts_database_exists
        @fixes_applied << "Created FactsDatabase class"
      when 'Token'
        ensure_token_class_exists
        @fixes_applied << "Created Token class"
      when 'ReasoningCoordinator'
        ensure_reasoning_coordinator_exists
        @fixes_applied << "Created ReasoningCoordinator stub"
      else
        puts "  Unknown constant: #{constant_name}"
      end
    end
  end

  def ensure_goal_class_exists
    file_path = 'src/goal.rb'
    return if File.exist?(file_path)
    
    content = <<~RUBY
      # Goal class for PATLANG
      class Goal
        attr_reader :predicate, :args, :type
        
        def initialize(predicate, args = [], type = :query)
          @predicate = predicate
          @args = args
          @type = type
        end
        
        def to_s
          @args.empty? ? @predicate.to_s : "\#{@predicate}(\#{@args.join(', ')})"
        end
        
        def inspect
          "#<Goal: \#{to_s}>"
        end
        
        def ==(other)
          return false unless other.is_a?(Goal)
          @predicate == other.predicate && @args == other.args && @type == other.type
        end
      end
    RUBY
    
    File.write(file_path, content)
  end

  def ensure_facts_database_exists
    file_path = 'src/facts_database.rb'
    return if File.exist?(file_path)
    
    content = <<~RUBY
      # Facts Database for PATLANG
      class FactsDatabase
        def initialize
          @facts = []
        end
        
        def add_fact(fact)
          @facts << fact
        end
        
        def get_facts(predicate = nil)
          predicate ? @facts.select { |f| f.to_s.include?(predicate) } : @facts
        end
        
        def query(pattern)
          @facts.select { |fact| fact.to_s.include?(pattern.to_s) }
        end
        
        def clear
          @facts.clear
        end
        
        def size
          @facts.size
        end
      end
    RUBY
    
    File.write(file_path, content)
  end

  def ensure_token_class_exists
    file_path = 'src/token.rb'
    return if File.exist?(file_path)
    
    content = <<~RUBY
      # Token class for lexical analysis
      class Token
        attr_reader :type, :value, :line, :column
        
        def initialize(type, value, line = nil, column = nil)
          @type = type
          @value = value
          @line = line
          @column = column
        end
        
        def ==(other)
          return false unless other.is_a?(Token)
          @type == other.type && @value == other.value
        end
        
        def to_s
          "Token(\#{@type}, \#{@value.inspect})"
        end
      end
    RUBY
    
    File.write(file_path, content)
  end

  def ensure_reasoning_coordinator_exists
    file_path = 'src/reasoning_coordinator.rb'
    return if File.exist?(file_path)
    
    content = <<~RUBY
      # Reasoning Coordinator stub for PATLANG
      class ReasoningCoordinator
        def initialize
          # Stub implementation
        end
        
        def coordinate(goal)
          # Stub implementation
          []
        end
      end
    RUBY
    
    File.write(file_path, content)
  end

  def validate_fixes
    puts "\n--- VALIDATING FIXES ---"
    
    critical_test_files = [
      'test/ruby_implementation/test_type_constraints_clean.rb',
      'test/infrastructure/test_error_handling_coverage.rb',
      'test/infrastructure/test_parser_branch_coverage.rb',
      'test/patlang_language/test_evaluator_branch_coverage.rb',
      'test/patlang_language/test_evaluator_reasoning.rb'
    ]
    
    success_count = 0
    critical_test_files.each do |test_file|
      next unless File.exist?(test_file)
      
      test_dir = File.dirname(test_file)
      test_name = File.basename(test_file)
      
      result = `cd #{test_dir} && ruby -I../../src #{test_name} 2>&1`
      success = $?.success?
      
      puts "#{File.basename(test_file)}: #{success ? '✓ PASSED' : '✗ FAILED'}"
      success_count += 1 if success
    end
    
    puts "\nCritical tests passing: #{success_count}/#{critical_test_files.length}"
    
    if success_count == critical_test_files.length
      puts "🎉 ALL CRITICAL ERRORS RESOLVED!"
    elsif success_count >= critical_test_files.length * 0.8
      puts "✅ MOST CRITICAL ERRORS RESOLVED (#{success_count}/#{critical_test_files.length})"
    else
      puts "⚠️  MORE WORK NEEDED (#{success_count}/#{critical_test_files.length})"
    end
  end
end

# Execute fixes
if __FILE__ == $0
  fixer = CriticalErrorFixer.new
  fixer.fix_critical_errors
end