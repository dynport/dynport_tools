module DynportTools
end

require "time"
require "typhoeus"
require "nokogiri"
require "cgi"
require "term/ansicolor"
require "diff/lcs"

%w(deep_merger differ jenkins redis_dumper xml_file have_attributes redis_q eta ascii_table embedded_redis).map { |m| require "dynport_tools/#{m}" }