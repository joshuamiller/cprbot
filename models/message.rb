require 'rubygems'
require 'activerecord'

ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database =>  'db/cprbot.sqlite3.db'
)

class Message < ActiveRecord::Base
end
  