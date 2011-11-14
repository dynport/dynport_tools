require 'spec_helper'

describe Settings do
  let(:redis) { Redis.new }
  let(:time) { Time.parse("2011-02-03 04:05:06") }
  
  before(:each) do
    Settings.defaults = nil
    Settings.redis = redis
    redis.del("settings")
    redis.del("settings/updated_at")
    Settings.instance_variable_set("@all", nil)
    Settings.instance_variable_set("@cached_at", nil)
  end
  
  it "allows setting a redis connection" do
    r = double("redis2")
    Settings.redis = r
    Settings.redis.should == r
  end
  
  it "allows addings new settings" do
    Settings.set(:refresh, 11)
    Settings.defaults[:refresh].should == 11
  end
  
  it "returns the correct defaults" do
    Settings.set(:refresh, 12)
    Settings.refresh.should == 12
  end
  
  it "allows setting of multiple settings at once" do
    Settings.set(:a => 1, :b => 2)
    Settings.a.should == 1
    Settings.b.should == 2
  end
  
  describe "#all" do
    it "fetches the correct values" do
      redis.hset("settings", "a", "1")
      redis.hset("settings", "b", "2")
      Settings.all.should == { "a" => "1", "b" => "2" }
    end
    
    it "caches the fetched records" do
      Timecop.freeze(time) do
        redis.hset("settings", "a", "1")
        redis.hset("settings", "b", "2")
        Settings.all
        Settings.instance_variable_get("@all").should == { "a" => "1", "b" => "2" }
        Settings.instance_variable_get("@cached_at").should == time
      end
    end
    
    it "returns the cached settings when not expired" do
      Settings.stub(:expired?).and_return false
      Settings.instance_variable_set("@all", { "c" => "3" })
      Settings.all.should == { "c" => "3" }
    end
  end
  
  describe "#expired?" do
    it "returns false when @cached_at is nil" do
      Settings.should_not be_expired
    end
    
    it "returns false when cached_at exactly 60 seconds ago" do
      Timecop.freeze(time) do
        Settings.instance_variable_set("@cached_at", time - 60)
        Settings.should_not be_expired
      end
    end
    
    it "returns true when exactly 61 seconds ago" do
      Timecop.freeze(time) do
        Settings.instance_variable_set("@cached_at", time - 61)
        Settings.should be_expired
      end
    end
  end
  
  describe "#changed?" do
    it "returns true when redis value != cached_at" do
      Timecop.freeze(time) do
        redis.set("settings/updated_at", time.to_i + 1)
        Settings.should be_changed
      end
    end
    
    it "returns true when both nil" do
      Settings.instance_variable_set("@cached_at", nil)
      Settings.should be_changed
    end
    
    it "false when redis value == cached_at" do
      Timecop.freeze(time) do
        Settings.instance_variable_set("@cached_at", time)
        redis.set("settings/updated_at", time.to_i)
        Settings.should_not be_changed
      end
    end
  end
  
  describe "#set_value" do
    it "resets the @all variable" do
      Settings.set :refresh, 11
      Settings.instance_variable_set("@all", { "b" => "2" })
      Settings.set_value(:refresh, 12)
      Settings.instance_variable_get("@all").should == { "refresh" => "12" }
    end
    
    it "sets the updated_at field" do
      Timecop.freeze(Time.at(11)) do
        Settings.set :refresh, 11
        Settings.set_value(:refresh, 12)
        redis.get("settings/updated_at").should == "11"
      end
    end
  end
  
  describe "dsl" do
    before(:each) do
      Settings.redis = redis
      redis.del("settings")
    end
    
    it "sets the defaults array" do
      Settings.set :refresh, 11
      Settings.defaults[:refresh].should == 11
    end
    
    it "allows addings settings" do
      Settings.set :refresh, 10
      Settings.refresh.should == 10
    end
    
    it "uses settings stored in redis" do
      redis.hset("settings", "refresh", 20)
      Settings.set(:refresh, 10)
      Settings.refresh.should == 20
    end
    
    it "returns the correct types for integers" do
      redis.hset("settings", "enabled", true)
      Settings.set(:enabled, false)
      Settings.enabled.should == true
    end
    
    describe "with boolean methods" do
      it "adds the enable_<key>! method" do
        Settings.set(:new_feature, true)
        Settings.disable_new_feature!
        Settings.new_feature.should == false
      end
      
      it "adds the enable_<key>! method" do
        Settings.set(:new_feature, false)
        Settings.enable_new_feature!
        Settings.new_feature.should == true
      end
      
      it "adds the new_feature?`method" do
        Settings.set(:new_feature, false)
        Settings.new_feature?.should == false
        Settings.enable_new_feature!
        Settings.new_feature?.should == true
      end
    end
    
    it "allows setting of settings" do
      Settings.set(:refresh, 12)
      Settings.set_refresh(13)
      Settings.refresh.should == 13
      redis.hgetall("settings")["refresh"].should == "13"
    end
  end
end
