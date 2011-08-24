require "tempfile"

class DynportTools::AsciiTable
  attr_accessor :headers
  attr_accessor :rows
  
  def initialize(attributes = {})
    self.headers = attributes[:headers] || []
    self.rows = attributes[:rows] || []
  end
  
  def to_tsv
    ([headers] + rows).map { |line| line.join("\t") }.join("\n")
  end
  
  def to_html
    html = "<table border=1 align=center>"
    html << "<tr>" + headers.map { |header| html_table_cell(header, "th") }.join("") if headers.any?
    html << rows.map { |row| "<tr>" + row.map { |r| html_table_cell(r, "td") }.join("") }.join("")
    html + "</table>"
  end
  
  def html_table_cell(text_or_array, node = "td")
    text, options = text_or_array
    "<#{node}#{options ? options.map { |key, value| " #{key}=#{value}" }.join("") : ""}>#{text}"
  end
  
  def to_ascii
    html2ascii(to_html)
  end
  
  def to(format)
    send(:"to_#{format}")
  end
  
  def html2ascii(html)
    tempfile = Tempfile.new("html2ascii")
    tempfile.print(html)
    tempfile.close
    ascii = Kernel.send(:`, "links -dump #{tempfile.path}")
    tempfile.delete
    ascii
  end
end