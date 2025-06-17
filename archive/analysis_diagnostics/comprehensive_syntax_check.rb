#!/usr/bin/env ruby

# Comprehensive syntax check for all Ruby files
require 'fileutils'

def check_syntax(file_path)
  result = `ruby -c "#{file_path}" 2>&1`
  exit_code = $?.exitstatus
  
  if exit_code == 0
    puts "✅ #{file_path}: Syntax OK"
    return true
  else
    puts "❌ #{file_path}: SYNTAX ERROR"
    puts "   #{result}"
    return false
  end
end

def find_ruby_files(directory)
  Dir.glob(File.join(directory, '**', '*.rb'))
end

puts "🔍 COMPREHENSIVE SYNTAX CHECK"
puts "=" * 50

# Check all Ruby files in src/
src_files = find_ruby_files('src')
test_files = find_ruby_files('test')
root_files = Dir.glob('*.rb')

all_files = src_files + test_files + root_files
syntax_errors = []

puts "\n📁 Checking #{all_files.length} Ruby files..."
puts

all_files.each do |file|
  unless check_syntax(file)
    syntax_errors << file
  end
end

puts "\n" + "=" * 50
puts "📊 SYNTAX CHECK SUMMARY"
puts "=" * 50

if syntax_errors.empty?
  puts "✅ All #{all_files.length} Ruby files have valid syntax!"
else
  puts "❌ Found syntax errors in #{syntax_errors.length} files:"
  syntax_errors.each { |file| puts "   - #{file}" }
end

puts "\n🔧 REQUIRE STATEMENT VALIDATION"
puts "=" * 30

# Check for common require issues
require_issues = []

all_files.each do |file|
  begin
    content = File.read(file)
    
    # Look for require statements
    content.scan(/require\s+['"]([^'"]+)['"]/) do |match|
      required_file = match[0]
      
      # Skip standard library requires
      next if required_file.match?(/^(minitest|test\/unit|fileutils|json|etc)/)
      
      # Check if it's a relative require
      if required_file.start_with?('./')
        full_path = File.expand_path(required_file + '.rb', File.dirname(file))
        unless File.exist?(full_path)
          require_issues << "#{file}: Missing required file #{required_file}"
        end
      end
    end
  rescue => e
    require_issues << "#{file}: Error reading file - #{e.message}"
  end
end

if require_issues.empty?
  puts "✅ No obvious require statement issues found"
else
  puts "⚠️  Found potential require issues:"
  require_issues.each { |issue| puts "   - #{issue}" }
end

puts "\n🎯 FINAL STATUS"
puts "=" * 20

if syntax_errors.empty? && require_issues.empty?
  puts "✅ CLEAN: All files ready for testing"
  exit 0
else
  puts "❌ ISSUES FOUND: #{syntax_errors.length} syntax errors, #{require_issues.length} require issues"
  exit 1
end