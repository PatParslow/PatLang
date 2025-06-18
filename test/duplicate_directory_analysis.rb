#!/usr/bin/env ruby

require 'find'
require 'json'

class DuplicateDirectoryAnalyzer
  def initialize
    @results = {
      duplicate_directories: [],
      empty_directories: [],
      migration_artifacts: [],
      recommendations: []
    }
  end

  def analyze
    puts "🔍 DUPLICATE TEST DIRECTORY STRUCTURE ANALYSIS"
    puts "=" * 60
    
    analyze_test_directories
    identify_empty_directories
    identify_migration_artifacts
    generate_recommendations
    
    write_report
    display_summary
  end

  private

  def analyze_test_directories
    puts "\n📁 Analyzing test directory structures..."
    
    # Check main test directories
    test_dirs = ['test/', 'tests/', 'test/test/']
    
    test_dirs.each do |dir|
      if Dir.exist?(dir)
        puts "  ✓ Found: #{dir}"
        analyze_directory_structure(dir)
      else
        puts "  ✗ Not found: #{dir}"
      end
    end
  end

  def analyze_directory_structure(base_dir)
    puts "    Contents of #{base_dir}:"
    
    Dir.entries(base_dir).reject { |f| f.start_with?('.') }.each do |entry|
      path = File.join(base_dir, entry)
      if File.directory?(path)
        file_count = count_files_recursively(path)
        puts "      📁 #{entry}/ (#{file_count} files)"
        
        if file_count == 0
          @results[:empty_directories] << path
        end
      else
        puts "      📄 #{entry}"
      end
    end
  end

  def count_files_recursively(dir)
    count = 0
    Find.find(dir) do |path|
      count += 1 if File.file?(path)
    end
    count
  end

  def identify_empty_directories
    puts "\n🗂️ Identifying empty directories..."
    
    @results[:empty_directories].each do |dir|
      puts "  📭 Empty: #{dir}"
    end
  end

  def identify_migration_artifacts
    puts "\n🔄 Identifying potential migration artifacts..."
    
    # Look for duplicate directory structures
    if Dir.exist?('test/test/patlang-core') && Dir.exist?('tests/patlang-core')
      @results[:migration_artifacts] << {
        type: 'duplicate_patlang_core',
        paths: ['test/test/patlang-core', 'tests/patlang-core'],
        description: 'Duplicate patlang-core test directory structures'
      }
    end
    
    # Check for nested test/test structure
    if Dir.exist?('test/test/')
      @results[:migration_artifacts] << {
        type: 'nested_test_directory',
        paths: ['test/test/'],
        description: 'Nested test/test/ directory structure'
      }
    end
    
    @results[:migration_artifacts].each do |artifact|
      puts "  🔄 #{artifact[:description]}: #{artifact[:paths].join(', ')}"
    end
  end

  def generate_recommendations
    puts "\n💡 Generating cleanup recommendations..."
    
    # Recommendation 1: Remove empty directories
    unless @results[:empty_directories].empty?
      @results[:recommendations] << {
        action: 'remove_empty_directories',
        directories: @results[:empty_directories],
        description: 'Remove empty test directories that serve no purpose'
      }
    end
    
    # Recommendation 2: Consolidate duplicate structures
    @results[:migration_artifacts].each do |artifact|
      case artifact[:type]
      when 'duplicate_patlang_core'
        @results[:recommendations] << {
          action: 'consolidate_patlang_core',
          paths: artifact[:paths],
          description: 'Remove duplicate patlang-core directories, keep functional structure'
        }
      when 'nested_test_directory'
        @results[:recommendations] << {
          action: 'remove_nested_test',
          paths: artifact[:paths],
          description: 'Remove confusing nested test/test/ directory'
        }
      end
    end
    
    @results[:recommendations].each_with_index do |rec, idx|
      puts "  #{idx + 1}. #{rec[:description]}"
    end
  end

  def write_report
    File.write('test/duplicate_directory_analysis_report.json', JSON.pretty_generate(@results))
    puts "\n📋 Full report written to: test/duplicate_directory_analysis_report.json"
  end

  def display_summary
    puts "\n" + "=" * 60
    puts "📊 SUMMARY"
    puts "=" * 60
    puts "Empty directories found: #{@results[:empty_directories].length}"
    puts "Migration artifacts found: #{@results[:migration_artifacts].length}"
    puts "Cleanup recommendations: #{@results[:recommendations].length}"
    
    puts "\n🎯 NEXT STEPS:"
    puts "1. Review the generated recommendations"
    puts "2. Remove empty directories safely"
    puts "3. Consolidate duplicate structures"
    puts "4. Update any scripts referencing old paths"
  end
end

# Run the analysis
analyzer = DuplicateDirectoryAnalyzer.new
analyzer.analyze