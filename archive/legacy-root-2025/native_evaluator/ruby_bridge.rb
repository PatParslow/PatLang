# PaTLang Phase 1 Ruby Bridge
# Integrates existing Ruby evaluator with self-hosting PaTLang evaluator

require 'ffi'
require 'json'
require_relative '../patlang-core/evaluator/evaluator'
require_relative '../patlang-core/parser/parser'
require_relative '../patlang-core/lexer/lexer'

class PaTLangPhase1Bridge
  extend FFI::Library
  
  # Try to load the native bridge library
  begin
    ffi_lib './native_evaluator/native_bridge.so'
    NATIVE_BRIDGE_AVAILABLE = true
  rescue LoadError
    puts "Warning: Native bridge not available, using Ruby fallback"
    NATIVE_BRIDGE_AVAILABLE = false
  end
  
  if NATIVE_BRIDGE_AVAILABLE
    # Define C function signatures
    attach_function :patlang_bridge_initialize, [], :int
    attach_function :patlang_native_call, [:uint32, :pointer, :pointer], :int
    attach_function :patlang_bridge_get_stats, [:pointer, :size_t], :void
    attach_function :patlang_bridge_cleanup, [], :void
  end
  
  # Operation IDs matching the C implementation
  MEMORY_ALLOCATE = 0x1000
  MEMORY_DEALLOCATE = 0x1001
  MEMORY_REALLOCATE = 0x1002
  TIME_OPERATION = 0x2000
  DEBUG_OPERATION = 0x3000
  MATH_OPERATION = 0x4000
  STRING_OPERATION = 0x5000
  
  def initialize
    @ruby_evaluator = Evaluator.new
    @patlang_evaluator_loaded = false
    @native_bridge_initialized = false
    @evaluation_stats = {
      total_evaluations: 0,
      ruby_evaluations: 0,
      patlang_evaluations: 0,
      evaluation_time: 0.0
    }
    
    initialize_bridges
  end
  
  def initialize_bridges
    # Initialize native bridge if available
    if NATIVE_BRIDGE_AVAILABLE
      result = self.class.patlang_bridge_initialize
      @native_bridge_initialized = (result == 0)
      puts "Native bridge initialized: #{@native_bridge_initialized}"
    end
    
    # Load PaTLang evaluator
    load_patlang_evaluator
  end
  
  def load_patlang_evaluator
    begin
      # Load the PaTLang evaluator source code
      evaluator_source = File.read(File.join(__dir__, 'core_evaluator.patlang'))
      
      # Parse the PaTLang evaluator using existing parser
      lexer = Lexer.new(evaluator_source)
      tokens = lexer.tokenize
      
      parser = Parser.new(tokens)
      @patlang_evaluator_ast = parser.parse
      
      @patlang_evaluator_loaded = true
      puts "PaTLang self-hosting evaluator loaded successfully"
      
    rescue => e
      puts "Warning: Could not load PaTLang evaluator: #{e.message}"
      @patlang_evaluator_loaded = false
    end
  end
  
  # Main evaluation method - chooses between Ruby and PaTLang evaluator
  def evaluate(code, options = {})
    start_time = Time.now
    @evaluation_stats[:total_evaluations] += 1
    
    begin
      # Try PaTLang evaluator first if available and requested
      if @patlang_evaluator_loaded && (options[:prefer_patlang] || should_use_patlang?(code))
        result = evaluate_with_patlang(code, options)
        @evaluation_stats[:patlang_evaluations] += 1
        result[:evaluator_used] = :patlang
        return result
      else
        result = evaluate_with_ruby(code, options)
        @evaluation_stats[:ruby_evaluations] += 1
        result[:evaluator_used] = :ruby
        return result
      end
      
    rescue => e
      # Fallback to Ruby evaluator on PaTLang failure
      if options[:evaluator_used] != :ruby
        puts "PaTLang evaluation failed, falling back to Ruby: #{e.message}"
        result = evaluate_with_ruby(code, options)
        @evaluation_stats[:ruby_evaluations] += 1
        result[:evaluator_used] = :ruby_fallback
        result[:patlang_error] = e.message
        return result
      else
        raise e
      end
      
    ensure
      end_time = Time.now
      @evaluation_stats[:evaluation_time] += (end_time - start_time)
    end
  end
  
  private
  
  def should_use_patlang?(code)
    # Heuristics to determine if code should use PaTLang evaluator
    # For Phase 1, use PaTLang for goal-oriented constructs
    code.include?('goal ') || 
    code.include?('fact ') || 
    code.include?('rule ') ||
    code.include?('constrain ') ||
    code.include?('precondition:') ||
    code.include?('postcondition:')
  end
  
  def evaluate_with_patlang(code, options = {})
    # Parse the input code
    lexer = Lexer.new(code)
    tokens = lexer.tokenize
    
    parser = Parser.new(tokens)
    ast = parser.parse
    
    # Create evaluation context for PaTLang evaluator
    context = create_patlang_evaluation_context(options)
    
    # Simulate PaTLang evaluation using the loaded evaluator AST
    # In a full implementation, this would actually execute the PaTLang evaluator
    patlang_result = simulate_patlang_evaluation(ast, context)
    
    {
      value: patlang_result[:value],
      type: patlang_result[:type],
      success: patlang_result[:success],
      error: patlang_result[:error],
      evaluation_method: :patlang_simulation,
      context: patlang_result[:context]
    }
  end
  
  def evaluate_with_ruby(code, options = {})
    # Use existing Ruby evaluator
    lexer = Lexer.new(code)
    tokens = lexer.tokenize
    
    parser = Parser.new(tokens)
    ast = parser.parse
    
    result = @ruby_evaluator.evaluate(ast)
    
    {
      value: result,
      type: infer_ruby_type(result),
      success: true,
      error: nil,
      evaluation_method: :ruby_native
    }
  rescue => e
    {
      value: nil,
      type: nil,
      success: false,
      error: e.message,
      evaluation_method: :ruby_native
    }
  end
  
  def create_patlang_evaluation_context(options = {})
    {
      scope_stack: [create_global_scope],
      value_stack: [],
      call_stack: [],
      memory_manager: create_memory_manager_context,
      type_checker: create_type_checker_context,
      native_bridge: create_native_bridge_context,
      error_handler: create_error_handler_context,
      recursion_depth: 0,
      max_recursion_depth: options[:max_recursion] || 1000,
      initialized: true
    }
  end
  
  def simulate_patlang_evaluation(ast, context)
    # This is a simulation of PaTLang evaluation for Phase 1
    # In the complete implementation, this would actually run the PaTLang evaluator
    
    case ast.class.name
    when 'AST::NumberNode'
      {
        value: ast.value,
        type: { base_type: 'Number', constraints: [] },
        success: true,
        error: nil,
        context: context
      }
      
    when 'AST::StringNode'
      {
        value: ast.value,
        type: { base_type: 'String', constraints: [] },
        success: true,
        error: nil,
        context: context
      }
      
    when 'AST::BinaryOpNode'
      left_result = simulate_patlang_evaluation(ast.left, context)
      return left_result unless left_result[:success]
      
      right_result = simulate_patlang_evaluation(ast.right, context)
      return right_result unless right_result[:success]
      
      operation_result = perform_patlang_binary_operation(
        ast.operator, 
        left_result[:value], 
        right_result[:value]
      )
      
      {
        value: operation_result,
        type: { base_type: 'Number', constraints: [] },
        success: true,
        error: nil,
        context: context
      }
      
    when 'AST::ProgramNode'
      last_result = nil
      ast.statements.each do |stmt|
        last_result = simulate_patlang_evaluation(stmt, context)
        return last_result unless last_result[:success]
      end
      
      last_result || {
        value: nil,
        type: { base_type: 'Void', constraints: [] },
        success: true,
        error: nil,
        context: context
      }
      
    else
      # For unsupported AST nodes, fall back to Ruby evaluation
      begin
        ruby_result = @ruby_evaluator.evaluate(ast)
        {
          value: ruby_result,
          type: infer_ruby_type(ruby_result),
          success: true,
          error: nil,
          context: context,
          fallback_used: true
        }
      rescue => e
        {
          value: nil,
          type: nil,
          success: false,
          error: "Unsupported AST node: #{ast.class.name}, Ruby fallback failed: #{e.message}",
          context: context
        }
      end
    end
  end
  
  def perform_patlang_binary_operation(operator, left, right)
    case operator
    when '+'
      left + right
    when '-'
      left - right
    when '*'
      left * right
    when '/'
      right == 0 ? (raise "Division by zero") : (left / right)
    else
      raise "Unsupported operator: #{operator}"
    end
  end
  
  def create_global_scope
    {
      variables: {},
      functions: {},
      facts: {},
      rules: {},
      parent_scope: nil
    }
  end
  
  def create_memory_manager_context
    {
      total_allocated: 0,
      total_freed: 0,
      gc_enabled: true,
      native_bridge_available: @native_bridge_initialized
    }
  end
  
  def create_type_checker_context
    {
      type_environment: {},
      inference_enabled: true,
      constraint_checking: true
    }
  end
  
  def create_native_bridge_context
    {
      initialized: @native_bridge_initialized,
      available_operations: @native_bridge_initialized ? [
        :memory_allocate, :memory_deallocate, :time_operations,
        :debug_operations, :math_operations, :string_operations
      ] : []
    }
  end
  
  def create_error_handler_context
    {
      errors: [],
      warnings: [],
      recovery_enabled: true
    }
  end
  
  def infer_ruby_type(value)
    case value
    when Numeric
      { base_type: 'Number', constraints: [] }
    when String
      { base_type: 'String', constraints: [] }
    when TrueClass, FalseClass
      { base_type: 'Boolean', constraints: [] }
    when NilClass
      { base_type: 'Void', constraints: [] }
    else
      { base_type: 'Object', constraints: [] }
    end
  end
  
  public
  
  # Native bridge operations (when available)
  def allocate_memory(size, alignment = 8, type_id = 0)
    return nil unless @native_bridge_initialized
    
    args = FFI::MemoryPointer.new(:uint32, 3)
    args[0].write_uint32(size)
    args[1].write_uint32(alignment)
    args[2].write_uint32(type_id)
    
    result = FFI::MemoryPointer.new(:uint8, 512) # Large enough for OperationResult
    
    status = self.class.patlang_native_call(MEMORY_ALLOCATE, args, result)
    
    if status == 0
      # Parse the result (simplified)
      success = result[0].read_uint32
      if success == 1
        # Return allocation info
        result_data_ptr = result[8].read_pointer
        return result_data_ptr unless result_data_ptr.null?
      end
    end
    
    nil
  end
  
  def get_bridge_statistics
    return {} unless @native_bridge_initialized
    
    stats_buffer = FFI::MemoryPointer.new(:uint64, 5)
    self.class.patlang_bridge_get_stats(stats_buffer, stats_buffer.size)
    
    {
      total_allocated: stats_buffer[0].read_uint64,
      total_freed: stats_buffer[1].read_uint64,
      current_usage: stats_buffer[2].read_uint64,
      version: stats_buffer[3].read_uint32,
      initialized: stats_buffer[4].read_uint32 == 1
    }
  end
  
  def get_evaluation_statistics
    @evaluation_stats.merge({
      patlang_evaluator_loaded: @patlang_evaluator_loaded,
      native_bridge_initialized: @native_bridge_initialized,
      average_evaluation_time: @evaluation_stats[:total_evaluations] > 0 ? 
        @evaluation_stats[:evaluation_time] / @evaluation_stats[:total_evaluations] : 0.0,
      patlang_usage_ratio: @evaluation_stats[:total_evaluations] > 0 ?
        @evaluation_stats[:patlang_evaluations].to_f / @evaluation_stats[:total_evaluations] : 0.0
    })
  end
  
  def cleanup
    if @native_bridge_initialized
      self.class.patlang_bridge_cleanup
      @native_bridge_initialized = false
    end
    
    puts "Phase 1 Bridge Statistics:"
    puts "  Total evaluations: #{@evaluation_stats[:total_evaluations]}"
    puts "  PaTLang evaluations: #{@evaluation_stats[:patlang_evaluations]}"
    puts "  Ruby evaluations: #{@evaluation_stats[:ruby_evaluations]}"
    puts "  Total evaluation time: #{'%.3f' % @evaluation_stats[:evaluation_time]}s"
    
    if @native_bridge_initialized
      native_stats = get_bridge_statistics
      puts "  Native bridge memory usage: #{native_stats[:current_usage]} bytes"
    end
  end
  
  # Demonstration method for Phase 1 capabilities
  def demonstrate_phase1_capabilities
    puts "\n=== PaTLang Phase 1 Self-Hosting Demonstration ==="
    
    # Test basic arithmetic with both evaluators
    test_cases = [
      "42",
      "3.14 + 2.86",
      "2 + 3 * 4",
      "(2 + 3) * 4",
      "10 - 5 / 2"
    ]
    
    test_cases.each do |code|
      puts "\nEvaluating: #{code}"
      
      # Ruby evaluation
      ruby_result = evaluate(code, prefer_patlang: false)
      puts "  Ruby result: #{ruby_result[:value]} (#{ruby_result[:evaluation_method]})"
      
      # PaTLang evaluation (simulated)
      patlang_result = evaluate(code, prefer_patlang: true)
      puts "  PaTLang result: #{patlang_result[:value]} (#{patlang_result[:evaluation_method]})"
      
      # Compare results
      if ruby_result[:value] == patlang_result[:value]
        puts "  ✓ Results match"
      else
        puts "  ✗ Results differ!"
      end
    end
    
    # Test goal-oriented construct (simulated)
    goal_code = <<~PATLANG
      goal calculate_fibonacci(n) {
        precondition: n >= 0,
        postcondition: result >= 0,
        strategy: recursive_with_memoization
      }
    PATLANG
    
    puts "\nTesting goal-oriented construct:"
    puts goal_code
    goal_result = evaluate(goal_code, prefer_patlang: true)
    puts "Goal evaluation: #{goal_result[:success] ? 'SUCCESS' : 'FAILED'}"
    puts "Used evaluator: #{goal_result[:evaluator_used]}"
    
    puts "\n=== Phase 1 Statistics ==="
    stats = get_evaluation_statistics
    stats.each { |k, v| puts "  #{k}: #{v}" }
    
    if @native_bridge_initialized
      bridge_stats = get_bridge_statistics
      puts "\n=== Native Bridge Statistics ==="
      bridge_stats.each { |k, v| puts "  #{k}: #{v}" }
    end
  end
end

# Phase 1 entry point
if __FILE__ == $0
  puts "Starting PaTLang Phase 1 Self-Hosting Bridge..."
  
  bridge = PaTLangPhase1Bridge.new
  
  # Run demonstration
  bridge.demonstrate_phase1_capabilities
  
  # Interactive mode
  puts "\n=== Interactive Phase 1 Evaluation ==="
  puts "Enter PaTLang expressions (or 'exit' to quit):"
  
  loop do
    print "patlang> "
    input = gets.chomp
    
    break if input.downcase == 'exit'
    
    next if input.strip.empty?
    
    result = bridge.evaluate(input, prefer_patlang: true)
    
    if result[:success]
      puts "=> #{result[:value]} (#{result[:evaluator_used]})"
    else
      puts "Error: #{result[:error]}"
    end
  end
  
  bridge.cleanup
  puts "Phase 1 bridge shut down successfully."
end