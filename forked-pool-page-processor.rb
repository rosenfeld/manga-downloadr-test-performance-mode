require 'thread'
require 'singleton'
require_relative 'simple-page-processor'

class ForkedPoolPageProcessor
  include Singleton

  @@pool_size = 6
  def self.pool_size=(pool_size)
    @@pool_size = pool_size
  end

  def initialize
    @io_pool = Queue.new
    @@pool_size.times{ Thread.start { start_reactor } }
  end

  def get_image_metadata(page_path, page)
    preader, pwriter, creader, cwriter = io = @io_pool.pop
    pwriter.puts page_path
    pwriter.puts page.tr("\n", ' ')
    Image.new *preader.gets.chomp.split(';')
  ensure
    @io_pool << io
  end

  def stop
    until @io_pool.empty?
      preader, pwriter, creader, cwriter = io = @io_pool.pop
      pwriter.puts ''
      io.each &:close
    end
  end

  private

  def start_reactor
    preader, cwriter = IO.pipe
    creader, pwriter = IO.pipe
    io = [preader, pwriter, creader, cwriter]
    fork do
      until (page_path = creader.gets.chomp).empty?
        page = creader.gets
        image = SimplePageProcessor.instance.get_image_metadata page_path, page
        cwriter.puts [image.host, image.path, image.filename].join(';')
      end
      io.each &:close
      exit 0
    end
    @io_pool << io
  end
end

