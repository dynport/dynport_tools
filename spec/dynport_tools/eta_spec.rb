require 'spec_helper'
require "time"

describe "DynportTools::ETA" do
  let(:eta) { DynportTools::ETA.new(:current => 17, :total => 100) }
  let(:time) { Time.parse("2011-02-03 04:50") }
  
  before(:each) do
    Timecop.freeze(time)
  end
  
  it "can be initialized" do
    DynportTools::ETA.new
  end
  
  it "allows setting of total" do
    eta.total = 10
    eta.total.should == 10
  end
  
  it "allos_setting of current" do
    eta.current = 10
    eta.current.should == 10
  end
  
  it "allows setting of started" do
    eta.started = "some value"
    eta.started.should == "some value"
  end
  
  it "allows setting of all value sthrough initalizer" do
    eta = DynportTools::ETA.new(:total => 10, :current => 1, :started => "started")
    eta.should return_values(:total => 10, :current => 1, :started => "started")
  end
  
  describe "#parse_time_string" do
    { 
      "00:15:26" => 926,
      "00:00:26" => 26,
      "1:00:26" => 3626,
    }.each do |from, to|
      it "returns #{to} for #{from}" do
        DynportTools::ETA.parse_time_string(from).should == to
      end
    end
  end
  
  describe "#percs" do
    it "returns the correct value for percs" do
      eta.total = 100
      eta.current = 62
      eta.percs.should == 0.62
    end

    it "raises an error when total is not set" do
      eta.total = nil
      eta.current = 10
      lambda {
        eta.percs
      }.should raise_error("current and total must be set")
    end
    
    it "raises an error when current is not set" do
      eta.current = nil
      eta.total = 10
      lambda {
        eta.percs
      }.should raise_error("current and total must be set")
    end
  end
  
  describe "#pending" do
    it "returns teh correct amount for pending" do
      eta.pending.should == 83
    end
    
    it "calls raise_error_when_current_or_total_not_set" do
      eta.should_receive(:raise_error_when_current_or_total_not_set)
      eta.pending
    end
  end
  
  it "returns the correct amount for running_for" do
    DynportTools::ETA.new(:current => 17, :total => 100, :started => time - 99).running_for.should == 99
  end
  
  it "returns the correct amount of total time" do
    DynportTools::ETA.new(:current => 10, :total => 100, :started => time - 10).total_time.should == 100
  end
  
  it "returns the correct amount of time to go" do
    DynportTools::ETA.new(:current => 10, :total => 100, :started => time - 10).to_go.should == 90
  end
  
  it "returns the correct eta" do
    DynportTools::ETA.new(:current => 10, :total => 100, :started => time - 10).eta.should == time + 90
  end
  
  it "returns the correct value for per_second" do
    DynportTools::ETA.new(:current => 10, :total => 100, :started => time - 1).per_second.should == 10
  end
  
  it "returns the correct string" do
    DynportTools::ETA.new(:current => 10, :total => 100, :started => time - 1).to_s.should == "10.0%, 10.0/second, ETA: 2011-02-03T04:50:09+01:00"
  end
  
  it "returns the correct string for real live examples" do
    Timecop.return
    puts DynportTools::ETA.from_time_string("00:38:25", :current => 1385, :total => 28654).to_s
  end
  
  describe "#from_time_string" do
    it "sets the correct values" do
      eta = DynportTools::ETA.from_time_string("00:01:10", :total => 100)
      eta.should be_kind_of(DynportTools::ETA)
      eta.should return_values(:started => time - 70, :total => 100)
    end
  end
end
