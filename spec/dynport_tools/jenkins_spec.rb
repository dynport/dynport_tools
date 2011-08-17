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
    
    it "returns a hash with the correct job details and normalizes with nokogiri" do
      response1 = Typhoeus::Response.new(:code => 200, :headers => "", :body => "<root><a>test1</a><b></b></root>")
      response2 = Typhoeus::Response.new(:code => 200, :headers => "", :body => "<root><a>test2</a><b></b></root>")
      jenkins.hydra.stub(:get, "http://hudson.host:8080/job/Job1/config.xml").and_return(response1)
      jenkins.hydra.stub(:get, "http://hudson.host:8080/job/Job2/config.xml").and_return(response2)
      details = jenkins.job_details
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
    
    it "has a builder" do
      builder = Nokogiri::XML::Builder.new(:encoding => "UTF-8") do |xml|
        xml.project {
          xml.actions
          xml.description
          xml.keepDependencies false
          xml.properties
          xml.scm(:class => "hudson.scm.NullSCM")
          xml.canRoam true
          xml.disabled false
          xml.blockBuildWhenDownstreamBuilding false
          xml.blockBuildWhenUpstreamBuilding false
          xml.triggers(:class => "vector")
          xml.concurrentBuild false
          xml.builders do
            xml.send("hudson.tasks.Shell") do
              xml.command %(#!/bin/sh\nssh some.host "cd /some/path && ./script/runner -e production 'Some.command'")
            end
          end
          xml.publishers
          xml.buildWrappers do
            xml.send("hudson.plugins.locksandlatches.LockWrapper") do
              xml.locks do
                xml.send("hudson.plugins.locksandlatches.LockWrapper_-LockWaitConfig") do
                  xml.name "Popularities"
                end
              end
            end
          end
        }
      end
      builder.to_xml.should == Nokogiri::XML(File.read(ROOT.join("spec/fixtures/jenkins_job.xml"))).to_s
    end
  end
end
