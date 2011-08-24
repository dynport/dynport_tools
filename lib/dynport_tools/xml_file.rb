require "nokogiri"

class DynportTools::XmlFile
  attr_accessor :path, :content
  
  def initialize(path_or_options = nil)
    if path_or_options.is_a?(Hash)
      self.path = path_or_options[:path].to_s if path_or_options[:path].to_s
      self.content = path_or_options[:content]
    elsif !path_or_options.nil?
      self.path = path_or_options.to_s
    end
  end
  
  def nodes_hash
    { key_for_node(doc.root) => parse_node(doc.root) }
  end
  
  def doc
    @doc ||= Nokogiri::XML(content || File.open(path))
  end
  
  def parse_node(node)
    child_elements = node.children.select { |n| n.is_a?(Nokogiri::XML::Element) }
    value = if child_elements.any?
      flatten_hash(
        child_elements.inject({}) do |hash, el|
          hash[key_for_node(el)] ||= Array.new
          hash[key_for_node(el)] << parse_node(el)
          hash
        end
      )
    else
      txt = node.inner_text.strip
      txt.length == 0 ? nil : txt
    end
  end
  
  def key_for_node(node)
    if node.attributes.any?
      node.attributes.inject({ :name => node.name }) do |hash, (key, value)|
        hash.merge!(key => value.value)
      end
    else
      node.name
    end
  end
  
  def flatten_hash(in_hash)
    in_hash.inject({}) do |hash, (key, arr_of_value)|
      if arr_of_value.is_a?(Array)
        if arr_of_value.length == 0
          hash[key] = nil
        elsif arr_of_value.length == 1
          hash[key] = arr_of_value.first
        else
          hash[key] = arr_of_value
        end
      else
        hash[key] = arr_of_value
      end
      hash
    end
  end
end