require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "DynportTools" do
  describe "#xmldiff" do
    it "raises print usage when first file does not exist" do
      catch(:print_usage) do
        DynportTools.xmldiff(nil, nil)
        violated "print_usage should been thrown"
      end
    end
  end
end
