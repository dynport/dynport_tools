require 'spec_helper'

describe EmbeddedRedis do
  let(:er) { EmbeddedRedis.instance }
  
  before(:each) do
    er.logger = Logger.new("/dev/null")
    er.stub(:system)
    er.stub!(:sleep)
    er.stub!(:kill)
    FileUtils.stub!(:mkdir_p)
  end
  
  after(:each) do
    EmbeddedRedis.instance.instance_variable_set("@connection", nil)
  end
  
  describe "#pid" do
    it "returns nil when file not found" do
      pid_path = root.join("tmp/some_weird_pid_path.pid")
      er.stub!(:pid_path).and_return pid_path
      er.pid.should be_nil
    end
    
    it "returns nil when blank" do
      pid_path = root.join("tmp/redis_test.pid")
      File.open(pid_path, "w") { |f| f.puts "  " }
      er.stub!(:pid_path).and_return pid_path
      er.pid.should be_nil
    end
    
    it "returns the correct pid when present" do
      pid_path = root.join("tmp/redis_test.pid")
      File.open(pid_path, "w") { |f| f.puts "123" }
      er.stub!(:pid_path).and_return pid_path
      er.pid.should == "123"
    end
  end
  
  describe "#running?" do
    it "returns false when pid is nil" do
      er.should_receive(:pid).and_return nil
      er.running?.should be_false
    end
    
    it "returns false when not in pid list" do
      er.stub!(:pid).and_return "1212"
      IO.should_receive(:popen).with("ps -p 1212 | grep redis-server").and_return([])
      er.running?.should be_false
    end
    
    it "returns true lines > 0" do
      er.stub!(:pid).and_return "1212"
      IO.stub(:popen).with("ps -p 1212 | grep redis-server").and_return(["line"])
      er.running?.should be_true
    end
  end
  
  describe "#start" do
    before(:each) do
      er.stub!(:do_start!)
      er.stub!(:connection).and_return double("connection")
    end
    
    it "calls do_start when running? is false" do
      er.should_receive(:running?).and_return false
      er.should_receive(:do_start!).and_return true
      er.start
    end
    
    it "does not call do_start! of running" do
      er.should_receive(:running?).and_return true
      er.should_not_receive(:do_start!).and_return true
      er.start
    end
  end
  
  describe "do_start" do
    it "sets started to true" do
      er.do_start!
      er.started.should be_true
    end
    
    it "creates dir of pid and socket paths" do
      er.stub(:base_path).and_return "/custom_base"
      FileUtils.should_receive(:mkdir_p).with("/custom_base/pids")
      FileUtils.should_receive(:mkdir_p).with("/custom_base/sockets")
      er.do_start!
    end
    
    it "starts redis" do
      er.stub(:config).and_return "some config"
      er.should_receive(:system).with(/echo "some config" \| redis-server -/)
      er.do_start!
    end
    
    it "registers an on_exit hook" do
      er.should_receive(:at_exit)
      er.do_start!
    end
  end
  
  describe "#started?" do
    it "returns true when started is true" do
      er.started = true
      er.started?.should == true
    end
    
    it "returns false when started is nil" do
      er.started = nil
      er.started?.should == false
    end
  end
  
  describe "#connection" do
    it "calls start when not started" do
      er.should_receive(:started?).and_return false
      er.should_receive(:start)
      er.connection
    end
    
    it "does not call start when already started" do
      er.should_receive(:started?).and_return true
      er.should_not_receive(:start)
      er.connection
    end
    
    it "creates a new redis connection" do
      er.instance_variable_set("@connection", nil)
      er.stub(:socket_path).and_return("/some/socket/path")
      er.stub(:started?).and_return true
      redis = er.connection
      redis.should be_kind_of(Redis)
    end
  end
end
