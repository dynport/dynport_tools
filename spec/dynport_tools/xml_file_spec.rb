require 'spec_helper'
require "dynport_tools/xml_file"

FILE1 = root.join("spec/fixtures/file_a.xml")
FILE2 = root.join("spec/fixtures/file_b.xml")

describe "DynportTools::XmlFile" do
  let(:file) { DynportTools::XmlFile.new(FILE1) }
  
  describe "#initialize" do
    it "sets the correct path" do
      expect(DynportTools::XmlFile.new(FILE1).path).to eql(FILE1.to_s)
    end
    
    it "also sets the pathwhen given as hash" do
      expect(DynportTools::XmlFile.new(:path => FILE1).path).to eql(FILE1.to_s)
    end
    
    it "sets content when given" do
      expect(DynportTools::XmlFile.new(:content => "some content").content).to eql("some content")
    end
  end
  
  describe "#doc" do
    it "opens a file when set" do
      f = double("f")
      File.should_receive(:open).with("/some/path").and_return f
      Nokogiri.should_receive(:XML).with(f).and_return nil
      DynportTools::XmlFile.new("/some/path").doc
    end
    
    it "parses the direct content when present" do
      file = DynportTools::XmlFile.new
      file.content = "some content"
      Nokogiri.should_receive(:XML).with("some content").and_return nil
      file.doc
    end
  end
  
  describe "#nodes_hash" do
    it "a hash" do
      file.nodes_hash.should be_an_instance_of(Hash)
    end
    
    it "parses the root node" do
      root = double("root", :attributes => {}, :name => "product")
      file.stub!(:doc).and_return(double("root", :root => root))
      res = double("response")
      file.should_receive(:parse_node).with(root).and_return res
      expect(file.nodes_hash).to eql({ "product" => res })
    end
    
    let(:key) { { :name => "file", "name" => "some_name" } }
    
    it "sets the root node" do
      expect(file.nodes_hash[key]["size"]).to eql("101")
      expect(file.nodes_hash[key]["title"]).to eql("Some Title")
    end
  end
  
  describe "#parse_node" do
    it "returns a the inner text as value when only text inside" do
      expect(file.parse_node(file.doc.root.at("size"))).to eql("101")
    end
    
    it "sets blank texts to nil" do
      file.parse_node(file.doc.root.at("comments")).should be_nil
    end
    
    it "extracts subnodes" do
      expect(file.parse_node(file.doc.root.at("attributes"))).to eql({"rights" => "rw", "type" => "file" })
    end
    
    it "extracts array of tracks" do
      file.parse_node(Nokogiri::XML("<a><title>a</title><title>b</title></a>").at("a"))["title"].should be_an_instance_of(Array)
    end
    
    it "uses key_for_node for keys" do
      file.parse_node(file.doc.root.at("lines"))[:name => "line", "id" => "0"].should be_an_instance_of(Hash)
    end
  end
  
  describe "key_for_node" do
    it "returns a string when node has no attributes" do
      expect(file.key_for_node(file.doc.root.at("size"))).to eql("size")
    end
    
    it "includes the attributes when node has attributes" do
      expect(file.key_for_node(file.doc.root)).to eql({ :name => "file", "name" => "some_name" })
    end
  end
  
  describe "#flatten_hash" do
    it "returns a flat hash when all arrays have length 1" do
      expect(file.flatten_hash({"a" => [1]})).to eql({ "a" => 1 })
    end
    
    it "does not break on empty hashes" do
      expect(file.flatten_hash({"a" => 1})).to eql({ "a" => 1 })
    end
    
    it "does not flatten arrays with more than one element" do
      expect(file.flatten_hash({"a" => [1, 2]})).to eql({ "a" => [1, 2] })
    end
    
    it "sets empty arrays to nil" do
      expect(file.flatten_hash({"a" => []})).to eql({ "a" => nil })
    end
  end
end
