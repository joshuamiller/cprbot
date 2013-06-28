require 'rubygems'
require 'active_record'
require 'active_support'

ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database => File.join(File.dirname(__FILE__), '..', 'db', 'cprbot.sqlite3.db')
)

class Message < ActiveRecord::Base

  def self.clear_old(time = 1.week.ago)
    Message.delete_all(['created_at < ? and preserve = ?', time, false])
  end

end
  
