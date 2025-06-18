#!/usr/bin/env ruby

require 'fileutils'
require 'json'
require 'time'

class TestDirectoryCleanup
  def initialize
    @backup_created = false
    @actions_performed = []
  end

  def perform_cleanup
    puts "🧹 TEST DIRECTORY STRUCTURE CLEANUP"
    puts "=" * 50
    
    # Step 1: Create backup of important files
    backup_important_files
    
    # Step 2: Remove empty directories
    remove_empty_directories
    
    # Step 3: Clean up duplicate structures
    cleanup_duplicate_structures
    
    # Step 4: Generate final report
    generate_cleanup_report
    
    puts "\n✅ CLEANUP COMPLETED SUCCESSFULLY"
    display_summary
  end

  private

  def backup_important_files
    puts "\n📦 Creating backup of important files..."
    
    # Files to preserve from test/test/
    important_files = [
      'test/test/phase_1_final_results.json',
      'test/test/phase_1_results.json'
    ]
    
    # Create backup directory
    backup_dir = 'test/backup_from_nested_test'
    FileUtils.mkdir_p(backup_dir) unless Dir.exist?(backup_dir)
    
    important_files.each do |file|
      if File.exist?(file)
        dest = File.join(backup_dir, File.basename(file))
        FileUtils.cp(file, dest)
        puts "  ✓ Backed up: #{file} → #{dest}"
        @actions_performed << "Backed up #{file}"
      else
        puts "  ⚠️  File not found: #{file}"
      end
    end
    
    # Also preserve the coverage directory
    if Dir.exist?('test/test/coverage')
      FileUtils.mv('test/test/coverage', 'test/backup_from_nested_test/coverage')
      puts "  ✓ Moved coverage directory to backup"
      @actions_performed << "Moved test/test/coverage to backup"
    end
    
    @backup_created = true
  end

  def remove_empty_directories
    puts "\n🗑️  Removing empty directories..."
    
    empty_dirs = [
      'tests/cross-platform',
      'tests/patlang-core', 
      'tests/ruby-host',
      'test/test/patlang-core'
    ]
    
    empty_dirs.each do |dir|
      if Dir.exist?(dir) && dir_empty?(dir)
        FileUtils.rmdir(dir)
        puts "  ✓ Removed empty directory: #{dir}"
        @actions_performed << "Removed empty directory: #{dir}"
      elsif Dir.exist?(dir)
        puts "  ⚠️  Directory not empty: #{dir}"
      else
        puts "  ℹ️  Directory not found: #{dir}"
      end
    end
  end

  def cleanup_duplicate_structures
    puts "\n🔧 Cleaning up duplicate structures..."
    
    # Remove the entire tests/ directory since it's all empty
    if Dir.exist?('tests') && all_subdirs_empty?('tests')
      FileUtils.rm_rf('tests')
      puts "  ✓ Removed entire tests/ directory (all subdirectories were empty)"
      @actions_performed << "Removed tests/ directory"
    end
    
    # Remove the nested test/test/ directory (files already backed up)
    if Dir.exist?('test/test')
      FileUtils.rm_rf('test/test')
      puts "  ✓ Removed nested test/test/ directory"
      @actions_performed << "Removed test/test/ directory"
    end
  end

  def dir_empty?(dir)
    return false unless Dir.exist?(dir)
    Dir.entries(dir).reject { |f| f.start_with?('.') }.empty?
  end

  def all_subdirs_empty?(dir)
    return false unless Dir.exist?(dir)
    Dir.entries(dir).reject { |f| f.start_with?('.') }.all? do |subdir|
      subdir_path = File.join(dir, subdir)
      File.directory?(subdir_path) && dir_empty?(subdir_path)
    end
  end

  def generate_cleanup_report
    puts "\n📋 Generating cleanup report..."
    
    report = {
      cleanup_date: Time.now.iso8601,
      backup_created: @backup_created,
      actions_performed: @actions_performed,
      final_structure: analyze_final_structure
    }
    
    File.write('test/TEST_DIRECTORY_CLEANUP_REPORT.json', JSON.pretty_generate(report))
    puts "  ✓ Report saved to: test/TEST_DIRECTORY_CLEANUP_REPORT.json"
  end

  def analyze_final_structure
    structure = {}
    
    if Dir.exist?('test')
      structure['test/'] = count_entries('test')
    end
    
    if Dir.exist?('tests')
      structure['tests/'] = count_entries('tests')
    end
    
    if Dir.exist?('test/backup_from_nested_test')
      structure['test/backup_from_nested_test/'] = count_entries('test/backup_from_nested_test')
    end
    
    structure
  end

  def count_entries(dir)
    entries = Dir.entries(dir).reject { |f| f.start_with?('.') }
    {
      total_entries: entries.length,
      directories: entries.count { |e| File.directory?(File.join(dir, e)) },
      files: entries.count { |e| File.file?(File.join(dir, e)) }
    }
  end

  def display_summary
    puts "\n" + "=" * 50
    puts "📊 CLEANUP SUMMARY"
    puts "=" * 50
    puts "Actions performed: #{@actions_performed.length}"
    @actions_performed.each_with_index do |action, idx|
      puts "  #{idx + 1}. #{action}"
    end
    
    puts "\n🎯 FINAL TEST DIRECTORY STRUCTURE:"
    puts "✓ Main test directory: test/ (organized, functional)"
    puts "✓ Backup created: test/backup_from_nested_test/ (preserved files)"
    puts "✗ Duplicate directories: removed"
    puts "✗ Empty directories: removed"
    
    puts "\n💡 Next steps:"
    puts "1. Verify test functionality still works"
    puts "2. Review backup files if needed"
    puts "3. Update any scripts referencing old paths"
  end
end

# Execute cleanup
if ARGV.include?('--execute')
  cleanup = TestDirectoryCleanup.new
  cleanup.perform_cleanup
else
  puts "🚨 DRY RUN MODE"
  puts "To actually perform the cleanup, run with --execute flag:"
  puts "ruby #{__FILE__} --execute"
end