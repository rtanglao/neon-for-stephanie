#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'pp'
require 'time'
require 'date'
require 'mongo'
require 'parseconfig'
require 'typhoeus'
require 'awesome_print'

flickr_config = ParseConfig.new('flickr.conf').params
api_key = flickr_config['api_key']

if ARGV.length < 1
  puts "usage: #{$0} [galleryid]"
  exit
end

def getFlickrResponse(url, params, logger)
  url = "https://api.flickr.com/" + url
  try_count = 0
  begin
    result = Typhoeus::Request.get(url,
                                 :params => params )
    x = JSON.parse(result.body)
   #logger.debug x["photos"].ai
  rescue JSON::ParserError => e
    try_count += 1
    if try_count < 4
      $stderr.printf("JSON::ParserError exception, retry:%d\n",\
                     try_count)
      sleep(10)
      retry
    else
      $stderr.printf("JSON::ParserError exception, retrying FAILED\n")
      x = nil
    end
  end
  return x
end

logger = Logger.new(STDERR)
logger.level = Logger::DEBUG
Mongo::Logger.logger.level = Logger::FATAL

MONGO_HOST = ENV["MONGO_HOST"]
raise(StandardError,"Set Mongo hostname in ENV: 'MONGO_HOST'") if !MONGO_HOST
MONGO_PORT = ENV["MONGO_PORT"]
raise(StandardError,"Set Mongo port in ENV: 'MONGO_PORT'") if !MONGO_PORT
MONGO_USER = ENV["MONGO_USER"]
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

extras_str = "description, license, date_upload, date_taken, owner_name, icon_server,"+
             "original_format, last_update, geo, tags, machine_tags, o_dims, views,"+
             "media, path_alias, url_sq, url_t, url_s, url_m, url_z, url_l, url_o,"+
             "url_c, url_q, url_n, url_k, url_h, url_b"

photosColl = db[:photos]
GALLERY_ID = ARGV[0]

search_url = "services/rest/"

first_page = true
photos_per_page = 0
page = 0
photo_number = 0

photosColl.indexes.create_one({ "id" => 1 }, :unique => true)
while true
  url_params = {
    :method => "flickr.galleries.getPhotos",
    :api_key => api_key,
    :format => "json",
    :nojsoncallback => "1",
    :per_page     => "500",
    :gallery_id => GALLERY_ID,
    :extras =>  extras_str,
    :sort => "date-taken-asc",
    :page => page.to_s
  }
  photos_on_this_page = getFlickrResponse(search_url, url_params, logger)
  if first_page
    first_page = false
    logger.debug photos_on_this_page["photos"]["pages"]
    number_of_pages_to_retrieve = photos_on_this_page["photos"]["pages"]
  end
  page += 1
  if page > number_of_pages_to_retrieve
    break
  end
  $stderr.printf("STATUS from flickr API:%s retrieved page:%d of:%d\n", photos_on_this_page["stat"],
    photos_on_this_page["photos"]["page"], photos_on_this_page["total"].to_i)
  photos_on_this_page["photos"]["photo"].each do|photo|
    logger.debug "date taken:" + photo["datetaken"]
    datetaken = Time.parse(photo["datetaken"])
    $stderr.printf("PHOTO datetaken:%s\n", datetaken)
    photo["datetaken"] = datetaken
    dateupload = Time.at(photo["dateupload"].to_i)
    $stderr.printf("PHOTO dateupload:%s\n", dateupload)
    photo["dateupload"] = dateupload
    lastupdate = Time.at(photo["lastupdate"].to_i)
    $stderr.printf("PHOTO lastupdate:%s\n", lastupdate)
    photo["lastupdate"] = lastupdate
    photo["tags_array"] = photo["tags"].split
    photo["id"] = photo["id"].to_i
    id = photo["id"]
    logger.debug "PHOTO id:" + id.to_s
    logger.debug photo.ai
    photo_number += 1
    logger.debug "PHOTO number:" + photo_number.to_s
    result_array = photosColl.find({ 'id' => id }).update_one(photo, :upsert => true ).to_a
    nModified = 0
    result_array.each do |item|
      nModified = item["nModified"] if item.include?("nModified")
      break
    end
    if nModified == 0
      logger.debug "INSERTED^^"
    else
      logger.debug "UPDATED^^^^^^"
    end
  end
end