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
            yield([prefix, key].flatten.compact, diff.first, diff.at(1))
          else
            each_diff(diff, [prefix, key], &block)
          end
        end
      end
    end
  
    def diff_to_message_lines(the_diff)
      diffs = []
      each_diff(the_diff) do |keys, old_value, new_value|
        if keys.nil?
          diffs << "expected #{expected_value(old_value)} to be #{expected_value(new_value)}"
        else
          diffs << "expected #{keys_to_s(keys)} to #{use_return ? "return" : "be"} #{expected_value(old_value)} but #{use_return ? "did" : "was"} #{expected_value(new_value)}"
        end
      end
      diffs
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
    
    def hash_value_from_key(hash, key, symbolize = false)
      if !symbolize || hash.has_key?(key)
        hash[key]
      elsif key.is_a?(Symbol)
        hash[key.to_s]
      else
        hash[key.to_sym]
      end
    end
  
    def diff_hash_values(a, b, keys)
      ret = keys.uniq.inject({}) do |hash, key|
        value_a = hash_value_from_key(a, key, symbolize_keys)
        value_b = hash_value_from_key(b, key, symbolize_keys)
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
    
    def keys_to_s(keys)
      keys.compact.map { |k| k.is_a?(Hash) ? k.inspect : k }.join("/")
    end
  
    def merge_prefixes(prefix, key)
      key_s = key.is_a?(Hash) ? key.inspect : key
      prefix ? "#{prefix}[#{key_s}]" : key_s
    end
  end
end