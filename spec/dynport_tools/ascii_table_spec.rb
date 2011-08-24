require 'spec_helper'

describe DynportTools::AsciiTable do
  let(:tempfile) { double("tmpfile").as_null_object }
  
  before(:each) do
    Tempfile.stub(:new).and_return tempfile
    Kernel.stub!(:`).and_return ""
  end
  
  describe "#to_tsv" do
    it "returns the correct tsv" do
      DynportTools::AsciiTable.new(:headers => %w(A B), :rows => [%w(1 2), %w(3 4)]).to_tsv.should == "A\tB\n1\t2\n3\t4"
    end
  end
  
  describe "#to_html" do
    it "returns the correct html" do
      result = "<table border=1 align=center><tr><th>A<th>B<tr><td>1<td>2<tr><td>3<td>4</table>"
      DynportTools::AsciiTable.new(:headers => %w(A B), :rows => [%w(1 2), %w(3 4)]).to_html.should == result
    end
    
    it "does not include a header when not set" do
      DynportTools::AsciiTable.new(:rows => [%w(1 2), %w(3 4)]).to_html.should_not include("th")
    end
    
    it "uses options for headers" do
      DynportTools::AsciiTable.new(:headers => [["A", {:colspan => 1}], "B"]).to_html.should include("<tr><th colspan=1>A<th>B")
    end
    
    it "uses options for rows" do
      DynportTools::AsciiTable.new(:rows => [[["A", {:colspan => 1}], "B"]]).to_html.should include("<tr><td colspan=1>A<td>B")
    end
  end
  
  describe "#to_ascii" do
    it "calls html2ascii with response of to_html" do
      table = DynportTools::AsciiTable.new
      html = double("html")
      table.should_receive(:to_html).and_return html
      ascii = double("ascii")
      table.should_receive(:html2ascii).with(html).and_return ascii
      table.to_ascii.should == ascii
    end
  end
  
  describe "#html2ascii" do
    it "writes the html to a tempfile, closes and deletes it" do
      Tempfile.should_receive(:new).with("html2ascii").and_return tempfile
      tempfile.should_receive(:print).with("text")
      tempfile.should_receive(:close)
      tempfile.should_receive(:delete)
      DynportTools::AsciiTable.new.html2ascii("text")
    end
    
    it "calls links with correct params" do
      tempfile.should_receive(:path).and_return "/some/path"
      Kernel.should_receive(:`).with("links -dump /some/path").and_return "result"
      DynportTools::AsciiTable.new.html2ascii("test")
    end
  end
  
  describe "#to" do
    { "html" => :to_html, :html => :to_html, "ascii" => :to_ascii }.each do |from, to|
      it "calls #{to} for #{from}" do
        table = DynportTools::AsciiTable.new
        table.should_receive(to).and_return ""
        table.to(from)
      end
    end
  end
end