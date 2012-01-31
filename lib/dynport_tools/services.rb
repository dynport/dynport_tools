class DynportTools::Services
  DEFAULTS = {
    :solr_url => "http://localhost:8983/solr/",
    :solr_data_root => "/opt/solr",
    :solr_xml => %(
      <?xml version="1.0" encoding="UTF-8" ?>
      <solr sharedLib="lib" persistent="true">
        <cores adminPath="/admin/cores">
        </cores>
      </solr>
    ).gsub(/^\s+/, "")
  }
  
  # solr
  attr_writer :solr_url
  attr_accessor :solr_instance_path, :solr_data_root
  
  def solr_data_root
    @solr_data_root || DEFAULTS[:solr_data_root]
  end
  
  def solr_xml_path
    "#{solr_data_root}/solr.xml"
  end
  
  def solr_core_names
    get(solr_url).to_s.scan(/a href=\"(.*?)\/admin/).flatten
  end
  
  def solr_bootstrapped?
    File.exists?(solr_xml_path)
  end
  
  def bootstrap_solr
    raise "#{solr_xml_path} already exists" if solr_bootstrapped?
    write_solr_xml_when_possible
  end
  
  def write_solr_xml_when_possible
    raise "please create #{solr_data_root} first" if !File.directory?(solr_data_root)
    write_solr_xml
  end
  
  def write_solr_xml
    File.open(solr_xml_path, "w") do |f|
      f.puts(DEFAULTS[:solr_xml])
    end
  end
  
  def head(url)
    if code = system_call(%(curl -s -I "#{url}" | head -n 1)).to_s.split(" ").at(1)
      code.to_i
    end
  end
  
  def get(url)
    system_call(%(curl -s "#{url}"))
  end
  
  def post(url)
    system_call(%(curl -s -I -XPOST "#{url}"))
  end
  
  def solr_url
    @solr_url || DEFAULTS[:solr_url]
  end
  
  def solr_running?
    head(self.solr_url) == 200
  end
  
  def solr_core_exists?(core_name)
    head("#{solr_url}#{core_name}/admin/") == 200
  end
  
  def create_solr_core(core_name)
    raise "please set solr_instance_path first!" if self.solr_instance_path.nil?
    raise "please set solr_data_root first!" if self.solr_data_root.nil?
    post("#{solr_url}admin/cores?action=CREATE&name=#{core_name}&instanceDir=#{solr_instance_path}&dataDir=#{solr_data_root}/#{core_name}")
  end
  
  def unload_solr_core(core_name)
    post("#{solr_url}admin/cores?action=UNLOAD&core=#{core_name}")
  end
  
  # redis
  attr_writer :redis_path_prefix, :redis_config_path, :redis_config_hash
  
  def redis_running?
    system_call(%(echo "info" | redis-cli -s #{redis_socket_path} 2> /dev/null | grep uptime_in_seconds)).include?("uptime_in_seconds")
  end
  
  def redis_path_prefix
    @redis_path_prefix or raise "redis_path_prefix not set!"
  end
  
  def redis_socket_path
    "#{redis_path_prefix}.socket"
  end
  
  def redis_config_path
    "#{redis_path_prefix}.conf"
  end
  
  def redis_log_path
    "#{redis_path_prefix}.log"
  end
  
  def redis_config_hash
    { 
      :unixsocket => redis_socket_path, 
      :port => 0,
      :logfile => redis_log_path,
      :daemonize => "yes"
    }.merge(@redis_config_hash || {})
  end
  
  def redis_config
    (redis_config_hash || {}).map { |key, value| "#{key} #{value}" if !value.nil? }.compact.join("\n")
  end
  
  def write_redis_config
    raise "please set redis_config_path first!" if redis_config_path.nil?
    File.open(redis_config_path, "w") do |f|
      f.puts(redis_config)
    end
  end
  
  def start_redis
    write_redis_config
    system_call("redis-server #{redis_config_path}")
  end
  
  def system_call(cmd)
    puts "executing: #{cmd}"
    Kernel.send(:`, cmd)
  end
end