# frozen_string_literal: true

# Emergency timeout protection mechanism to prevent test hangs
class EmergencyTimeout
  class TimeoutError < StandardError; end

  # Protect a block of code with emergency timeout
  # @param timeout_seconds [Numeric] Maximum time to allow execution
  # @param error_message [String] Custom error message on timeout
  # @yield Block to execute with timeout protection
  # @return Result of the block execution
  # @raise [TimeoutError] If execution exceeds timeout
  def self.protect(timeout_seconds, error_message: nil)
    return yield unless timeout_seconds && timeout_seconds > 0

    start_time = Time.now
    result = nil
    thread = Thread.new do
      begin
        result = yield
      rescue => e
        Thread.current[:exception] = e
      end
    end

    # Wait for completion or timeout
    if thread.join(timeout_seconds)
      # Completed within timeout
      if thread[:exception]
        raise thread[:exception]
      end
      result
    else
      # Timeout exceeded - forcefully terminate
      thread.kill
      elapsed = Time.now - start_time
      message = error_message || "Operation exceeded timeout of #{timeout_seconds}s (elapsed: #{elapsed.round(2)}s)"
      raise TimeoutError, message
    end
  end

  # Protect with a very short timeout for individual operations
  def self.protect_operation(operation_timeout = 0.1)
    protect(operation_timeout, error_message: "Individual operation timeout exceeded") do
      yield
    end
  end

  # Protect with longer timeout for batch operations
  def self.protect_batch(batch_timeout = 30)
    protect(batch_timeout, error_message: "Batch operation timeout exceeded") do
      yield
    end
  end
end