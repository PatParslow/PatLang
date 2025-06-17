#!/usr/bin/env ruby

# Integration Test Performance Monitor
# Captures real-time metrics during the complete Git workflow test

require 'json'
require 'time'

class IntegrationTestMonitor
  def initialize
    @start_time = Time.now
    @metrics = {
      test_name: "Complete Unified Reasoning System Integration Test",
      start_time: @start_time.iso8601,
      workflow_stages: {},
      performance_metrics: {},
      validation_results: {},
      git_operations: {}
    }
  end

  def start_stage(stage_name)
    @current_stage = stage_name
    @stage_start = Time.now
    puts "🔄 Starting stage: #{stage_name}"
    @metrics[:workflow_stages][stage_name] = {
      start_time: @stage_start.iso8601,
      status: "running"
    }
  end

  def end_stage(success = true)
    return unless @current_stage
    
    end_time = Time.now
    duration = end_time - @stage_start
    
    @metrics[:workflow_stages][@current_stage].merge!({
      end_time: end_time.iso8601,
      duration_seconds: duration.round(3),
      status: success ? "completed" : "failed"
    })
    
    status_emoji = success ? "✅" : "❌"
    puts "#{status_emoji} Stage completed: #{@current_stage} (#{duration.round(3)}s)"
    @current_stage = nil
  end

  def record_git_operation(operation, details = {})
    @metrics[:git_operations][operation] = details.merge({
      timestamp: Time.now.iso8601
    })
  end

  def record_validation_result(validator, result)
    @metrics[:validation_results][validator] = result.merge({
      timestamp: Time.now.iso8601
    })
  end

  def record_performance_metric(metric_name, value, unit = nil)
    @metrics[:performance_metrics][metric_name] = {
      value: value,
      unit: unit,
      timestamp: Time.now.iso8601
    }
  end

  def finalize_report
    @metrics[:end_time] = Time.now.iso8601
    @metrics[:total_duration_seconds] = (Time.now - @start_time).round(3)
    
    # Calculate success rate
    total_stages = @metrics[:workflow_stages].size
    successful_stages = @metrics[:workflow_stages].values.count { |stage| stage[:status] == "completed" }
    @metrics[:success_rate] = (successful_stages.to_f / total_stages * 100).round(2)
    
    # Write detailed report
    File.write('integration_test_results.json', JSON.pretty_generate(@metrics))
    
    puts "\n" + "=" * 60
    puts "🏁 INTEGRATION TEST COMPLETE"
    puts "=" * 60
    puts "📊 Total Duration: #{@metrics[:total_duration_seconds]}s"
    puts "✅ Success Rate: #{@metrics[:success_rate]}%"
    puts "📝 Detailed report: integration_test_results.json"
    puts "=" * 60
  end

  def print_stage_summary
    puts "\n📈 STAGE SUMMARY:"
    @metrics[:workflow_stages].each do |stage, data|
      status = data[:status] == "completed" ? "✅" : 
               data[:status] == "failed" ? "❌" : "🔄"
      duration = data[:duration_seconds] ? "(#{data[:duration_seconds]}s)" : "(running)"
      puts "   #{status} #{stage} #{duration}"
    end
  end
end

# Export for use in integration test
if __FILE__ == $0
  puts "Integration Test Monitor initialized"
  puts "Use: monitor = IntegrationTestMonitor.new"
end