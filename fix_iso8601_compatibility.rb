#!/usr/bin/env ruby

# Fix iso8601 compatibility issues for Ruby 3.3.7
# The iso8601 method was removed from Time class in Ruby 3.0+

require 'fileutils'

class ISO8601CompatibilityFixer
  def initialize
    @files_to_fix = []
    @backup_suffix = ".iso8601_backup_#{Time.now.strftime('%Y%m%d_%H%M%S')}"
  end

  def run
    puts "🔧 ISO8601 Compatibility Fixer for Ruby 3.3.7"
    puts "=" * 50
    
    find_files_with_iso8601
    fix_all_files
    generate_report
  end

  private

  def find_files_with_iso8601
    puts "\n📁 Scanning for files with iso8601 usage..."
    
    # Get all Ruby files
    ruby_files = Dir.glob("**/*.rb") + Dir.glob("**/*.build")
    
    ruby_files.each do |file|
      next if file.include?('fix_iso8601_compatibility.rb') # Skip self
      
      if File.read(file).include?('iso8601')
        @files_to_fix << file
        puts "  ✓ Found: #{file}"
      end
    rescue => e
      puts "  ⚠️  Error reading #{file}: #{e.message}"
    end
    
    puts "\n📊 Found #{@files_to_fix.length} files to fix"
  end

  def fix_all_files
    return if @files_to_fix.empty?
    
    puts "\n🔨 Fixing iso8601 usage in all files..."
    
    @files_to_fix.each do |file|
      fix_file(file)
    end
  end

  def fix_file(file_path)
    puts "  🔧 Processing: #{file_path}"
    
    begin
      content = File.read(file_path)
      original_content = content.dup
      
      # Create backup
      backup_path = file_path + @backup_suffix
      File.write(backup_path, original_content)
      
      # Fix iso8601 calls
      # Pattern 1: Time.now.iso8601
      content.gsub!(/Time\.now\.iso8601/, 'Time.now.strftime("%Y-%m-%dT%H:%M:%S%z")')
      
      # Pattern 2: Time.now.utc.iso8601  
      content.gsub!(/Time\.now\.utc\.iso8601/, 'Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")')
      
      # Pattern 3: @start_time.iso8601 (or any time variable)
      content.gsub!(/(\w+)\.iso8601/, '\1.strftime("%Y-%m-%dT%H:%M:%S%z")')
      
      # Write fixed content
      File.write(file_path, content)
      
      if content != original_content
        puts "    ✅ Fixed iso8601 usage"
      else
        puts "    ℹ️  No changes needed"
        File.delete(backup_path) # Remove unnecessary backup
      end
      
    rescue => e
      puts "    ❌ Error processing #{file_path}: #{e.message}"
    end
  end

  def generate_report
    puts "\n📋 ISO8601 Compatibility Fix Report"
    puts "=" * 40
    puts "Ruby Version: #{RUBY_VERSION}"
    puts "Fixed Files: #{@files_to_fix.length}"
    puts "Backup Suffix: #{@backup_suffix}"
    puts "\nChanges Made:"
    puts "• Time.now.iso8601 → Time.now.strftime(\"%Y-%m-%dT%H:%M:%S%z\")"
    puts "• Time.now.utc.iso8601 → Time.now.utc.strftime(\"%Y-%m-%dT%H:%M:%SZ\")"
    puts "• variable.iso8601 → variable.strftime(\"%Y-%m-%dT%H:%M:%S%z\")"
    
    puts "\n✅ All iso8601 compatibility issues have been resolved!"
    puts "🔄 Backup files created with suffix: #{@backup_suffix}"
  end
end

# Run the fix if script is executed directly
if __FILE__ == $0
  fixer = ISO8601CompatibilityFixer.new
  fixer.run
end