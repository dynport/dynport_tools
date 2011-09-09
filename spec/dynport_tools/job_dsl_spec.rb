require 'spec_helper'

describe Jenkins::JobDSL do
  let(:job) { Jenkins::JobDSL.new }
  
  after(:each) do
    Jenkins::JobDSL.jobs = nil
  end
  
  describe "Job" do
    it "can be initialized with a scope" do
      Jenkins::JobDSL.new(:node => "Some Node").node.should == "Some Node"
    end
    
    it "sets the current scope to an empty hash" do
      Jenkins::JobDSL.new.current_scope.should == {}
    end
  end
  
  describe "setters and getters" do
    { 
      :node => "Some Node", :disabled => true, :days_to_keep => 10, :num_to_keep => 1
    }.each do |key, value|
      it "sets #{key} to #{value}" do
        job.send(key, value)
        job.send(key).should == value
      end
    end
    
    it "allows setting multiple email addresses" do
      job.notify "email1@test.xx", "email2@test.xx"
      job.notify.should == %w(email1@test.xx email2@test.xx)
    end
    
    %w(cron_pattern lock command command).each do |singular|
      it "allows setting #{singular}s with #{singular}" do
        job.send(singular, "#{singular}1")
        job.send("#{singular}").should == ["#{singular}1"]
      end
      
      it "allows setting #{singular}s with #{singular}s" do
        job.send("#{singular}s", "#{singular}1", "#{singular}2")
        job.send("#{singular}").should == ["#{singular}1", "#{singular}2"]
      end
    end
    
    it "provides a simple setter_or_getter" do
      lambda {
        job.disabled!
      }.should change(job, :disabled).to(true)
    end
  end
  
  describe "#node" do
    before(:each) do
      job.current_scope = { :ttl => 1 }
    end
    
    it "can set the node" do
      job.node "Some Node"
      job.node.should == "Some Node"
    end
    
    it "does not set the node when block given" do
      job.node "Some Node" do
      end
      job.node.should be_nil
    end
    
    it "resets the correct scope" do
      job.node "Some Node" do
      end
      job.current_scope.should == { :ttl => 1 }
    end
    
    it "merges the current scope with the node" do
      scope = nil
      job.node "Some Node" do
        scope = self.current_scope
      end
      scope.should have_attributes(:ttl => 1, :node => "Some Node")
    end
  end
  
  describe "#setup" do
    it "returns a new instance of Jenkins" do
      Jenkins::JobDSL.setup.should be_kind_of(Array)
    end
    
    it "sets the new jobs to the default key when no namespace given" do
      Jenkins::JobDSL.setup do
        job "Default Job"
      end
      Jenkins::JobDSL.jobs[:default].count.should == 1
      Jenkins::JobDSL.jobs[:default].first.name.should == "Default Job"
    end
    
    it "does not overwrite jobs" do
      Jenkins::JobDSL.setup do
        job "First Job"
      end
      Jenkins::JobDSL.setup do
        job "Second Job"
      end
      Jenkins::JobDSL.jobs[:default].count.should == 2
    end
    
    it "dass the jobs to a custom key" do
      Jenkins::JobDSL.setup :custom do
        job "Default Job"
      end
      Jenkins::JobDSL.jobs[:custom].count.should == 1
      Jenkins::JobDSL.jobs[:custom].first.name.should == "Default Job"
    end
  end
  
  describe "#job" do
    let(:job) { Jenkins::JobDSL.new }
    
    it "adds a new job to the children" do
      job.job "Some Name"
      job.jobs.count.should == 1
      job.jobs.first.name.should == "Some Name"
    end
    
    it "initializes the job with current_scope" do
      job.current_scope = { :node => "Test" }
      job.job "Some Name"
      job.jobs.first.node.should == "Test"
    end
    
    it "adds a prefix to the name when current_prefix is set" do
      job.current_prefix = "A"
      job.job "Some Name"
      job.jobs.first.name.should == "A001 Some Name"
    end
  end
  
  describe "integration" do
    it "adds a new job to the dsl object" do
      Jenkins::JobDSL.setup do
        job "some name" do
          node "Import"
        end
        
        job "some other name" do
          command "ls"
          
          job "child job"
        end
        
        node "Backup" do
          job "Backup Task"
        end
        
        with_options :locks => %w(Lock1 Lock2), :node => "Other Node" do
          job "Other Job"
        end
        
        ordered "A" do
          job "First"
          job "Second"
        end
      end
      jobs = Jenkins::JobDSL.jobs[:default]
      jobs.count.should == 6
      jobs.first.name.should == "some name"
      jobs.first.node.should == "Import"
      jobs.at(1).commands.should == %w(ls)
      jobs.at(1).jobs.count.should == 1
      jobs.at(1).jobs.first.name.should == "child job"
      jobs.at(2).name.should == "Backup Task"
      jobs.at(2).node.should == "Backup"
      
      jobs.at(3).node.should == "Other Node"
      jobs.at(3).locks.should == %w(Lock1 Lock2)
      jobs.at(3).name.should == "Other Job"
      jobs.at(4).name.should == "A001 First"
      jobs.at(5).name.should == "A002 Second"
    end
  end
end