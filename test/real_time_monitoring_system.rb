#!/usr/bin/env ruby

# PATLANG Real-time Monitoring and Alerting System
# Provides continuous monitoring of test execution, coverage trends, and system health

require 'json'
require 'fileutils'
require 'benchmark'
require 'net/http'
require 'uri'

class RealTimeMonitoringSystem
  VERSION = "1.0.0"
  
  def initialize
    @base_path = File.dirname(__FILE__)
    @config_file = File.join(@base_path, 'monitoring_config.json')
    @metrics_file = File.join(@base_path, 'monitoring_metrics.json')
    @alerts_file = File.join(@base_path, 'monitoring_alerts.json')
    @dashboard_file = File.join(@base_path, 'monitoring_dashboard.html')
    
    load_configuration
    initialize_metrics
  end

  def start_monitoring
    puts "🔍 PATLANG Real-time Monitoring System v#{VERSION}"
    puts "=" * 60
    puts "📊 Starting continuous system monitoring..."
    puts "🕐 Started: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
    puts

    # Create monitoring loop
    loop do
      begin
        cycle_start = Time.now
        
        # Collect metrics
        metrics = collect_system_metrics
        
        # Analyze trends
        analyze_trends(metrics)
        
        # Check alert conditions
        check_alert_conditions(metrics)
        
        # Update dashboard
        update_dashboard(metrics)
        
        # Calculate cycle time
        cycle_time = Time.now - cycle_start
        
        puts "📊 Monitoring cycle completed in #{cycle_time.round(2)}s"
        
        # Sleep until next cycle
        sleep(@config['monitoring_interval'] - cycle_time) if cycle_time < @config['monitoring_interval']
        
      rescue Interrupt
        puts "\n🛑 Monitoring stopped by user"
        break
      rescue => e
        puts "❌ Monitoring error: #{e.message}"
        sleep(5)  # Wait before retrying
      end
    end
  end

  def generate_health_report
    puts "🏥 PATLANG System Health Report"
    puts "=" * 50
    
    metrics = collect_system_metrics
    health_score = calculate_health_score(metrics)
    
    puts "🎯 Overall Health Score: #{health_score}/100"
    puts "📊 Test Execution Health: #{metrics[:test_health]}/100"
    puts "📈 Coverage Trend Health: #{metrics[:coverage_health]}/100"
    puts "⚡ Performance Health: #{metrics[:performance_health]}/100"
    puts "🔧 System Integration Health: #{metrics[:integration_health]}/100"
    puts
    
    # Generate recommendations
    recommendations = generate_health_recommendations(metrics)
    if recommendations.any?
      puts "💡 Health Recommendations:"
      recommendations.each_with_index do |rec, i|
        puts "   #{i+1}. #{rec}"
      end
    else
      puts "✅ System is in excellent health!"
    end
    
    # Save health report
    health_report = {
      timestamp: Time.now.to_i,
      health_score: health_score,
      metrics: metrics,
      recommendations: recommendations
    }
    
    File.write(File.join(@base_path, 'system_health_report.json'), JSON.pretty_generate(health_report))
    puts "\n💾 Health report saved to: system_health_report.json"
    
    health_report
  end

  private

  def load_configuration
    @config = {
      'monitoring_interval' => 30,  # seconds
      'alert_thresholds' => {
        'coverage_drop' => 5,  # percentage
        'test_failure_rate' => 10,  # percentage
        'performance_regression' => 50  # percentage increase
      },
      'retention_days' => 30,
      'dashboard_refresh' => 10,
      'notification_channels' => ['console', 'file']
    }
    
    if File.exist?(@config_file)
      saved_config = JSON.parse(File.read(@config_file)) rescue {}
      @config.merge!(saved_config)
    else
      save_configuration
    end
  end

  def save_configuration
    File.write(@config_file, JSON.pretty_generate(@config))
  end

  def initialize_metrics
    @metrics_history = []
    
    if File.exist?(@metrics_file)
      @metrics_history = JSON.parse(File.read(@metrics_file)) rescue []
    end
    
    # Clean old metrics
    cutoff_time = Time.now.to_i - (@config['retention_days'] * 24 * 60 * 60)
    @metrics_history = @metrics_history.select { |m| m['timestamp'] > cutoff_time }
  end

  def collect_system_metrics
    metrics = {
      timestamp: Time.now.to_i,
      test_health: calculate_test_health,
      coverage_health: calculate_coverage_health,
      performance_health: calculate_performance_health,
      integration_health: calculate_integration_health
    }
    
    # Add to history
    @metrics_history << metrics
    save_metrics
    
    metrics
  end

  def calculate_test_health
    health_score = 100
    
    # Check recent test results
    test_files = Dir.glob(File.join(@base_path, 'test_*.json'))
    
    if test_files.any?
      recent_results = test_files.map do |file|
        JSON.parse(File.read(file)) rescue {}
      end.select { |r| r.any? }
      
      if recent_results.any?
        total_tests = recent_results.sum { |r| r.values.length }
        failed_tests = recent_results.sum do |r|
          r.values.count { |test| test.is_a?(Hash) && test['status'] == 'failed' }
        end
        
        failure_rate = total_tests > 0 ? (failed_tests.to_f / total_tests * 100) : 0
        health_score -= failure_rate * 2  # Penalty for failures
      end
    end
    
    [health_score, 0].max.round(1)
  end

  def calculate_coverage_health
    health_score = 100
    
    # Check coverage trend
    if @metrics_history.length >= 5
      recent_coverage = @metrics_history.last(5).map { |m| m['coverage_health'] || 88.7 }
      coverage_trend = recent_coverage.last - recent_coverage.first
      
      if coverage_trend < -@config['alert_thresholds']['coverage_drop']
        health_score -= (coverage_trend.abs * 2)
      end
    end
    
    # Current coverage simulation (replace with actual SimpleCov data)
    current_coverage = 88.7
    health_score = [health_score, current_coverage].min
    
    [health_score, 0].max.round(1)
  end

  def calculate_performance_health
    health_score = 100
    
    # Check performance metrics
    if File.exist?(File.join(@base_path, 'performance_metrics.json'))
      metrics = JSON.parse(File.read(File.join(@base_path, 'performance_metrics.json'))) rescue {}
      
      # Check test execution times
      smoke_time = metrics.dig('smoke_tests', 'execution_time') || 1.08
      fast_time = metrics.dig('fast_tests', 'execution_time') || 1.36
      
      # Performance thresholds
      if smoke_time > 2.0
        health_score -= 20
      end
      
      if fast_time > 30.0
        health_score -= 30
      end
    end
    
    [health_score, 0].max.round(1)
  end

  def calculate_integration_health
    health_score = 100
    
    # Check production readiness score
    if File.exist?(File.join(@base_path, 'production_validation_results.json'))
      results = JSON.parse(File.read(File.join(@base_path, 'production_validation_results.json'))) rescue {}
      overall_score = results['overall_score'] || 85
      
      health_score = overall_score
    end
    
    [health_score, 0].max.round(1)
  end

  def calculate_health_score(metrics)
    weights = {
      test_health: 0.3,
      coverage_health: 0.25,
      performance_health: 0.25,
      integration_health: 0.2
    }
    
    weighted_score = weights.sum do |metric, weight|
      (metrics[metric] || 0) * weight
    end
    
    weighted_score.round(1)
  end

  def analyze_trends(metrics)
    return unless @metrics_history.length >= 3
    
    # Analyze coverage trend
    recent_coverage = @metrics_history.last(3).map { |m| m[:coverage_health] }
    if recent_coverage.all? { |c| c < recent_coverage.first }
      puts "⚠️  Coverage declining trend detected"
    end
    
    # Analyze performance trend
    recent_performance = @metrics_history.last(3).map { |m| m[:performance_health] }
    if recent_performance.all? { |p| p < recent_performance.first }
      puts "⚠️  Performance declining trend detected"
    end
  end

  def check_alert_conditions(metrics)
    alerts = []
    
    # Coverage alerts
    if metrics[:coverage_health] < 80
      alerts << {
        type: 'coverage_low',
        severity: 'warning',
        message: "Coverage health below 80%: #{metrics[:coverage_health]}%",
        timestamp: Time.now.to_i
      }
    end
    
    # Performance alerts
    if metrics[:performance_health] < 70
      alerts << {
        type: 'performance_degraded',
        severity: 'warning',
        message: "Performance health below 70%: #{metrics[:performance_health]}%",
        timestamp: Time.now.to_i
      }
    end
    
    # Integration alerts
    if metrics[:integration_health] < 90
      alerts << {
        type: 'integration_issues',
        severity: 'info',
        message: "Integration health below 90%: #{metrics[:integration_health]}%",
        timestamp: Time.now.to_i
      }
    end
    
    # Send alerts
    alerts.each { |alert| send_alert(alert) }
    
    # Save alerts
    save_alerts(alerts) if alerts.any?
  end

  def send_alert(alert)
    puts "🚨 ALERT [#{alert[:severity].upcase}]: #{alert[:message]}"
    
    # Additional notification channels can be added here
    # (email, Slack, webhooks, etc.)
  end

  def save_alerts(alerts)
    existing_alerts = []
    if File.exist?(@alerts_file)
      existing_alerts = JSON.parse(File.read(@alerts_file)) rescue []
    end
    
    existing_alerts.concat(alerts)
    
    # Keep only recent alerts
    cutoff_time = Time.now.to_i - (7 * 24 * 60 * 60)  # 7 days
    existing_alerts = existing_alerts.select { |a| a['timestamp'] > cutoff_time }
    
    File.write(@alerts_file, JSON.pretty_generate(existing_alerts))
  end

  def update_dashboard(metrics)
    health_score = calculate_health_score(metrics)
    
    dashboard_html = generate_dashboard_html(metrics, health_score)
    File.write(@dashboard_file, dashboard_html)
  end

  def generate_dashboard_html(metrics, health_score)
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
          <title>PATLANG System Monitoring Dashboard</title>
          <meta charset="UTF-8">
          <meta http-equiv="refresh" content="#{@config['dashboard_refresh']}">
          <style>
              body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
              .header { background: #2c3e50; color: white; padding: 20px; border-radius: 5px; }
              .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin: 20px 0; }
              .metric-card { background: white; padding: 20px; border-radius: 5px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
              .metric-value { font-size: 2em; font-weight: bold; color: #3498db; }
              .metric-label { color: #7f8c8d; text-transform: uppercase; font-size: 0.9em; }
              .health-excellent { color: #27ae60; }
              .health-good { color: #f39c12; }
              .health-poor { color: #e74c3c; }
              .status-bar { background: white; padding: 15px; border-radius: 5px; margin: 10px 0; }
              .timestamp { text-align: right; color: #7f8c8d; font-size: 0.9em; }
          </style>
      </head>
      <body>
          <div class="header">
              <h1>🔍 PATLANG System Monitoring Dashboard</h1>
              <p>Real-time system health and performance monitoring</p>
          </div>
          
          <div class="status-bar">
              <h2>Overall System Health: <span class="health-#{health_score >= 90 ? 'excellent' : health_score >= 70 ? 'good' : 'poor'}">#{health_score}/100</span></h2>
              <div class="timestamp">Last updated: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}</div>
          </div>
          
          <div class="metrics">
              <div class="metric-card">
                  <div class="metric-label">Test Health</div>
                  <div class="metric-value health-#{metrics[:test_health] >= 90 ? 'excellent' : metrics[:test_health] >= 70 ? 'good' : 'poor'}">#{metrics[:test_health]}/100</div>
              </div>
              
              <div class="metric-card">
                  <div class="metric-label">Coverage Health</div>
                  <div class="metric-value health-#{metrics[:coverage_health] >= 90 ? 'excellent' : metrics[:coverage_health] >= 70 ? 'good' : 'poor'}">#{metrics[:coverage_health]}/100</div>
              </div>
              
              <div class="metric-card">
                  <div class="metric-label">Performance Health</div>
                  <div class="metric-value health-#{metrics[:performance_health] >= 90 ? 'excellent' : metrics[:performance_health] >= 70 ? 'good' : 'poor'}">#{metrics[:performance_health]}/100</div>
              </div>
              
              <div class="metric-card">
                  <div class="metric-label">Integration Health</div>
                  <div class="metric-value health-#{metrics[:integration_health] >= 90 ? 'excellent' : metrics[:integration_health] >= 70 ? 'good' : 'poor'}">#{metrics[:integration_health]}/100</div>
              </div>
          </div>
          
          <div class="status-bar">
              <h3>🚀 Quick Actions</h3>
              <p>• <strong>Run Tests:</strong> <code>rake smart:fast</code></p>
              <p>• <strong>Coverage Analysis:</strong> <code>cd test && ruby coverage_analysis.rb</code></p>
              <p>• <strong>Production Validation:</strong> <code>cd test && ruby production_readiness_validator.rb</code></p>
              <p>• <strong>Health Report:</strong> <code>cd test && ruby real_time_monitoring_system.rb health</code></p>
          </div>
      </body>
      </html>
    HTML
  end

  def save_metrics
    File.write(@metrics_file, JSON.pretty_generate(@metrics_history))
  end

  def generate_health_recommendations(metrics)
    recommendations = []
    
    if metrics[:test_health] < 90
      recommendations << "Review and fix failing tests to improve test health"
    end
    
    if metrics[:coverage_health] < 85
      recommendations << "Add tests for uncovered code areas to improve coverage"
    end
    
    if metrics[:performance_health] < 80
      recommendations << "Optimize slow tests and improve test execution performance"
    end
    
    if metrics[:integration_health] < 95
      recommendations << "Complete remaining system integration components"
    end
    
    recommendations
  end
end

# CLI Interface
if __FILE__ == $0
  monitor = RealTimeMonitoringSystem.new
  
  case ARGV[0]
  when 'start', 'monitor'
    monitor.start_monitoring
  when 'health', 'report'
    monitor.generate_health_report
  when 'dashboard'
    metrics = monitor.send(:collect_system_metrics)
    monitor.send(:update_dashboard, metrics)
    puts "📊 Dashboard updated: test/monitoring_dashboard.html"
  else
    puts "📊 PATLANG Real-time Monitoring System v#{RealTimeMonitoringSystem::VERSION}"
    puts "Usage:"
    puts "  ruby real_time_monitoring_system.rb start    # Start continuous monitoring"
    puts "  ruby real_time_monitoring_system.rb health   # Generate health report"
    puts "  ruby real_time_monitoring_system.rb dashboard # Update dashboard"
  end
end