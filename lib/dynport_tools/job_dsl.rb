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
    
    [
      :node, :disabled, :days_to_keep, :num_to_keep, :notify, :cron_patterns, :locks, :commands, :ordered, :rails_root,
      :rails_env
    ].each do |method|
      attr_writer method
      
      define_method(method) do |*values, &block|
        self.setter_or_getter(method, *values, &block)
      end
    end
    
    alias_method :cron_pattern, :cron_patterns
    alias_method :lock, :locks
    alias_method :command, :commands
    alias_method :prefix, :ordered
    
    def disabled!(&block)
      disabled(true, &block)
    end
    
    def use_rails3!
      @rails3 = true
    end
    
    def use_bundle_exec!
      @bundle_exec = true
    end
    
    def rails_command(cmd, options = {})
      rails_command_or_script(%("#{cmd.gsub('"', '\\"')}"), options)
    end
    
    def rails_script(*args)
      rails_command_or_script(*args)
    end
    
    def rake_task(task, options = {})
      options[:env] = (options[:env] || {}).merge("RAILS_ENV" => options[:rails_env]) if options[:rails_env]
      command "cd #{rails_root} && " + command_with_env("rake #{task}", options[:env])
    end
    
    def rails_command_or_script(cmd_or_script, options = {})
      raise "rails_root must be set" if rails_root.nil?
      command %(cd #{rails_root} && #{command_with_env(runner_command(options[:rails_env]), options[:env])} #{cmd_or_script})
    end
    
    def runner_command(env = nil)
      env ||= rails_env
      [@rails3 ? "rails runner" : "./script/runner", env ? "-e #{env}" : nil].compact.join(" ")
    end
    
    def command_with_env(cmd, env = {})
      ((env || {}).sort.map { |key, value| "#{key}=#{value}" } + [@bundle_exec ? "bundle exec" : nil, cmd].compact).join(" ")
    end
    
    def with(options, &block)
      old_scope = self.current_scope
      self.current_scope = self.current_scope.merge(options)
      self.instance_eval(&block)
      self.current_scope = old_scope
    end
    
    def current_prefix
      self.current_scope[:ordered] || self.current_scope[:prefix]
    end
    
    def setter_or_getter(key, *values, &block)
      value = MULTIPLE.include?(key) ? values : values.first
      if block_given?
        with(key => value, &block)
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