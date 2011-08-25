require 'spec_helper'
require "ostruct"

describe "DynportTools::HaveAttributesMatcher" do
  include DynportTools::HaveAttributesMatcher
  
  it "returns a correct error message error message" do
    matcher = DynportTools::HaveAttributesMatcher::HaveAttributes.new(:a => 1)
    matcher.matches?(:a => 2).should == false
    matcher.failure_message.should == "expected a to be <1> but was <2>"
  end
  
  it "returns true when arrays are equal" do
    matcher = DynportTools::HaveAttributesMatcher::HaveAttributes.new(:a => 1)
    matcher.matches?(:a => 1).should be_true
  end
  
  it "returns true when expected hash as viewer values than target" do
    matcher = DynportTools::HaveAttributesMatcher::HaveAttributes.new(:a => 1)
    matcher.matches?(:a => 1, :b => 2).should be_true
  end
  
  it "returns false when expected hash as viewer values than target but HaveAllAttributes is used" do
    matcher = DynportTools::HaveAttributesMatcher::HaveAllAttributes.new(:a => 1)
    matcher.matches?(:a => 1, :b => 2).should be_false
    matcher.failure_message.should == "expected b to be <nil> but was <2>"
  end
  
  it "returns true when object returns the correct values" do
    struct = OpenStruct.new(:a => 1, :b => 2)
    matcher = DynportTools::HaveAttributesMatcher::ReturnValues.new(:a => 1)
    matcher.matches?(struct).should be_true
  end
  
  it "returns false when object returns other values" do
    struct = OpenStruct.new(:a => 1, :b => 3)
    matcher = DynportTools::HaveAttributesMatcher::ReturnValues.new(:a => 1, :b => 2)
    matcher.matches?(struct).should be_false
    matcher.failure_message.should == "expected b to return <2> but did <3>"
  end
  
  it "returns the correct error message for complex hashes" do
    matcher = DynportTools::HaveAttributesMatcher::HaveAttributes.new(:a => { :b => [1] })
    matcher.matches?(:a => { :b => [2] }).should be_false
    matcher.failure_message.should == "expected a/b/0 to be <1> but was <2>"
  end
  
  it "returns false when target hash as viewer values than expected" do
    matcher = DynportTools::HaveAttributesMatcher::HaveAttributes.new(:a => 1, :b => 2)
    matcher.matches?(:a => 1).should be_false
  end
  
  it "returns true when comparing ActiveRecord like objects with hashes" do
    attributes = { "title" => "Some Title" }
    ar = double("ar", :attributes => attributes)
    matcher = DynportTools::HaveAttributesMatcher::HaveAttributes.new(:title => "Some Title")
    matcher.matches?(ar).should be_true
  end
  
  it "returns false when comparing ActiveRecord like objects with hashes but not equal" do
    attributes = { "title" => "Some Title" }
    ar = double("ar", :attributes => attributes)
    matcher = DynportTools::HaveAttributesMatcher::HaveAttributes.new(:title => "Some Other Title")
    matcher.matches?(ar).should be_false
  end
end
