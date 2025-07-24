# frozen_string_literal: true

module PerformanceMonitoring
  extend ActiveSupport::Concern

  included do
    around_action :monitor_performance
  end

  private

  def monitor_performance
    start_time = Time.current
    start_memory = GetProcessMem.new.mb
    
    yield
    
    end_time = Time.current
    end_memory = GetProcessMem.new.mb
    
    duration = (end_time - start_time) * 1000 # Convert to milliseconds
    memory_used = end_memory - start_memory
    
    # Log slow requests
    if duration > 500 # Log requests taking more than 500ms
      Rails.logger.warn "SLOW_REQUEST: #{request.path} took #{duration.round(2)}ms, memory: #{memory_used.round(2)}MB"
    end
    
    # Log high memory usage
    if memory_used > 50 # Log requests using more than 50MB
      Rails.logger.warn "HIGH_MEMORY: #{request.path} used #{memory_used.round(2)}MB in #{duration.round(2)}ms"
    end
  end
end