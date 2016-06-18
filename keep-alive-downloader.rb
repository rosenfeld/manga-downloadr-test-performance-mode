require 'net/http'
require_relative 'base-downloader'

# assumes scheme is HTTP
class KeepAliveDownloader < BaseDownloader
  def initialize(uri, workers_count: 1)
    super(uri)
    @queue = Queue.new
    @finished = false
    @running_threads = Queue.new
    workers_count.times { start_reactor }
  end

  def stop
    @finished = true
    @running_threads.size.times{@queue << nil}
    sleep 0.5 while not @running_threads.empty?
  end

  private

  def _fetch(path, &block)
    @queue << [path, block]
  end
  
  def start_reactor
    @running_threads << Thread.start do
      begin
        Net::HTTP.start @uri.host, @uri.port do |http|
          while !@finished
            next unless pair = @queue.pop
            path, block = pair
            uri = @uri.clone
            uri.path = path
            response = http.request Net::HTTP::Get.new uri
            @running_threads << run_in_thread(path, block, response)
          end
        end
      rescue Exception => e
        puts "unexpected error in keep alive downloader: #{e.message}"
      ensure
        @running_threads.pop
      end
    end
  end

  def run_in_thread(path, block, response)
    Thread.start do
      begin
        block[response.body]
      rescue Exception => e
        puts "failed to fetch #{path}: #{e.message}"
      ensure
        @running_threads.pop
      end
    end
  end
end
