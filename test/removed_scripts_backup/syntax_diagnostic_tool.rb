#!/usr/bin/env ruby

# Syntax Diagnostic Tool for PATLANG Critical Issue Resolution
# Identifies and attempts to fix syntax errors blocking test execution

require 'tempfile'

class SyntaxDiagnosticTool
  def initialize
    @base_path = File.dirname(File.dirname(__FILE__))
    @src_path = File.join(@base_path, 'src')
  end

  def diagnose_and_fix_critical_syntax_errors
    puts "🔍 SYNTAX DIAGNOSTIC TOOL"
    puts "=" * 50
    
    critical_files = ['lexer.rb', 'parser.rb', 'evaluator.rb']
    issues_found = []
    
    critical_files.each do |file|
      file_path = File.join(@src_path, file)
      next unless File.exist?(file_path)
      
      puts "\n📋 Checking #{file}..."
      issues = check_file_syntax(file_path)
      
      if issues.any?
        puts "   ❌ Found #{issues.length} syntax issues"
        issues.each { |issue| puts "      - #{issue}" }
        issues_found.concat(issues.map { |i| { file: file, issue: i } })
      else
        puts "   ✅ No syntax errors detected"
      end
    end
    
    if issues_found.any?
      puts "\n🔧 Attempting to fix critical syntax errors..."
      fix_critical_syntax_errors(issues_found)
    else
      puts "\n✅ No critical syntax errors found in core files"
    end
    
    issues_found
  end

  private

  def check_file_syntax(file_path)
    issues = []
    
    begin
      # Try to parse the file with Ruby's built-in syntax checker
      output = `ruby -c "#{file_path}" 2>&1`
      
      unless $?.success?
        issues << "Ruby syntax check failed: #{output.strip}"
      end
      
      # Check for common issues manually
      content = File.read(file_path)
      
      # Check for unmatched keywords
      if content.scan(/\bclass\b/).length > content.scan(/^end\s*$/).length
        issues << "Possible missing 'end' for class definition"
      end
      
      # Check for unmatched case statements
      case_count = content.scan(/\bcase\b/).length
      end_count = content.scan(/\bend\b/).length
      if case_count > 0 && end_count < case_count
        issues << "Possible missing 'end' for case statement"
      end
      
    rescue => e
      issues << "Error reading file: #{e.message}"
    end
    
    issues
  end

  def fix_critical_syntax_errors(issues)
    issues.each do |issue_info|
      file_path = File.join(@src_path, issue_info[:file])
      issue = issue_info[:issue]
      
      puts "   🔧 Fixing: #{issue_info[:file]} - #{issue}"
      
      if issue.include?("missing 'end'")
        attempt_end_fix(file_path)
      elsif issue.include?("syntax check failed")
        attempt_syntax_fix(file_path, issue)
      end
    end
  end

  def attempt_end_fix(file_path)
    content = File.read(file_path)
    lines = content.split("\n")
    
    # Simple heuristic: if last non-empty line isn't 'end', add one
    last_non_empty = lines.reverse.find { |line| !line.strip.empty? }
    
    if last_non_empty && !last_non_empty.strip.match(/^end\s*$/)
      puts "      Adding missing 'end' to #{File.basename(file_path)}"
      File.write(file_path, content + "\nend\n")
    end
  end

  def attempt_syntax_fix(file_path, error_message)
    # For now, just report the issue - manual intervention needed
    puts "      Manual fix required for: #{error_message}"
  end
end

# CLI Interface
if __FILE__ == $0
  tool = SyntaxDiagnosticTool.new
  issues = tool.diagnose_and_fix_critical_syntax_errors
  
  exit(issues.empty? ? 0 : 1)
end