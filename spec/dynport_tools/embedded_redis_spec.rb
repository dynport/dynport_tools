require 'spec_helper'

describe DynportTools::EmbeddedRedis do
  let(:er) { DynportTools::EmbeddedRedis.instance }
  
  before(:each) do
    er.logger = Logger.new("/dev/null")
    er.stub(:system)
    er.stub!(:sleep)
    er.stub!(:kill)
    FileUtils.stub!(:mkdir_p)
  end
  
  after(:each) do
    DynportTools::EmbeddedRedis.instance.instance_variable_set("@connection", nil)
  end
  
  describe "#kill" do
    before(:each) do
      er.unstub(:kill)
      er.stub!(:killed?).and_return false
      er.stub!(:pid).and_return "123"
      FileUtils.stub!(:rm_f)
    end
    
    it "kills the proces" do
      er.should_receive(:system).with("kill 123")
      er.kill
    end
    
    it "removes the socket file" do
      er.should_receive(:socket_path).and_return("/path/to/socket.tst")
      FileUtils.should_receive(:rm_f).with("/path/to/socket.tst")
      er.kill
    end
    
    it "removes the file path" do
      er.stub!(:base_path).and_return("/base/path")
      er.stub!(:dbfilename).and_return("some_name")
      FileUtils.should_receive(:rm_f).with("/base/path/some_name")
      er.kill
    end
    
    it "sets killed to true" do
      er.kill
      er.killed.should == true
    end
    
    it "does not call system when killed" do
      er.stub(:killed?).and_return true
      er.should_not_receive(:system)
    end
    
    it "does not call system when pid is nil" do
      er.stub(:pid?).and_return nil
      er.should_not_receive(:system)
    end
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
  
  describe "#config" do
    it "returns the default config" do
      er.stub!(:default_config).and_return(:a => 1, :b => 2)
      er.config.should == "a 1\nb 2"
    end
    
    it "merges the custom_config when defined" do
      er.stub!(:default_config).and_return(:a => 1, :b => 2)
      er.custom_config = { :a => 3 }
      er.config.should == "a 3\nb 2"
    end
  end
  
  describe "#do_start" do
    it "sets started to true" do
      er.do_start!
      er.started.should be_true
    end
    
    it "creates dir of pid and socket paths" do
      er.stub(:base_path).and_return "/custom_base/test"
      FileUtils.should_receive(:mkdir_p).with("/custom_base/test")
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
