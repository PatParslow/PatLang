#!/usr/bin/env ruby

# Fix script for CrossParadigmCoordinator syntax errors
# Problem: Random 'ensure' keywords scattered throughout the file without proper begin blocks

require 'fileutils'

def fix_syntax_errors
  file_path = 'src/reasoning/cross_paradigm_coordinator.rb'
  
  puts "Reading #{file_path}..."
  content = File.read(file_path)
  
  # Create backup
  backup_path = "#{file_path}.backup.#{Time.now.to_i}"
  File.write(backup_path, content)
  puts "Backup created: #{backup_path}"
  
  # Count original issues
  ensure_issues = content.scan(/\s+ensure\s*$/).length
  puts "Found #{ensure_issues} standalone 'ensure' statements"
  
  # Remove all standalone 'ensure' statements that are not part of proper begin/rescue/ensure blocks
  # Pattern: line ending with code followed by spaces and 'ensure'
  fixed_content = content.gsub(/^(.+?)\s+ensure\s*$/, '\1')
  
  # Also remove ensure statements that appear at the end of blocks incorrectly
  fixed_content = fixed_content.gsub(/\s+ensure\s*\n\s*@workflow_depth -= 1 if @workflow_depth > 0\s*\n\s*end/, "\n    end")
  
  # Remove duplicate ensure statements
  fixed_content = fixed_content.gsub(/\s+ensure\s*\n\s*end/, "\n    end")
  
  # Count fixed issues
  remaining_issues = fixed_content.scan(/\s+ensure\s*$/).length
  puts "Fixed #{ensure_issues - remaining_issues} syntax errors"
  puts "Remaining issues: #{remaining_issues}"
  
  # Write fixed content
  File.write(file_path, fixed_content)
  puts "Fixed file written to #{file_path}"
  
  # Validate syntax
  puts "\nValidating syntax..."
  system("ruby -c #{file_path}")
  
  return $?.success?
end

if __FILE__ == $0
  puts "=== CrossParadigmCoordinator Syntax Fix ==="
  success = fix_syntax_errors
  
  if success
    puts "✅ Syntax errors fixed successfully!"
  else
    puts "❌ Syntax errors remain - manual review needed"
  end
end