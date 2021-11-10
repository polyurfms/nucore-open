# frozen_string_literal: true

class RelaySC < Relay

  include PowerRelay

  private

  def self.to_s
    "SC Relay"
  end

  def relay_connection    
    @relay_connection ||= ScRelayConnect::Http::Rev.new(host, connection_options)
    return @relay_connection
  end

end
