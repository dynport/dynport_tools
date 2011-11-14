require "guard/guard"

SPORK_CONFIG = {
  # "SPORK_INTEGRATION" => 8987,
  # "SPORK_LIGHT" => 8988,
  "SPORK_DEFAULT" => 8989
}

module ::Guard
  class Multispork < ::Guard::Guard
    def start
      ENV["AUTOTEST"] = "true"
      SPORK_CONFIG.each do |env_key, port|
        Process.fork do
          ENV[env_key] = "true"
          cmd = "spork -p #{port}"
          puts "running: #{cmd} with #{ENV[env_key]}=true"
          system cmd
        end
      end
    end
  end
end

module ::Guard
  class Simplespec < ::Guard::Guard
    def run_all
      puts "running all"
    end

    def run_on_change(paths)
      paths = paths.select { |path| File.exists?(path) }.uniq
      if paths.any?
        started = Time.now
        cmd = "rspec #{paths.join(" ")}"
        port = nil
        if paths.first.include?("spec/integration")
          port = SPORK_CONFIG["SPORK_INTEGRATION"]
        elsif paths.length == 1 && File.read(paths.first).match(/^# (SPORK_.*?)\n/)
          port = SPORK_CONFIG[$1]
        end
        cmd << " --drb"
        # cmd << " --drb --port #{port || SPORK_CONFIG["SPORK_DEFAULT"]} --color"
        cmd << " --color"
        puts "-" * 100
        stats = run_specs(cmd)
        # status = :success #!!out.match(/ 0 failure/) ? :success : :failed
        diff = Time.now - started
        puts "-" * 100
        time_s = "#{diff} (#{diff - stats[:time]} overhead)"
        puts "total time: #{time_s}"
        ::Guard::Notifier.notify("#{stats[:status]} in #{time_s}", :title => "RSpec #{stats[:examples]} examples", :image => stats[:status])
      end
    end
    
    def run_specs(cmd)
      puts "running #{cmd}"
      chars = ""
      IO.popen(cmd, "r") do |f|
        until f.eof?
          char = f.readchar.chr
          print char
          $stdout.flush
          chars << char
        end
      end
      { :time => chars[/Finished in ([\d|\.]+)/, 1].to_f, :examples => chars[/(\d+) examples/].to_i }.tap do |stats|
        if !chars.include?(" 0 failures")
          stats.merge!(:status => :failed)
        # elsif !chars.include?(" 0 pending")
        #   :pending
        else
          stats.merge!(:status => :success)
        end
      end
    end
  end
end

group "spork" do
  guard "multispork" do
  end
end

group "spec" do
  guard "simplespec" do
    watch(%r{^spec/.*_spec.rb})
    watch(%r{^spec/.+_spec\.rb$})
    watch(%r{^lib/(.+)\.rb$})     { |m| "spec/#{m[1]}_spec.rb" }
    # watch('spec/spec_helper.rb')  { "spec" }

    # Rails example
    watch(%r{^spec/.+_spec\.rb$})
    watch(%r{^app/(.+)\.rb$})                           { |m| "spec/#{m[1]}_spec.rb" }
    watch(%r{^lib/(.+)\.rb$})                           { |m| "spec/lib/#{m[1]}_spec.rb" }
    watch(%r{^app/controllers/(.+)_(controller)\.rb$})  { |m| ["spec/routing/#{m[1]}_routing_spec.rb", "spec/#{m[2]}s/#{m[1]}_#{m[2]}_spec.rb", "spec/acceptance/#{m[1]}_spec.rb"] }
    # watch(%r{^spec/support/(.+)\.rb$})                  { "spec" }
    # watch('spec/spec_helper.rb')                        { "spec" }
    # watch('config/routes.rb')                           { "spec/routing" }
    # watch('app/controllers/application_controller.rb')  { "spec/controllers" }
    # Capybara request specs
    # watch(%r{^app/views/(.+)/.*\.(erb|haml)$})          { |m| "spec/requests/#{m[1]}_spec.rb" }
  end
end