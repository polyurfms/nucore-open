require 'net/http'
require 'nokogiri'
require 'uri'
require 'encryption/aes'

module ScRelayConnect

  class HttpConnection

    def initialize(host, options = {})
      @host = host
      @options = {
        :port => 80
      }.merge(options)
    end

    def info(info)
      @info = info
    end

    def status(outlet = 1)
      statuses.fetch outlet do
        raise ScRelayConnect::Error.new('Error communicating with relay')
      end
    end

    def toggle_on(outlet = 1)
      toggle(outlet, true)
    end

    def toggle_off(outlet = 1)
      toggle(outlet, false)
    end

    def toggle(outlet, status)
      # current_status = status(outlet)
      # if current_status != status
      #   toggle_relay(outlet, status)
      #   new_status = status(outlet)
      #   raise NetBooter::Error.new("Cannot \"Begin Reservation\" when a previously scheduled reservation is ongoing.")  unless new_status != current_status
      # else
      #   raise NetBooter::Error.new("Cannot \"Begin Reservation\" when a previously scheduled reservation is ongoing.")
      # end

      toggle_relay(outlet, status)
    end

    def statuses
      raise NotImplementedError.new
    end

    def toggle_relay(outlet)
      raise NotImplementedError.new('Must implement toggle_relay in subclass')
    end

    private
    def get_request(path)
      resp = nil
      begin
        Timeout::timeout(5) do
          resp = do_http_request(path)
        end
      rescue => e
        # raise ScRelayConnect::Error.new("Error connecting to relay: #{e.message}")
        raise ScRelayConnect::Error.new("Error connecting to relay")
      end
      resp
    end

    def do_http_request(path)
      resp = nil

      aes = ScRelayConnect::AES.new()
      req_body = path.include?("on") || path.include?("off") ? aes.aes_encrypt(@info.to_json) : ""

      Net::HTTP.start(@host, @options[:port], use_ssl: true, verify_mode:OpenSSL::SSL::VERIFY_NONE) do |http|
        req = Net::HTTP::Post.new(path, {'Content-Type' => 'application/json'})
        req.basic_auth @options[:username], @options[:password] if @options[:username] && @options[:password]
        req.body = {data: req_body.to_s}.to_json
        req.body = req_body
        req.body = {"data": req_body}.to_json
        resp = http.request(req)
        unless ['200', '302'].include? resp.code
          raise NetBooter::Error.new "Relay responded with #{resp.code}. Perhaps you have the wrong relay type specified."
        end
      end
      resp


    end

  end

end
