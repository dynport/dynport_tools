require 'spec_helper'

require "dynport_tools/jenkins"

describe "DynportTools::Jenkins" do
  let(:root) { "http://some.url.com:8098" }
  let(:jenkins) { DynportTools::Jenkins.new(root) }
  
  describe "#initialize" do
    it "sets the root url" do
      DynportTools::Jenkins.new("some/host").url.should == "some/host"
    end
  end
  
  describe "#jobs_hash" do
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
      jenkins.jobs_hash
    end
    
    it "returns the correct jobs_hash" do
      jobs = jenkins.jobs_hash
      jobs["http://hudson.host:8080/job/Job1/"].should == { :url => "http://hudson.host:8080/job/Job1/", :name => "Job 1"}
      jobs["http://hudson.host:8080/job/Job2/"].should == { :url => "http://hudson.host:8080/job/Job2/", :name => "Job 2"}
    end
  end

  describe "#job_details" do
    before(:each) do
      jenkins.stub!(:jobs_hash).and_return(
        "http://hudson.host:8080/job/Job1/" => { :url => "http://hudson.host:8080/job/Job1/", :name => "Job 1"},
        "http://hudson.host:8080/job/Job2/" => { :url => "http://hudson.host:8080/job/Job2/", :name => "Job 2"}
      )
    end
    
    it "returns a hash with the correct job details" do
      response1 = Typhoeus::Response.new(:code => 200, :headers => "", :body => "response1")
      response2 = Typhoeus::Response.new(:code => 200, :headers => "", :body => "response2")
      jenkins.hydra.stub(:get, "http://hudson.host:8080/job/Job1/config.xml").and_return(response1)
      jenkins.hydra.stub(:get, "http://hudson.host:8080/job/Job2/config.xml").and_return(response2)
      details = jenkins.job_details
      details.should be_an_instance_of(Hash)
      details["http://hudson.host:8080/job/Job2/"].should == { :body=>"response2", :md5=>"6d8aa682668fbd4a324aa5299495cc69", 
        :name => "Job 2", :url => "http://hudson.host:8080/job/Job2/"
      }
      details["http://hudson.host:8080/job/Job1/"].should == { :body=>"response1", :md5=>"d20a5df8f659a0af0f08de8da34fe8bc", 
        :name => "Job 1", :url => "http://hudson.host:8080/job/Job1/"
      }
    end
  end
end
