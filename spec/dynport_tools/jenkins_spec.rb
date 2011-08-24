require 'spec_helper'

describe "DynportTools::Jenkins" do
  let(:url) { "http://some.url.com:8098" }
  let(:jenkins) { DynportTools::Jenkins.new(url) }
  before(:each) do
    Typhoeus::Request.stub!(:post).and_return nil
  end
  
  describe "RemoteProject" do
    let(:remote_project) do
      xml = File.read(root.join("spec/fixtures/jenkins_job.xml")) 
      remote_project = DynportTools::Jenkins::RemoteProject.new(:xml => xml)
      remote_project
    end
    
    it "can be initialized" do
      DynportTools::Jenkins::RemoteProject.new(:url => "some/url", :name => "Some Name", :rgne => "true").should return_values(:url => "some/url", 
        :name => "Some Name"
      )
    end
    
    it "returns the correct " do
      remote_project.commands.should == [%(ssh some.host \"touch /some/path/running.pid\")]
    end
    
    it "returns an empty array when no commands found" do
      DynportTools::Jenkins::RemoteProject.new(:url => "some/url", :name => "Some Name", :xml => "<project/>").commands.should be_empty
    end
    
    it "returns the correct crontab_patterns" do
      remote_project.crontab_patterns.should == ["0 4 * * *"]
    end
    
    it "returns the correct childProjects" do
      remote_project.child_projects.should == ["Project 2", "Project 6", "Prohect 9"]
    end
    
    it "returns the correct locks" do
      remote_project.locks.should == %w(Import)
    end
    
    it "returns the correct md5" do
      remote_project.stub!(:xml).and_return "some xml"
      remote_project.md5.should == "53bdfcda073f189a71901011123abf9a"
    end
    
    describe "logrotate" do
      it "returns the correct amount of days_to_keep" do
        remote_project.days_to_keep.should == 7
      end

      it "returns nil when days_to_keep == -1" do
        DynportTools::Jenkins::RemoteProject.new(:xml => "<project><logRotator><daysToKeep>-1</daysToKeep></logRotator></project>").days_to_keep.should be_nil
      end
      
      it "returns nil for num_to_keep when -1" do
        remote_project.num_to_keep.should be_nil
      end
      
      it "returns the correct value for num_to_keep when set" do
        DynportTools::Jenkins::RemoteProject.new(:xml => "<project><logRotator><numToKeep>20</numToKeep></logRotator></project>").num_to_keep.should == 20
      end
    end
    
    it "returns the correct disabled status" do
      remote_project.should be_disabled
    end
    
    it "returns the correct email_addresses" do
      remote_project.email_addresses.should == %w(test@test.xx)
    end
    
    it "returns false when not disabled" do
      DynportTools::Jenkins::RemoteProject.new(:xml => "<project><disabled>false</disabled></project>").should_not be_disabled
    end
    
    it "extracts the correct node" do
      remote_project.node.should == "Import"
    end
    
    describe "#with nothing found" do
      let(:empty_remote_project) { DynportTools::Jenkins::RemoteProject.new(:xml => "<project/>") }
      [:child_projects, :commands, :crontab_patterns, :locks].each do |method|
        it "returns an empty array for #{method}" do
          empty_remote_project.send(method).should == []
        end
      end
    end
  end
  
  describe "Project" do
    let(:job) { DynportTools::Jenkins::Project.new("Some Name") }
    let(:doc) { Nokogiri::XML(job.to_xml) }
    
    describe "#initialize" do
      it "sets the commands to an empty array" do
        job.commands.should == []
      end
      
      it "sets the commands to an empty array" do
        job.child_projects.should == []
      end
      
      it "sets the commands to an empty array" do
        job.locks.should == []
      end
      
      it "sets the email addresses to an empty array" do
        job.email_addresses.should == []
      end
      
      it "sets the name" do
        job.name.should == "Some Name"
      end
    end
    
    describe "#to_xml" do
      it "returns a string" do
        job.to_xml.should be_kind_of(String)
      end
      
      it "includes a xml header line" do
        job.to_xml.should include(%(<?xml version="1.0" encoding="UTF-8"?>))
      end
      
      it "includes a project root" do
        job.to_xml.should include("<project>")
        job.to_xml.should include("</project>")
      end
      
      %w(actions description properties publishers buildWrappers).each do |key|
        it "includes an empty node #{key}" do
          doc.at("/project/#{key}").children.should be_empty
        end
      end
      
      it "sets the correct email_addresses when present" do
        job.email_addresses = %w(test@test.xx test2@test.xx)
        doc.xpath("/project/publishers/hudson.tasks.Mailer/recipients").map(&:inner_text).should == ["test@test.xx,test2@test.xx"]
        doc.at("/project/publishers/hudson.tasks.Mailer/dontNotifyEveryUnstableBuild").inner_text.should == "true"
        doc.at("/project/publishers/hudson.tasks.Mailer/sendToIndividuals").inner_text.should == "false"
      end
      
      { 
        "keepDependencies" => "false",
        "canRoam" => "true",
        "disabled" => "false",
        "blockBuildWhenDownstreamBuilding" => "false",
        "blockBuildWhenUpstreamBuilding" => "false",
        "concurrentBuild" => "false"
      }.each do |key, value|
        it "sets #{key} to #{value}" do
          doc.at("/project/#{key}").inner_text.should == value
        end
      end
      
      it "sets disabled to true when set" do
        job.disabled = true
        doc.at("/project/disabled").inner_text.should == "true"
      end
      
      { "scm" => "hudson.scm.NullSCM", "triggers" => "vector" }.each do |key, clazz|
        it "sets the class of #{key} to #{clazz}" do
          doc.at("/project/#{key}")["class"].should == clazz
        end
      end
      
      it "includes all set commands" do
        job.commands << "hostname"
        job.commands << "date"
        shell_tasks = doc.search("project/builders/*")
        shell_tasks.map(&:name).should == ["hudson.tasks.Shell", "hudson.tasks.Shell"]
        shell_tasks.map { |node| node.at("command").inner_text }.should == ["hostname", "date"]
      end
      
      it "includes crontab like triggers" do
        pattern = "0 2 * * *"
        job.crontab_pattern = pattern
        triggers = doc.search("project/triggers/*")
        triggers.map(&:name).should == ["hudson.triggers.TimerTrigger"]
        triggers.first.at("spec").inner_text.should == "0 2 * * *"
      end
      
      %w(logRotator assignedNode).each do |key|
        it "does not include a #{key} node by default" do
          doc.at("/project/#{key}").should be_nil
        end
      end
      
      it "sets assignedNode when node is set" do
        job.node = "processor"
        doc.at("/project/assignedNode").inner_text.should == "processor"
        doc.at("/project/canRoam").inner_text.should == "false"
      end
      
      it "allows setting a description" do
        job.description = "some description"
        doc.at("/project/description").inner_text.should == "some description"
      end
      
      it "returns the correct md5" do
        job.stub(:to_xml).and_return "some test"
        job.md5.should == "f1b75ac7689ff88e1ecc40c84b115785"
      end
      
      describe "with days_to_keep set" do
        before(:each) do
          job.days_to_keep = 7
        end
        
        it "sets days_to_keep to 7" do
          doc.at("/project/logRotator/daysToKeep").inner_text.should == "7"
        end
        
        %w(numToKeep artifactDaysToKeep artifactNumToKeep).each do |key|
          it "sets #{key} to -1" do
            doc.at("/project/logRotator/#{key}").inner_text.should == "-1"
          end
        end
      end
      
      describe "with num_to_keep set" do
        before(:each) do
          job.num_to_keep = 30
        end
        
        it "sets num_to_keep to 30" do
          doc.at("/project/logRotator/numToKeep").inner_text.should == "30"
        end
        
        %w(daysToKeep artifactDaysToKeep artifactNumToKeep).each do |key|
          it "sets #{key} to -1" do
            doc.at("/project/logRotator/#{key}").inner_text.should == "-1"
          end
        end
      end
      
      it "sets numToKeep and daysToKeep when both set" do
        job.num_to_keep = 10
        job.days_to_keep = 2
        doc.at("/project/logRotator/numToKeep").inner_text.should == "10"
        doc.at("/project/logRotator/daysToKeep").inner_text.should == "2"
      end
      
      describe "with child projects" do
        let(:child1) { DynportTools::Jenkins::Project.new("child 1") }
        let(:child2) { DynportTools::Jenkins::Project.new("child 2") }
        let(:triggers) { doc.xpath("/project/publishers/hudson.tasks.BuildTrigger") }
        
        before(:each) do
          job.child_projects << child2
          job.child_projects << child1
        end
        
        it "includes all child projects" do
          triggers.count.should == 1
          triggers.first.at("childProjects").inner_text.should == "child 2,child 1"
        end
        
        { "name" => "SUCCESS", "ordinal" => "0", "color" => "BLUE" }.each do |key, value|
          it "sets #{key} to #{value} in threshold" do
            triggers.first.at("threshold/#{key}").inner_text.should == value
          end
        end
      end
      
      describe "#with locks" do
        let(:locks) { doc.xpath("/project/buildWrappers/hudson.plugins.locksandlatches.LockWrapper/locks/hudson.plugins.locksandlatches.LockWrapper_-LockWaitConfig") }
        before(:each) do
          job.locks << "exclusive3"
          job.locks << "exclusive2"
        end
        
        it "sets the correct amount of locks" do
          locks.count.should == 2
        end
        
        it "sets the correct locks" do
          locks.map { |l| l.at("name").inner_text }.should == %w(exclusive3 exclusive2)
        end
      end
    end
  end
  
  describe "#initialize" do
    it "sets the root url" do
      DynportTools::Jenkins.new("some/host").url.should == "some/host"
    end
  end
  
  describe "#post_request" do
    it "clears the local cache" do
      jenkins.instance_variable_set("@cache", { :a => 1 })
      jenkins.post_request("some/path")
      jenkins.instance_variable_get("@cache").should == {}
    end
  end
  
  describe "#projects_hash" do
    let(:body) do
      html =<<-HTML
        <hudson>
        <assignedLabel/>
        <mode>NORMAL</mode>
        <nodeDescription>the master Hudson node</nodeDescription>
        <nodeName/>
        <numExecutors>5</numExecutors>
        <job>
        <name>Job 2</name>
        <url>
        http://hudson.host:8080/job/Job2/
        </url>
        <color>blue</color>
        </job>
        <job>
        <name>Job 1</name>
        <url>
        http://hudson.host:8080/job/Job1/
        </url>
        <color>blue</color>
        </job>
        </hudson>
      HTML
    end
    
    let(:response) { double("response", :body => body).as_null_object }
    
    before(:each) do
      Typhoeus::Request.stub(:get).and_return response
    end
    
    it "fetches the correct url" do
      Typhoeus::Request.should_receive(:get).with("http://some.url.com:8098/api/xml")
      jenkins.projects_hash
    end
    
    it "returns the correct projects_hash" do
      jobs = jenkins.projects_hash
      jobs["http://hudson.host:8080/job/Job1/"].should == { :url => "http://hudson.host:8080/job/Job1/", :name => "Job 1"}
      jobs["http://hudson.host:8080/job/Job2/"].should == { :url => "http://hudson.host:8080/job/Job2/", :name => "Job 2"}
    end
  end
  
  it "sends the correct Typhoeus request when creating a project" do
    xml = "some_xml"
    Typhoeus::Request.should_receive(:post).with("http://some.url.com:8098/createItem?name=Test%20Job",
      :headers => { "Content-Type" => "application/xml" }, :body => "some_xml"
    )
    jenkins.create_project("Test Job", xml)
  end
  
  it "sends the correct request when updating a project" do
    xml = "some_update"
    Typhoeus::Request.should_receive(:post).with("http://some.url.com:8098/job/Test%20Job/config.xml",
      :headers => { "Content-Type" => "application/xml" }, :body => "some_update"
    )
    jenkins.update_project("Test Job", xml)
  end
  
  { 
    :delete_project => "doDelete", :build_project => "build", :disable_project => "disable",
    :enable_project => "enable"
  }.each do |method, action|
    it "posts to the correct url when calling #{action}" do
      Typhoeus::Request.should_receive(:post).with("http://some.url.com:8098/job/Test%20Job/#{action}")
      jenkins.send(method, "Test Job")
    end
  end

  describe "#project_details" do
    before(:each) do
      jenkins.stub!(:projects_hash).and_return(
        "http://hudson.host:8080/job/Job1/" => { :url => "http://hudson.host:8080/job/Job1/", :name => "Job 1"},
        "http://hudson.host:8080/job/Job2/" => { :url => "http://hudson.host:8080/job/Job2/", :name => "Job 2"}
      )
    end
    
    it "returns a hash with the correct job details and normalizes with nokogiri" do
      response1 = Typhoeus::Response.new(:code => 200, :headers => "", :body => "<root><a>test1</a><b></b></root>")
      response2 = Typhoeus::Response.new(:code => 200, :headers => "", :body => "<root><a>test2</a><b></b></root>")
      jenkins.hydra.stub(:get, "http://hudson.host:8080/job/Job1/config.xml").and_return(response1)
      jenkins.hydra.stub(:get, "http://hudson.host:8080/job/Job2/config.xml").and_return(response2)
      details = jenkins.project_details
      details.should be_an_instance_of(Hash)
      details["http://hudson.host:8080/job/Job2/"].should == {
        :body=>"<?xml version=\"1.0\"?>\n<root>\n  <a>test2</a>\n  <b/>\n</root>\n", 
        :md5=>"b52105fcdd28fe6428df019e121f106a", :name=>"Job 2", :url=>"http://hudson.host:8080/job/Job2/"
      }
      details["http://hudson.host:8080/job/Job1/"].should == {
        :body=>"<?xml version=\"1.0\"?>\n<root>\n  <a>test1</a>\n  <b/>\n</root>\n", 
        :md5=>"14fa3890bea86820f7e45ce7f5a3ada4", :name=>"Job 1", :url=>"http://hudson.host:8080/job/Job1/"
      }
    end
  end

  describe "#remote_projects" do
    before(:each) do
      jenkins.stub(:project_details).and_return({})
    end
    it "calls project_details" do
      jenkins.should_receive(:project_details).and_return({})
      jenkins.remote_projects
    end
    
    it "returns a hash" do
      jenkins.remote_projects.should be_kind_of(Hash)
    end
    
    it "sets RemoteProject as values for hash" do
      jenkins.should_receive(:project_details).and_return(
        "url1" => { :name => "Project 1", :body => "some xml", :url => "url1" },
        "url2" => { :name => "Project 2", :body => "some other xml", :url => "url2" }
      )
      remote_projects = jenkins.remote_projects
      remote_projects.values.map(&:class).should == [DynportTools::Jenkins::RemoteProject, DynportTools::Jenkins::RemoteProject]
      remote_projects["Project 1"].should return_values(:url => "url1", :name => "Project 1", :xml => "some xml")
    end
  end
end
