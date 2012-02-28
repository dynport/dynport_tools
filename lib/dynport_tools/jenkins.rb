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
        self.send(:"#{key}=", value)
      end
    end
    
    def doc
      @doc ||= Nokogiri::XML(xml) if xml
    end
    
    def md5
      Digest::MD5.hexdigest(xml) if xml
    end
    
    def days_to_keep
      logrotate_value_when_set("daysToKeep")
    end
    
    def num_to_keep
      logrotate_value_when_set("numToKeep")
    end
    
    def logrotate_value_when_set(key)
      if node = doc.at("/project/logRotator/#{key}")
        node.inner_text.to_i if node.inner_text.to_i != -1
      end
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
    
    def email_addresses
      doc.xpath("/project/publishers/hudson.tasks.Mailer/recipients").map { |rec| rec.inner_text.split(",") }.flatten
    end
    
    def node
      doc.xpath("/project/assignedNode").map { |n| n.inner_text }.first
    end
    
    def locks
 doc.xpath("/project/buildWrappers/hudson.plugins.locksandlatches.LockWrapper/locks/hudson.plugins.locksandlatches.LockWrapper_-LockWaitConfig/name").map(&:inner_text)
    end
  end
end

require "dynport_tools/jenkins/project"