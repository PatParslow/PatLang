#!/usr/bin/env ruby
# frozen_string_literal: true

# PaTLang Build Tool - Main Entry Point
# Goal-oriented build system leveraging PaTLang's reasoning capabilities

require_relative 'core/build_runner'
require_relative 'dsl/build_dsl'
require 'optparse'

class PaTLangBuildCLI
  def initialize
    @options = {
      build_file: 'build.patlang',
      targets: [],
      verbose: false,
      parallel: true,
      clean: false,
      list: false,
      graph: false
    }
  end

  def run(args = ARGV)
    parse_options(args)
    
    if @options[:help]
      show_help
      return 0
    end
    
    if @options[:version]
      show_version
      return 0
    end
    
    # Execute appropriate command
    begin
      case
      when @options[:demo]
        run_demo
      when @options[:clean]
        run_clean
      when @options[:list]
        run_list
      when @options[:graph]
        run_graph
      else
        run_build
      end
      
      0 # Success
    rescue => e
      puts "❌ Error: #{e.message}"
      puts e.backtrace.first(3).join("\n") if @options[:verbose]
      1 # Error
    end
  end

  private

  def parse_options(args)
    OptionParser.new do |opts|
      opts.banner = "Usage: patlang-build [options] [targets...]"
      opts.separator ""
      opts.separator "PaTLang Goal-Oriented Build System"
      opts.separator ""
      
      opts.on("-f", "--file FILE", "Build file (default: build.patlang)") do |file|
        @options[:build_file] = file
      end
      
      opts.on("-v", "--verbose", "Verbose output") do
        @options[:verbose] = true
      end
      
      opts.on("-j", "--parallel", "Enable parallel execution (default)") do
        @options[:parallel] = true
      end
      
      opts.on("--no-parallel", "Disable parallel execution") do
        @options[:parallel] = false
      end
      
      opts.on("-c", "--clean", "Clean build artifacts") do
        @options[:clean] = true
      end
      
      opts.on("-l", "--list", "List available targets") do
        @options[:list] = true
      end
      
      opts.on("-g", "--graph", "Show dependency graph") do
        @options[:graph] = true
      end
      
      opts.on("--demo", "Run build tool demonstration") do
        @options[:demo] = true
      end
      
      opts.on("--version", "Show version information") do
        @options[:version] = true
      end
      
      opts.on_tail("-h", "--help", "Show this help message") do
        @options[:help] = true
      end
    end.parse!(args)
    
    @options[:targets] = args unless args.empty?
  end

  def show_help
    puts <<~HELP
      PaTLang Build Tool - Goal-Oriented Build System
      
      DESCRIPTION:
        A sophisticated build system that leverages PaTLang's goal-oriented 
        programming and reasoning capabilities for intelligent dependency 
        resolution, parallel execution, and adaptive build strategies.
      
      FEATURES:
        • Goal-oriented target definition and execution
        • Advanced dependency resolution using reasoning system
        • Intelligent parallel execution with automatic optimization  
        • Incremental builds with smart change detection
        • Rich DSL with Ruby integration
        • Real-time build adaptation and strategy selection
      
      EXAMPLES:
        patlang-build                    # Build default targets
        patlang-build compile test       # Build specific targets
        patlang-build -f my.build -v     # Use custom build file with verbose output
        patlang-build --clean            # Clean build artifacts
        patlang-build --list             # List available targets
        patlang-build --graph            # Show dependency graph
        patlang-build --demo             # Run demonstration
      
      BUILD FILE FORMAT:
        Build files use PaTLang's goal-oriented DSL:
        
        # Variables
        var :src_dir, "src"
        var :build_dir, "build"
        
        # Default targets
        default :build, :test
        
        # Target definition
        compile :compile_sources do
          description "Compile all source files"
          inputs glob("\#{var(:src_dir)}/**/*.rb")
          outputs ["\#{var(:build_dir)}/app.rb"]
          depends_on :clean
          parallel_safe true
          
          action do |target, context|
            # Build logic here
          end
        end
    HELP
  end

  def show_version
    puts "PaTLang Build Tool v1.0.0"
    puts "Goal-Oriented Build System"
    puts "Built with PaTLang reasoning capabilities"
  end

  def run_demo
    puts "🚀 Running PaTLang Build Tool demonstration..."
    require_relative 'demo/build_tool_demo'
    demo = BuildToolDemo.new
    demo.run_complete_demo
  end

  def run_clean
    if File.exist?(@options[:build_file])
      result = BuildDSL::DSLLoader.load_build_file(@options[:build_file])
      runner = result[:runner]
      
      clean_result = runner.clean(@options[:targets].empty? ? nil : @options[:targets])
      
      puts "🧹 Cleaned #{clean_result[:count]} files"
      clean_result[:cleaned_files].each { |file| puts "   Removed: #{file}" } if @options[:verbose]
    else
      puts "⚠️  Build file not found: #{@options[:build_file]}"
    end
  end

  def run_list
    if File.exist?(@options[:build_file])
      result = BuildDSL::DSLLoader.load_build_file(@options[:build_file])
      runner = result[:runner]
      
      targets = runner.list_targets
      
      puts "📋 Available targets:"
      targets.each do |target|
        status = target[:up_to_date] ? "✅" : "🔨"
        puts "   #{status} #{target[:name]} (#{target[:type]})"
        puts "      #{target[:inputs].length} inputs → #{target[:outputs].length} outputs" if @options[:verbose]
        puts "      Dependencies: #{target[:dependencies].join(', ')}" if @options[:verbose] && target[:dependencies].any?
      end
    else
      puts "⚠️  Build file not found: #{@options[:build_file]}"
    end
  end

  def run_graph
    if File.exist?(@options[:build_file])
      result = BuildDSL::DSLLoader.load_build_file(@options[:build_file])
      runner = result[:runner]
      
      graph = runner.dependency_graph
      
      puts "📊 Dependency Graph:"
      graph.each do |target, deps|
        if deps.empty?
          puts "   #{target} (no dependencies)"
        else
          puts "   #{target}"
          deps.each { |dep| puts "      └── #{dep}" }
        end
      end
    else
      puts "⚠️  Build file not found: #{@options[:build_file]}"
    end
  end

  def run_build
    unless File.exist?(@options[:build_file])
      puts "⚠️  Build file not found: #{@options[:build_file]}"
      puts "💡 Create a build file or use --demo to see examples"
      return
    end
    
    puts "🚀 PaTLang Build System"
    puts "📁 Build file: #{@options[:build_file]}"
    puts "🎯 Targets: #{@options[:targets].empty? ? 'default' : @options[:targets].join(', ')}"
    puts "⚡ Parallel: #{@options[:parallel] ? 'enabled' : 'disabled'}"
    puts

    build_options = {
      verbose: @options[:verbose],
      parallel_execution: @options[:parallel],
      continue_on_error: false
    }

    result = BuildDSL::DSLLoader.execute_build_file(
      @options[:build_file], 
      @options[:targets].empty? ? nil : @options[:targets]
    )

    puts
    case result[:status]
    when :success
      puts "✅ Build completed successfully!"
    when :partial_failure
      puts "⚠️  Build completed with some failures"
    else
      puts "❌ Build failed"
    end

    puts "📊 Build Summary:"
    puts "   • Targets built: #{result[:targets_built].length}"
    puts "   • Build time: #{result[:build_time].round(3)}s"
    
    if result[:summary]
      puts "   • Successful: #{result[:summary][:successful_targets]}"
      puts "   • Failed: #{result[:summary][:failed_targets]}" if result[:summary][:failed_targets] > 0
      puts "   • Parallel execution: #{result[:summary][:parallel_groups_used] ? 'utilized' : 'not used'}"
    end

    if @options[:verbose] && result[:results]
      puts "\n📋 Detailed Results:"
      result[:results].each do |target, target_result|
        status_icon = case target_result[:status]
                     when :success then "✅"
                     when :up_to_date then "📋"
                     when :failure then "❌"
                     else "❓"
                     end
        puts "   #{status_icon} #{target}: #{target_result[:status]}"
      end
    end
  end
end

# Main execution
if __FILE__ == $0
  cli = PaTLangBuildCLI.new
  exit(cli.run)
end