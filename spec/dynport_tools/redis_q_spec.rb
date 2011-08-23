require 'spec_helper'

describe DynportTools::RedisQ do
  let(:key) { "test/redis_queue" }
  let(:redis) { Redis.new(:path => root.join("tmp/redis.socket")) }
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
      DynportTools::RedisQ.new("some/queue").retry_count.should == 3
    end
    
    it "sets the retry_count to a custom value when given" do
      DynportTools::RedisQ.new("some/queue", :retry_count => 2).retry_count.should == 2
    end
    
    it "sets the redis_key" do
      DynportTools::RedisQ.new("some/queue").redis_key.should == "some/queue"
    end
    
    it "sets the redis connection" do
      DynportTools::RedisQ.new("some/queue", :redis => "redis con").redis.should == "redis con"
    end
  end
  
  it "sets the redis key when initializing" do
    queue = DynportTools::RedisQ.new("some/queue")
    queue.redis_key.should == "some/queue"
  end
  
  describe "#push" do
    it "pushes the records with negative timestamps" do
      Timecop.freeze(Time.at(112233))
      queue.push(99)
      Timecop.freeze(Time.at(112235))
      queue.push(101)
      redis.zrevrange(key, 0, -1, :with_scores => true).should == ["99", "-112233", "101", "-112235"]
    end
    
    it "does not push records when already on the queue" do
      Timecop.freeze(Time.at(112233))
      queue.push(99)
      Timecop.freeze(Time.at(112235))
      queue.push(99)
      redis.zrevrange(key, 0, -1, :with_scores => true).should == ["99", "-112233"]
    end
    
    it "changes the priority of a member when higher" do
      queue.push(99, 1)
      queue.push(99, 2)
      redis.zrevrange(key, 0, -1, :with_scores => true).should == ["99", "2"]
    end
    
    it "uses a custom priority when given" do
      queue.push(99, 1234)
      redis.zrevrange(key, 0, -1, :with_scores => true).should == ["99", "1234"]
    end
    
    it "removes the key from the failed zset" do
      queue.mark_failed("99")
      redis.zrevrange("test/redis_queue/failed_counts", 0, -1, :with_scores => true).should == ["99", "1"]
      queue.push(99, 1234)
      redis.zrevrange("test/redis_queue/failed_counts", 0, -1, :with_scores => true).should == []
    end
    
    it "does not call redis.multi when no_multi is set to true" do
      redis.should_not_receive(:multi)
      queue.push(99, 1234, :no_multi => true)
    end
    
    it "does not call redis.zrem when failed is true" do
      redis.should_not_receive(:zrem)
      queue.push(99, 1234, :failed => true)
    end
  end
  
  it "returns the correct number of elements" do
    queue.count.should == 0
    queue.push(99, 1234)
    queue.push(101, 1234)
    queue.count.should == 2
  end
  
  describe "#pop" do
    before(:each) do
      queue.push(98, 10)
      queue.push(99, 1)
      queue.push(101, 100)
    end
    
    it "returns the highest member and rank" do
      queue.pop.should == ["101", "100"]
    end
    
    it "removes the member from the set" do
      queue.pop
      redis.zrevrange(key, 0, -1, :with_scores => true).should == ["98", "10", "99", "1"]
    end
    
    it "returns an empty array when nothing in the queue" do
      queue.pop
      queue.pop
      queue.pop
      queue.pop.should == []
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
      ids.should == ["100", "99", "101"]
      redis.zrevrange(key, 0, -1, :with_scores => true).should == []
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
      stats[:ok].should == ["99", "101"]
      stats[:errors]["100"].should match(/^some error/)
      redis.zrevrange(key, 0, -1, :with_scores => true).should == ["100", "9"]
    end
    
    # change this to n times
    it "only tries to process one failing id 3 times" do
      queue.push(100, 9)
      processor = double("processor")
      processor.stub(:process).with("100").exactly(3).and_raise("some error")
      
      stats = queue.each { |id| processor.process(id) } 
      redis.zrevrange(key, 0, -1, :with_scores => true).should == ["100", "9"]
      redis.zrevrange("test/redis_queue/failed_counts", 0, -1, :with_scores => true).should == ["100", "1"]
      
      stats = queue.each { |id| processor.process(id) } 
      redis.zrevrange(key, 0, -1, :with_scores => true).should == ["100", "9"]
      redis.zrevrange("test/redis_queue/failed_counts", 0, -1, :with_scores => true).should == ["100", "2"]
      
      stats = queue.each { |id| processor.process(id) } 
      redis.zrevrange(key, 0, -1, :with_scores => true).should == []
      redis.zrevrange("test/redis_queue/failed_counts", 0, -1, :with_scores => true).should == ["100", "3"]
    end
  end
  
  describe "#mark_failed" do
    it "increments the counter in the zset" do
      queue.mark_failed("100")
      redis.zrevrange("test/redis_queue/failed_counts", 0, -1, :with_scores => true).should == ["100", "1"]
    end
    
    it "returns the new failed count" do
      queue.mark_failed("100").should == 1
      queue.mark_failed("100").should == 2
    end
  end
end
