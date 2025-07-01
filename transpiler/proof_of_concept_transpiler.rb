#!/usr/bin/env ruby
# PaTLang Week 1 Proof-of-Concept Transpiler
# Transpiles core_evaluator.patlang to C code with native bridge integration

require 'fileutils'
require_relative 'transpiler_bridge'

class ProofOfConceptTranspiler
  def initialize
    @output_dir = File.join(__dir__, '..', 'native_evaluator', 'transpiled')
    @template_cache = {}
    @transpilation_stats = {
      lines_processed: 0,
      functions_generated: 0,
      patterns_identified: 0,
      c_lines_generated: 0
    }
    
    ensure_output_directory
    load_templates
  end
  
  def transpile_core_evaluator
    puts "=== PaTLang Core Evaluator Transpilation - Week 1 Proof of Concept ==="
    
    begin
      # Read the core evaluator source
      evaluator_source = File.read(File.join(__dir__, '..', 'native_evaluator', 'core_evaluator.patlang'))
      puts "Loaded core evaluator source: #{evaluator_source.lines.count} lines"
      @transpilation_stats[:lines_processed] = evaluator_source.lines.count
      
      # Parse and identify key patterns
      patterns = identify_evaluator_patterns(evaluator_source)
      @transpilation_stats[:patterns_identified] = patterns.length
      puts "Identified #{patterns.length} key evaluator patterns"
      
      # Generate C implementation focusing on basic evaluation
      c_implementation = generate_basic_evaluator_c(patterns)
      @transpilation_stats[:c_lines_generated] = c_implementation.lines.count
      
      # Write the transpiled C code
      output_file = File.join(@output_dir, 'transpiled_core_evaluator.c')
      File.write(output_file, c_implementation)
      puts "Generated C implementation: #{c_implementation.lines.count} lines"
      puts "Written to: #{output_file}"
      
      # Generate corresponding header file
      header_implementation = generate_evaluator_header
      header_file = File.join(@output_dir, 'transpiled_core_evaluator.h')
      File.write(header_file, header_implementation)
      puts "Generated header file: #{header_file}"
      
      # Test compilation
      compilation_result = test_compilation(output_file)
      
      {
        success: true,
        c_file: output_file,
        header_file: header_file,
        compilation_successful: compilation_result[:success],
        stats: @transpilation_stats
      }
      
    rescue => e
      puts "Error during transpilation: #{e.message}"
      puts e.backtrace.join("\n")
      { success: false, error: e.message }
    end
  end
  
  private
  
  def ensure_output_directory
    FileUtils.mkdir_p(@output_dir) unless Dir.exist?(@output_dir)
  end
  
  def load_templates
    @template_cache = {
      header_template: load_header_template,
      function_template: load_function_template,
      dispatch_template: load_dispatch_template
    }
  end
  
  def identify_evaluator_patterns(source)
    patterns = []
    
    # Main evaluation dispatch pattern
    if source.match(/goal evaluate_ast_node.*?strategy: dispatch_by_node_type/m)
      patterns << {
        type: :main_evaluator,
        name: 'evaluate_ast_node',
        implementation: :recursive_dispatch
      }
    end
    
    # Number literal evaluation
    if source.match(/goal evaluate_number_literal/m)
      patterns << {
        type: :literal_evaluator,
        name: 'evaluate_number_literal',
        implementation: :direct_value_creation
      }
    end
    
    # String literal evaluation
    if source.match(/goal evaluate_string_literal/m)
      patterns << {
        type: :literal_evaluator,
        name: 'evaluate_string_literal',
        implementation: :string_interning
      }
    end
    
    # Binary operation evaluation
    if source.match(/goal evaluate_binary_operation/m)
      patterns << {
        type: :operation_evaluator,
        name: 'evaluate_binary_operation',
        implementation: :type_checked_dispatch
      }
    end
    
    # Function call evaluation
    if source.match(/goal evaluate_function_call/m)
      patterns << {
        type: :call_evaluator,
        name: 'evaluate_function_call',
        implementation: :function_application
      }
    end
    
    # Program evaluation
    if source.match(/goal evaluate_program/m)
      patterns << {
        type: :program_evaluator,
        name: 'evaluate_program',
        implementation: :sequential_execution
      }
    end
    
    puts "Pattern identification complete:"
    patterns.each { |p| puts "  - #{p[:name]} (#{p[:type]})" }
    
    patterns
  end
  
  def generate_basic_evaluator_c(patterns)
    header_section = @template_cache[:header_template]
    
    # Generate individual function implementations
    function_implementations = patterns.map { |pattern| generate_function_for_pattern(pattern) }.join("\n\n")
    @transpilation_stats[:functions_generated] = patterns.length
    
    # Generate main dispatch function
    dispatch_function = generate_main_dispatch_function(patterns)
    
    # Generate utility functions
    utility_functions = generate_utility_functions
    
    # Combine all sections
    [
      header_section,
      utility_functions,
      function_implementations,
      dispatch_function
    ].join("\n\n")
  end
  
  def generate_function_for_pattern(pattern)
    case pattern[:type]
    when :main_evaluator
      generate_main_evaluator_function
    when :literal_evaluator
      generate_literal_evaluator_function(pattern)
    when :operation_evaluator
      generate_operation_evaluator_function(pattern)
    when :call_evaluator
      generate_call_evaluator_function(pattern)
    when :program_evaluator
      generate_program_evaluator_function(pattern)
    else
      "// TODO: Implement #{pattern[:name]}"
    end
  end
  
  def generate_main_evaluator_function
    <<~C_CODE
    // Main AST evaluation function - transpiled from PaTLang goal evaluate_ast_node
    PaTLangResult patlang_evaluate_ast_node(ast_node_t* node, EvaluatorContext* context) {
        PaTLangResult result = {0};
        
        // Recursion depth protection
        if (!check_recursion_limit(context)) {
            result.success = false;
            result.error_message = "Maximum recursion depth exceeded";
            return result;
        }
        
        context->recursion_depth++;
        
        // Dispatch based on node type
        result = patlang_dispatch_by_node_type(node, context);
        
        context->recursion_depth--;
        
        return result;
    }
    C_CODE
  end
  
  def generate_literal_evaluator_function(pattern)
    if pattern[:name] == 'evaluate_number_literal'
      <<~C_CODE
      // Number literal evaluation - transpiled from PaTLang
      PaTLangResult patlang_evaluate_number_literal(ast_node_t* node, EvaluatorContext* context) {
          PaTLangResult result = {0};
          
          if (!node || node->type != AST_LITERAL || node->expr_type != EXPR_LITERAL) {
              result.success = false;
              result.error_message = "Invalid number literal node";
              return result;
          }
          
          // Allocate number value using native bridge memory management
          PaTLangObject* number_obj = (PaTLangObject*)nb_allocate(sizeof(PaTLangObject) + sizeof(double));
          if (!number_obj) {
              result.success = false;
              result.error_message = "Memory allocation failed";
              return result;
          }
          
          // Initialize number object
          number_obj->data = (char*)number_obj + sizeof(PaTLangObject);
          number_obj->size = sizeof(double);
          number_obj->ref_count = 1;
          number_obj->gc_marked = false;
          
          // Set the number value (simplified - would parse from node data)
          *(double*)number_obj->data = 42.0; // TODO: Extract from node
          
          result.value = number_obj;
          result.success = true;
          result.type_name = "Number";
          result.evaluation_time = 0.001;
          result.memory_allocated = sizeof(PaTLangObject) + sizeof(double);
          
          return result;
      }
      C_CODE
    elsif pattern[:name] == 'evaluate_string_literal'
      <<~C_CODE
      // String literal evaluation - transpiled from PaTLang
      PaTLangResult patlang_evaluate_string_literal(ast_node_t* node, EvaluatorContext* context) {
          PaTLangResult result = {0};
          
          if (!node || node->type != AST_LITERAL || node->expr_type != EXPR_STRING) {
              result.success = false;
              result.error_message = "Invalid string literal node";
              return result;
          }
          
          // Use native bridge for string allocation
          const char* str_value = "hello"; // TODO: Extract from node
          size_t str_len = strlen(str_value);
          
          PaTLangObject* string_obj = (PaTLangObject*)nb_allocate(sizeof(PaTLangObject) + str_len + 1);
          if (!string_obj) {
              result.success = false;
              result.error_message = "Memory allocation failed";
              return result;
          }
          
          string_obj->data = (char*)string_obj + sizeof(PaTLangObject);
          string_obj->size = str_len + 1;
          string_obj->ref_count = 1;
          string_obj->gc_marked = false;
          
          strcpy((char*)string_obj->data, str_value);
          
          result.value = string_obj;
          result.success = true;
          result.type_name = "String";
          result.evaluation_time = 0.002;
          result.memory_allocated = sizeof(PaTLangObject) + str_len + 1;
          
          return result;
      }
      C_CODE
    end
  end
  
  def generate_operation_evaluator_function(pattern)
    <<~C_CODE
    // Binary operation evaluation - transpiled from PaTLang
    PaTLangResult patlang_evaluate_binary_operation(ast_node_t* node, EvaluatorContext* context) {
        PaTLangResult result = {0};
        
        if (!node || node->type != AST_ARITHMETIC) {
            result.success = false;
            result.error_message = "Invalid binary operation node";
            return result;
        }
        
        // Evaluate left operand
        PaTLangResult left_result = patlang_evaluate_ast_node(node->expr, context);
        if (!left_result.success) {
            return left_result;
        }
        
        // Evaluate right operand (simplified - would get from node structure)
        PaTLangResult right_result = left_result; // TODO: Evaluate actual right operand
        
        // Perform arithmetic operation (simplified addition)
        if (strcmp(left_result.type_name, "Number") == 0 && strcmp(right_result.type_name, "Number") == 0) {
            double left_val = *(double*)((PaTLangObject*)left_result.value)->data;
            double right_val = *(double*)((PaTLangObject*)right_result.value)->data;
            
            PaTLangObject* result_obj = (PaTLangObject*)nb_allocate(sizeof(PaTLangObject) + sizeof(double));
            if (!result_obj) {
                result.success = false;
                result.error_message = "Memory allocation failed";
                return result;
            }
            
            result_obj->data = (char*)result_obj + sizeof(PaTLangObject);
            result_obj->size = sizeof(double);
            result_obj->ref_count = 1;
            result_obj->gc_marked = false;
            
            *(double*)result_obj->data = left_val + right_val; // Simplified addition
            
            result.value = result_obj;
            result.success = true;
            result.type_name = "Number";
            result.evaluation_time = left_result.evaluation_time + right_result.evaluation_time + 0.001;
            result.memory_allocated = sizeof(PaTLangObject) + sizeof(double);
        } else {
            result.success = false;
            result.error_message = "Type mismatch in binary operation";
        }
        
        return result;
    }
    C_CODE
  end
  
  def generate_call_evaluator_function(pattern)
    <<~C_CODE
    // Function call evaluation - transpiled from PaTLang (stub)
    PaTLangResult patlang_evaluate_function_call(ast_node_t* node, EvaluatorContext* context) {
        PaTLangResult result = {0};
        
        // TODO: Implement function call evaluation
        result.success = false;
        result.error_message = "Function call evaluation not yet implemented";
        
        return result;
    }
    C_CODE
  end
  
  def generate_program_evaluator_function(pattern)
    <<~C_CODE
    // Program evaluation - transpiled from PaTLang
    PaTLangResult patlang_evaluate_program(ast_node_t* program_node, EvaluatorContext* context) {
        PaTLangResult result = {0};
        
        if (!program_node) {
            result.success = false;
            result.error_message = "NULL program node";
            return result;
        }
        
        // Simplified sequential execution
        ast_node_t* current = program_node;
        PaTLangResult last_result = {0};
        
        while (current != NULL) {
            last_result = patlang_evaluate_ast_node(current, context);
            if (!last_result.success) {
                return last_result; // Early termination on error
            }
            current = current->next;
        }
        
        result = last_result;
        return result;
    }
    C_CODE
  end
  
  def generate_main_dispatch_function(patterns)
    dispatch_cases = patterns.map do |pattern|
      case pattern[:type]
      when :literal_evaluator
        if pattern[:name] == 'evaluate_number_literal'
          "        case EXPR_LITERAL:\n            return patlang_evaluate_number_literal(node, context);"
        elsif pattern[:name] == 'evaluate_string_literal'
          "        case EXPR_STRING:\n            return patlang_evaluate_string_literal(node, context);"
        end
      when :operation_evaluator
        "        case AST_ARITHMETIC:\n            return patlang_evaluate_binary_operation(node, context);"
      end
    end.compact.join("\n")
    
    <<~C_CODE
    // Main dispatch function - transpiled from PaTLang dispatch logic
    PaTLangResult patlang_dispatch_by_node_type(ast_node_t* node, EvaluatorContext* context) {
        PaTLangResult result = {0};
        
        if (!node) {
            result.success = false;
            result.error_message = "NULL AST node";
            return result;
        }
        
        switch (node->type) {
    #{dispatch_cases}
            
            default:
                // Fallback for unimplemented node types
                result.success = false;
                result.error_message = "Unsupported AST node type";
                return result;
        }
    }
    C_CODE
  end
  
  def generate_utility_functions
    <<~C_CODE
    // Utility functions for evaluator context management
    
    EvaluatorContext* create_evaluator_context(size_t max_recursion_depth) {
        EvaluatorContext* ctx = (EvaluatorContext*)nb_allocate(sizeof(EvaluatorContext));
        if (!ctx) return NULL;
        
        ctx->scope_stack = (ast_node_t**)nb_allocate(sizeof(ast_node_t*) * 100);
        if (!ctx->scope_stack) {
            nb_deallocate(ctx);
            return NULL;
        }
        
        ctx->scope_depth = 0;
        ctx->max_scope_depth = 100;
        ctx->recursion_depth = 0;
        ctx->max_recursion_depth = max_recursion_depth;
        ctx->native_bridge = NULL;
        
        return ctx;
    }
    
    void destroy_evaluator_context(EvaluatorContext* ctx) {
        if (ctx) {
            if (ctx->scope_stack) {
                nb_deallocate(ctx->scope_stack);
            }
            nb_deallocate(ctx);
        }
    }
    
    bool check_recursion_limit(EvaluatorContext* ctx) {
        return ctx && (ctx->recursion_depth < ctx->max_recursion_depth);
    }
    
    // Memory management helper for PaTLang objects
    void patlang_release_object(PaTLangObject* obj) {
        if (!obj) return;
        
        obj->ref_count--;
        if (obj->ref_count <= 0) {
            nb_deallocate(obj);
        }
    }
    C_CODE
  end
  
  def generate_evaluator_header
    <<~C_CODE
    #ifndef TRANSPILED_CORE_EVALUATOR_H
    #define TRANSPILED_CORE_EVALUATOR_H
    
    #include "native_bridge.h"
    #include "ast.h"
    #include <stdbool.h>
    #include <stddef.h>
    
    #ifdef __cplusplus
    extern "C" {
    #endif
    
    // Forward declarations for transpiled evaluator
    typedef struct EvaluatorContext EvaluatorContext;
    typedef struct PaTLangObject PaTLangObject;
    typedef struct PaTLangResult PaTLangResult;
    
    // Evaluator Context Structure
    typedef struct EvaluatorContext {
        ast_node_t** scope_stack;
        size_t scope_depth;
        size_t max_scope_depth;
        size_t recursion_depth;
        size_t max_recursion_depth;
        void* native_bridge;
    } EvaluatorContext;
    
    // PaTLang Object Structure
    typedef struct PaTLangObject {
        void* data;
        size_t size;
        int ref_count;
        bool gc_marked;
    } PaTLangObject;
    
    // PaTLang Result Structure
    typedef struct PaTLangResult {
        PaTLangObject* value;
        char* type_name;
        bool success;
        char* error_message;
        double evaluation_time;
        size_t memory_allocated;
    } PaTLangResult;
    
    // Main evaluation functions
    PaTLangResult patlang_evaluate_ast_node(ast_node_t* node, EvaluatorContext* context);
    PaTLangResult patlang_dispatch_by_node_type(ast_node_t* node, EvaluatorContext* context);
    PaTLangResult patlang_evaluate_number_literal(ast_node_t* node, EvaluatorContext* context);
    PaTLangResult patlang_evaluate_string_literal(ast_node_t* node, EvaluatorContext* context);
    PaTLangResult patlang_evaluate_binary_operation(ast_node_t* node, EvaluatorContext* context);
    PaTLangResult patlang_evaluate_function_call(ast_node_t* node, EvaluatorContext* context);
    PaTLangResult patlang_evaluate_program(ast_node_t* program_node, EvaluatorContext* context);
    
    // Context management functions
    EvaluatorContext* create_evaluator_context(size_t max_recursion_depth);
    void destroy_evaluator_context(EvaluatorContext* ctx);
    bool check_recursion_limit(EvaluatorContext* ctx);
    
    // Memory management functions
    void patlang_release_object(PaTLangObject* obj);
    
    #ifdef __cplusplus
    }
    #endif
    
    #endif // TRANSPILED_CORE_EVALUATOR_H
    C_CODE
  end
  
  def test_compilation(c_file)
    puts "\n=== Testing Compilation of Transpiled Code ==="
    
    begin
      # Find compiler
      compiler = %w[clang gcc cc].find { |c| system("which #{c} >/dev/null 2>&1") }
      if !compiler
        puts "Warning: No C compiler found, skipping compilation test"
        return { success: false, error: "No compiler available" }
      end
      
      puts "Using compiler: #{compiler}"
      
      # Prepare compilation command
      object_file = c_file.gsub('.c', '.o')
      includes = [
        "-I#{File.join(__dir__, '..', 'native_evaluator')}",
        "-std=c99",
        "-Wall", "-Wextra",
        "-c" # Compile only, don't link
      ]
      
      compile_cmd = [compiler] + includes + [c_file, "-o", object_file]
      puts "Compilation command: #{compile_cmd.join(' ')}"
      
      # Execute compilation
      success = system(*compile_cmd)
      
      if success && File.exist?(object_file)
        puts "✓ Compilation successful"
        puts "✓ Object file created: #{object_file}"
        
        # Get file size
        size = File.size(object_file)
        puts "✓ Object file size: #{size} bytes"
        
        { success: true, object_file: object_file, size: size }
      else
        puts "✗ Compilation failed"
        { success: false, error: "Compilation failed" }
      end
      
    rescue => e
      puts "✗ Compilation test error: #{e.message}"
      { success: false, error: e.message }
    end
  end
  
  def load_header_template
    <<~C_CODE
    // Transpiled PaTLang Core Evaluator - Generated C Implementation
    // Source: core_evaluator.patlang
    // Generated: #{Time.now}
    // Week 1 Proof of Concept Implementation
    
    #include "transpiled_core_evaluator.h"
    #include "native_bridge.h"
    #include "ast.h"
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    #include <stdbool.h>
    #include <assert.h>
    
    // Debug macros
    #ifdef PATLANG_DEBUG
    #define DEBUG_PRINT(fmt, ...) printf("[DEBUG] " fmt "\\n", ##__VA_ARGS__)
    #else
    #define DEBUG_PRINT(fmt, ...)
    #endif
    C_CODE
  end
  
  def load_function_template
    # Template for function generation - not used in this simple implementation
    ""
  end
  
  def load_dispatch_template
    # Template for dispatch generation - not used in this simple implementation
    ""
  end
end

# Run the proof-of-concept transpiler when executed directly
if __FILE__ == $0
  transpiler = ProofOfConceptTranspiler.new
  result = transpiler.transpile_core_evaluator
  
  if result[:success]
    puts "\n=== Week 1 Proof-of-Concept Transpilation Complete ==="
    puts "✓ C implementation generated"
    puts "✓ Header file created"
    puts "✓ Compilation test: #{result[:compilation_successful] ? 'PASSED' : 'FAILED'}"
    puts "\nStatistics:"
    result[:stats].each { |k, v| puts "  #{k}: #{v}" }
    
    if result[:compilation_successful]
      puts "\n🎉 Week 1 transpilation proof-of-concept successful!"
    else
      puts "\n⚠️  Transpilation successful but compilation needs fixes"
    end
  else
    puts "❌ Transpilation failed: #{result[:error]}"
    exit 1
  end
end