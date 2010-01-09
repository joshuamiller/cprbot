require 'rubygems'
require 'active_support'

require 'grackle'
twitter_client = Grackle::Client.new(:auth=>{:type=>:basic,:username=>'centralparuby',:password=>'nope'})

require 'simple-rss'
require 'open-uri'
require 'nokogiri'

require File.join(File.dirname(__FILE__), 'models', 'message')

require 'isaac'
configure do |c|
  c.nick    = "CPRBot"
  c.server  = "irc.cplug.net"
  c.port    = 6667
end

on :connect do
  join "#cprb"
end

on :channel, /^:tw(eet|itter) @?(\w+)\^?(\d*)/ do |_, user, offset|
  begin
    info = twitter_client.statuses.user_timeline.json? :screen_name => user, :count => 1, :page => (offset || 1)
    msg channel, "Tweet: #{user}: #{info.first.try(:text)}"
  rescue
    msg channel, "Fail whale. Sorry."
  end
end

on :channel, /^:quote (\w+)\^?(\d*)/ do |user, offset|
  offset = offset.try(:to_i) || 1
  quote = Message.find(:last, :conditions => {:nick => user}, :offset => (offset - 1))
  if quote
    quote.update_attributes(:preserve => true)
    msg channel, "#{nick}: The operation was a success."
  else
    msg channel, "#{nick}: Sorry, can't go back that far."
  end
end

on :channel, /^:random (\w+)/ do |user|
  quote = Message.find(:first, :conditions => {:nick => user, :preserve => true}, :order => 'random()')
  if quote
    msg channel, "#{nick}: <#{quote.nick}> #{quote.message}"
  else
    msg channel, "#{nick}: Nothing matched that nick."
  end
end

on :channel, /^:fml\^?(\d*)/ do |offset|
  offset = offset.try(:to_i) || 1
  rss = SimpleRSS.parse open('http://feeds.feedburner.com/fmylife')
  entry = begin 
    rss.entries[offset-1].content.split("FML")[0]
  rescue
    "FML AM BROKE"
  end
  msg channel, "#{nick}: #{entry} FML."
end

on :channel, /^:ifml\^?(\d*)/ do |fmlid|
  begin
  entry = "Fuck _your_ life. FYL"
  rss = SimpleRSS.parse open('http://feeds.feedburner.com/fmylife')
    rss.entries.each do |fml|
      if fml[:id].split("/")[4] == "#{fmlid}"
        entry = "#{fml[:content].split("FML")[0]} FML"
        break
      end
    end
  rescue
    entry = "FML AM BROKE"
  end
  msg channel, "#{nick}: #{entry}"
end

on :channel, /^:tfln\^?(\d*)/ do |offset|
  offset = offset.try(:to_i) || 1
  rss = SimpleRSS.parse open('http://feeds.feedburner.com/tfln')
  entry = begin 
    rss.entries[offset-1].description.split("\r\n")[0]
  rescue
    "TFLN AM BROKE"
  end
  msg channel, "#{nick}: #{entry}"
end

on :channel, /^:weather (.*)/ do |location|
  result = begin
    nok = Nokogiri::XML(open("http://api.wunderground.com/auto/wui/geo/GeoLookupXML/index.xml?query=#{location}"))
    station = nok.search('//station/icao').first.text
    nok = Nokogiri::XML(open("http://api.wunderground.com/auto/wui/geo/WXCurrentObXML/index.xml?query=#{station}"))
    weather = nok.search('//weather').first.text
    temp = nok.search('//temperature_string').first.text
    location_string = nok.search('//observation_location/full').first.text
    "#{nick}: Weather for #{location_string} (#{station}): #{weather}, #{temp}"
  rescue
    "#{nick}: Couldn't find weather for #{location}"
  end
  msg channel, result
end

on :channel, /^:larry/ do
  msg channel, "#{nick}: OMG that is AMAZING!!"
end

on :channel, /^:slaney/ do
  msg channel, "#{nick}: Not big enough"
  msg channel, " "
end  

on :channel, /^:h(a|e)lp/ do
  msg channel, "#{nick}: :tweet @username^n | :quote nick^n | :random nick | :tfln^n | :fml^n | :weather zip"
end

on :channel do
  Message.create(:channel => channel, :nick => nick, :message => message)
end
