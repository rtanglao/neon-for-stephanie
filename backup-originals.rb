#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'curb'
require 'pp'
require 'time'
require 'date'
require 'mongo'
require 'parseconfig'
require 'uri'

MONGO_HOST = ENV["MONGO_HOST"]
raise(StandardError,"Set Mongo hostname in ENV: 'MONGO_HOST'") if !MONGO_HOST
MONGO_PORT = ENV["MONGO_PORT"]
raise(StandardError,"Set Mongo port in ENV: 'MONGO_PORT'") if !MONGO_PORT
MONGO_USER = ENV["MONGO_USER"]
# raise(StandardError,"Set Mongo user in ENV: 'MONGO_USER'") if !MONGO_USER
MONGO_PASSWORD = ENV["MONGO_PASSWORD"]
# raise(StandardError,"Set Mongo user in ENV: 'MONGO_PASSWORD'") if !MONGO_PASSWORD
FLICKR_DB = ENV["FLICKR_DB"]
raise(StandardError,"Set Mongo flickr database name in ENV: 'FLICKR_DB'") if !FLICKR_DB
#FLICKR_USER = ENV["FLICKR_USER"]
#raise(StandardError,"Set flickr user name in ENV: 'FLICKR_USER'") if !FLICKR_USER

db = Mongo::Client.new([MONGO_HOST], :database => FLICKR_DB)
if MONGO_USER
  auth = db.authenticate(MONGO_USER, MONGO_PASSWORD)
  if !auth
    raise(StandardError, "Couldn't authenticate, exiting")
    exit
  end
end

photosColl = db[:photos]

def fetch_1_at_a_time(urls_filenames)

  easy = Curl::Easy.new
  easy.follow_location = true

  urls_filenames.each do|url_fn|
    easy.url = url_fn["url"]
    filename = url_fn["filename"]
    $stderr.print "filename:'#{filename}'"
    $stderr.print "url:'#{url_fn["url"]}'"
    if File.exist?(filename)
      $stderr.printf("skipping EXISTING filename:%s\n", filename)
      next
    end
    try_count = 0
    begin
      File.open(filename, 'wb') do|f|
        easy.on_progress {|dl_total, dl_now, ul_total, ul_now| $stderr.print "="; true }
        easy.on_body {|data| f << data; data.size }
        easy.perform
        $stderr.puts "=> '#{filename}'"
      end
    rescue Curl::Err::ConnectionFailedError => e
      try_count += 1
      if try_count < 4
        $stderr.printf("Curl:ConnectionFailedError exception, retry:%d\n",\
                       try_count)
        sleep(10)
        retry
      else
        $stderr.printf("Curl:ConnectionFailedError exception, retrying FAILED\n")
        raise e
      end
    end
  end
end

urls_filenames = []
photosColl.find(
  {}
  ).sort(
    {"id"=> 1}
    ).projection(
    {
      "id" => 1,
      "url_o" => 1,
      "title" => 1,
}).each do |p|
      id = p["id"]
      title = p["title"].gsub("/", " ")
      url = p["url_o"]
      filename = sprintf("%d-%s.jpg", id, title)

      $stderr.printf("photo:%d, title:%s url:%s filename:%s\n", id, title, url, filename)
      urls_filenames.push({"url"=> url, "filename" => filename}) if !url.nil?
end

$stderr.printf("FETCHING:%d originals\n", urls_filenames.length)

fetch_1_at_a_time(urls_filenames)

