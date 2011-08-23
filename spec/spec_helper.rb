$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rspec'
require 'dynport_tools'
require "timecop"

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|
  config.include DynportTools::HaveAttributesMatcher
  config.after(:each) do
    Timecop.return
  end
end

def root
  Pathname.new(File.expand_path("../../", __FILE__))
end

def redis_pidfile
  root.join("tmp/redis.pid")
end

def redis_socket
  root.join("tmp/redis.socket")
end

redis_config = [
  "port 0",
  "unixsocket #{redis_socket}",
  "pidfile #{redis_pidfile}",
  "daemonize yes"
].join("\n")

FileUtils.mkdir_p(File.dirname(redis_pidfile))

system("echo '#{redis_config}' | redis-server -")

at_exit do
  pid = File.read(redis_pidfile).strip
  system("kill #{pid}")
  FileUtils.rm_f(redis_socket)
end