require 'spec_helper'

describe DynportTools::Features do
  let(:redis) { Redis.new }
  
  before(:each) do
    DynportTools::Features.features = nil
    keys = redis.keys("features*")
    redis.multi do
      keys.each do |key|
        redis.del(key)
      end
    end
    DynportTools::Features.redis = redis
  end
  
  describe "defining features" do
    it "adds the features to an array" do
      DynportTools::Features.feature :solr
      DynportTools::Features.feature :sphinx
      DynportTools::Features.features.should == [:solr, :sphinx]
    end
    
    it "adds the *_enabled_for? method" do
      DynportTools::Features.feature :solr
      DynportTools::Features.should respond_to(:solr_enabled_for?)
    end
    
    it "returns true when user included in users set" do
      user = double("user", :id => 2)
      DynportTools::Features.feature :solr
      DynportTools::Features.add_user(:solr, user)
      DynportTools::Features.solr_enabled_for?(user).should == true
    end
    
    it "returns false when user not included in user set" do
      user = double("user", :id => 2)
      DynportTools::Features.feature :solr
      DynportTools::Features.solr_enabled_for?(user).should == false
    end
    
    it "returns false when user is nil" do
      DynportTools::Features.feature :solr
      DynportTools::Features.solr_enabled_for?(nil).should == false
    end
    
    it "executes the block given when enabled" do
      user = double("user", :id => 2)
      DynportTools::Features.feature :solr
      DynportTools::Features.add_user(:solr, user)
      called = false
      DynportTools::Features.solr_enabled_for?(user) do
        called = true
      end.should == true
      called.should == true
    end
    
    it "does not execute the block given when not enabled" do
      DynportTools::Features.feature :solr
      called = false
      DynportTools::Features.solr_enabled_for?(nil) do
        called = true
      end.should == false
      called.should == false
    end
  end
  
  it "allows setting a redis instance" do
    r = double("my r")
    DynportTools::Features.redis = r
    DynportTools::Features.redis.should == r
  end
  
  describe "add_user" do
    before(:each) do
      DynportTools::Features.feature :solr
    end
    
    it "raises an error when feature not defined" do
      lambda { 
        DynportTools::Features.add_user(:some_other, double("user", :id => 2))
      }.should raise_error
    end
    
    it "adds the user id to the specific group" do
      DynportTools::Features.add_user(:solr, double("user", :id => 2))
      DynportTools::Features.add_user(:solr, double("user", :id => 2))
      DynportTools::Features.add_user(:solr, double("user", :id => 4))
      redis.smembers("features/solr/users").should == %w(2 4)
    end
  end
  
  describe "remove_user" do
    it "correctly removes users" do
      DynportTools::Features.feature :solr
      DynportTools::Features.add_user(:solr, double("user", :id => 2))
      redis.smembers("features/solr/users").should == %w(2)
      DynportTools::Features.remove_user(:solr, double("user", :id => 2))
      redis.smembers("features/solr/users").should == %w()
    end
  end
end
