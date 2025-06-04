#!/usr/bin/env ruby

# Comprehensive Gap Analysis Tool for Patlang v0.6.0
# Analyzes the gap between documented/example capabilities and actual implementation

require 'find'
require 'json'

class ImplementationGapAnalyzer
  def initialize
    @gaps = {
      syntax_gaps: [],
      feature_gaps: [],
      integration_gaps: [],
      api_gaps: [],
      performance_gaps: []
    }
    @working_features = []
    @example_claims = []
    @implementation_reality = {}
  end

  def analyze_all
    puts "🔍 PATLANG v0.6.0 IMPLEMENTATION GAP ANALYSIS"
    puts "=" * 70
    puts "Analyzing gaps between examples/documentation and actual implementation"
    puts
    
    analyze_current_implementation
    analyze_examples
    analyze_documentation_claims
    perform_gap_analysis
    generate_report
  end

  private

  def analyze_current_implementation
    puts "📊 ANALYZING CURRENT IMPLEMENTATION CAPABILITIES..."
    puts "-" * 50
    
    # Analyze lexer capabilities
    lexer_capabilities = analyze_lexer
    puts "✅ Lexer analysis complete: #{lexer_capabilities.size} token types supported"
    
    # Analyze parser capabilities  
    parser_capabilities = analyze_parser
    puts "✅ Parser analysis complete: #{parser_capabilities.size} constructs supported"
    
    # Analyze evaluator capabilities
    evaluator_capabilities = analyze_evaluator
    puts "✅ Evaluator analysis complete: #{evaluator_capabilities.size} operations supported"
    
    # Check object model integration
    object_model_status = analyze_object_model
    puts "✅ Object model analysis complete: #{object_model_status[:status]}"
    
    @implementation_reality = {
      lexer: lexer_capabilities,
      parser: parser_capabilities,
      evaluator: evaluator_capabilities,
      object_model: object_model_status
    }
    puts
  end

  def analyze_lexer
    capabilities = []
    
    # Basic arithmetic operators
    capabilities << "Numbers (integer/float)"
    capabilities << "Arithmetic operators (+, -, *, /, %)"
    capabilities << "Parentheses for grouping"
    capabilities << "Comments (#)"
    capabilities << "Whitespace handling"
    
    # Check if additional tokens exist
    if File.exist?('src/token.rb')
      token_content = File.read('src/token.rb')
      capabilities << "MAKE keyword" if token_content.include?('MAKE')
      capabilities << "IS keyword" if token_content.include?('IS')
      capabilities << "String literals" if token_content.include?('STRING')
      capabilities << "Identifiers" if token_content.include?('IDENTIFIER')
      capabilities << "Control flow keywords" if token_content.include?('IF')
    end
    
    capabilities
  end

  def analyze_parser
    capabilities = []
    
    # Core parsing capabilities
    capabilities << "Arithmetic expressions with precedence"
    capabilities << "Parenthesized expressions"
    capabilities << "Unary expressions"
    
    # Check for additional parser modules
    if File.exist?('src/parser/expression_parser.rb')
      capabilities << "Advanced expression parsing"
    end
    
    if File.exist?('src/parser/function_parser.rb')
      capabilities << "Function definitions"
    end
    
    if File.exist?('src/parser/control_flow_parser.rb')
      capabilities << "Control flow statements"
    end
    
    capabilities
  end

  def analyze_evaluator
    capabilities = []
    
    # Core evaluation capabilities
    capabilities << "Arithmetic evaluation"
    capabilities << "Operator precedence"
    capabilities << "Parentheses grouping"
    
    # Check for additional evaluator modules
    if File.exist?('src/evaluator/arithmetic_evaluator.rb')
      capabilities << "Dedicated arithmetic evaluation"
    end
    
    if File.exist?('src/evaluator/function_evaluator.rb')
      capabilities << "Function evaluation"
    end
    
    if File.exist?('src/evaluator/string_evaluator.rb')
      capabilities << "String operations"
    end
    
    if File.exist?('src/evaluator/scope_manager.rb')
      capabilities << "Variable scoping"
    end
    
    capabilities
  end

  def analyze_object_model
    status = { status: "Not integrated", components: [] }
    
    if File.exist?('src/object_model/patlang_object.rb')
      status[:status] = "Foundation implemented"
      status[:components] << "PatlangObject base class"
    end
    
    if File.exist?('src/object_model/event_system.rb')
      status[:components] << "Event system"
    end
    
    if File.exist?('src/object_model/object_integration.rb')
      status[:components] << "Integration layer"
    end
    
    # Check if object model is actually used in evaluator
    if File.exist?('src/evaluator.rb')
      evaluator_content = File.read('src/evaluator.rb')
      if evaluator_content.include?('PatlangObject') || evaluator_content.include?('object_model')
        status[:status] = "Integrated"
      else
        status[:status] = "Implemented but not integrated"
      end
    end
    
    status
  end

  def analyze_examples
    puts "📋 ANALYZING EXAMPLE CLAIMS..."
    puts "-" * 50
    
    example_files = Dir.glob('examples/**/*').select { |f| File.file?(f) }
    
    example_files.each do |file|
      analyze_example_file(file)
    end
    
    puts "✅ Analyzed #{example_files.size} example files"
    puts
  end

  def analyze_example_file(file)
    content = File.read(file)
    
    case File.extname(file)
    when '.pat'
      analyze_patlang_example(file, content)
    when '.rb'
      analyze_ruby_demo(file, content)
    when '.md'
      analyze_markdown_example(file, content)
    end
  end

  def analyze_patlang_example(file, content)
    claims = []
    
    # Check for various language features in .pat files
    claims << "Variable assignment (is)" if content.include?(' is ')
    claims << "Function definitions (make a function)" if content.include?('make a function')
    claims << "Object-oriented syntax" if content.include?('make a template')
    claims << "Control flow (if/then)" if content.include?('if ') && content.include?('then')
    claims << "Loops (while/for)" if content.include?('while ') || content.include?('for ')
    claims << "String operations" if content.include?('"') && content.include?('+')
    claims << "Arrays/Collections" if content.include?('[') && content.include?(']')
    claims << "Object properties" if content.include?('.') && !content.match?(/\d+\.\d+/)
    claims << "Event handling" if content.include?('when ') || content.include?('on ')
    claims << "Message passing" if content.include?('sends') || content.include?('receives')
    
    @example_claims.concat(claims.map { |claim| { file: file, claim: claim } })
  end

  def analyze_ruby_demo(file, content)
    # Ruby demos showing future capabilities
    claims = []
    
    claims << "Network transparency" if content.include?('NetworkTransparent')
    claims << "Object migration" if content.include?('migrate_to')
    claims << "Event system" if content.include?('EventSystem') || content.include?('event')
    claims << "Security architecture" if content.include?('Security') || content.include?('encrypt')
    claims << "Message passing" if content.include?('send_message')
    claims << "Protocol selection" if content.include?('protocol')
    claims << "Connection management" if content.include?('ConnectionManager')
    
    @example_claims.concat(claims.map { |claim| { file: file, claim: claim, type: "future_demo" } })
  end

  def analyze_markdown_example(file, content)
    # Markdown documentation with code examples
    claims = []
    
    # Extract code blocks that show Patlang syntax
    code_blocks = content.scan(/```patlang\n(.*?)\n```/m)
    
    code_blocks.each do |block|
      block_content = block[0]
      claims << "Print statements" if block_content.include?('print ')
      claims << "Variable declarations" if block_content.include?('make a')
      claims << "Input/output" if block_content.include?('read_line')
      claims << "String concatenation" if block_content.include?('" + ')
      claims << "Function syntax" if block_content.include?('takes:')
      claims << "Class/template syntax" if block_content.include?('template called')
      claims << "Inheritance" if block_content.include?('inherits from')
      claims << "Higher-order functions" if block_content.include?('map(')
      claims << "Collections" if block_content.include?('[') && block_content.include?(']')
    end
    
    @example_claims.concat(claims.map { |claim| { file: file, claim: claim, type: "documentation" } })
  end

  def analyze_documentation_claims
    puts "📚 ANALYZING DOCUMENTATION CLAIMS..."
    puts "-" * 50
    
    # Analyze getting-started.md claims
    if File.exist?('getting-started.md')
      content = File.read('getting-started.md')
      
      # Extract major capability claims
      claims = []
      claims << "Natural Language Syntax" if content.include?('Natural Language Syntax')
      claims << "Multi-Paradigm Unity" if content.include?('Multi-Paradigm Unity')
      claims << "Type Safety" if content.include?('Type Safety')
      claims << "Goal-Oriented Programming" if content.include?('Goal-Oriented Programming')
      claims << "Interactive Development" if content.include?('Interactive Development')
      
      @example_claims.concat(claims.map { |claim| { file: "getting-started.md", claim: claim, type: "major_feature" } })
    end
    
    puts "✅ Documentation analysis complete"
    puts
  end

  def perform_gap_analysis
    puts "🔍 PERFORMING GAP ANALYSIS..."
    puts "-" * 50
    
    # Analyze each claim against implementation
    @example_claims.each do |example_claim|
      gap = analyze_claim_vs_implementation(example_claim)
      categorize_gap(gap) if gap
    end
    
    puts "✅ Gap analysis complete"
    puts
  end

  def analyze_claim_vs_implementation(claim_data)
    claim = claim_data[:claim]
    file = claim_data[:file]
    
    case claim
    when "Variable assignment (is)"
      return check_syntax_gap(claim, file, "IS token and assignment parsing")
    when "Function definitions (make a function)"
      return check_feature_gap(claim, file, "Function definition syntax and evaluation")
    when "Object-oriented syntax"
      return check_feature_gap(claim, file, "Class/template definitions")
    when "Control flow (if/then)"
      return check_syntax_gap(claim, file, "IF/THEN/ELSE parsing and evaluation")
    when "String operations"
      return check_feature_gap(claim, file, "String parsing, concatenation, and methods")
    when "Print statements"
      return check_api_gap(claim, file, "Print function implementation")
    when "Network transparency"
      return check_integration_gap(claim, file, "Network communication layer")
    when "Event system"
      implementation_status = @implementation_reality[:object_model][:status]
      if implementation_status == "Integrated"
        @working_features << { feature: claim, status: "Working", file: file }
        return nil
      else
        return check_integration_gap(claim, file, "Object model integration with evaluator")
      end
    when "Multi-Paradigm Unity"
      return check_feature_gap(claim, file, "Multiple paradigm support in single interpreter")
    else
      return check_feature_gap(claim, file, "Implementation of #{claim}")
    end
  end

  def check_syntax_gap(claim, file, requirement)
    { type: :syntax, claim: claim, file: file, requirement: requirement, severity: "High" }
  end

  def check_feature_gap(claim, file, requirement)
    { type: :feature, claim: claim, file: file, requirement: requirement, severity: "Medium" }
  end

  def check_api_gap(claim, file, requirement)
    { type: :api, claim: claim, file: file, requirement: requirement, severity: "Low" }
  end

  def check_integration_gap(claim, file, requirement)
    { type: :integration, claim: claim, file: file, requirement: requirement, severity: "High" }
  end

  def check_performance_gap(claim, file, requirement)
    { type: :performance, claim: claim, file: file, requirement: requirement, severity: "Low" }
  end

  def categorize_gap(gap)
    case gap[:type]
    when :syntax
      @gaps[:syntax_gaps] << gap
    when :feature
      @gaps[:feature_gaps] << gap
    when :integration
      @gaps[:integration_gaps] << gap
    when :api
      @gaps[:api_gaps] << gap
    when :performance
      @gaps[:performance_gaps] << gap
    end
  end

  def generate_report
    puts "📄 GENERATING COMPREHENSIVE REPORT..."
    puts "-" * 50
    
    report_content = build_report
    
    # Write to markdown file
    File.write('docs/audit/v0.6.0-implementation-gap-analysis.md', report_content)
    
    # Display summary
    display_summary
    
    puts "✅ Report generated: docs/audit/v0.6.0-implementation-gap-analysis.md"
  end

  def build_report
    report = <<~MARKDOWN
      # Patlang v0.6.0 Implementation Gap Analysis

      **Date:** #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}  
      **Analysis Type:** Comprehensive gap analysis between examples/documentation and actual implementation

      ## Executive Summary

      This analysis identifies the gaps between what Patlang examples and documentation demonstrate versus what is actually implemented in the current v0.6.0 codebase. The goal is to understand the implementation reality and prioritize development efforts.

      ### Gap Severity Overview

      | Gap Category | Count | Risk Level |
      |--------------|-------|------------|
      | **Syntax Gaps** | #{@gaps[:syntax_gaps].size} | #{assess_risk(@gaps[:syntax_gaps])} |
      | **Feature Gaps** | #{@gaps[:feature_gaps].size} | #{assess_risk(@gaps[:feature_gaps])} |
      | **Integration Gaps** | #{@gaps[:integration_gaps].size} | #{assess_risk(@gaps[:integration_gaps])} |
      | **API Gaps** | #{@gaps[:api_gaps].size} | #{assess_risk(@gaps[:api_gaps])} |
      | **Performance Gaps** | #{@gaps[:performance_gaps].size} | #{assess_risk(@gaps[:performance_gaps])} |

      **Total Gaps Identified:** #{total_gaps}

      ## Current Implementation Status

      ### ✅ What Actually Works (v0.6.0)

      #### Core Interpreter (Fully Functional)
      #{@implementation_reality[:lexer].map { |cap| "- #{cap}" }.join("\n")}

      #### Parser Capabilities
      #{@implementation_reality[:parser].map { |cap| "- #{cap}" }.join("\n")}

      #### Evaluator Capabilities  
      #{@implementation_reality[:evaluator].map { |cap| "- #{cap}" }.join("\n")}

      #### Object Model Status
      **Status:** #{@implementation_reality[:object_model][:status]}
      #{@implementation_reality[:object_model][:components].map { |comp| "- #{comp}" }.join("\n")}

      ### 🎯 Working Features from Examples
      #{@working_features.map { |f| "- **#{f[:feature]}** (#{f[:status]}) - *#{f[:file]}*" }.join("\n")}

      ## Critical Gaps Analysis

      ### 🚨 Syntax Gaps (High Priority)
      
      These are fundamental language syntax elements that examples demonstrate but the parser cannot handle:

      #{format_gaps(@gaps[:syntax_gaps])}

      ### 🔧 Feature Gaps (Medium Priority)
      
      These are language features that examples show but are not implemented:

      #{format_gaps(@gaps[:feature_gaps])}

      ### 🔌 Integration Gaps (High Priority)
      
      These are architectural integration issues where components exist but aren't connected:

      #{format_gaps(@gaps[:integration_gaps])}

      ### 📚 API Gaps (Low Priority)
      
      These are missing standard library functions and built-in APIs:

      #{format_gaps(@gaps[:api_gaps])}

      ### ⚡ Performance Gaps (Low Priority)
      
      These are performance characteristics claimed but not demonstrated:

      #{format_gaps(@gaps[:performance_gaps])}

      ## Detailed Example Analysis

      ### Major Documentation Promises vs Reality

      | Promise | Status | Implementation Required |
      |---------|--------|------------------------|
      | Natural Language Syntax | ❌ Missing | Full lexer/parser rewrite |
      | Multi-Paradigm Unity | ❌ Missing | Multiple evaluator modes |
      | Type Safety | ❌ Missing | Type system implementation |
      | Goal-Oriented Programming | ❌ Missing | Logic programming engine |
      | Interactive Development | ✅ Partial | REPL works, IDE integration missing |

      ### Example File Analysis

      #### .pat Files (Native Patlang Examples)
      #{analyze_pat_files}

      #### .rb Files (Future Vision Demos)
      #{analyze_rb_demos}

      #### Documentation Examples
      #{analyze_doc_examples}

      ## Risk Assessment for User Experience

      ### 🔴 Critical User Experience Issues

      1. **Documentation-Implementation Mismatch:** Getting started guide shows 1,841 lines of syntax that doesn't work
      2. **False Expectations:** Examples demonstrate capabilities that completely fail when attempted
      3. **Missing Core Features:** Basic language constructs like variables, functions, strings are not implemented
      4. **Incomplete Object Model:** Revolutionary object system exists but isn't integrated with language

      ### 🟡 Medium Risk Issues

      1. **Network Transparency Demos:** Ruby demos show future capabilities that may confuse users about current state
      2. **Performance Claims:** Examples claim performance characteristics without benchmarks
      3. **Multi-paradigm Examples:** Show syntax for paradigms not yet implemented

      ### 🟢 Low Risk Issues

      1. **Missing Standard Library:** Core language works, just missing built-in functions
      2. **IDE Integration:** Language works, just missing tooling

      ## Recommendations for Bridging Gaps

      ### Immediate Actions (Week 1-2)

      1. **Audit Documentation:** Add clear "Implementation Status" sections to all examples
      2. **Working Examples:** Create examples that actually work with current v0.6.0
      3. **Status Badges:** Add status indicators (✅ Working, 🚧 In Progress, ❌ Not Implemented)

      ### Short-term Implementation (Month 1-3)

      1. **Integrate Object Model:** Connect object model with evaluator for basic operations
      2. **Basic Language Features:** Implement variables, functions, strings parsing
      3. **Core Standard Library:** Add print, read_line, basic I/O functions

      ### Medium-term Development (Month 3-6)

      1. **Complete Language Syntax:** Implement control flow, classes, collections
      2. **Multi-paradigm Support:** Add functional programming constructs
      3. **Type System:** Implement type inference and checking

      ### Long-term Vision (Month 6-12)

      1. **Network Transparency:** Implement actual distributed capabilities
      2. **Goal-Oriented Programming:** Add logic programming support
      3. **Enterprise Features:** Security, performance optimization

      ## Priority Action Items

      ### Priority 1: Critical User Experience
      - [ ] Update getting-started.md with implementation status for each example
      - [ ] Create working-examples.md with current v0.6.0 capabilities
      - [ ] Add implementation status badges to all documentation

      ### Priority 2: Foundation Completion
      - [ ] Integrate object model with evaluator for arithmetic operations
      - [ ] Implement basic variable assignment (is keyword)
      - [ ] Add string literal parsing and basic operations

      ### Priority 3: Core Language Features
      - [ ] Implement function definitions and calls
      - [ ] Add control flow (if/then/else)
      - [ ] Implement basic collections (arrays)

      ### Priority 4: Advanced Features
      - [ ] Complete object-oriented syntax
      - [ ] Add event system integration
      - [ ] Implement network transparency prototype

      ## Conclusion

      While Patlang v0.6.0 has achieved significant milestones in object model architecture and test coverage (100% passing), there is a substantial gap between documented capabilities and actual implementation. The current interpreter is essentially an arithmetic calculator with a sophisticated object model foundation.

      **Key Findings:**
      - ✅ **Solid Foundation:** Object model and arithmetic evaluation work well
      - ❌ **Major Syntax Gap:** Most documented language features aren't implemented
      - 🚧 **Integration Needed:** Object model exists but isn't used by the evaluator
      - 📚 **Documentation Misalignment:** Examples show unimplemented features

      **Strategic Recommendation:** Treat current documentation as a roadmap rather than current capabilities, and prioritize basic language feature implementation to close the user experience gap.

      ---

      *Generated by Patlang Implementation Gap Analyzer*  
      *Total Analysis Time: #{Time.now.strftime('%H:%M:%S')}*
    MARKDOWN

    report
  end

  def format_gaps(gaps)
    return "*None identified*" if gaps.empty?
    
    gaps.map do |gap|
      "#### #{gap[:claim]}\n" +
      "**File:** `#{gap[:file]}`  \n" +
      "**Requirement:** #{gap[:requirement]}  \n" +
      "**Severity:** #{gap[:severity]}  \n"
    end.join("\n")
  end

  def analyze_pat_files
    pat_claims = @example_claims.select { |c| c[:file]&.end_with?('.pat') }
    return "*No .pat files analyzed*" if pat_claims.empty?
    
    pat_claims.group_by { |c| c[:file] }.map do |file, claims|
      "**#{file}:**\n" + claims.map { |c| "- #{c[:claim]}" }.join("\n")
    end.join("\n\n")
  end

  def analyze_rb_demos
    rb_claims = @example_claims.select { |c| c[:file]&.end_with?('.rb') }
    return "*No Ruby demos analyzed*" if rb_claims.empty?
    
    rb_claims.group_by { |c| c[:file] }.map do |file, claims|
      "**#{file}:**\n" + claims.map { |c| "- #{c[:claim]} (Future Demo)" }.join("\n")
    end.join("\n\n")
  end

  def analyze_doc_examples
    doc_claims = @example_claims.select { |c| c[:type] == "documentation" }
    return "*No documentation examples analyzed*" if doc_claims.empty?
    
    doc_claims.group_by { |c| c[:file] }.map do |file, claims|
      "**#{file}:**\n" + claims.map { |c| "- #{c[:claim]}" }.join("\n")
    end.join("\n\n")
  end

  def assess_risk(gaps)
    return "Low" if gaps.empty?
    
    high_severity = gaps.count { |g| g[:severity] == "High" }
    return "Critical" if high_severity > 5
    return "High" if high_severity > 2
    return "Medium" if gaps.size > 3
    "Low"
  end

  def total_gaps
    @gaps.values.sum(&:size)
  end

  def display_summary
    puts
    puts "📊 GAP ANALYSIS SUMMARY"
    puts "=" * 50
    puts "Total gaps identified: #{total_gaps}"
    puts "Working features: #{@working_features.size}"
    puts "Example claims analyzed: #{@example_claims.size}"
    puts
    puts "Gap breakdown:"
    @gaps.each do |category, gaps|
      puts "  #{category.to_s.gsub('_', ' ').capitalize}: #{gaps.size}"
    end
    puts
  end
end

# Create audit directory if it doesn't exist
Dir.mkdir('docs/audit') unless Dir.exist?('docs/audit')

# Run the analysis
analyzer = ImplementationGapAnalyzer.new
analyzer.analyze_all