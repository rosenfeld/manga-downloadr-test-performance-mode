require 'net/http'
require 'nokogiri'
require 'benchmark'
require 'time'
require 'thread'
require_relative 'simple-downloader'
require_relative 'keep-alive-downloader'
require_relative 'simple-chapters-processor'
require_relative 'forked-chapters-processor'
require_relative 'forked-pool-chapters-processor'
require_relative 'simple-page-processor'
require_relative 'forked-page-processor'
require_relative 'forked-pool-page-processor'

class MangaDownloader
  def initialize(url)
    @url = url
    @uri = URI(url)
    @host = @uri.host
    @port = @uri.port
    @main_path = @uri.path

    @running_tasks = Queue.new
    @finished_mutex = Mutex.new
    @finished_cond = ConditionVariable.new
    @image_metadatas = Queue.new

    unless RUBY_PLATFORM == 'java'
      ForkedPoolChaptersProcessor.pool_size = 6
      ForkedPoolPageProcessor.pool_size = 6
      # fork workers to speed up initialization
      ForkedPoolChaptersProcessor.instance
      ForkedPoolPageProcessor.instance
    end
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
          #@chapter_paths = @chapter_paths[0..1] # in case you want to speed up during development
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
      increment_tasks
      download chapter_path do |chapter_page|
        (r=chapters_processor.get_page_paths(chapter_page)).each do |page_path|
          fetch_image_metadatas page_path
        end
        decrement_tasks
      end
    end
  end

  def increment_tasks
    @running_tasks << nil
  end

  def decrement_tasks
    @running_tasks.pop
    return unless @running_tasks.empty?
    @finished_mutex.synchronize{ @finished_cond.signal }
  end

  if RUBY_PLATFORM == 'java'
    def chapters_processor
      SimpleChaptersProcessor.instance # try other processors to compare
    end
  else
    def chapters_processor
      #SimpleChaptersProcessor.instance # try other processors to compare
      #ForkedChaptersProcessor.instance
      ForkedPoolChaptersProcessor.instance
    end
  end

  def fetch_image_metadatas(page_path)
    increment_tasks
    download page_path do |page|
      @image_metadatas << page_processor.get_image_metadata(page_path, page)
      decrement_tasks
    end
  end

  if RUBY_PLATFORM == 'java'
    def page_processor
      SimplePageProcessor.instance
    end
  else
    def page_processor
      #SimplePageProcessor.instance
      #ForkedPageProcessor.instance
      ForkedPoolPageProcessor.instance
    end
  end

  def wait_until_finished
    @finished_mutex.synchronize{ @finished_cond.wait @finished_mutex }
    downloader.stop
    chapters_processor.stop if chapters_processor.respond_to? :stop
    page_processor.stop if page_processor.respond_to? :stop
  end
end

MangaDownloader.new('http://www.mangareader.net/onepunch-man').process
