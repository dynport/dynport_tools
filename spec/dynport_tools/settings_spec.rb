require 'spec_helper'

describe DynportTools::Settings do
  let(:redis) { Redis.new }
  let(:time) { Time.parse("2011-02-03 04:05:06") }
  
  before(:each) do
    DynportTools::Settings.defaults = nil
    DynportTools::Settings.redis = redis
    redis.del("settings")
    redis.del("settings/updated_at")
    DynportTools::Settings.instance_variable_set("@all", nil)
    DynportTools::Settings.instance_variable_set("@cached_at", nil)
  end
  
  it "allows setting a redis connection" do
    r = double("redis2")
    DynportTools::Settings.redis = r
    expect(DynportTools::Settings.redis).to eql(r)
  end
  
  it "allows addings new settings" do
    DynportTools::Settings.set(:refresh, 11)
    expect(DynportTools::Settings.defaults[:refresh]).to eql(11)
  end
  
  it "returns the correct defaults" do
    DynportTools::Settings.set(:refresh, 12)
    expect(DynportTools::Settings.refresh).to eql(12)
  end
  
  it "allows setting of multiple settings at once" do
    DynportTools::Settings.set(:a => 1, :b => 2)
    expect(DynportTools::Settings.a).to eql(1)
    expect(DynportTools::Settings.b).to eql(2)
  end
  
  describe "#all" do
    it "fetches the correct values" do
      redis.hset("settings", "a", "1")
      redis.hset("settings", "b", "2")
      expect(DynportTools::Settings.all).to eql({ "a" => "1", "b" => "2" })
    end
    
    it "caches the fetched records" do
      Timecop.freeze(time) do
        redis.hset("settings", "a", "1")
        redis.hset("settings", "b", "2")
        DynportTools::Settings.all
        expect(DynportTools::Settings.instance_variable_get("@all")).to eql({ "a" => "1", "b" => "2" })
        expect(DynportTools::Settings.instance_variable_get("@cached_at")).to eql(time)
      end
    end
    
    it "returns the cached settings when not expired" do
      DynportTools::Settings.stub(:expired?).and_return false
      DynportTools::Settings.instance_variable_set("@all", { "c" => "3" })
      expect(DynportTools::Settings.all).to eql({ "c" => "3" })
    end
  end
  
  describe "#expired?" do
    it "returns false when @cached_at is nil" do
      DynportTools::Settings.should_not be_expired
    end
    
    it "returns false when cached_at exactly 60 seconds ago" do
      Timecop.freeze(time) do
        DynportTools::Settings.instance_variable_set("@cached_at", time - 60)
        DynportTools::Settings.should_not be_expired
      end
    end
    
    it "returns true when exactly 61 seconds ago" do
      Timecop.freeze(time) do
        DynportTools::Settings.instance_variable_set("@cached_at", time - 61)
        DynportTools::Settings.should be_expired
      end
    end
  end
  
  describe "#changed?" do
    it "returns true when redis value != cached_at" do
      Timecop.freeze(time) do
        redis.set("settings/updated_at", time.to_i + 1)
        DynportTools::Settings.should be_changed
      end
    end
    
    it "returns true when both nil" do
      DynportTools::Settings.instance_variable_set("@cached_at", nil)
      DynportTools::Settings.should be_changed
    end
    
    it "false when redis value == cached_at" do
      Timecop.freeze(time) do
        DynportTools::Settings.instance_variable_set("@cached_at", time)
        redis.set("settings/updated_at", time.to_i)
        DynportTools::Settings.should_not be_changed
      end
    end
  end
  
  describe "#set_value" do
    it "resets the @all variable" do
      DynportTools::Settings.set :refresh, 11
      DynportTools::Settings.instance_variable_set("@all", { "b" => "2" })
      DynportTools::Settings.set_value(:refresh, 12)
      expect(DynportTools::Settings.instance_variable_get("@all")).to eql({ "refresh" => "12" })
    end
    
    it "sets the updated_at field" do
      Timecop.freeze(Time.at(11)) do
        DynportTools::Settings.set :refresh, 11
        DynportTools::Settings.set_value(:refresh, 12)
        expect(redis.get("settings/updated_at")).to eql("11")
      end
    end
  end
  
  describe "dsl" do
    before(:each) do
      DynportTools::Settings.redis = redis
      redis.del("settings")
    end
    
    it "sets the defaults array" do
      DynportTools::Settings.set :refresh, 11
      expect(DynportTools::Settings.defaults[:refresh]).to eql(11)
    end
    
    it "allows addings settings" do
      DynportTools::Settings.set :refresh, 10
      expect(DynportTools::Settings.refresh).to eql(10)
    end
    
    it "uses settings stored in redis" do
      redis.hset("settings", "refresh", 20)
      DynportTools::Settings.set(:refresh, 10)
      expect(DynportTools::Settings.refresh).to eql(20)
    end
    
    it "returns the correct types for integers" do
      redis.hset("settings", "enabled", true)
      DynportTools::Settings.set(:enabled, false)
      expect(DynportTools::Settings.enabled).to eql(true)
    end
    
    describe "with boolean methods" do
      it "adds the enable_<key>! method" do
        DynportTools::Settings.set(:new_feature, true)
        DynportTools::Settings.disable_new_feature!
        expect(DynportTools::Settings.new_feature).to eql(false)
      end
      
      it "adds the enable_<key>! method" do
        DynportTools::Settings.set(:new_feature, false)
        DynportTools::Settings.enable_new_feature!
        expect(DynportTools::Settings.new_feature).to eql(true)
      end
      
      it "adds the new_feature?`method" do
        DynportTools::Settings.set(:new_feature, false)
        expect(DynportTools::Settings.new_feature?).to eql(false)
        DynportTools::Settings.enable_new_feature!
        expect(DynportTools::Settings.new_feature?).to eql(true)
      end
    end
    
    it "allows setting of settings" do
      DynportTools::Settings.set(:refresh, 12)
      DynportTools::Settings.set_refresh(13)
      expect(DynportTools::Settings.refresh).to eql(13)
      expect(redis.hgetall("settings")["refresh"]).to eql("13")
    end
  end
end
