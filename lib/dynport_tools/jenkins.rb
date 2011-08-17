require "typhoeus"
require "nokogiri"

class DynportTools::Jenkins
  attr_accessor :url
  
  def initialize(url = nil)
    self.url = url
  end
  
  def hydra
    @hydra ||= Typhoeus::Hydra.new
  end
  
  def jobs_hash
    Nokogiri::XML(Typhoeus::Request.get("#{url}/api/xml").body).search("job").inject({}) do |hash, node|
      url = node.at("url").inner_text.strip if node.at("url")
      name = node.at("name").inner_text.strip if node.at("name")
      hash[url] = { :url => url, :name => name }
      hash
    end
  end
  
  def job_details
    jobs = {}
    jobs_hash.each do |url, job|
      request = Typhoeus::Request.new("#{url}config.xml")
      request.on_complete do |response|
        xml = Nokogiri::XML(response.body).to_s
        jobs[url] = job.merge(:body => xml, :md5 => Digest::MD5.hexdigest(xml))
      end
      hydra.queue(request)
    end
    hydra.run
    jobs
  end
end