# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{dynport_tools}
  s.version = "0.2.14"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Tobias Schwab"]
  s.date = %q{2011-09-02}
  s.description = %q{Collection of various tools}
  s.email = %q{tobias.schwab@dynport.de}
  s.executables = ["xmldiff", "redis_dumper"]
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.rdoc"
  ]
  s.files = [
    ".autotest",
    ".document",
    ".rbenv-version",
    ".rspec",
    "Gemfile",
    "Gemfile.lock",
    "LICENSE.txt",
    "README.rdoc",
    "Rakefile",
    "VERSION",
    "autotest/discover.rb",
    "bin/redis_dumper",
    "bin/xmldiff",
    "dynport_tools.gemspec",
    "lib/dynport_tools.rb",
    "lib/dynport_tools/ascii_table.rb",
    "lib/dynport_tools/deep_merger.rb",
    "lib/dynport_tools/differ.rb",
    "lib/dynport_tools/eta.rb",
    "lib/dynport_tools/have_attributes.rb",
    "lib/dynport_tools/jenkins.rb",
    "lib/dynport_tools/redis_dumper.rb",
    "lib/dynport_tools/redis_q.rb",
    "lib/dynport_tools/xml_file.rb",
    "spec/dynport_tools/ascii_table_spec.rb",
    "spec/dynport_tools/deep_merger_spec.rb",
    "spec/dynport_tools/differ_spec.rb",
    "spec/dynport_tools/eta_spec.rb",
    "spec/dynport_tools/have_attributes_spec.rb",
    "spec/dynport_tools/jenkins_spec.rb",
    "spec/dynport_tools/redis_dumper_spec.rb",
    "spec/dynport_tools/redis_q_spec.rb",
    "spec/dynport_tools/xml_file_spec.rb",
    "spec/dynport_tools_spec.rb",
    "spec/fixtures/file_a.xml",
    "spec/fixtures/jenkins_job.xml",
    "spec/spec_helper.rb",
    "spec/xml_diff_spec.rb"
  ]
  s.homepage = %q{http://github.com/tobstarr/dynport_tools}
  s.licenses = ["MIT"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.6.2}
  s.summary = %q{Collection of various tools}

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<nokogiri>, [">= 0"])
      s.add_runtime_dependency(%q<redis>, [">= 0"])
      s.add_runtime_dependency(%q<typhoeus>, [">= 0"])
      s.add_runtime_dependency(%q<term-ansicolor>, [">= 0"])
      s.add_runtime_dependency(%q<diff-lcs>, [">= 0"])
      s.add_development_dependency(%q<rspec>, ["~> 2.3.0"])
      s.add_development_dependency(%q<bundler>, ["~> 1.0.0"])
      s.add_development_dependency(%q<jeweler>, ["~> 1.6.4"])
      s.add_development_dependency(%q<rcov>, [">= 0"])
      s.add_development_dependency(%q<ZenTest>, ["= 4.5.0"])
      s.add_development_dependency(%q<autotest>, [">= 0"])
      s.add_development_dependency(%q<autotest-growl>, [">= 0"])
      s.add_development_dependency(%q<ruby-debug>, [">= 0"])
      s.add_development_dependency(%q<timecop>, [">= 0"])
    else
      s.add_dependency(%q<nokogiri>, [">= 0"])
      s.add_dependency(%q<redis>, [">= 0"])
      s.add_dependency(%q<typhoeus>, [">= 0"])
      s.add_dependency(%q<term-ansicolor>, [">= 0"])
      s.add_dependency(%q<diff-lcs>, [">= 0"])
      s.add_dependency(%q<rspec>, ["~> 2.3.0"])
      s.add_dependency(%q<bundler>, ["~> 1.0.0"])
      s.add_dependency(%q<jeweler>, ["~> 1.6.4"])
      s.add_dependency(%q<rcov>, [">= 0"])
      s.add_dependency(%q<ZenTest>, ["= 4.5.0"])
      s.add_dependency(%q<autotest>, [">= 0"])
      s.add_dependency(%q<autotest-growl>, [">= 0"])
      s.add_dependency(%q<ruby-debug>, [">= 0"])
      s.add_dependency(%q<timecop>, [">= 0"])
    end
  else
    s.add_dependency(%q<nokogiri>, [">= 0"])
    s.add_dependency(%q<redis>, [">= 0"])
    s.add_dependency(%q<typhoeus>, [">= 0"])
    s.add_dependency(%q<term-ansicolor>, [">= 0"])
    s.add_dependency(%q<diff-lcs>, [">= 0"])
    s.add_dependency(%q<rspec>, ["~> 2.3.0"])
    s.add_dependency(%q<bundler>, ["~> 1.0.0"])
    s.add_dependency(%q<jeweler>, ["~> 1.6.4"])
    s.add_dependency(%q<rcov>, [">= 0"])
    s.add_dependency(%q<ZenTest>, ["= 4.5.0"])
    s.add_dependency(%q<autotest>, [">= 0"])
    s.add_dependency(%q<autotest-growl>, [">= 0"])
    s.add_dependency(%q<ruby-debug>, [">= 0"])
    s.add_dependency(%q<timecop>, [">= 0"])
  end
end

