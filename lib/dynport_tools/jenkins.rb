class DynportTools::Jenkins
  attr_accessor :url
  
  def initialize(url = nil)
    self.url = url
  end
  
  def hydra
    @hydra ||= Typhoeus::Hydra.new
  end
  
  def create_project(name, xml)
    post_request "createItem?name=#{escape_job_name(name)}", :headers => { "Content-Type" => "application/xml" }, :body => xml
  end
  
  def update_project(name, xml)
    post_request "job/#{escape_job_name(name)}/config.xml", :headers => { "Content-Type" => "application/xml" }, :body => xml
  end
  
  def delete_project(name)
    send_to_project(name, "doDelete")
  end
  
  def build_project(name)
    send_to_project(name, "build")
  end
  
  def disable_project(name)
    send_to_project(name, "disable")
  end
  
  def enable_project(name)
    send_to_project(name, "enable")
  end
  
  def send_to_project(name, action)
    post_request "job/#{escape_job_name(name)}/#{action}"
  end
  
  def post_request(path, options = nil)
    @cache = {}
    Typhoeus::Request.post(*["#{url}/#{path}", options].compact)
  end
  
  def cache
    @cache ||= {}
  end
  
  def escape_job_name(name)
    URI.escape(name)
  end
  
  def projects_hash
    cache[:projects_hash] ||= Nokogiri::XML(Typhoeus::Request.get("#{url}/api/xml").body).search("job").inject({}) do |hash, node|
      url = node.at("url").inner_text.strip if node.at("url")
      name = node.at("name").inner_text.strip if node.at("name")
      hash[url] = { :url => url, :name => name }
      hash
    end
  end
  
  def project_details
    return cache[:projects_details] if cache[:projects_details]
    jobs = {}
    projects_hash.each do |url, job|
      request = Typhoeus::Request.new("#{url}config.xml")
      request.on_complete do |response|
        xml = Nokogiri::XML(response.body).to_s
        jobs[url] = job.merge(:body => xml, :md5 => Digest::MD5.hexdigest(xml))
      end
      hydra.queue(request)
    end
    hydra.run
    cache[:projects_details] = jobs
  end
  
  def remote_projects
    project_details.inject({}) do |hash, (url, project_hash)|
      hash.merge!(project_hash[:name] => RemoteProject.new(:url => project_hash[:url], :name => project_hash[:name], :xml => project_hash[:body]))
    end
  end
  
  class RemoteProject
    attr_accessor :url, :name, :xml
    
    def initialize(options = {})
      options.each do |key, value|
        self.send(:"#{key}=", value) if self.respond_to?(:"#{key}=")
      end
    end
    
    def doc
      @doc ||= Nokogiri::XML(xml) if xml
    end
    
    def md5
      Digest::MD5.hexdigest(xml) if xml
    end
    
    def commands
      doc.xpath("/project/builders/hudson.tasks.Shell/command").map(&:inner_text)
    end
    
    def crontab_patterns
      doc.xpath("/project/triggers/hudson.triggers.TimerTrigger/spec").map(&:inner_text)
    end
    
    def disabled?
      doc.at("/project/disabled/text()").to_s == "true"
    end
    
    def child_projects
      if projects = doc.xpath("/project/publishers/hudson.tasks.BuildTrigger/childProjects").first
        projects.inner_text.split(/\s*,\s*/)
      else
        []
      end
    end
    
    def locks
 doc.xpath("/project/buildWrappers/hudson.plugins.locksandlatches.LockWrapper/locks/hudson.plugins.locksandlatches.LockWrapper_-LockWaitConfig/name").map(&:inner_text)
    end
  end
  
  class Project
    attr_accessor :name, :commands, :crontab_pattern, :days_to_keep, :num_to_keep, :node, :child_projects, :locks
    DEFAUL_SCM = "hudson.scm.NullSCM"
    
    def initialize(name)
      self.name = name
      self.commands = []
      self.child_projects = []
      self.locks = []
    end
    
    def to_xml
      Nokogiri::XML::Builder.new(:encoding => "UTF-8") do |xml|
        xml.project do
          xml.actions
          xml.description
          if days_to_keep || num_to_keep
            xml.logRotator do
              xml.daysToKeep days_to_keep || -1
              xml.numToKeep num_to_keep || -1 
              xml.artifactDaysToKeep -1
              xml.artifactNumToKeep -1
            end
          end
          xml.keepDependencies "false"
          xml.properties
          xml.scm(:class => DEFAUL_SCM)
          if node
            xml.assignedNode node 
            xml.canRoam "false"
          else
            xml.canRoam "true"
          end
          xml.disabled "false"
          xml.blockBuildWhenDownstreamBuilding "false"
          xml.blockBuildWhenUpstreamBuilding "false"
          xml.triggers(:class => "vector") do
            if crontab_pattern
              xml.send("hudson.triggers.TimerTrigger") do
                xml.spec crontab_pattern
              end
            end
          end
          xml.concurrentBuild "false"
          xml.builders do
            commands.each do |command|
              xml.send("hudson.tasks.Shell") do
                xml.command ["#!/bin/sh", command].join("\n")
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
end