class DynportTools::Jenkins::RemoteProject
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