require 'spec_helper'

describe "DynportTools::Jenkins" do
  let(:url) { "http://some.url.com:8098" }
  let(:jenkins) { DynportTools::Jenkins.new(url) }
  before(:each) do
    Typhoeus::Request.stub!(:post).and_return nil
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
