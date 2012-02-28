require "spec_helper"

describe "RemoteProject" do
  let(:remote_project) do
    xml = File.read(root.join("spec/fixtures/jenkins_job.xml")) 
    remote_project = DynportTools::Jenkins::RemoteProject.new(:xml => xml)
    remote_project
  end
    
  it "can be initialized" do
    DynportTools::Jenkins::RemoteProject.new(:url => "some/url", :name => "Some Name").should return_values(:url => "some/url", 
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