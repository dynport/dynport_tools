require File.expand_path("../../../lib/differ", __FILE__)
module HaveAttributesMatcher
  class HaveAttributes
    def initialize(expected)
      @expected = expected
    end
    
    def differ
      @differ ||= Differ.new(:diff_all => false)
    end

    def matches?(target)
      @target = target
      if diff = differ.diff(@expected, target)
        @error = differ.diff_to_message_lines(diff).join("\n")
        false
      else
        true
      end
    end

    def failure_message
      @error
    end
  end
  
  class ReturnValues < HaveAttributes
    def matches?(target)
      differ.use_return = true
      super(@expected.keys.inject({}) { |hash, key| hash.merge!(key => target.send(key)) })
    end
  end
  
  class HaveAllAttributes < HaveAttributes
    def matches?(record)
      differ.diff_all = true
      super(record)
    end
  end
  
  class HaveOneWithAttributes < HaveAttributes
    def matches?(target)
      target.any? do |record|
        super(record)
      end
    end
    
    def failure_message
      "expected to have one record with attributes #{@expected.inspect}"
    end
  end
  
  def return_values(expected)
    ReturnValues.new(expected)
  end

  def have_attributes(expected)
    HaveAttributes.new(expected)
  end
  
  def exactly_have_attributes(expected)
    have_all_attributes(expected)
  end
  
  def have_all_attributes(expected)
    HaveAllAttributes.new(expected)
  end
  
  def have_one_with_attributes(expected)
    HaveOneWithAttributes.new(expected)
  end
end