class DynportTools::ETA
  attr_accessor :total, :current, :started
  
  def initialize(options = {})
    options.each do |key, value|
      self.send(:"#{key}=", value) if self.respond_to?(:"#{key}=")
    end
  end
  
  def percs
    raise_error_when_current_or_total_not_set
    current.to_f / total
  end
  
  def pending
    raise_error_when_current_or_total_not_set
    total - current
  end
  
  def running_for
    Time.now - started
  end
  
  def total_time
    running_for / percs
  end
  
  def to_go
    total_time - running_for
  end
  
  def eta
    Time.now + to_go
  end
  
  def per_second
    current / running_for
  end
  
  def to_s
    "%.2f%%, %.2f/second, ETA: %s" % [percs * 100, per_second, eta.iso8601]
  end
  
  def raise_error_when_current_or_total_not_set
    raise "current and total must be set" if total.nil? || current.nil?
  end
  
  class << self
    FACTORS = [1, 60, 3600]
    
    def parse_time_string(string)
      sum = 0.0
      string.split(":").map { |s| s.to_i }.reverse.each_with_index do |value, i|
        sum += value * FACTORS[i]
      end
      sum
    end
    
    def from_time_string(string, options = {})
      self.new(options.merge(:started => Time.now - parse_time_string(string)))
    end
  end
end