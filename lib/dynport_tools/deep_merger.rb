class DynportTools::DeepMerger
  class << self
    def merge(a, b)
      if a.is_a?(Hash) && b.is_a?(Hash)
        merge_hashes(a, b)
      elsif a.is_a?(Array) && b.is_a?(Array)
        merge_arrays(a, b)
      else
        b
      end
    end
    
    def merge_arrays(a, b)
      [a.length, b.length].max.times.map do |i|
        if b.length < i + 1
          a[i]
        elsif a.length < i + 1
          b[i]
        else
          merge(a[i], b[i])
        end
      end
    end
    
    def merge_hashes(a, b)
      (a.keys + b.keys).uniq.inject({}) do |hash, key|
        if !a.has_key?(key)
          hash[key] = b[key]
        elsif !b.has_key?(key)
          hash[key] = a[key]
        else
          hash[key] = merge(a[key], b[key])
        end
        hash
      end
    end
  end
end