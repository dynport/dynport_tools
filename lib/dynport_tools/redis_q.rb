class DynportTools::RedisQ
  DEFAULTS = { :retry_count => 3 }
  attr_accessor :redis_key, :retry_count, :redis
  
  def initialize(redis_key, options = {})
    DEFAULTS.merge(options).merge(:redis_key => redis_key).each do |key, value|
      self.send(:"#{key}=", value) if self.respond_to?(:"#{key}=")
    end
  end
  
  def push(id, priority = nil, options = {})
    priority ||= Time.now.to_i * -1
    if nil_or_lower?(priority_of(id), priority)
      redis.multi if !options[:no_multi]
      redis.zrem(failed_key, id) if !options[:failed]
      redis.zadd(redis_key, priority, id)
      redis.exec if !options[:no_multi]
    end
  end
  
  def push_many(array, options = {})
    redis.multi do
     array.each do | (id, popularity) |
        push(id, popularity, options.merge(:no_multi => true))
      end
    end
  end
  
  def nil_or_lower?(a, b)
    a.nil? || a.to_i < b
  end
  
  def priority_of(id)
    redis.zscore(redis_key, id)
  end
  
  def count
    redis.zcard(redis_key)
  end
  
  def pop
    redis.multi do
      redis.zrevrange(redis_key, 0, 0, :with_scores => true)
      redis.zremrangebyrank(redis_key, -1, -1)
    end.first
  end
  
  def failed_tries
    @failed_tries ||= Hash.new(0)
  end
  
  def each
    entries_with_errors = []
    stats = { :errors => {}, :ok => [] }
    while (result = pop).any?
      begin
        yield(result.first)
        stats[:ok] << result.first
      rescue => err
        stats[:errors][result.first] = ([err.message] + err.backtrace[0,5]).join("\n")
        entries_with_errors << result if mark_failed(result.first) < retry_count
      end
    end
    push_many(entries_with_errors, :failed => true) if entries_with_errors.any?
    stats
  end
  
  def mark_failed(id)
    redis.zincrby(failed_key, 1, id).to_i
  end
  
  def failed_key
    "#{redis_key}/failed_counts"
  end
end