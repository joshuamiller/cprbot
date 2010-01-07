require 'rubygems'

require 'grackle'
twitter_client = Grackle::Client.new(:auth=>{:type=>:basic,:username=>'centralparuby',:password=>'nope'})

require 'models/message'

require 'isaac'
configure do |c|
  c.nick    = "CPRBot"
  c.server  = "irc.cplug.net"
  c.port    = 6667
end

on :connect do
  join "#cprb"
end

on :channel, /^:tweet @(\w+)\^?(\d*)/ do |user, offset|
  info = twitter_client.statuses.user_timeline.json? :screen_name => user, :count => 1, :page => (offset || 1)
  msg channel, "Tweet: #{user}: #{info.status.text}"
end

on :channel, /^:quote (\w+)\^?(\d*)/ do |user, offset|
  quote = Message.find(:last, :conditions => {:nick => user}, :offset => offset || 0)
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
  offset ||= 1
  rss = SimpleRSS.parse open('http://feeds.feedburner.com/fmylife')
  entry = begin 
    rss.entries[0].content.split("FML")[0]
  rescue
    "FML AM BROKE"
  end
  msg channel, "#{nick}: #{entry} FML."
end

on :channel, /^:tfln\^?(\d*)/ do |offset|
  offset ||= 1
  rss = SimpleRSS.parse open('http://feeds.feedburner.com/tfln')
  entry = begin 
    rss.entries[0].description.split("\r\n")[0]
  rescue
    "TFLN AM BROKE"
  end
  msg channel, "#{nick}: #{entry}"
end


on :channel, /^:h(a|e)lp/ do
  msg channel, "#{nick}: :tweet @username^n | :quote nick^n | :random nick"
end

on :channel do
  Message.create(:channel => channel, :nick => nick, :message => message)
end