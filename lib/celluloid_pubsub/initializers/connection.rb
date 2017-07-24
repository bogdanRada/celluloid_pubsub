require 'celluloid/websocket/client'
Celluloid::WebSocket::Client::Connection.class_eval do

  alias_method :old_initialize, :initialize

  def initialize(url, handler)
    @url = url
    uri = URI.parse(url)
    port = uri.port || (uri.scheme == "ws" ? 80 : 443)
    @socket = Celluloid::IO::TCPSocket.new(uri.host, port)
    # ADDED this line for WSS protocol support
    @socket = Celluloid::IO::SSLSocket.new(@socket) if port == 443

    @client = ::WebSocket::Driver.client(self)
    @handler = handler || Celluloid::Actor.current

    async.run
  end

end
