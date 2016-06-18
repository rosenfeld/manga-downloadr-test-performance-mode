require 'thread'
require 'singleton'
require_relative 'simple-chapters-processor'

class ForkedPoolChaptersProcessor
  include Singleton

  @@pool_size = 6
  def self.pool_size=(pool_size)
    @@pool_size = pool_size
  end

  def initialize
    @io_pool = Queue.new
    @@pool_size.times{start_reactor}
  end

  def get_page_paths(chapter_page)
    preader, pwriter, creader, cwriter = io = @io_pool.pop
    pwriter.puts chapter_page.tr("\n", ' ')
    preader.gets.chomp.split(';')
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
      until (chapter_page = creader.gets.chomp).empty?
        paths = SimpleChaptersProcessor.instance.get_page_paths chapter_page
        cwriter.puts paths.join(';')
      end
      io.each &:close
      exit 0
    end
    @io_pool << io
  end
end
