# -*- coding: utf-8 -*-
require 'rubygems'
require 'cgi'
require 'i18n'
require 'active_support'
require 'scrobbler'

require 'action_view'
include ActionView::Helpers::DateHelper

require 'grackle'
twitter_client = Grackle::Client.new(
  :auth => {
    :type => :oauth,
    :consumer_key => 'SOMECONSUMERKEYFROMTWITTER',
    :consumer_secret => 'SOMECONSUMERTOKENFROMTWITTER',
    :token => 'ACCESSTOKENACQUIREDONUSERSBEHALF',
    :token_secret => 'SUPERSECRETACCESSTOKENSECRET'
  })

require 'simple-rss'
require 'open-uri'
require 'hpricot'
require 'sanitize'
require 'nokogiri'
require 'whois'

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

on :channel, /^:shady\s+(.*)/ do |url|
  entry = "I can't shady that shit man"
  begin
    entry = Hpricot(open("http://shadyurl.com/create.php?myUrl=" + url)).search('//div#output/a')[1].attributes['href']
  rescue
    entry = "SHADYURL AM BROKE"
  end
  msg channel, "#{nick}: #{entry}"
end

on :channel, /^:twss\^?(\d*)/ do |twssid|
  entry = "No idea dude."
  begin
    if twssid.to_s == ""
      entry = Hpricot(open("http://thatswh.at/")).search('//p[@class = "text"]').first.inner_html
    else
      entry = Hpricot(open("http://thatswh.at/item/" + twssid.to_s  + "/")).search('//p[@class = "text"]').first.inner_html
    end
  rescue
    entry = "THATSWH.AT AM BROKE"
  end
  msg channel, "#{nick}: #{Sanitize.clean(entry)}"
end

on :channel, /^:dns\s+(.*)/ do |host|
  response = "This doesn't work."
#  begin
#    response = Socket::getaddrinfo(host, "echo", Socket::AF_INET, Socket::SOCK_DGRAM)[0][#3]
#  rescue 
#    response = "DNS lookup shit the bed!"
#  end
  msg channel, "#{nick}: #{response}"
end

on :channel, /^:lastfm\s+(\w*)\^?(\d*)/ do |username, index|
  response = "Sorry, couldn't find that user or most recent track."
  begin
    user = Scrobbler::User.new(username)
    track = user.recent_tracks[index.to_i + 1]
    response = "#{ CGI.unescapeHTML(track.artist) }: #{ CGI.unescapeHTML(track.name) } (#{ time_ago_in_words(Time.at(track.date_uts.to_i)) } ago)"
  rescue
  end
  msg channel, "#{nick}: #{response}"
end

on :channel, /^:dice\s+(\d*)d(\d*)/ do |dice, sides|
  begin
    dice = dice.to_i
    sides = sides.to_i
    response = 0
    if dice > 6
      response = "#{nick}: You can't roll more than 6 dice"
    elsif sides > 100
      response = "#{nick}: You can't have more that 100 sides.  Asshole."
    else
      (1..dice).each do
        roll = rand(sides + 1)
        if roll == 0
          roll = 1
        end
        response = response + roll
      end
    end
    msg channel, "#{nick}: #{response}"
  rescue
    msg channel, "Something is not quite right with this bot"
  end
end

on :channel, /^:tw(eet|itter) #(\w+)\^?(\d*)/ do |_, hash_tag, offset|
  begin
    offset ||= 1
    offset = offset.to_i
    info = twitter_client[:search].search.json?(:q => "##{hash_tag}").results[offset - 1]
    info.text.split('\n').each do |tweet_line|
      msg channel, "Tweet: #{info.from_user}: #{CGI.unescapeHTML(tweet_line)}"
    end
  rescue
    msg channel, "Fail whale. Sorry."
  end
end

on :channel, /^:tw(eet|itter) @?(\w+)\^?(\d*) (\w+)\^?(\d*)/ do |_, user, offset, requestor|
  begin
    info = twitter_client.statuses.user_timeline.json? :screen_name => user, :count => 1, :page => (offset || 1), :include_rts => true
    info.first.try(:text).split("\n").each do |tweet_line|
      msg channel, "#{requestor}: Tweet: #{user}: #{CGI.unescapeHTML(tweet_line)}"
    end
  rescue
    msg channel, "Fail whale. Sorry."
  end
end

on :channel, /^:tw(eet|itter) @?(\w+)\^?(\d*)/ do |_, user, offset|
  begin
    info = twitter_client.statuses.user_timeline.json? :screen_name => user, :count => 1, :page => (offset || 1), :include_rts => true
    info.first.try(:text).split("\n").each do |tweet_line|
      msg channel, "Tweet: #{user}: #{CGI.unescapeHTML(tweet_line)}"
    end
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
  quote = Message.where(:nick => user, :preserve => true).order('random()').first
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

on :channel, /^:whois\s+(.*)/ do |domain|
  result = begin
    w = Whois::Client.new
  rescue
    "Whois not working right now."
  end
  msg channel, w.query(domain)
end

on :channel, /^:date/ do
  msg channel, "#{nick}: " + Time.new.strftime('%a %b %d %H:%M:%S %Z %Y')
end

on :channel, /^:larry/ do
  raw "/nick larry_"
  msg channel, "omg that's freaking awesome"
  raw "/nick CPRBot"
end

on :channel, /^:slaney/ do
  msg channel, "#{nick}: Not big enough"
  msg channel, " "
end  

on :channel, /^:h(a|e)lp/ do
  msg channel, "#{nick}: :tweet @username^n | :quote nick^n | :random nick | :tfln^n | :fml^n | :weather zip | :whois domain | :purpose | :fight nick1 nick2"
end

on :channel, /^:purpose/ do
  msg channel, "Bringing people back to life since 2010."
end

on :channel, /^:t/ do
  new_topic = Message.where(:preserve => true).order('random()').first
  if new_topic
    topic channel, "<#{new_topic.nick}> #{new_topic.message}"
  else
    msg channel, "#{nick}: Sorry, I can't come up with a topic."
  end
end

on :channel, /^:dick/ do
  balls,shaft,head = "8","=","D"
  msg channel, "#{balls}#{shaft * (rand(10)+1)}#{head}"
end

on :channel, /^:boobs/ do
  # via mjwhitt
  n = ['.', 'o', '@', '·', '°', '¤']
  c = [')(', 'Y', 'ϒ', 'Ƴ', 'λ', 'Λ']
  outside = rand(4)
  inside = rand(2) + 1 + outside
  nipples = n[rand(n.size)]
  cleavage = c[rand(c.size)]
  boobs = '(' + ' '*outside + nipples + ' '*inside + cleavage + ' '*inside + nipples + ' '*outside + ')'
  msg channel, boobs
end

on :channel, /^:(fight|fite) (\w+) (\w+)/ do |keyword,nick1,nick2|
	msg channel, "LET'S GET IT ON"
	rand1 = (Random.rand(20) + 1)
	rand2 = (Random.rand(20) + 1)
	msg channel, nick1 + ": " + rand1.to_s
	msg channel, nick2 + ": " + rand2.to_s
	msg channel, (rand1 >= rand2) ? nick1 + " wins!" : nick2 + " wins!"
end

on :channel do
  Message.create(:channel => channel, :nick => nick, :message => message.to_s.gsub(/^\x01ACTION /, '* Krazylegz ').gsub(/\x01$/, ' *').encode('UTF-8', {:invalid => :replace, :undef => :replace, :replace => '?'}))
end
