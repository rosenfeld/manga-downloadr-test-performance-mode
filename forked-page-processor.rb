require_relative 'simple-page-processor'

class ForkedPageProcessor < SimplePageProcessor

  def get_image_metadata(page_path, page)
    reader, writer = IO.pipe
    fork do
      reader.close
      image = super
      writer.write [image.host, image.path, image.filename].join(';')
    end
    writer.close
    Image.new *p(reader.gets.chomp.split(';'))
  end
end

