#!/usr/bin/env ruby

# Fix Namespace Specific Issues
# Address the specific namespace and class availability issues

class NamespaceSpecificFixer
  def initialize
    @fixes_applied = []
  end

  def fix_all_namespace_issues
    puts "=== FIXING NAMESPACE SPECIFIC ISSUES ==="
    
    # Fix each test's specific namespace requirements
    fix_type_constraints_namespace
    fix_error_handling_namespace  
    fix_parser_branch_namespace
    fix_evaluator_branch_namespace
    fix_evaluator_reasoning_namespace
    
    # Test the fixes
    validate_namespace_fixes
    
    puts "\n=== NAMESPACE FIXES APPLIED ==="
    @fixes_applied.each { |fix| puts "✓ #{fix}" }
  end

  private

  def fix_type_constraints_namespace
    puts "\n--- Fixing TypeConstraints namespace issue ---"
    
    # The test expects TypeConstraintSystem to be available
    # We need to make sure it's properly required
    test_file = 'test/ruby_implementation/test_type_constraints_clean.rb'
    if File.exist?(test_file)
      content = File.read(test_file)
      
      # Check what it's trying to require
      if content.include?("require_relative '../../src/reasoning/type_constraint'")
        # Make sure the path is correct and the class is properly defined
        ensure_type_constraint_system_in_correct_location
        @fixes_applied << "Fixed TypeConstraintSystem location and availability"
      end
    end
  end

  def fix_error_handling_namespace
    puts "\n--- Fixing ErrorHandling namespace issue ---"
    
    # The test expects Evaluator to be available in its namespace
    test_file = 'test/infrastructure/test_error_handling_coverage.rb'
    if File.exist?(test_file)
      content = File.read(test_file)
      
      # Add proper requires at the top of the test file if missing
      unless content.include?('require_relative ../../src/evaluator')
        # Insert require after existing requires
        lines = content.split("\n")
        insert_index = lines.find_index { |line| line.start_with?('require') }
        if insert_index
          lines.insert(insert_index + 1, "require_relative '../../src/evaluator'")
          File.write(test_file, lines.join("\n"))
          @fixes_applied << "Added Evaluator require to error handling test"
        end
      end
    end
  end

  def fix_parser_branch_namespace
    puts "\n--- Fixing Parser branch namespace issue ---"
    
    # The test expects IdentifierNode to be available
    # We need to create the missing AST node classes
    create_missing_ast_nodes
    
    # Also fix the test to properly require AST nodes
    test_file = 'test/infrastructure/test_parser_branch_coverage.rb'
    if File.exist?(test_file)
      content = File.read(test_file)
      
      # Add requires for AST nodes if missing
      unless content.include?('require_relative ../../src/ast')
        lines = content.split("\n")
        insert_index = lines.find_index { |line| line.start_with?('require') }
        if insert_index
          lines.insert(insert_index + 1, "require_relative '../../src/ast/identifier_node'")
          lines.insert(insert_index + 2, "require_relative '../../src/ast/number_node'")
          lines.insert(insert_index + 3, "require_relative '../../src/ast/string_node'")
          File.write(test_file, lines.join("\n"))
          @fixes_applied << "Added AST node requires to parser branch test"
        end
      end
    end
  end

  def fix_evaluator_branch_namespace
    puts "\n--- Fixing Evaluator branch namespace issue ---"
    
    # The test expects ReasoningModeError to inherit from StandardError properly
    # Let's check the current implementation
    error_file = 'src/reasoning_mode_error.rb'
    if File.exist?(error_file)
      content = File.read(error_file)
      
      # Make sure it properly inherits from StandardError
      unless content.include?('class ReasoningModeError < StandardError')
        # Fix the inheritance
        updated_content = content.gsub(
          'class ReasoningModeError',
          'class ReasoningModeError < StandardError'
        )
        File.write(error_file, updated_content)
        @fixes_applied << "Fixed ReasoningModeError inheritance"
      end
    end
    
    # Also make sure the test file can access it
    test_file = 'test/patlang_language/test_evaluator_branch_coverage.rb'
    if File.exist?(test_file)
      content = File.read(test_file)
      
      unless content.include?('require_relative ../../src/reasoning_mode_error')
        lines = content.split("\n")
        insert_index = lines.find_index { |line| line.start_with?('require') }
        if insert_index
          lines.insert(insert_index + 1, "require_relative '../../src/reasoning_mode_error'")
          File.write(test_file, lines.join("\n"))
          @fixes_applied << "Added ReasoningModeError require to evaluator branch test"
        end
      end
    end
  end

  def fix_evaluator_reasoning_namespace
    puts "\n--- Fixing Evaluator reasoning namespace issue ---"
    
    # Make sure all reasoning components are properly available
    reasoning_dir = 'src/reasoning'
    Dir.mkdir(reasoning_dir) unless Dir.exist?(reasoning_dir)
    
    # Create a comprehensive reasoning module
    reasoning_module_file = File.join(reasoning_dir, 'reasoning.rb')
    unless File.exist?(reasoning_module_file)
      content = <<~RUBY
        # Main Reasoning Module for PATLANG
        # Provides unified access to all reasoning components
        
        require_relative 'type_constraint_system'
        require_relative 'type_constraint'
        require_relative 'reasoning_coordinator'
        
        module Reasoning
          def self.create_constraint_system
            TypeConstraintSystem.new
          end
          
          def self.create_coordinator
            ReasoningCoordinator.new
          end
        end
      RUBY
      
      File.write(reasoning_module_file, content)
      @fixes_applied << "Created unified Reasoning module"
    end
  end

  def ensure_type_constraint_system_in_correct_location
    # Make sure TypeConstraintSystem is properly defined and accessible
    system_file = 'src/reasoning/type_constraint_system.rb'
    
    if File.exist?(system_file)
      content = File.read(system_file)
      
      # Make sure it has all the methods the test expects
      unless content.include?('def create_constraint')
        # The file exists but might be incomplete
        enhanced_content = <<~RUBY
          # Enhanced Type Constraint System for PATLANG
          require_relative 'type_constraint'
          
          class TypeConstraintSystem
            def initialize
              @constraints = []
              @event_handlers = Hash.new { |h, k| h[k] = [] }
            end
            
            def create_constraint(variable, constraint_type, constraint_data)
              constraint = TypeConstraint.new(variable, constraint_type, constraint_data)
              @constraints << constraint
              fire_event(:constraint_created, constraint)
              constraint
            end
            
            def validate_constraint(constraint, value)
              result = constraint.validate(value)
              event_type = result ? :constraint_validated : :constraint_failed
              fire_event(event_type, constraint)
              result
            end
            
            def on_event(event_type, &block)
              @event_handlers[event_type] << block
            end
            
            def constraints
              @constraints
            end
            
            def clear
              @constraints.clear
              @event_handlers.clear
            end
            
            private
            
            def fire_event(event_type, data)
              @event_handlers[event_type].each do |handler|
                # Create event object with type
                event = OpenStruct.new(type: event_type, data: data)
                handler.call(event)
              end
            end
          end
        RUBY
        
        File.write(system_file, enhanced_content)
      end
    end
  end

  def create_missing_ast_nodes
    puts "   Creating missing AST node classes..."
    
    ast_dir = 'src/ast'
    Dir.mkdir(ast_dir) unless Dir.exist?(ast_dir)
    
    # Create IdentifierNode
    identifier_file = File.join(ast_dir, 'identifier_node.rb')
    unless File.exist?(identifier_file)
      content = <<~RUBY
        # Identifier Node for AST
        require_relative 'node'
        
        class IdentifierNode < Node
          attr_reader :name, :value
          
          def initialize(name, value = nil)
            super(:identifier)
            @name = name
            @value = value
          end
          
          def to_s
            @name.to_s
          end
          
          def ==(other)
            other.is_a?(IdentifierNode) && @name == other.name
          end
        end
      RUBY
      
      File.write(identifier_file, content)
    end
    
    # Create NumberNode
    number_file = File.join(ast_dir, 'number_node.rb')
    unless File.exist?(number_file)
      content = <<~RUBY
        # Number Node for AST
        require_relative 'node'
        
        class NumberNode < Node
          attr_reader :value
          
          def initialize(value)
            super(:number)
            @value = value
          end
          
          def to_s
            @value.to_s
          end
          
          def ==(other)
            other.is_a?(NumberNode) && @value == other.value
          end
        end
      RUBY
      
      File.write(number_file, content)
    end
    
    # Create StringNode
    string_file = File.join(ast_dir, 'string_node.rb')
    unless File.exist?(string_file)
      content = <<~RUBY
        # String Node for AST
        require_relative 'node'
        
        class StringNode < Node
          attr_reader :value
          
          def initialize(value)
            super(:string)
            @value = value
          end
          
          def to_s
            @value.to_s
          end
          
          def ==(other)
            other.is_a?(StringNode) && @value == other.value
          end
        end
      RUBY
      
      File.write(string_file, content)
    end
    
    @fixes_applied << "Created missing AST node classes (IdentifierNode, NumberNode, StringNode)"
  end

  def validate_namespace_fixes
    puts "\n--- VALIDATING NAMESPACE FIXES ---"
    
    critical_tests = [
      'test/ruby_implementation/test_type_constraints_clean.rb',
      'test/infrastructure/test_error_handling_coverage.rb',
      'test/infrastructure/test_parser_branch_coverage.rb',
      'test/patlang_language/test_evaluator_branch_coverage.rb',
      'test/patlang_language/test_evaluator_reasoning.rb'
    ]
    
    success_count = 0
    critical_tests.each do |test_file|
      next unless File.exist?(test_file)
      
      test_dir = File.dirname(test_file)
      test_name = File.basename(test_file)
      
      puts "Testing: #{test_name}"
      result = `cd #{test_dir} && ruby -I../../src #{test_name} 2>&1`
      success = $?.success?
      
      if success
        puts "  ✅ PASSED"
        success_count += 1
      else
        puts "  ❌ FAILED"
        # Show specific error
        error_lines = result.split("\n").select { |line|
          line.include?('Error:') || line.include?('NameError') || 
          line.include?('uninitialized constant') || line.include?('LoadError')
        }
        error_lines.first(2).each { |line| puts "     #{line.strip}" }
      end
    end
    
    puts "\n📊 NAMESPACE FIX RESULTS:"
    puts "   Tests now passing: #{success_count}/#{critical_tests.length}"
    puts "   Success rate: #{(success_count.to_f / critical_tests.length * 100).round(1)}%"
    
    if success_count == critical_tests.length
      puts "🎉 ALL CRITICAL NAMESPACE ISSUES RESOLVED!"
    elsif success_count > 0
      puts "✅ SIGNIFICANT PROGRESS MADE"
    else
      puts "⚠️  ADDITIONAL WORK NEEDED"
    end
    
    success_count
  end
end

# Execute the namespace fixes
if __FILE__ == $0
  require 'ostruct'  # For event objects
  
  fixer = NamespaceSpecificFixer.new
  fixer.fix_all_namespace_issues
end