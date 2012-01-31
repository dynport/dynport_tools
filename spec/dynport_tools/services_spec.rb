$:<<File.expand_path("../../../", __FILE__)
require "dynport_tools"
require "dynport_tools/services"
require "spec_helper"

describe "Services" do
  let(:services) { DynportTools::Services.new }
  before(:each) do
    services.stub(:system_call).and_raise("stub me")
    services.stub!(:exec).and_raise("stub me")
  end
  
  it "can be initialized" do
    DynportTools::Services.new.should be_kind_of(DynportTools::Services)
  end
  
  describe "solr_root" do
    it "allows setting the solr root" do
      services.solr_data_root = "/tmp/solr_path"
      services.solr_data_root.should == "/tmp/solr_path"
    end
    
    it "returns /opt/solr by default" do
      services.solr_data_root.should == "/opt/solr"
    end
  end
  
  describe "solr" do
    let(:tmp_path) { "/tmp/solr_#{Time.now.to_f.to_s.gsub(".", "")}" }
    let(:solr_xml) { "#{tmp_path}/solr.xml"}
    
    after do(:each)
      FileUtils.rm_rf(tmp_path)
    end
    
    before(:each) do
      services.solr_data_root = tmp_path
    end
    
    describe "#start_solr" do
      before(:each) do
        FileUtils.mkdir_p(tmp_path)
      end
      
      it "raises an error when running" do
        services.stub!(:solr_running?).and_return true
        lambda {
          services.start_solr
        }.should raise_error("solr already running")
      end
      
      it "raises an error when not bootstrapped" do
        services.stub!(:solr_running?).and_return false
        services.stub!(:solr_bootstrapped?).and_return false
        lambda {
          services.start_solr
        }.should raise_error("solr must be bootstrapped first")
      end
      
      it "executes the correct system call" do
        services.stub!(:solr_running?).and_return false
        services.stub!(:solr_bootstrapped?).and_return true
        services.unstub(:exec)
        services.should_receive(:exec).with("solr #{tmp_path} > #{tmp_path}/solr.log 2>&1 &")
        services.start_solr
      end
    end
    
    describe "#solr_core_names" do
      before(:each) do
        services.stub!(:get).and_return("")
      end
      
      it "returns an array" do
        services.solr_core_names.should be_kind_of(Array)
      end
      
      it "calls the correct url" do
        services.should_receive(:get).with("http://localhost:8983/solr/").and_return ""
        services.solr_core_names
      end
      
      it "returns the cirrect core_names" do
        services.stub!(:get).and_return(File.read(root.join("spec/fixtures/solr_admin.html")))
        services.solr_core_names.should == %w(test supernova_test some_other)
      end
    end
    
    describe "#solr_bootstrapped?" do
      it "returns false by default" do
        services.should_not be_solr_bootstrapped
      end
      
      it "returns true when solr.xml exists" do
        FileUtils.mkdir_p(tmp_path)
        FileUtils.touch(solr_xml)
        services.should be_solr_bootstrapped
      end
    end
    
    describe "bootstrap_solr" do
      it "raises an error when dir not exists" do
        lambda {
          services.bootstrap_solr
        }.should raise_error("please create #{tmp_path} first")
      end
      
      it "creates a new solr.xml when not exists" do
        FileUtils.mkdir_p(tmp_path)
        services.bootstrap_solr
        File.should be_exists(solr_xml)
      end
      
      it "sets the correct content" do
        FileUtils.mkdir_p(tmp_path)
        services.bootstrap_solr
        expected = %(
          <?xml version="1.0" encoding="UTF-8" ?>
          <solr sharedLib="lib" persistent="true">
            <cores adminPath="/admin/cores">
            </cores>
          </solr>
        ).gsub(/^\s+/, "")
        File.read(solr_xml).should == expected
      end
      
      it "raises an error when solr.xml already exists" do
        FileUtils.mkdir_p(tmp_path)
        FileUtils.touch(solr_xml)
        lambda {
          services.bootstrap_solr
        }.should raise_error("#{solr_xml} already exists")
      end
    end
    
    describe "#solr_running?" do
      it "calls head with the correct url" do
        services.should_receive(:head).with("http://localhost:8983/solr/").and_return 200
        services.should be_solr_running
      end
    
      it "returns false when head != 200" do
        services.should_receive(:head).with("http://localhost:8983/solr/").and_return 404
        services.should_not be_solr_running
      end
    
      it "uses a custom solr_url when set" do
        services.solr_url = "http://some.host:8080/solr/"
        services.should_receive(:head).with("http://some.host:8080/solr/").and_return 200
        services.should be_solr_running
      end
    end
    
    describe "#solr_core_exists?" do
      it "calls head with the correct url" do
        services.solr_url = "http://some.host:8080/solr/"
        services.should_receive(:head).with("http://some.host:8080/solr/custom_core_name/admin/").and_return 200
        services.should be_solr_core_exists("custom_core_name")
      end
      
      it "returns false when status code != 200" do
        services.solr_url = "http://some.host:8080/solr/"
        services.should_receive(:head).with("http://some.host:8080/solr/custom_core_name_2/admin/").and_return 404
        services.should_not be_solr_core_exists("custom_core_name_2")
      end
    end
    
    describe "#create_solr_core" do
      before(:each) do
        services.solr_url = "http://some.host:8080/solr/"
        services.solr_instance_path = "/path/to/solr/instance"
        services.solr_data_root = "/solr/data"
      end
      
      it "calls post with the correct url" do
        url = "http://some.host:8080/solr/admin/cores?action=CREATE&name=new_core_name&instanceDir=/path/to/solr/instance&dataDir=/solr/data/new_core_name"
        services.should_receive(:post).with(url)
        services.create_solr_core("new_core_name")
      end
      
      it "raises an error when solr_instance_path is not set" do
        services.should_not_receive(:post)
        services.solr_instance_path = nil
        lambda {
          services.create_solr_core("new_core_name")
        }.should raise_error("please set solr_instance_path first!")
      end
    end
    
    describe "#unload_solr_core" do
      it "calls the correct post method (haha, post)" do
        services.solr_url = "http://some.host:8080/solr/"
        url = "http://some.host:8080/solr/admin/cores?action=UNLOAD&core=core_to_unload"
        services.should_receive(:post).with(url)
        services.unload_solr_core("core_to_unload")
      end
    end
    
    describe "#reload_solr_core" do
      it "calls the correct post method (haha, post)" do
        services.solr_url = "http://some.host:8080/solr/"
        url = "http://some.host:8080/solr/admin/cores?action=RELOAD&core=core_to_unload"
        services.should_receive(:post).with(url)
        services.reload_solr_core("core_to_unload")
      end
    end
    
    describe "#reload_all_solr_cores" do
      it "calls reload_solr_core with all core_names" do
        services.stub!(:solr_core_names).and_return(%w(b d f))
        services.should_receive(:reload_solr_core).with("b")
        services.should_receive(:reload_solr_core).with("d")
        services.should_receive(:reload_solr_core).with("f")
        services.reload_all_solr_cores
      end
    end
    
  end
  
  describe "redis" do
    before(:each) do
      services.redis_path_prefix = "/tmp/path/to/redis"
    end
    
    describe "#redis_path_prefix" do
      it "raises an error when not set" do
        services.redis_path_prefix = nil
        lambda {
          services.redis_path_prefix
        }.should raise_error("redis_path_prefix not set!")
      end
    end
    
    it "returns the correct redis_socket_path when redis_path_prefix is set" do
      services.redis_socket_path.should == "/tmp/path/to/redis.socket"
    end
    
    it "returns the correct redis_config_path when redis_path_prefix is set" do
      services.redis_config_path.should == "/tmp/path/to/redis.conf"
    end
    
    describe "#redis_running?" do
      before(:each) do
        services.unstub(:system_call)
        services.stub(:redis_socket_path).and_return("/path/to/redis.socket")
      end
    
      it "executes the correct command" do
        services.should_receive(:system_call).with(%(echo "info" | redis-cli -s /path/to/redis.socket 2> /dev/null | grep uptime_in_seconds)).and_return "uptime_in_seconds:1787353"
        services.should be_redis_running
      end
    
      it "returns false when system_call returns a blank string" do
        services.should_receive(:system_call).with(%(echo "info" | redis-cli -s /path/to/redis.socket 2> /dev/null | grep uptime_in_seconds)).and_return ""
        services.should_not be_redis_running
      end
    end
  
    describe "#start_redis" do
      before(:each) do
        services.stub!(:write_redis_config)
        services.stub!(:system_call)
      end
    
      it "calls write_redis_config" do
        services.should_receive(:write_redis_config)
        services.start_redis
      end
    
      it "starts redis with the correct command" do
        services.redis_path_prefix = "/path/to/redis"
        services.should_receive(:system_call).with("redis-server /path/to/redis.conf")
        services.start_redis
      end
    end
  
    describe "#write_redis_config" do
      it "writes redis_config to the correct path" do
        services.stub!(:redis_config).and_return("some config")
        services.redis_path_prefix = "/path/to/redis"
        file = double("file")
        File.should_receive(:open).with("/path/to/redis.conf", "w").and_yield(file)
        file.should_receive(:puts).with("some config")
        services.write_redis_config
      end
    end
    
    describe "#redis_config_hash" do
      it "returns the default hash by default" do
        services.redis_path_prefix = "/path/to/redis"
        services.redis_config_hash.should == {
          :unixsocket => "/path/to/redis.socket",
          :logfile => "/path/to/redis.log",
          :daemonize => "yes",
          :port => 0
        }
      end
      
      it "merges the custom set redis_config_path" do
        services.redis_path_prefix = "/path/to/redis"
        services.redis_config_hash = { :port => 1234 }
        services.redis_config_hash.should == {
          :unixsocket => "/path/to/redis.socket",
          :port => 1234,
          :logfile => "/path/to/redis.log",
          :daemonize => "yes"
        }
      end
    end
  
    describe "#redis_config" do
      it "returns a string" do
        services.redis_config.should be_kind_of(String)
      end
    
      it "returns the correct string" do
        services.stub(:redis_config_hash).and_return(
          :port => 0,
          :unixsocket => "/path/to/socket"
        )
        services.redis_config.split("\n").sort.should == ["port 0", "unixsocket /path/to/socket"].sort
      end
      
      it "does not include empty values" do
        services.stub(:redis_config_hash).and_return(
          :port => nil,
          :unixsocket => "/path/to/socket"
        )
        services.redis_config.should == "unixsocket /path/to/socket"
      end
    end
  end
  
  it "forwards the system call" do
    services.unstub(:system_call)
    services.stub(:puts)
    Kernel.should_receive(:`).with("ls -l").and_return("the result")
    services.system_call("ls -l").should == "the result"
  end
  
  describe "http methods" do
    let(:url) { "http://www.some.host:1234/path" }
    
    describe "#head" do
      before(:each) do
        services.unstub(:system_call)
      end
    
      it "executes the correct system call" do
        services.should_receive(:system_call).with(%(curl -s -I "#{url}" | head -n 1)).and_return("HTTP/1.1 200 OK")
        services.head(url).should == 200
      end
    
      it "returns nil when result is empty" do
        services.stub(:system_call).and_return("")
        services.head("/some/path").should be_nil
      end
    end
    
    describe "#get" do
      before(:each) do
        services.unstub(:system_call)
      end
      
      it "executes the correct system call" do
        services.should_receive(:system_call).with(%(curl -s "#{url}")).and_return("response body")
        services.get(url).should == "response body"
      end
    end
    
    describe "#post" do
      before(:each) do
        services.unstub(:system_call)
      end
      
      it "executes the correct system call" do
        services.should_receive(:system_call).with(%(curl -s -I -XPOST "#{url}"))
        services.post(url)
      end
    end
  end
end