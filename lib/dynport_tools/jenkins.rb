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
    clear_cache
    Typhoeus::Request.post(*["#{url}/#{path}", options].compact)
  end
  
  def clear_cache
    cache.clear
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
  
  CONFIGURED_PROJECTS_HASH = :configured_projects_hash
  
  def configured_projects_hash=(new_hash)
    @configured_projects_hash = new_hash
  end
  
  def configured_projects_hash
    @configured_projects_hash ||= {}
  end
  
  def configured_projects
    configured_projects_hash.values
  end
  
  def remote_projects
    project_details.inject({}) do |hash, (url, project_hash)|
      hash[project_hash[:name]] = RemoteProject.from_details_hash(project_hash)
      hash
    end
  end
  
  def exists_remotely?(project)
    remote_projects.keys.include?(project.name)
  end
  
  def projects_to_delete
    configured_projects.select { |project| project.deleted? && exists_remotely?(project) }
  end
  
  def projects_to_create
    configured_projects.select { |project| !project.deleted? && !exists_remotely?(project) }
  end
  
  def projects_to_update
    configured_projects.select { | project| exists_remotely?(project) && !project.deleted? && (project.md5 != remote_projects[project.name].md5) }
  end
  
  def not_configured_projects
    remote_projects.values.select { |project| !configured_projects_hash.keys.include?(project.name) }
  end
end

require "dynport_tools/jenkins/project"
require "dynport_tools/jenkins/remote_project"