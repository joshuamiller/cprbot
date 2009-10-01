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

on :channel, /^:tweet @(\w+)/ do |user|
  info = twitter_client.users.show.json? :screen_name => user
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

on :channel do
  Message.create(:channel => channel, :nick => nick, :message => message)
end