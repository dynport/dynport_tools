require "redis"
require "singleton"
require "logger"

class EmbeddedRedis
  include Singleton
  
  attr_accessor :started, :base_path
  attr_writer :logger
  
  def initialize(options = {})
    self.base_path = options[:base_path] || "/tmp"
    self.logger = options[:logger] || Logger.new($stderr)
  end
  
  def pid_path
    "#{base_path}/pids/redis.#{Process.pid}.pid"
  end
  
  def socket_path
    "#{base_path}/sockets/redis.#{Process.pid}.socket"
  end
  
  def pid
    File.read(pid_path).strip.presence if File.exists?(pid_path)
  end
  
  def running?
    !!(pid && `ps -p #{pid} | tail -n +2`.present?)
  end
  
  def start
    if !running?
      [socket_path, pid_path].each { |path| FileUtils.mkdir_p(File.dirname(path)) }
      system(%(echo "#{config}" | redis-server -))
      sleep 0.1
      self.started = true
      log "started redis with pid #{pid}"
      at_exit do
        kill
      end
      connection
    else
      log "already running with pid #{pid}"
    end
  end
  
  def started?
    !!self.started
  end
  
  def connection
    start if !started?
    @connection ||= Redis.new(:path => socket_path)
  end
  
  def log(message)
    logger.info("EMBEDDED_REDIS: #{message}")
  end
  
  def logger
    @logger ||= Logger.new($stdout)
  end
  
  def kill
    log "killing redis"
    if pid
      system(%(kill #{pid})) 
      FileUtils.rm_f(socket_path)
    end
  end
  
  def config
    [
      "daemonize yes",
      "pidfile #{pid_path}",
      "port 0",
      "unixsocket #{socket_path}"
      
    ].join("\n")
  end
end