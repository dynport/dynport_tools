require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require "dynport_tools/redis_dumper"

describe "DynportTools::RedisDumper" do
  let(:redis) { double("redis", :type => "zset") }
  let(:dumper) { DynportTools::RedisDumper.new(redis) }
  
  describe "#initialize" do
    it "can be initialized with redis" do
      redis = double("redis")
      dumper = DynportTools::RedisDumper.new(redis)
      dumper.redis.should == redis
    end
  end
  
  describe "#zset_to_hash" do
    it "calls zrevrange the correct number of times" do
      redis.should_receive(:zrevrange).with("redis_key", 0, 1, :with_scores => true).and_return(["1", "2", "2", "4"])
      redis.should_receive(:zrevrange).with("redis_key", 2, 3, :with_scores => true).and_return(["3", "2"])
      dumper.zset_to_hash("redis_key", 2).should == { "1" => "2", "2" => "4", "3" => "2" }
    end
    
    it "only calls once when window is big enough" do
      redis.should_receive(:zrevrange).with("redis_key", 0, 9999, :with_scores => true).and_return(["1", "2", "2", "4"])
      dumper.zset_to_hash("redis_key").should == { "1" => "2", "2" => "4" }
    end
  end
  
  describe "#dump_hash" do
    it "calls puts the correct lines" do
      dumper.should_receive(:puts).with("a\t1")
      dumper.should_receive(:puts).with("b\t3")
      dumper.dump_hash("a" => "1", "b" => "3")
    end
  end
  
  describe "#run_from_args" do
    before(:each) do
      Redis.stub!(:new).and_return redis
      dumper.stub(:zset_to_hash).and_return({})
      dumper.stub(:dump_hash).and_return true
    end
    
    it "initializes a new redis instance" do
      Redis.should_receive(:new).with(:host => "host", :port => "port").and_return redis
      dumper.redis = nil
      dumper.run_from_args(["host", "port", "key"])
      dumper.redis.should == redis
    end
    
    it "calls dump_hash with zset_to_hash when type is zset" do
      redis.should_receive(:type).with("key").and_return "zset"
      hash = { "a" => 1 }
      dumper.should_receive(:zset_to_hash).and_return(hash)
      dumper.should_receive(:dump_hash).with(hash)
      dumper.run_from_args(["host", "port", "key"])
    end
    
    it "prints a message when type is not zset" do
      redis.should_receive(:type).with("key").and_return "hash"
      dumper.should_receive(:puts).with("only zsets are supported for now")
      dumper.run_from_args(["host", "port", "key"])
    end
    
    it "calls print_usage when not enough parameters" do
      dumper.should_receive(:print_usage)
      dumper.run_from_args(["host", "port"])
    end
  end
end
