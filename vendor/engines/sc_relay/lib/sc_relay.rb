require 'error'
require 'http'

module ScRelayConnect
	class Engine < Rails::Engine

    config.autoload_paths << File.join(File.dirname(__FILE__), "../lib")

  	end
end
