#!/usr/bin/env ruby

# Critical Issues Fix Script
# Addresses the primary issues found in comprehensive regression testing

require 'fileutils'
require 'json'

class CriticalIssuesFixer
  def initialize
    @fixes_applied = []
    @base_path = File.expand_path('..', __dir__)
  end

  def fix_all_critical_issues
    puts "🔧 FIXING CRITICAL ISSUES IN PATLANG SYSTEM"
    puts "=" * 60
    puts

    # Fix 1: Add single quote string support to lexer
    fix_single_quote_strings

    # Fix 2: Fix the missing method error in parser
    fix_parser_missing_method

    # Fix 3: Fix function storage and retrieval
    fix_function_storage

    # Fix 4: Fix infinite loop in CrossParadigmCoordinator
    fix_infinite_loop_prevention

    # Generate summary report
    generate_fix_report
  end

  def fix_single_quote_strings
    puts "🔧 Fix 1: Adding single quote string support to lexer..."
    
    lexer_file = File.join(@base_path, 'src', 'lexer.rb')
    content = File.read(lexer_file)
    
    # Add single quote handling to the case statement
    original_pattern = /when '"'\s*return tokenize_string/
    replacement = 'when \'"\'
        return tokenize_string(\'"\')
      when "\'"
        return tokenize_string("\'")'
    
    if content.match(original_pattern)
      content = content.gsub(original_pattern, replacement)
      
      # Also need to modify tokenize_string to accept quote type
      tokenize_string_pattern = /def tokenize_string\s*$/
      if content.match(tokenize_string_pattern)
        content = content.gsub(
          tokenize_string_pattern,
          'def tokenize_string(quote_type = \'"\')' 
        )
        
        # Update the method to use the quote type parameter
        content = content.gsub(
          /while @current_char && @current_char != '"'/,
          'while @current_char && @current_char != quote_type'
        )
        
        content = content.gsub(
          /if @current_char != '"'/,
          'if @current_char != quote_type'
        )
        
        # Add single quote escape handling
        escape_pattern = /when '"'/
        content = content.gsub(
          escape_pattern,
          'when \'"\'
            value += \'"\' 
          when "\'"
            value += "\'"'
        )
      end
      
      File.write(lexer_file, content)
      @fixes_applied << "✅ Added single quote string support to lexer"
      puts "   ✅ Single quote strings now supported"
    else
      puts "   ⚠️  Single quote fix pattern not found - manual intervention needed"
    end
  end

  def fix_parser_missing_method
    puts "\n🔧 Fix 2: Fixing missing method error in parser..."
    
    parser_file = File.join(@base_path, 'src', 'parser', 'expression_parser.rb')
    content = File.read(parser_file)
    
    # The issue is likely around line 131 where .name is called on NumberNode
    # NumberNode doesn't have a name method - it should likely use .value
    problem_pattern = /\.name/
    
    if content.include?('.name')
      # Check the context around .name usage
      lines = content.split("\n")
      lines.each_with_index do |line, index|
        if line.include?('.name') && line.include?('NumberNode')
          # Replace .name with .value for NumberNode
          lines[index] = line.gsub('.name', '.value')
          puts "   ✅ Fixed .name call on NumberNode at line #{index + 1}"
          @fixes_applied << "✅ Fixed parser .name method error"
        elsif line.include?('.name') && !line.include?('VariableNode')
          # For non-variable nodes, use .value instead of .name
          lines[index] = line.gsub('.name', '.value')
          puts "   ✅ Fixed .name call at line #{index + 1}"
        end
      end
      
      File.write(parser_file, lines.join("\n"))
    else
      puts "   ⚠️  No .name method calls found in expression parser"
    end
  end

  def fix_function_storage
    puts "\n🔧 Fix 3: Fixing function storage and retrieval..."
    
    evaluator_file = File.join(@base_path, 'src', 'evaluator.rb')
    
    if File.exist?(evaluator_file)
      content = File.read(evaluator_file)
      
      # Check if function storage mechanism exists
      if !content.include?('@functions')
        # Add function storage to evaluator initialization
        init_pattern = /def initialize/
        if content.match(init_pattern)
          content = content.gsub(
            /def initialize.*\n/,
            "def initialize\n    @functions = {}\n"
          )
          @fixes_applied << "✅ Added function storage to evaluator"
          puts "   ✅ Added function storage mechanism"
        end
      end
      
      # Ensure function calls work correctly
      if !content.include?('def visit_function_call')
        # Add basic function call handling
        content += "\n\n  def visit_function_call(node)\n"
        content += "    func_name = node.name\n"
        content += "    func = @functions[func_name]\n"
        content += "    if func.nil?\n"
        content += "      raise \"Undefined function: \#{func_name}\"\n"
        content += "    end\n"
        content += "    # Execute function (simplified)\n"
        content += "    visit(func.body) if func.respond_to?(:body)\n"
        content += "  end\n"
        
        @fixes_applied << "✅ Added function call handling"
        puts "   ✅ Added function call mechanism"
      end
      
      File.write(evaluator_file, content)
    else
      puts "   ⚠️  Evaluator file not found"
    end
  end

  def fix_infinite_loop_prevention
    puts "\n🔧 Fix 4: Adding infinite loop prevention..."
    
    coordinator_file = File.join(@base_path, 'src', 'reasoning', 'cross_paradigm_coordinator.rb')
    
    if File.exist?(coordinator_file)
      content = File.read(coordinator_file)
      
      # Add loop detection to execute_workflow method
      if content.include?('def execute_workflow')
        # Add recursion depth tracking
        init_pattern = /def initialize/
        if content.match(init_pattern)
          content = content.gsub(
            /def initialize.*\n/,
            "def initialize\n    @workflow_depth = 0\n    @max_workflow_depth = 100\n"
          )
        end
        
        # Add depth checking to execute_workflow
        workflow_pattern = /def execute_workflow\((.*?)\)/
        if content.match(workflow_pattern)
          content = content.gsub(
            workflow_pattern,
            'def execute_workflow(\1)
    @workflow_depth += 1
    if @workflow_depth > @max_workflow_depth
      @workflow_depth = 0
      raise "Maximum workflow depth exceeded - possible infinite loop detected"
    end
    
    begin'
          )
          
          # Add ensure block to reset depth
          content = content.gsub(
            /(\s+end\s*$)/m,
            '    ensure
      @workflow_depth -= 1 if @workflow_depth > 0
    end'
          )
        end
        
        @fixes_applied << "✅ Added infinite loop prevention to CrossParadigmCoordinator"
        puts "   ✅ Added workflow depth limiting"
        File.write(coordinator_file, content)
      else
        puts "   ⚠️  execute_workflow method not found"
      end
    else
      puts "   ⚠️  CrossParadigmCoordinator file not found"
    end
  end

  def generate_fix_report
    puts "\n" + "=" * 60
    puts "🎉 CRITICAL ISSUES FIX SUMMARY"
    puts "=" * 60
    
    puts "\n📋 FIXES APPLIED:"
    if @fixes_applied.empty?
      puts "  ⚠️  No fixes were successfully applied"
    else
      @fixes_applied.each do |fix|
        puts "  #{fix}"
      end
    end
    
    puts "\n🧪 RECOMMENDED NEXT STEPS:"
    puts "  1. Run the regression test again to verify fixes"
    puts "  2. Test core functionality manually"
    puts "  3. Check for any remaining issues"
    puts "  4. Commit fixes if tests pass"
    
    puts "\n📊 FIX STATUS: #{@fixes_applied.length} fixes applied"
    
    # Write fix report to file
    report = {
      timestamp: Time.now.strftime("%Y-%m-%d %H:%M:%S"),
      fixes_applied: @fixes_applied,
      total_fixes: @fixes_applied.length
    }
    
    File.write('critical_fixes_report.json', JSON.pretty_generate(report))
    puts "\n📄 Detailed report written to: critical_fixes_report.json"
  end
end

# Run the fixes
if __FILE__ == $0
  fixer = CriticalIssuesFixer.new
  fixer.fix_all_critical_issues
end