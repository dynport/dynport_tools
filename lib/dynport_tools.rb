module DynportTools
end

%w(deep_merger differ jenkins redis_dumper xml_file).map { |m| require "dynport_tools/#{m}" }