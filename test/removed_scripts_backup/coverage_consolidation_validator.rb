#!/usr/bin/env ruby

require 'fileutils'
require 'json'

class CoverageConsolidationValidator
  def self.run
    puts "🧪 COVERAGE CONSOLIDATION VALIDATION"
    puts "=" * 60
    
    validator = new
    validator.validate_consolidation
  end
  
  def initialize
    @root_coverage_dir = 'coverage'
    @test_coverage_dir = 'test/coverage'
    @validation_results = {}
  end
  
  def validate_consolidation
    puts "📋 Phase 1: Recording initial state..."
    initial_state = record_coverage_state
    
    puts "🏃 Phase 2: Running test to generate coverage..."
    test_success = run_coverage_test
    
    puts "📊 Phase 3: Analyzing coverage generation..."
    final_state = record_coverage_state
    
    puts "🔍 Phase 4: Comparing states..."
    analyze_changes(initial_state, final_state)
    
    puts "📋 Phase 5: Validation report..."
    generate_report(test_success)
    
    @validation_results[:success]
  end
  
  private
  
  def record_coverage_state
    state = {}
    
    # Record root coverage directory state
    if Dir.exist?(@root_coverage_dir)
      state[:root_coverage] = {
        exists: true,
        files: Dir.glob("#{@root_coverage_dir}/**/*").select { |f| File.file?(f) },
        last_modified: Dir.glob("#{@root_coverage_dir}/**/*").select { |f| File.file?(f) }.map { |f| File.mtime(f) }.max
      }
    else
      state[:root_coverage] = { exists: false }
    end
    
    # Record test coverage directory state
    if Dir.exist?(@test_coverage_dir)
      state[:test_coverage] = {
        exists: true,
        files: Dir.glob("#{@test_coverage_dir}/**/*").select { |f| File.file?(f) },
        last_modified: Dir.glob("#{@test_coverage_dir}/**/*").select { |f| File.file?(f) }.map { |f| File.mtime(f) }.max
      }
    else
      state[:test_coverage] = { exists: false }
    end
    
    state[:timestamp] = Time.now
    state
  end
  
  def run_coverage_test
    puts "   🧪 Running coverage generation test..."
    
    # Run the coverage generation test
    result = system("ruby test/coverage_generation_test.rb")
    
    if result
      puts "   ✅ Coverage generation completed successfully"
    else
      puts "   ⚠️  Coverage generation completed with warnings (exit code: #{$?.exitstatus})"
    end
    
    result
  end
  
  def analyze_changes(initial, final)
    changes = {}
    
    # Analyze root coverage changes
    if initial[:root_coverage][:exists] && final[:root_coverage][:exists]
      root_new_files = final[:root_coverage][:files] - initial[:root_coverage][:files]
      root_modified = final[:root_coverage][:last_modified] > initial[:timestamp] if final[:root_coverage][:last_modified]
      
      changes[:root_coverage] = {
        new_files: root_new_files,
        files_added: root_new_files.any?,
        modified_since_test: root_modified || false,
        total_files: final[:root_coverage][:files].length
      }
    end
    
    # Analyze test coverage changes
    if initial[:test_coverage][:exists] && final[:test_coverage][:exists]
      test_new_files = final[:test_coverage][:files] - initial[:test_coverage][:files]
      test_modified = final[:test_coverage][:last_modified] > initial[:timestamp] if final[:test_coverage][:last_modified]
      
      changes[:test_coverage] = {
        new_files: test_new_files,
        files_added: test_new_files.any?,
        modified_since_test: test_modified || false,
        total_files: final[:test_coverage][:files].length
      }
    end
    
    @validation_results[:changes] = changes
    
    # Report findings
    puts "   📁 Root coverage directory (#{@root_coverage_dir}):"
    if changes[:root_coverage]
      puts "      - Total files: #{changes[:root_coverage][:total_files]}"
      puts "      - New files added: #{changes[:root_coverage][:files_added] ? 'YES' : 'NO'}"
      puts "      - Modified during test: #{changes[:root_coverage][:modified_since_test] ? 'YES' : 'NO'}"
      if changes[:root_coverage][:files_added]
        puts "      - New files: #{changes[:root_coverage][:new_files].join(', ')}"
      end
    end
    
    puts "   📂 Test coverage directory (#{@test_coverage_dir}):"
    if changes[:test_coverage]
      puts "      - Total files: #{changes[:test_coverage][:total_files]}"
      puts "      - New files added: #{changes[:test_coverage][:files_added] ? 'YES' : 'NO'}"
      puts "      - Modified during test: #{changes[:test_coverage][:modified_since_test] ? 'YES' : 'NO'}"
      if changes[:test_coverage][:files_added]
        puts "      - New files: #{changes[:test_coverage][:new_files].join(', ')}"
      end
    end
  end
  
  def generate_report(test_success)
    changes = @validation_results[:changes]
    
    # Determine if consolidation is working
    consolidation_working = false
    if changes[:test_coverage] && changes[:root_coverage]
      # Success criteria: test coverage gets new files, root coverage doesn't
      consolidation_working = changes[:test_coverage][:modified_since_test] && 
                             !changes[:root_coverage][:modified_since_test]
    end
    
    @validation_results[:success] = consolidation_working
    @validation_results[:test_success] = test_success
    
    puts "\n" + "=" * 60
    puts "📊 VALIDATION RESULTS"
    puts "=" * 60
    
    if consolidation_working
      puts "✅ COVERAGE CONSOLIDATION IS WORKING!"
      puts "   • New coverage files generated in: #{@test_coverage_dir}"
      puts "   • No new files in old location: #{@root_coverage_dir}"
      puts "   • Configuration successfully consolidated"
      
      if File.exist?(@root_coverage_dir)
        puts "\n📋 CLEANUP RECOMMENDATION:"
        puts "   • Old coverage directory can be safely archived"
        puts "   • Suggested action: mv #{@root_coverage_dir} #{@root_coverage_dir}.old"
      end
    else
      puts "❌ COVERAGE CONSOLIDATION NEEDS ATTENTION"
      if changes[:root_coverage] && changes[:root_coverage][:modified_since_test]
        puts "   • WARNING: New coverage files still being generated in old location"
        puts "   • Root coverage directory: #{@root_coverage_dir}"
      end
      if changes[:test_coverage] && !changes[:test_coverage][:modified_since_test]
        puts "   • WARNING: No new coverage files in consolidated location"
        puts "   • Test coverage directory: #{@test_coverage_dir}"
      end
    end
    
    puts "\n📈 Test execution: #{test_success ? 'PASSED' : 'FAILED'}"
    
    # Save results to file
    File.write('test/coverage_consolidation_results.json', JSON.pretty_generate(@validation_results))
    puts "\n📄 Detailed results saved to: test/coverage_consolidation_results.json"
  end
end

# Run validation if executed directly
if __FILE__ == $0
  success = CoverageConsolidationValidator.run
  exit(success ? 0 : 1)
end