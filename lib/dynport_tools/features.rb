class DynportTools::Features
  class << self
    attr_accessor :features, :redis
    
    def feature(name)
      self.features ||= Array.new
      self.features << name
      self.class.send(:define_method, :"#{name}_enabled_for?") do |user, &block|
        enabled = !user.nil? && redis.sismember("features/#{name}/users", user.id.to_s)
        block.call if enabled && block
        enabled
      end
    end
    
    def add_user(feature, user)
      raise "feature #{feature} not defined" if !(features || []).include?(feature)
      redis.sadd("features/#{feature}/users", user.id)
    end
    
    def remove_user(feature, user)
      redis.srem("features/#{feature}/users", user.id)
    end
  end
end