require 'spec_helper'

describe DynportTools::Differ do
  let(:differ) { DynportTools::Differ.new }
  
  def uncolor(str)
    str.gsub(/\e\[(\d+)m/, '')
  end
  
  describe "#initialize" do
    it "sets diff_all to true by default" do
      DynportTools::Differ.new.diff_all.should == true
    end
    
    it "sets diff_all to false when initialized with that option" do
      DynportTools::Differ.new(:diff_all => false).diff_all.should == false
    end
  end
  
  describe "#diff_strings" do
    it "diffs two strings" do
      a = %("#!/bin/sh\nssh some.server 'cd /path/to/project && script/runner -e production_slave \"do something\"")
      b = %("#!/bin/sh\nssh some.server \"cd /path/to/project && ./script/runner -e production 'do something'\")
      uncolor(differ.diff_strings(a, b)).should == %("#!/bin/sh\nssh some.server <'|">cd /path/to/project && <|./>script/runner -e production<_slave|> <"|'>do something<"|'>")
    end

    it "diffes simple strings" do
      a = %(-e production_slave "something)
      b = %(-e production "something)
      uncolor(differ.diff_strings(a, b)).should == %(-e production<_slave|> "something)
    end

    it "diffs a little bit more complicated string" do
      a = %(-e production_slave "something)
      b = %(-e production 'something)
      uncolor(differ.diff_strings(a, b)).should == %(-e production<_slave|> <"|'>something)
    end
  end
  
  describe "diffing two hashes" do
    it "returns true when both hashes are equal" do
      hash = { :a => 1 }
      differ.diff(hash, hash).should be_nil
    end
    
    it "returns true when symbolize_keys is set to true and comparing hashes with symbols and strings" do
      differ.symbolize_keys = true
      differ.diff({ :a => 1 }, { "a" => 1 }).should be_nil
    end
    
    it "returns false when symbolize_keys is set to false and comparing hashes with symbols and strings" do
      differ.symbolize_keys = nil
      differ.diff({ :a => 1 }, { "a" => 1 }).should_not be_nil
    end
    
    it "returns the diff when there is one" do
      a = { :a => 1, :b => 2 }
      b = { :a => 1, :b => 3 }
      
      differ.diff(a, b).should == {
        :b => [2, 3]
      }
    end
    
    it "returns nested diffs" do
      a = { :a => 1, :b => { :c => 1 } }
      b = { :a => 1, :b => { :c => 2 } }
      
      differ.diff(a, b).should == {
        :b => { :c => [1, 2] }
      }
    end
  end
  
  describe "#diff" do
    it "returns an array with both values when not equal" do
      differ.diff("a", "b").should == ["a", "b"]
    end
    
    it "returns nil when equal" do
      differ.diff("a", "a").should be_nil
    end
    
    describe "with first one being a hash" do
      let(:a) { { :a => 1 } }
      let(:b) { { :a => 2 } }
      
      it "returns a hash when first value is a hash" do
        differ.diff(a, b).should be_an_instance_of(Hash)
      end
      
      it "returns an array when first is a hash and second is string" do
        differ.diff(a, "a").should == [a, "a"]
      end
      
      it "returns an array when first is a string and second is hash" do
        differ.diff("a", a).should == ["a", a]
      end
      
      it "returns the correct diff" do
        differ.diff(a, b).should == { :a => [1, 2] }
      end
      
      it "sets nil as value when equal" do
        differ.diff(a, a).should be_nil
      end
      
      it "sets the correct diff when b has more keys then a" do
        differ.diff({ :a => 1 }, { :b => 2 }).should == { :a => [1, nil], :b => [nil, 2] }
      end
      
      it "only uses b's keys when diff_all is true" do
        differ.diff_all = false
        differ.diff({ :a => 1 }, { :a => 2, :b => 3 }).should == { :a => [1, 2] }
      end
    end
    
    describe "with two arrays given" do
      let(:a) { [1, 2] }
      let(:b) { [1, 3] }
      
      it "returns an empty hash when equal" do
        differ.diff(a, a).should be_nil
      end
      
      it "sets the correct diff when there is one" do
        differ.diff(a, b).should == { 1 => [2, 3] }
      end
      
      it "sets the correct diff when second array is bigger" do
        differ.diff(a, [1, 2, 3]).should == { 2 => [nil, 3] }
      end
    end
  end
  
  describe "diff_to_message_lines" do
    it "returns an empty array when diff is nil" do
      differ.diff_to_message_lines(nil).should == []
    end
    
    it "uses inspect when key is a hash" do
      differ.diff_to_message_lines({ { :a => 1 } => [1, 2]}).should == ["expected {:a=>1} to be <1> but was <2>"]
    end
    
    it "returns a message for array" do
      differ.diff_to_message_lines([1, 2]).should == ["expected <1> to be <2>"]
    end
    
    it "returns the correct message for a simple hash" do
      differ.diff_to_message_lines({ :a => [1, 2]}).should == ["expected a to be <1> but was <2>"]
    end
    
    it "uses return instead of be" do
      differ.use_return = true
      differ.diff_to_message_lines({ :a => [1, 2]}).should == ["expected a to return <1> but did <2>"]
    end
    
    it "adds a prefix when diff is array" do
      differ.diff_to_message_lines({ :a => [1, 2]}, "b").should == ["expected b[a] to be <1> but was <2>"]
    end
    
    it "returns the correctly nested diff" do
      differ.diff_to_message_lines({ :a => { :b => [3, 4] } }).should == ["expected a[b] to be <3> but was <4>"]
    end
    
    it "returns the correctly neep nested diff" do
      differ.diff_to_message_lines({ :a => { :b => [3, 4] } }, "c").should == ["expected c[a][b] to be <3> but was <4>"]
    end
    
    it "returns multiple messages" do
      differ.diff_to_message_lines({ :a => { :b => [3, 4], :c => [nil, 1] } }, "c").sort.should == [
        "expected c[a][b] to be <3> but was <4>",
        "expected c[a][c] to be <nil> but was <1>",
      ].sort
    end
  end
end
