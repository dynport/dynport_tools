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
  
  
  describe "#runner_command" do
    it "returns ./script/runner when no env given" do
      job.runner_command.should == "./script/runner"
    end
    
    it "returns rails runner when rails3 is set" do
      job.use_rails3!
      job.runner_command.should == "rails runner"
    end
    
    it "adds the rails env when given" do
      job.runner_command("staging").should == "./script/runner -e staging"
    end
    
    it "adds the default rails_env" do
      job.rails_env = "staging"
      job.runner_command.should == "./script/runner -e staging"
    end
    
    it "uses given rails env when both given" do
      job.rails_env = "staging"
      job.runner_command("staging2").should == "./script/runner -e staging2"
    end
  end
  
  describe "#rails_script" do
    it "calls rails_command_or_script with script" do
      job.should_receive(:rails_command_or_script).with("./jobs/do_something.rb", :rails_env => "staging")
      job.rails_script("./jobs/do_something.rb", :rails_env => "staging")
    end
  end
  
  describe "#rake_task" do
    before(:each) do
      job.rails_root "/rails/root"
    end
    
    it "sets the correct rails command" do
      job.rake_task "db:check"
      job.commands.should == ["cd /rails/root && rake db:check"]
    end
    
    it "hands in env variables" do
      job.should_receive(:command_with_env).with("rake db:check", { "A" => "true" }).and_return "some command"
      job.rake_task "db:check", :env => { "A" => "true"}
      job.commands.should == ["cd /rails/root && some command"]
    end
    
    it "correctly merges the rails env when given" do
      job.should_receive(:command_with_env).with("rake db:check", { "A" => "true", "RAILS_ENV" => "staging" }).and_return "some other command"
      job.rake_task "db:check", :env => { "A" => "true"}, :rails_env => "staging"
      job.commands.should == ["cd /rails/root && some other command"]
    end
  end
  
  describe "#rails_command" do
    it "calls rails_command_or_script with script" do
      job.should_receive(:rails_command_or_script).with(%("puts 1"), :rails_env => "staging")
      job.rails_command("puts 1", :rails_env => "staging")
    end
    
    it "correctly escapes the command" do
      job.should_receive(:rails_command_or_script).with(%("puts \\\"hello\\\""), :rails_env => "staging")
      job.rails_command(%(puts "hello"), :rails_env => "staging")
    end
  end
  
  describe "#command_with_env" do
    it "puts all env variables in front of command" do
      job.command_with_env("some command", "A" => "true").should == "A=true some command"
    end
    
    it "returns the command without env when env is nil" do
      job.command_with_env("some command").should == "some command"
    end
    
    it "adds bundle exec between env and command" do
      job.use_bundle_exec!
      job.command_with_env("some command", "A" => "true").should == "A=true bundle exec some command"
    end
  end
  
  describe "#rails_command_or_script" do
    before(:each) do
      job.rails_root = "/path/to/rails"
      job.stub!(:runner_command).and_return "./script/runner"
    end
    
    it "calls command with correct args" do
      job.rails_command_or_script "./some/script.rb"
      job.commands.should == [%(cd /path/to/rails && ./script/runner ./some/script.rb)]
    end
    
    it "calls runner_command with correct env" do
      job.should_receive(:runner_command).with("staging")
      job.rails_command_or_script "puts 1", :rails_env => "staging"
      job.commands
    end
    
    it "can set various env flags" do
      job.rails_command_or_script "./script.rb", :env => { "A" => "a", "B" => "b"}
      job.commands.should == [%(cd /path/to/rails && A=a B=b ./script/runner ./script.rb)]
    end
    
    it "raises an error when rails_root is nil" do
      job.rails_root = nil
      lambda {
        job.rails_command_or_script "some"
      }.should raise_error("rails_root must be set")
    end
  end
  
  describe "setters and getters" do
    { 
      :node => "Some Node", :disabled => true, :days_to_keep => 10, :num_to_keep => 1, :ordered => "A", 
      :rails_root => "/some/path"
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
      job.current_scope = { :ordered => "A" }
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
        
        with :locks => %w(Lock1 Lock2), :node => "Other Node" do
          job "Other Job"
        end
        
        ordered "A" do
          job "First" do
            with :prefix => "B" do
              job "Third"
              job "Fourth"
            end
          end
          
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
      jobs.at(4).jobs.map { |j| j.name }.should == ["B001 Third", "B002 Fourth"]
    end
  end
end