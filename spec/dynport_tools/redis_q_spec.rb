require 'spec_helper'
require "fileutils"

describe DynportTools::RedisQ do
  let(:redis_dir) { File.expand_path("../../../tmp/redis", __FILE__) }
  let(:redis_config_path) { "#{redis_dir}/redis.config" }
  let(:redis_socket_path) { "#{redis_dir}/redis.socket" }
  let(:redis_pid_path) { "#{redis_dir}/redis.pid" }
  
  def init_redis!
    FileUtils.mkdir_p(redis_dir)
    File.open(redis_config_path, "w") do |f|
      f.puts("port 0")
      f.puts("daemonize yes")
      f.puts("unixsocket #{redis_socket_path}")
      f.puts("pidfile #{redis_pid_path}")
    end
    begin
      Redis.current = Redis.new(path: redis_socket_path)
      Redis.current.info
    rescue
      system "redis-server #{redis_config_path}"
      20.times do
        begin
          Redis.current.info
          break
        rescue
          sleep 0.1
        end
      end
    end
  end
  
  before(:each) do
    init_redis!
  end
  
  let(:redis) { Redis.current }
  
  let(:key) { "test/redis_queue" }
  let(:queue) do 
    q = DynportTools::RedisQ.new(key)
    q.redis = redis
    q
  end
  
  before(:each) do
    redis.del(key)
    redis.del("test/redis_queue/failed_counts")
  end
  
  describe "#initialize" do
    it "sets the retry_count to the default value when nil" do
      expect(DynportTools::RedisQ.new("some/queue").retry_count).to eql(3)
    end
    
    it "sets the retry_count to a custom value when given" do
      expect(DynportTools::RedisQ.new("some/queue", retry_count: 2).retry_count).to eql(2)
    end
    
    it "sets the redis_key" do
      expect(DynportTools::RedisQ.new("some/queue").redis_key).to eql("some/queue")
    end
    
    it "sets the redis connection" do
      expect(DynportTools::RedisQ.new("some/queue", redis: "redis con").redis).to eql("redis con")
    end
  end
  
  it "sets the redis key when initializing" do
    queue = DynportTools::RedisQ.new("some/queue")
    expect(queue.redis_key).to eql("some/queue")
  end
  
  describe "#push_many" do
    it "pushes nested arrays" do
      queue.push_many([[1, 2], [3, 4]])
      expect(redis.zrevrange(key, 0, -1, with_scores: true)).to eql([["3", 4.0], ["1", 2.0]])
    end
    
    it "also pushes hashes" do
      queue.push_many({ 2 => 4, 6 => 8})
      expect(redis.zrevrange(key, 0, -1, with_scores: true)).to eql([["6", 8.0], ["2", 4.0]])
    end
    
    it "adds arrays of hashes" do
      queue.push_many([{ 2 => 4 }, { 6 => 8}])
      expect(redis.zrevrange(key, 0, -1, with_scores: true)).to eql([["6", 8.0], ["2", 4.0]])
    end
  end
  
  describe "#push" do
    it "pushes the records with negative timestamps" do
      Timecop.freeze(Time.at(112233)) do
        queue.push(99)
      end
      Timecop.freeze(Time.at(112235)) do
        queue.push(101)
      end
      expect(redis.zrevrange(key, 0, -1, with_scores: true)).to eql([["99", -112233.0], ["101", -112235.0]])
    end
    
    it "does not push records when already on the queue" do
      Timecop.freeze(Time.at(112233)) do
        queue.push_many([99])
      end
      Timecop.freeze(Time.at(112235)) do
        queue.push_many([99])
      end
      expect(redis.zrevrange(key, 0, -1, with_scores: true)).to eql([["99", -112233.0]])
    end
    
    it "changes the priority of a member when higher" do
      queue.push(99, 1)
      queue.push(99, 2)
      expect(redis.zrevrange(key, 0, -1, with_scores: true)).to eql([["99", 2.0]])
    end
    
    it "uses a custom priority when given" do
      queue.push(99, 1234)
      expect(redis.zrevrange(key, 0, -1, with_scores: true)).to eql([["99", 1234.0]])
    end
    
    it "removes the key from the failed zset" do
      queue.mark_failed("99")
      expect(redis.zrevrange("test/redis_queue/failed_counts", 0, -1, with_scores: true)).to eql([["99", 1.0]])
      queue.push(99, 1234)
      expect(redis.zrevrange("test/redis_queue/failed_counts", 0, -1, with_scores: true)).to eql([])
    end
    
    it "does not call redis.multi when no_multi is set to true" do
      redis.should_not_receive(:multi)
      queue.push(99, 1234, no_multi: true)
    end
    
    it "does not call redis.zrem when failed is true" do
      redis.should_not_receive(:zrem)
      queue.push(99, 1234, failed: true)
    end
  end
  
  it "returns the correct number of elements" do
    expect(queue.count).to eql(0)
    queue.push(99, 1234)
    queue.push(101, 1234)
    expect(queue.count).to eql(2)
  end
  
  describe "#pop" do
    before(:each) do
      queue.push(98, 10)
      queue.push(99, 1)
      queue.push(101, 100)
    end
    
    it "returns the highest member and rank" do
      expect(queue.pop).to eql({ "101" => 100.0 })
    end
    
    it "can also return 2 elements" do
      expect(queue.pop(2)).to eql({ "101" => 100.0, "98" => 10.0 })
      expect(redis.zrevrange(key, 0, -1, with_scores: true)).to eql([["99", 1.0]])
    end
    
    it "can also return 3 elements" do
      queue.push("1", "0")
      expect(queue.pop(3)).to eql({ "101" => 100.0, "98" => 10.0, "99" => 1.0 })
      expect(redis.zrevrange(key, 0, -1, with_scores: true)).to eql([["1", 0.0]])
    end
    
    it "removes the member from the set" do
      queue.pop
      expect(redis.zrevrange(key, 0, -1, with_scores: true)).to eql([["98", 10.0], ["99", 1.0]])
    end
    
    it "returns an empty array when nothing in the queue" do
      queue.pop
      queue.pop
      queue.pop
      expect(queue.pop).to eql({})
    end
  end
  
  describe "#each" do
    it "calls the block with all members in the queue" do
      queue.push(99, 1)
      queue.push(100, 9)
      queue.push(101, 0)
      ids = []
      queue.each do |id|
        ids << id
      end
      expect(ids).to eql(["100", "99", "101"])
      expect(redis.zrevrange(key, 0, -1, with_scores: true)).to eql([])
    end
    
    it "is able to yield batches" do
      queue.push(99, 1)
      queue.push(100, 9)
      queue.push(101, 0)
      all_ids = []
      queue.each(batch_size: 2) do |ids|
        all_ids << ids
      end
      expect(all_ids).to eql([["100", "99"], ["101"]])
      expect(redis.zrevrange(key, 0, -1, with_scores: true)).to eql([])
    end
    
    it "readds all ids to the queue which raised errors" do
      queue.push(99, 1)
      queue.push(100, 9)
      queue.push(101, 0)
      processor = double("processor")
      processor.should_receive(:process).with("99").and_return true
      processor.should_receive(:process).with("101").and_return true
      processor.should_receive(:process).with("100").and_raise("some error")
      stats = queue.each do |id|
        processor.process(id)
      end
      expect(stats[:ok]).to eql(["99", "101"])
      stats[:errors]["100"].should match(/^some error/)
      expect(redis.zrevrange(key, 0, -1, with_scores: true)).to eql([["100", 9.0]])
    end
    
    # change this to n times
    it "only tries to process one failing id 3 times" do
      queue.push(100, 9)
      processor = double("processor")
      processor.stub(:process).with("100").exactly(3).and_raise("some error")
      
      stats = queue.each { |id| processor.process(id) } 
      expect(redis.zrevrange(key, 0, -1, with_scores: true)).to eql([["100", 9.0]])
      expect(redis.zrevrange("test/redis_queue/failed_counts", 0, -1, with_scores: true)).to eql([["100", 1.0]])
      
      stats = queue.each { |id| processor.process(id) } 
      expect(redis.zrevrange(key, 0, -1, with_scores: true)).to eql([["100", 9.0]])
      expect(redis.zrevrange("test/redis_queue/failed_counts", 0, -1, with_scores: true)).to eql([["100", 2.0]])
      
      stats = queue.each { |id| processor.process(id) } 
      expect(redis.zrevrange(key, 0, -1, with_scores: true)).to eql([])
      expect(redis.zrevrange("test/redis_queue/failed_counts", 0, -1, with_scores: true)).to eql([["100", 3.0]])
    end
  end
  
  describe "#mark_failed" do
    it "increments the counter in the zset" do
      queue.mark_failed("100")
      expect(redis.zrevrange("test/redis_queue/failed_counts", 0, -1, with_scores: true)).to eql([["100", 1.0]])
    end
    
    it "returns the new failed count" do
      expect(queue.mark_failed("100")).to eql(1)
      expect(queue.mark_failed("100")).to eql(2)
    end
  end
end
