#!/usr/bin/env ruby
# Root Folder Cleanup Script for PatLang Project
# This script organizes files from the root directory into appropriate subdirectories

require 'fileutils'

class RootFolderCleanup
  def initialize
    @root_dir = '.'
    @moved_files = {}
    @removed_files = []
    @created_dirs = []
    @errors = []
  end

  def run
    puts "=== PatLang Root Folder Cleanup ==="
    puts "Analyzing current root directory structure..."
    
    analyze_current_state
    create_directory_structure
    move_files_by_category
    remove_obsolete_files
    update_file_references
    generate_report
    
    puts "\n=== Cleanup Complete ==="
  end

  private

  def analyze_current_state
    puts "\n1. Current Root Directory Analysis:"
    root_files = Dir.glob("*").select { |f| File.file?(f) }
    puts "   - Total files in root: #{root_files.count}"
    
    # Categorize files
    @coverage_files = root_files.select { |f| f.match?(/coverage|analyze|analysis/) }
    @debug_files = root_files.select { |f| f.match?(/debug|diagnostic/) }
    @report_files = root_files.select { |f| f.match?(/(report|summary|plan|roadmap)\.md$/i) }
    @test_files = root_files.select { |f| f.match?(/test.*\.rb$/) }
    @json_files = root_files.select { |f| f.match?(/\.(json|txt)$/) }
    @temp_files = root_files.select { |f| f.match?(/temp|current-|phase_.*\.json$/) }
    
    puts "   - Coverage/Analysis files: #{@coverage_files.count}"
    puts "   - Debug/Diagnostic files: #{@debug_files.count}"
    puts "   - Report/Documentation files: #{@report_files.count}"
    puts "   - Test files: #{@test_files.count}"
    puts "   - JSON/Data files: #{@json_files.count}"
    puts "   - Temporary files: #{@temp_files.count}"
  end

  def create_directory_structure
    puts "\n2. Creating Directory Structure:"
    
    directories = [
      'test/analysis',
      'test/debug',
      'docs/reports',
      'docs/development',
      'archive/temp_files',
      'archive/output_files'
    ]
    
    directories.each do |dir|
      unless Dir.exist?(dir)
        FileUtils.mkdir_p(dir)
        @created_dirs << dir
        puts "   - Created: #{dir}"
      end
    end
  end

  def move_files_by_category
    puts "\n3. Moving Files to Appropriate Directories:"
    
    # Move coverage and analysis files
    move_file_group(@coverage_files, 'test/analysis', 'Coverage/Analysis')
    
    # Move debug files
    move_file_group(@debug_files, 'test/debug', 'Debug/Diagnostic')
    
    # Move report files to docs
    report_files_to_move = @report_files.reject { |f| ['README.md', 'getting-started.md'].include?(f) }
    move_file_group(report_files_to_move, 'docs/reports', 'Reports')
    
    # Move test files to test directory
    move_file_group(@test_files, 'test/analysis', 'Test Scripts')
    
    # Move temporary files to archive
    move_file_group(@temp_files, 'archive/temp_files', 'Temporary Files')
    
    # Move remaining JSON files to archive/output_files
    json_files_to_move = @json_files.reject { |f| f == 'comprehensive-test-report.json' }
    move_file_group(json_files_to_move, 'archive/output_files', 'Output Files')
  end

  def move_file_group(files, destination, category)
    return if files.empty?
    
    puts "   - Moving #{category} files to #{destination}:"
    files.each do |file|
      if File.exist?(file)
        begin
          FileUtils.mv(file, File.join(destination, File.basename(file)))
          @moved_files[file] = File.join(destination, File.basename(file))
          puts "     ✓ #{file} → #{destination}/"
        rescue => e
          @errors << "Error moving #{file}: #{e.message}"
          puts "     ✗ Failed to move #{file}: #{e.message}"
        end
      end
    end
  end

  def remove_obsolete_files
    puts "\n4. Removing Obsolete Files:"
    
    # Look for obviously temporary or duplicate files
    obsolete_patterns = [
      'ideas',  # Single file without extension
      '*.tmp',
      '*.bak'
    ]
    
    obsolete_patterns.each do |pattern|
      Dir.glob(pattern).each do |file|
        if File.file?(file)
          begin
            File.delete(file)
            @removed_files << file
            puts "   - Removed: #{file}"
          rescue => e
            @errors << "Error removing #{file}: #{e.message}"
            puts "   ✗ Failed to remove #{file}: #{e.message}"
          end
        end
      end
    end
  end

  def update_file_references
    puts "\n5. Checking for File References:"
    
    # Check key files that might reference moved files
    key_files = ['Rakefile', 'bin/test', 'bin/coverage']
    
    key_files.each do |file|
      if File.exist?(file)
        content = File.read(file)
        @moved_files.each do |old_path, new_path|
          if content.include?(old_path)
            puts "   - Warning: #{file} may reference moved file: #{old_path}"
            puts "     Consider updating reference to: #{new_path}"
          end
        end
      end
    end
  end

  def generate_report
    puts "\n6. Cleanup Summary:"
    puts "   - Directories created: #{@created_dirs.count}"
    puts "   - Files moved: #{@moved_files.count}"
    puts "   - Files removed: #{@removed_files.count}"
    puts "   - Errors: #{@errors.count}"
    
    if @errors.any?
      puts "\n   Errors encountered:"
      @errors.each { |error| puts "     - #{error}" }
    end
    
    # Generate detailed report file
    report_content = generate_detailed_report
    File.write('CLEANUP_REPORT.md', report_content)
    puts "\n   Detailed report saved to: CLEANUP_REPORT.md"
  end

  def generate_detailed_report
    <<~REPORT
      # PatLang Root Folder Cleanup Report
      
      Generated: #{Time.now}
      
      ## Summary
      
      - **Directories Created**: #{@created_dirs.count}
      - **Files Moved**: #{@moved_files.count}
      - **Files Removed**: #{@removed_files.count}
      - **Errors**: #{@errors.count}
      
      ## Directory Structure Created
      
      #{@created_dirs.map { |dir| "- `#{dir}`" }.join("\n")}
      
      ## Files Moved
      
      #{@moved_files.map { |old, new| "- `#{old}` → `#{new}`" }.join("\n")}
      
      ## Files Removed
      
      #{@removed_files.map { |file| "- `#{file}`" }.join("\n")}
      
      ## Errors
      
      #{@errors.any? ? @errors.map { |error| "- #{error}" }.join("\n") : "None"}
      
      ## Final Root Directory Structure
      
      After cleanup, the root directory should only contain:
      - Core project files (README.md, Rakefile, Gemfile, etc.)
      - Essential documentation (getting-started.md)
      - Main source directories (src/, test/, docs/, etc.)
      
      ## Recommendations
      
      1. Review moved files in their new locations
      2. Update any scripts that reference moved files
      3. Consider creating symbolic links if backward compatibility is needed
      4. Archive or remove files in `archive/temp_files` after verification
      
    REPORT
  end
end

# Run the cleanup
if __FILE__ == $0
  cleanup = RootFolderCleanup.new
  cleanup.run
end