require 'nokogiri'
require 'net/http'
require 'encryption/aes'

module ScRelayConnect

  module Http

    class Rev < HttpConnection

      def toggle_relay(outlet, status)
        if status != true
          get_request('/off') 
        else 
          get_request('/on')
        end
      end

      def statuses        
        aes = ScRelayConnect::AES.new()
        resp   = get_request('/status') 

        resp_str = aes.aes_decrypt(resp.body)
        result = JSON.parse(resp_str).with_indifferent_access


        status = {}
        if result[:status] == 'success' 
          status[1] = result[:realy_status] == 'ON' ? true : false
        end
        
        # status = result[:status] == 'success' ? true: false

        status 
      end

    end

  end

end
