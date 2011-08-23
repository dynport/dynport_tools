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
  
  class Job
    attr_accessor :commands, :crontab_pattern, :days_to_keep
    DEFAUL_SCM = "hudson.scm.NullSCM"
    
    def initialize
      self.commands = []
    end
    
    def to_xml
      Nokogiri::XML::Builder.new(:encoding => "UTF-8") do |xml|
        xml.project do
          xml.actions
          xml.description
          if days_to_keep
            xml.logRotator do
              xml.daysToKeep days_to_keep
              xml.numToKeep -1
              xml.artifactDaysToKeep -1
              xml.artifactNumToKeep -1
            end
          end
          xml.keepDependencies "false"
          xml.properties
          xml.scm(:class => DEFAUL_SCM)
          xml.canRoam "true"
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
          end
          xml.buildWrappers do
          end
        end
      end.to_xml
    end
  end
end