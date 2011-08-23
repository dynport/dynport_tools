module DynportTools
end

%w(deep_merger differ jenkins redis_dumper xml_file have_attributes redis_q eta).map { |m| require "dynport_tools/#{m}" }