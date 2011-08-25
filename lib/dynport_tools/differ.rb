module DynportTools
  class Differ
    attr_accessor :diff_all, :use_return, :symbolize_keys
  
  
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
    
    def each_diff(the_diff, prefix = nil, &block)
      if the_diff.is_a?(Array)
        yield(prefix, the_diff.first, the_diff.at(1))
      elsif the_diff.is_a?(Hash)
        the_diff.each do |key, diff|
          if diff.is_a?(Array)
            yield([prefix, key], diff.first, diff.at(1))
          else
            each_diff(diff, merge_prefixes(prefix, key), &block)
          end
        end
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
    
    def diff_strings(a, b)
      chunks = []
      last = 0
      Diff::LCS.diff(a, b).each do |group|
        old_s = []
        new_s = []
        removed_elements(group).each_with_index do |c, i|
          chunks << a[last..(c.position - 1)] if i == 0
          old_s << c.element 
          last = c.position + 1
        end
        added_elements(group).each_with_index do |c, i|
          if i == 0 && removed_elements(group).empty?
            chunks << a[last..(c.position - 1)]
            last = c.position
          end
          new_s << c.element
        end
        if (old_s.join("").length > 0 || new_s.join("").length > 0)
          chunks << Term::ANSIColor.bold("<#{Term::ANSIColor.red(old_s.join(""))}|#{Term::ANSIColor.green(new_s.join(""))}>")
        end
      end
      chunks.join("")
    end
  
  private
    def removed_elements(group)
      group.select { |c| c.action == "-" }
    end

    def added_elements(group)
      group.select { |c| c.action == "+" }
    end
    
    def expected_value(value)
      "<#{value.inspect}>"
    end
  
    def all_array_indexes(a, b)
      0.upto([a.length, b.length].max - 1).to_a
    end
  
    def diff_hash_values(a, b, keys)
      ret = keys.uniq.inject({}) do |hash, key|
        value_a = a[key]
        value_b = b[key]
        if symbolize_keys
          value_a ||= a[key.is_a?(Symbol) ? key.to_s : key.to_sym]
          value_b ||= b[key.is_a?(Symbol) ? key.to_s : key.to_sym]
        end
        if diff = diff(value_a, value_b)
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
      key_s = key.is_a?(Hash) ? key.inspect : key
      prefix ? "#{prefix}[#{key_s}]" : key_s
    end
  end
end