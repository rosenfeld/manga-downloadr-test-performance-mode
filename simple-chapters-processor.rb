require 'nokogiri'
require 'singleton'

class SimpleChaptersProcessor
  include Singleton

  def get_page_paths(chapter_page)
    Nokogiri::HTML(chapter_page).
      xpath("//div[@id='selectpage']//select[@id='pageMenu']//option").
      map{|option| option['value'] }
  end
end
