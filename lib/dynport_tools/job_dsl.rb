class Jenkins
  class JobDSL
    class << self
      attr_accessor :jobs
      
      def setup(namespace = :default, &block)
        dsl = self.new
        dsl.instance_eval(&block) if block_given?
        self.jobs ||= {}
        self.jobs[namespace] ||= Array.new
        self.jobs[namespace] += dsl.jobs
        self.jobs[namespace]
      end
    end
    
    attr_accessor :name, :jobs, :current_scope, :current_prefix
    
    def initialize(options = {})
      options.each do |key, value|
        self.send(:"#{key}=", value) if self.respond_to?(:"#{key}=")
      end
      self.jobs = []
      self.current_scope = {}
    end
    
    MULTIPLE = [:notify, :cron_patterns, :locks, :commands]
    
    [:node, :disabled, :days_to_keep, :num_to_keep, :notify, :cron_patterns, :locks, :commands].each do |method|
      attr_writer method
      
      define_method(method) do |*values, &block|
        self.setter_or_getter(method, *values, &block)
      end
    end
    
    alias_method :cron_pattern, :cron_patterns
    alias_method :lock, :locks
    alias_method :command, :commands
    
    def disabled!(&block)
      disabled(true, &block)
    end
    
    def with_options(options, &block)
      old_scope = self.current_scope
      self.current_scope = self.current_scope.merge(options)
      self.instance_eval(&block)
      self.current_scope = old_scope
    end
    
    def ordered(prefix, &block)
      self.current_prefix = prefix
      self.instance_eval(&block)
      self.current_prefix = nil
    end
    
    def setter_or_getter(key, *values, &block)
      value = MULTIPLE.include?(key) ? values : values.first
      if block_given?
        with_options(key => value, &block)
      elsif ![[], nil].include?(value)
        self.send(:"#{key}=", value)
      end
      self.instance_variable_get("@#{key}")
    end
    
    def job(name, &block)
      if current_prefix
        @prefix_indexes ||= Hash.new(0)
        name = "#{current_prefix}%03d %s" % [@prefix_indexes[current_prefix] += 1, name]
      end
      job = JobDSL.new(self.current_scope.merge(:name => name))
      job.instance_eval(&block) if block_given?
      self.jobs << job
    end
  end
end