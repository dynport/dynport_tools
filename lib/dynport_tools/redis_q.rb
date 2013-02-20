class DynportTools::RedisQ
  DEFAULTS = { retry_count: 3 }
  attr_accessor :redis_key, :retry_count, :redis
  
  def initialize(redis_key, options = {})
    DEFAULTS.merge(options).merge(redis_key: redis_key).each do |key, value|
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
    redis.pipelined do
      array.each do |(id, popularity)|
        @priorities ||= {}
        @priorities[redis_key] ||= {}
        @priorities[redis_key][id] = redis.zscore(redis_key, id)
      end
    end
 
    response = redis.multi do
      array.each do | (id, popularity) |
        (id.is_a?(Hash) ? id : { id => popularity }).each do |id2, popularity2|
          push(id2, popularity2, options.merge(no_multi: true))
        end
      end
    end
    @priorities = {}
    response
  end
  
  def nil_or_lower?(a, b)
    a.nil? || a.to_i < b
  end
  
  def priority_of(id)
    @priorities ||= {}
    @priorities[redis_key] ||= {}
    future = @priorities[redis_key][id]
    if future
      future.value
    end
  end
  
  def count
    redis.zcard(redis_key)
  end
  
  def pop(number = 1)
    response = redis.multi do
      redis.zrevrange(redis_key, 0, number - 1, with_scores: true)
      redis.zremrangebyrank(redis_key, 0 - number, -1)
    end
    Hash[response.first]
  end
  
  def failed_tries
    @failed_tries ||= Hash.new(0)
  end
  
  def each(options = {})
    entries_with_errors = []
    stats = { errors: {}, ok: [] }
    batch_size = options[:batch_size].to_i if options[:batch_size].to_i > 0
    while (result_hash = pop(batch_size || 1)).any?
      begin
        yield(batch_size ? result_hash.to_a.sort_by { |a| a.last }.reverse.map { |a| a.first } : result_hash.keys.first)
        stats[:ok] << result_hash.keys.join(",")
      rescue => err
        stats[:errors][result_hash.keys.join(",")] = ([err.message] + err.backtrace[0,5]).join("\n")
        entries_with_errors << result_hash if mark_failed(result_hash.keys.join(",")) < retry_count
      end
    end
    push_many(entries_with_errors, failed: true) if entries_with_errors.any?
    stats
  end
  
  def mark_failed(id)
    redis.zincrby(failed_key, 1, id).to_i
  end
  
  def failed_key
    "#{redis_key}/failed_counts"
  end
end
