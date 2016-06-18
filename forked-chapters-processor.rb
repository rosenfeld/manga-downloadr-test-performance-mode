require_relative 'simple-chapters-processor'

class ForkedChaptersProcessor < SimpleChaptersProcessor

  def get_page_paths(chapter_page)
    reader, writer = IO.pipe
    fork do
      reader.close
      paths = super
      paths.each{|p| writer.puts p}
      writer.puts ''
      writer.close
      exit 0
    end
    writer.close
    paths = []
    until (s = reader.gets.chomp).empty?; paths << s; end
    reader.close
    paths
  end
end
