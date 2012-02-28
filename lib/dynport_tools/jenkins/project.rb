class DynportTools::Jenkins::Project
  attr_accessor :name, :commands, :crontab_pattern, :days_to_keep, :num_to_keep, :node, :child_projects, :locks, :disabled, :description, 
    :email_addresses, :git_repository, :destroyed
  DEFAULT_SCM = "hudson.scm.NullSCM"
  GIT_SCM = "hudson.plugins.git.GitSCM"
    
  def initialize(name = nil)
    self.name = name
    self.commands = []
    self.child_projects = []
    self.email_addresses = []
    self.locks = []
  end
    
  def destroyed?
    !!@destroyed
  end
    
  def md5
    Digest::MD5.hexdigest(to_xml)
  end
    
  def log_rotate_xml(node)
    node.logRotator do
      node.daysToKeep days_to_keep || -1
      node.numToKeep num_to_keep || -1 
      node.artifactDaysToKeep -1
      node.artifactNumToKeep -1
    end
  end
    
  def git_repository_xml(xml)
    xml.send("org.spearce.jgit.transport.RemoteConfig") do
      xml.string "origin"
      xml.int 5
      xml.string "fetch"
      xml.string "+refs/heads/*:refs/remotes/origin/*"
      xml.string "receivepack"
      xml.string "git-upload-pack"
      xml.string "uploadpack"
      xml.string "git-upload-pack"
      xml.string "url"
      xml.string git_repository
      xml.string "tagopt"
      xml.string
    end
  end
    
  def git_options_xml(xml)
    xml.mergeOptions
    xml.recursiveSubmodules false
    xml.doGenerateSubmoduleConfigurations false
    xml.authorOrCommitter false
    xml.clean false
    xml.wipeOutWorkspace false
    xml.pruneBranches false
    xml.buildChooser(:class => "hudson.plugins.git.util.DefaultBuildChooser")
    xml.gitTool "Default"
    xml.submoduleCfg(:class => "list")
    xml.relativeTargetDir
    xml.excludedRegion
    xml.excludedUsers
    xml.skipTag false
  end
    
  def git_xml(xml)
    xml.scm(:class => GIT_SCM) do
      xml.config_version 1
      xml.remoteRepositories do
        git_repository_xml(xml)
      end
      xml.branches do
        xml.send("hudson.plugins.git.BranchSpec") do
          xml.name "master"
        end
      end
      git_options_xml(xml)
    end
  end
    
  def to_xml
    Nokogiri::XML::Builder.new(:encoding => "UTF-8") do |xml|
      xml.project do
        xml.actions
        xml.description *[description].compact
        log_rotate_xml(xml) if days_to_keep || num_to_keep
        xml.keepDependencies false
        xml.properties
        if git_repository
          git_xml(xml)
        else
          xml.scm(:class => DEFAULT_SCM)
        end
        if node
          xml.assignedNode node 
          xml.canRoam false
        else
          xml.canRoam true
        end
        xml.disabled disabled ? true : false
        xml.blockBuildWhenDownstreamBuilding false
        xml.blockBuildWhenUpstreamBuilding false
        xml.triggers(:class => "vector") do
          if crontab_pattern
            xml.send("hudson.triggers.TimerTrigger") do
              xml.spec crontab_pattern
            end
          end
        end
        xml.concurrentBuild false
        xml.builders do
          commands.each do |command|
            xml.send("hudson.tasks.Shell") do
              xml.command command
            end
          end
        end
        xml.publishers do
          if child_projects.any?
            xml.send("hudson.tasks.BuildTrigger") do
              xml.childProjects child_projects.map { |c| c.name }.join(",")
              xml.threshold do
                xml.name "SUCCESS"
                xml.ordinal "0"
                xml.color "BLUE"
              end
            end
          end
          if email_addresses.any?
            xml.send("hudson.tasks.Mailer") do
              xml.recipients email_addresses.join(",")
              xml.dontNotifyEveryUnstableBuild true
              xml.sendToIndividuals false
            end
          end
        end
        xml.buildWrappers do
          if locks.any?
            xml.send("hudson.plugins.locksandlatches.LockWrapper") do
              xml.locks do
                locks.each do |lock|
                  xml.send("hudson.plugins.locksandlatches.LockWrapper_-LockWaitConfig") { xml.name lock }
                end
              end
            end
          end
        end
      end
    end.to_xml
  end
end