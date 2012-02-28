require "redis"
require "singleton"
require "logger"
require "fileutils"

class DynportTools::EmbeddedRedis
  include Singleton
  
  attr_accessor :started, :base_path, :killed, :custom_config
  attr_writer :logger
  
  def initialize(options = {})
    self.base_path = options[:base_path] || "/tmp/embedded_redis"
    self.logger = options[:logger] || Logger.new($stderr)
  end
  
  def pid_path
    "#{base_path}/redis.#{Process.pid}.pid"
  end
  
  def socket_path
    "#{base_path}/redis.#{Process.pid}.socket"
  end
  
  def dbfilename
    "redis.#{Process.pid}.rdb"
  end
  
  def dbfile_path
    "#{base_path}/#{dbfilename}"
  end
  
  def pid
    if File.exists?(pid_path)
      pid = File.read(pid_path).strip
      pid.length > 0 ? pid : nil
    end
  end
  
  def running?
    !!(pid && IO.popen("ps -p #{pid} | grep redis-server").count > 0)
  end
  
  def start
    if !running?
      do_start!
    else
      log "already running with pid #{pid}"
    end
    connection
  end
  
  def self.system(cmd)
    Kernel.send(:system, cmd)
  end
  
  def do_start!
    FileUtils.mkdir_p(base_path)
    self.class.system(%(echo "#{config}" | redis-server -))
    sleep 0.1
    self.started = true
    log "started redis with pid #{pid}"
    at_exit do
      kill
    end
  end
  
  def started?
    !!self.started
  end
  
  def connection
    if !started?
      start 
    end
    @connection ||= Redis.new(:path => socket_path)
  end
  
  def log(message)
    logger.info("EMBEDDED_REDIS: #{message}")
  end
  
  def logger
    @logger ||= Logger.new($stdout)
  end
  
  def killed?
    !!killed
  end
  
  def kill
    log "killing redis"
    if !killed? && pid
      log "killing #{pid}"
      self.class.system(%(kill #{pid})) 
      FileUtils.rm_f(socket_path)
      FileUtils.rm_f(dbfile_path)
      self.killed = true
    end
  end
  
  def default_config
    { 
      :daemonize => "yes", :pidfile => pid_path, :port => 0, :unixsocket => socket_path, :dir => base_path, 
      :dbfilename  => dbfilename
    }
  end
  
  def config
    default_config.merge(custom_config || {}).map { |key, value| ["#{key} #{value}"] }.join("\n")
  end
end