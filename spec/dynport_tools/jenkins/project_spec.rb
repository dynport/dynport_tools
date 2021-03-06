require "spec_helper"

describe "Project" do
  let(:job) { DynportTools::Jenkins::Project.new("Some Name") }
  let(:doc) { Nokogiri::XML(job.to_xml) }
    
  describe "#initialize" do
    it "sets the commands to an empty array" do
      expect(job.commands).to eql([])
    end
      
    it "sets the commands to an empty array" do
      expect(job.child_projects).to eql([])
    end
      
    it "sets the commands to an empty array" do
      expect(job.locks).to eql([])
    end
      
    it "sets the email addresses to an empty array" do
      expect(job.email_addresses).to eql([])
    end
      
    it "sets the name" do
      expect(job.name).to eql("Some Name")
    end
      
    it "allows setting othe deleted flag" do
      job.delete = true
      expect(job.delete).to eql(true)
    end
  end
    
  it "returns the correct status for deleted" do
    job.should_not be_deleted
    job.delete = true
    job.should be_deleted
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
      
    it "adds a git entry when git is set" do
      job.git_repository = "git@github.com:dynport/dynport_tools.git"
      job.to_xml.should include(%(scm class="hudson.plugins.git.GitSCM">))
    end
      
    it "sets the correct email_addresses when present" do
      job.email_addresses = %w(test@test.xx test2@test.xx)
      expect(doc.xpath("/project/publishers/hudson.tasks.Mailer/recipients").map(&:inner_text)).to eql(["test@test.xx,test2@test.xx"])
      expect(doc.at("/project/publishers/hudson.tasks.Mailer/dontNotifyEveryUnstableBuild").inner_text).to eql("true")
      expect(doc.at("/project/publishers/hudson.tasks.Mailer/sendToIndividuals").inner_text).to eql("false")
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
        expect(doc.at("/project/#{key}").inner_text).to eql(value)
      end
    end
      
    it "sets disabled to true when set" do
      job.disabled = true
      expect(doc.at("/project/disabled").inner_text).to eql("true")
    end
      
    { "scm" => "hudson.scm.NullSCM", "triggers" => "vector" }.each do |key, clazz|
      it "sets the class of #{key} to #{clazz}" do
        expect(doc.at("/project/#{key}")["class"]).to eql(clazz)
      end
    end
      
    it "includes all set commands" do
      job.commands << "hostname"
      job.commands << "date"
      shell_tasks = doc.search("project/builders/*")
      expect(shell_tasks.map(&:name)).to eql(["hudson.tasks.Shell", "hudson.tasks.Shell"])
      expect(shell_tasks.map { |node| node.at("command").inner_text }).to eql(["hostname", "date"])
    end
      
    it "includes crontab like triggers" do
      pattern = "0 2 * * *"
      job.crontab_pattern = pattern
      triggers = doc.search("project/triggers/*")
      expect(triggers.map(&:name)).to eql(["hudson.triggers.TimerTrigger"])
      expect(triggers.first.at("spec").inner_text).to eql("0 2 * * *")
    end
      
    %w(logRotator assignedNode).each do |key|
      it "does not include a #{key} node by default" do
        doc.at("/project/#{key}").should be_nil
      end
    end
      
    it "sets assignedNode when node is set" do
      job.node = "processor"
      expect(doc.at("/project/assignedNode").inner_text).to eql("processor")
      expect(doc.at("/project/canRoam").inner_text).to eql("false")
    end
      
    it "allows setting a description" do
      job.description = "some description"
      expect(doc.at("/project/description").inner_text).to eql("some description")
    end
      
    it "returns the correct md5" do
      job.stub(:to_xml).and_return "some test"
      expect(job.md5).to eql("f1b75ac7689ff88e1ecc40c84b115785")
    end
      
    describe "with days_to_keep set" do
      before(:each) do
        job.days_to_keep = 7
      end
        
      it "sets days_to_keep to 7" do
        expect(doc.at("/project/logRotator/daysToKeep").inner_text).to eql("7")
      end
        
      %w(numToKeep artifactDaysToKeep artifactNumToKeep).each do |key|
        it "sets #{key} to -1" do
          expect(doc.at("/project/logRotator/#{key}").inner_text).to eql("-1")
        end
      end
    end
      
    describe "with num_to_keep set" do
      before(:each) do
        job.num_to_keep = 30
      end
        
      it "sets num_to_keep to 30" do
        expect(doc.at("/project/logRotator/numToKeep").inner_text).to eql("30")
      end
        
      %w(daysToKeep artifactDaysToKeep artifactNumToKeep).each do |key|
        it "sets #{key} to -1" do
          expect(doc.at("/project/logRotator/#{key}").inner_text).to eql("-1")
        end
      end
    end
      
    it "sets numToKeep and daysToKeep when both set" do
      job.num_to_keep = 10
      job.days_to_keep = 2
      expect(doc.at("/project/logRotator/numToKeep").inner_text).to eql("10")
      expect(doc.at("/project/logRotator/daysToKeep").inner_text).to eql("2")
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
        expect(triggers.count).to eql(1)
        expect(triggers.first.at("childProjects").inner_text).to eql("child 2,child 1")
      end
        
      { "name" => "SUCCESS", "ordinal" => "0", "color" => "BLUE" }.each do |key, value|
        it "sets #{key} to #{value} in threshold" do
          expect(triggers.first.at("threshold/#{key}").inner_text).to eql(value)
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
        expect(locks.count).to eql(2)
      end
        
      it "sets the correct locks" do
        expect(locks.map { |l| l.at("name").inner_text }).to eql(%w(exclusive3 exclusive2))
      end
    end
  end
end
