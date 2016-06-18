require 'nokogiri'
require 'singleton'
require_relative 'image'

class SimplePageProcessor
  include Singleton

  def get_image_metadata(page_path, page)
    image = Nokogiri::HTML(page).at_css('#img')

    unless (image_alt = image['alt']) && (image_src = image['src'])
      puts "failed to find metadata for #{page_path}"
      raise Exception.new("Couldn't find proper metadata alt in the image tag")
    end
    extension      = image_src.split('.').last
    list           = image_alt.split(' ').reverse
    title_name     = list[4..-1].join(' ')
    chapter_number = list[3].rjust(5, '0')
    page_number    = list[0].rjust(5, '0')

    uri = URI.parse(image_src)
    Image.new(uri.host, uri.path, "#{title_name}-Chap-#{chapter_number}-Pg-#{page_number}.#{extension}")
  end
end
