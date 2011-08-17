require 'spec_helper'

describe DynportTools::DeepMerger do
  it "merges two hashes" do
    DynportTools::DeepMerger.merge({ :a => 1 }, { :b => 2 }).should == { :a => 1, :b => 2 }
  end
  
  it "merges two arrays with same number of attributes" do
    DynportTools::DeepMerger.merge([{ :a => 1, :b => 1 }], [{ :a => 2, :c => 3 }]).should == [{ :a => 2, :b => 1, :c => 3 }]
  end
  
  it "correctly merges two arrays with the first one being longer" do
    DynportTools::DeepMerger.merge([{ :a => 1, :b => 1 }], []).should == [{ :a => 1, :b => 1 }]
  end
  
  it "correctly merges two arrays with the first one being longer" do
    DynportTools::DeepMerger.merge([], [{ :a => 1, :b => 1 }]).should == [{ :a => 1, :b => 1 }]
  end
  
  it "merges simple arrays" do
    DynportTools::DeepMerger.merge([1, 2, 3], [3, 4]).should == [3, 4, 3]
  end
  
  it "correctly merges two arrays with different numbers and content" do
    DynportTools::DeepMerger.merge([{ :a => 1 }, { :b => 2, :c => 3 }], [{ :b => 2 }, { :c => 2 }, { :d => 1 }]).should == [
      { :a => 1, :b => 2 },
      { :b => 2, :c => 2 },
      { :d => 1 }
    ]
  end
  
  it "returns the second argument when types are different" do
    DynportTools::DeepMerger.merge([], "a").should == "a"
  end
  
  it "calls merge on each value of two hashes" do
    a = { :a => 1, :b => 2 }
    b = { :b => 1, :c => 2 }
    DynportTools::DeepMerger.merge(a, b).should == { :a => 1, :b => 1, :c => 2 }
  end
  
  it "returns b when both have the same type but not array or hash" do
    DynportTools::DeepMerger.merge(1, 2).should == 2
  end
  
  describe "#merge_hashes" do
    it "joins both hashes" do
      DynportTools::DeepMerger.merge_hashes({:a => 1}, {:b => 2}).should == { :a => 1, :b => 2 }
    end
    
    it "overwrites values from a with values from b" do
      DynportTools::DeepMerger.merge_hashes({:a => 1}, {:a => 2}).should == { :a => 2 }
    end
    
    it "merges nested hashes" do
      DynportTools::DeepMerger.merge_hashes({ :nested => { :a1 => 1, :b1 => 1 } }, { :nested => { :a1 => 2, :b2 => 3 }}).should == { 
        :nested => { :a1 => 2, :b1 => 1, :b2 => 3 }
      }
    end
  end
end