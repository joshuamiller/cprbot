require 'rubygems'
require 'activerecord'

ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database => File.join(File.dirname(__FILE__), 'cprbot.sqlite3.db')
)

class CreateMessages < ActiveRecord::Migration
  def self.up
	  create_table :messages do |t|
      t.string :message
      t.string :nick
      t.string :channel
      t.boolean :preserve, :default => false
      t.timestamps
    end
  end

  def self.down
    drop_table :messages
  end
end

CreateMessages.up