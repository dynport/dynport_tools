class Differ
  attr_accessor :diff_all, :use_return
  
  
  def initialize(options = {})
    self.diff_all = options[:diff_all] != false
    self.use_return = options[:use_return] == true
  end
  
  def diff(a, b)
    if both?(a, b, Hash)
      diff_hash_values(a, b, a.keys + (self.diff_all ? b.keys : []))
    elsif both?(a, b, Array)
      diff_hash_values(a, b, all_array_indexes(a, b))
    else
      [a, b] if a != b
    end
  end
  
  def diff_to_message_lines(the_diff, prefix = nil)
    if the_diff.is_a?(Array)
      ["expected #{expected_value(the_diff.first)} to be #{expected_value(the_diff.at(1))}"]
    elsif the_diff.is_a?(Hash)
      the_diff.map do |key, diff|
        if diff.is_a?(Array)
          "expected #{merge_prefixes(prefix, key)} to #{use_return ? "return" : "be"} #{expected_value(diff.first)} but #{use_return ? "did" : "was"} #{expected_value(diff.at(1))}"
        else
          diff_to_message_lines(diff, merge_prefixes(prefix, key))
        end
      end.flatten
    else
      []
    end
  end
  
private
  def expected_value(value)
    "<#{value.inspect}>"
  end
  
  def all_array_indexes(a, b)
    0.upto([a.length, b.length].max - 1).to_a
  end
  
  def diff_hash_values(a, b, keys)
    ret = keys.uniq.inject({}) do |hash, key|
      if diff = diff(a[key], b[key])
        hash[key] = diff
      end
      hash
    end
    ret.empty? ? nil : ret
  end
  
  def both?(a, b, clazz)
    a.is_a?(clazz) && b.is_a?(clazz)
  end
  
  def merge_prefixes(prefix, key)
    prefix ? "#{prefix}[#{key}]" : key
  end
end