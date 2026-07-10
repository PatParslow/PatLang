# Centralized instrumentation gating for Patlang
# Usage: PatlangDebug.log(:EVAL, "message")
# Enable all logs: PATLANG_DEBUG=1
# Enable specific tags: PATLANG_DEBUG_TAGS=EVAL,INCLUDE,CLI
# Silence everything (default): unset both env vars
module PatlangDebug
  class << self
    def enabled?
      return true if ENV['PATLANG_DEBUG'] == '1'
      !enabled_tags.empty?
    end

    def enabled_tags
      @enabled_tags ||= begin
        raw = ENV['PATLANG_DEBUG_TAGS']
        if raw && !raw.strip.empty?
          raw.split(',').map { |t| t.strip.upcase }.to_set
        else
          Set.new
        end
      end
    end

    def tag_enabled?(tag)
      return true if ENV['PATLANG_DEBUG'] == '1'
      enabled_tags.include?(tag.to_s.upcase)
    end

    def log(tag, message=nil, &block)
      return unless tag_enabled?(tag)
      msg = message || (block && block.call) || ''
      $stdout.puts("[#{tag}] #{msg}")
    end

    def scoped(tag, header=nil)
      if tag_enabled?(tag)
        $stdout.puts("[#{tag}] BEGIN #{header}") if header
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC) rescue Time.now.to_f
        yield
        finish = Process.clock_gettime(Process::CLOCK_MONOTONIC) rescue Time.now.to_f
        $stdout.puts("[#{tag}] END #{header} (#{format('%.3f', finish - start)}s)") if header
      else
        yield
      end
    end
  end
end
