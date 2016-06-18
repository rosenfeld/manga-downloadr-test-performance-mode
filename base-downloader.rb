class BaseDownloader
  attr_reader :count

  def initialize(uri)
    @uri = uri
    @count = 0
    @mutex = Mutex.new
  end

  def fetch(path, &block)
    @mutex.synchronize{ @count += 1 }
    _fetch path, &block
  end

  def stop
  end

  private

  def _fetch(path, &block)
    raise 'Not implemented'
  end
end
