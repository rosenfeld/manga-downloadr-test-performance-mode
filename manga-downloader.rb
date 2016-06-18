require 'net/http'
require 'nokogiri'
require 'benchmark'
require 'time'
require 'thread'
require_relative 'simple-downloader'
require_relative 'keep-alive-downloader'
require_relative 'simple-chapters-processor'
require_relative 'simple-page-processor'
require_relative 'forked-page-processor'

class MangaDownloader
  def initialize(url)
    @url = url
    @uri = URI(url)
    @host = @uri.host
    @port = @uri.port
    @main_path = @uri.path

    @running_tasks = Queue.new
    @image_metadatas = Queue.new
  end

  def process
    fetch_chapters_paths
    fetch_pages_paths
    wait_until_finished
    puts "Total image paths: #{@image_metadatas.size}", "downloads total: #{downloader.count}"
    paths = []
    until @image_metadatas.empty?
      image = @image_metadatas.pop
      paths << "#{image.filename} #{image.host}#{image.path}"
    end
    File.write 'image-paths.txt', paths.sort.join("\n")
  end

  private

  def fetch_chapters_paths
    continue = Queue.new
    start = Time.now
    download @main_path do |main_page|
      begin
        puts "Time to download main page: #{Time.now - start}"
        measure 'Find chapters paths' do
          @chapter_paths = Nokogiri::HTML(main_page).css('#listing a').map{|n| n['href']}
          #@chapter_paths = @chapter_paths[0..5] # in case you want to speed up during development
        end
      ensure
        continue << nil
      end
    end
    continue.pop
  end

  def download(path, &block)
    downloader.fetch path, &block
  end

  def downloader
    #@downloader ||= SimpleDownloader.new(@uri) # change to others to experiment
    @downloader ||= KeepAliveDownloader.new(@uri, workers_count: 150)
  end

  def measure(title, &block)
    puts "#{title} time: #{Benchmark.measure(&block).total}"
  end

  def fetch_pages_paths
    @chapter_paths.each do |chapter_path|
      @running_tasks << nil
      download chapter_path do |chapter_page|
        (r=chapters_processor.get_page_paths(chapter_page)).each do |page_path|
          fetch_image_metadatas page_path
        end
        @running_tasks.pop
      end
    end
  end

  def chapters_processor
    SimpleChaptersProcessor.instance # try other processors to compare
  end

  def fetch_image_metadatas(page_path)
    @running_tasks << nil
    download page_path do |page|
      @image_metadatas << page_processor.get_image_metadata(page_path, page)
      @running_tasks.pop
    end
  end

  if RUBY_PLATFORM == 'java'
    def page_processor
      SimplePageProcessor.instance
    end
  else
    def page_processor
      SimplePageProcessor.instance
      # I'm not an specialist on IPC for forked children and this is not working well:
      #ForkedPageProcessor.instance
    end
  end

  def wait_until_finished
    sleep 0.5 until @running_tasks.empty?
    downloader.stop
  end
end

MangaDownloader.new('http://www.mangareader.net/onepunch-man').process
