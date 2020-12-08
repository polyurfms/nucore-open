# config/initializers/scenic.rb

require 'scenic/mysql_adapter'

Scenic.configure do |config|
  config.database = Scenic::Adapters::MySQL.new
end
