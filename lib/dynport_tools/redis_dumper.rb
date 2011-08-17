require "dynport_tools"
require "redis"

class DynportTools::RedisDumper
  attr_accessor :redis
  
  def initialize(redis = nil)
    self.redis = redis
  end
  
  def zset_to_hash(key, window = 10_000)
    hash = {}
    offset = 0
    while true
      values = redis.zrevrange(key, offset, offset + (window - 1), :with_scores => true)
      current_key = nil
      values.each do |value|
        if current_key.nil?
          current_key = value
        else
          hash[current_key] = value
          current_key = nil
        end
      end
      offset += window
      break if values.length < window * 2
    end
    hash
  end
  
  def dump_hash(hash)
    hash.each do |key, value|
      puts [key, value].join("\t")
    end
  end
  
  def run_from_args(args)
    host, port, key = args
    if key
      self.redis = Redis.new(:host => host, :port => port)
      key_type = redis.type(key)
      if key_type == "zset"
        dump_hash(zset_to_hash(key))
      else
        $stderr.puts "only zsets are supported for now"
        exit(1)
      end
    else
      print_usage_and_die
    end
  end

  def print_usage_and_die
    $stderr.puts "USAGE: redis_dumper <redis_host> <redis_port> <key>"
    exit(1)
  end
end