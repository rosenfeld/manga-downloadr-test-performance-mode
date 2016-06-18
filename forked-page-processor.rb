require_relative 'simple-page-processor'

class ForkedPageProcessor < SimplePageProcessor

  def get_image_metadata(page_path, page)
    reader, writer = IO.pipe
    fork do
      reader.close
      image = super
      writer.write [image.host, image.path, image.filename].join(';')
      writer.close
      exit 0
    end
    writer.close
    img = Image.new *reader.gets.chomp.split(';')
    reader.close
    img
  end
end

