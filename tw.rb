#!/usr/local/bin/ruby

require 'net/http'

Net::HTTP.version_1_2

class Tw
  def initialize(id, pass)
    @request = Net::HTTP::Post.new('/statuses/update.json')
    @request.basic_auth(id, pass)
    @http = nil
  end

  def connect
    Net::HTTP.start('twitter.com', 80) do |http|
      @http = http
      yield(self)
      @http = nil
    end
  end

  def say(message)
    return false if @request.nil?
    @request.body = 'status=' + message
    @http.request(@request)
    true
  end
end

