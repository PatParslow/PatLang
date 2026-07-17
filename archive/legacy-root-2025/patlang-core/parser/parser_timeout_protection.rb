# frozen_string_literal: true

require_relative '../../ruby-host/bootstrap/emergency_timeout'

# Timeout protection mixin for parser operations
module ParserModules
  module TimeoutProtection
    # Maximum time allowed for parsing operations (in seconds)
    PARSE_TIMEOUT = 10.0
    EXPRESSION_TIMEOUT = 2.0
    TOKEN_RESOLUTION_TIMEOUT = 1.0
    
    # Circuit breaker for detecting infinite loops
    class CircuitBreaker
      def initialize(max_iterations = 1000, window_size = 100)
        @max_iterations = max_iterations
        @window_size = window_size
        @iteration_count = 0
        @last_positions = []
        @start_time = Time.now
      end
      
      def check_iteration(position = nil)
        @iteration_count += 1
        
        # Check for excessive iterations
        if @iteration_count > @max_iterations
          raise EmergencyTimeout::TimeoutError, "Circuit breaker: Maximum iterations exceeded - possible infinite loop detected"
        end
        
        # Check for position loops (same token position repeatedly)
        if position
          @last_positions << position
          if @last_positions.length > @window_size
            @last_positions.shift
          end
          
          # If we've seen the same position too many times recently, it's likely a loop
          if @last_positions.count(position) > (@window_size / 10)
            raise EmergencyTimeout::TimeoutError, "Circuit breaker: Detected infinite loop at position #{position}"
          end
        end
        
        # Check for time-based timeout
        elapsed = Time.now - @start_time
        if elapsed > PARSE_TIMEOUT
          raise EmergencyTimeout::TimeoutError, "Circuit breaker: Parse timeout (#{elapsed.round(2)}s) exceeded"
        end
      end
      
      def reset
        @iteration_count = 0
        @last_positions.clear
        @start_time = Time.now
      end
    end
    
    # Protect a parsing operation with timeout
    def with_parse_timeout(timeout = PARSE_TIMEOUT, operation_name = "parse operation")
      EmergencyTimeout.protect(timeout, error_message: "#{operation_name} timeout exceeded") do
        yield
      end
    rescue EmergencyTimeout::TimeoutError => e
      # Convert to ParseError for consistent error handling
      return ErrorNode.new("Parser timeout: #{e.message}")
    end
    
    # Protect expression parsing with shorter timeout
    def with_expression_timeout(operation_name = "expression parsing")
      EmergencyTimeout.protect(EXPRESSION_TIMEOUT, error_message: "#{operation_name} timeout exceeded") do
        yield
      end
    rescue EmergencyTimeout::TimeoutError => e
      # Return an ErrorNode since we might not have access to safe_error
      return ErrorNode.new("Expression timeout: #{e.message}")
    end
    
    # Protect token resolution with very short timeout
    def with_token_resolution_timeout(operation_name = "token resolution")
      EmergencyTimeout.protect(TOKEN_RESOLUTION_TIMEOUT, error_message: "#{operation_name} timeout exceeded") do
        yield
      end
    rescue EmergencyTimeout::TimeoutError => e
      return ErrorNode.new("Token resolution timeout: #{e.message}")
    end
    
    # Create a new circuit breaker for loop protection
    def create_circuit_breaker(max_iterations = 1000)
      CircuitBreaker.new(max_iterations)
    end
  end
end