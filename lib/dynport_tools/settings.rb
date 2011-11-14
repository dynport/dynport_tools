class Settings
  SETTINGS_KEY = "settings"
  SETTINGS_UPDATED_AT_KEY = "#{SETTINGS_KEY}/updated_at"
  
  class << self
    attr_accessor :redis, :defaults

    def set(key_or_hash, default_or_nil = nil)
      self.defaults ||= Hash.new
      if key_or_hash.is_a?(Hash)
        key_or_hash.each do |key, default|
          self.defaults[key.to_sym] = default
          define_methods_for_key_and_default(key.to_sym, default)
        end
      elsif !default_or_nil.nil?
        self.defaults[key_or_hash.to_sym] = default_or_nil
        define_methods_for_key_and_default(key_or_hash.to_sym, default_or_nil)
      end
    end
    
    def define_methods_for_key_and_default(key, default)
      self.class.send(:define_method, key) do
        get(key)
      end
      
      self.class.send(:define_method, :"set_#{key}") do |value|
        set_value(key, value)
      end
      
      # bool methods
      if [true, false].include?(default)
        self.class.send(:define_method, "#{key}?") do
          get(key)
        end
        
        self.class.send(:define_method, :"disable_#{key}!") do
          set_value(key, false)
        end
        
        self.class.send(:define_method, :"enable_#{key}!") do
          set_value(key, true)
        end
      end
    end
    
    def set_value(key, value)
      time = Time.now
      redis.multi do
        redis.hset(SETTINGS_KEY, key, value)
        redis.set(SETTINGS_UPDATED_AT_KEY, time.to_i)
      end
      reload!(time)
    end
    
    def convert_value_for_key(key, value)
      if defaults[key].is_a?(Numeric)
        value.to_i
      elsif [true, false].include?(defaults[key])
        value == "true"
      else
        value.to_s
      end
    end
    
    def get(key)
      if value = all[key.to_s]
        convert_value_for_key(key, value)
      else
        defaults[key]
      end
    end
    
    def all
      if @all.nil? || expired?
        reload!
      end
      @all
    end
    
    def reload!(timestamp = nil)
      @all = redis.hgetall(SETTINGS_KEY) 
      @cached_at = timestamp || Time.now
    end
    
    def expired?
      @cached_at && Time.now - @cached_at > 60
    end
    
    def changed?
      @cached_at.nil? || redis.get(SETTINGS_UPDATED_AT_KEY).to_i != @cached_at.to_i
    end
  end
end