require 'net/http'
require_relative 'base-downloader'

class SimpleDownloader < BaseDownloader
  private

  def _fetch(path, &block)
    uri = @uri.clone
    uri.path = path
    block[Net::HTTP.get uri]
  end
end
