$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rspec'
require 'dynport_tools'
require "timecop"
require "ruby-debug"

if defined?(Debugger) && Debugger.respond_to?(:settings)
  Debugger.settings[:autolist] = 1
  Debugger.settings[:autoeval] = true
end

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|
  config.include DynportTools::HaveAttributesMatcher
  config.after(:each) do
    Timecop.return
  end
end

DynportTools::EmbeddedRedis.instance.logger = Logger.new("/dev/null")

def root
  Pathname.new(File.expand_path("../../", __FILE__))
end