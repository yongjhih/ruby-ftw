require "ftw/namespace"
require "openssl"
require "base64" # stdlib 
require "digest/sha1" # stdlib

# WebSockets, RFC6455.
#
# TODO(sissel): Find a comfortable way to make this websocket stuff 
# both use HTTP::Connection for the HTTP handshake and also be usable
# from HTTP::Client
# TODO(sissel): Also consider SPDY and the kittens.
class FTW::WebSocket
  include FTW::CRLF

  WEBSOCKET_ACCEPT_UUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

  # Protocol phases
  # 1. tcp connect
  # 2. http handshake (RFC6455 section 4)
  # 3. websocket protocol

  public
  def initialize(request)
    @key_nonce = generate_key_nonce
    @request = request
    prepare(@request)
  end # def initialize

  public
  def connection=(connection)
    @connection = connection
  end # def connection=

  public
  def origin=(origin)
    @request.headers.set("Origin", origin)
  end # def origin=

  private
  def prepare(request)
    # RFC6455 section 4.1:
    #  "2.   The method of the request MUST be GET, and the HTTP version MUST
    #        be at least 1.1."
    request.method = "GET"
    request.version = 1.1

    # RFC6455 section 4.2.1 bullet 3
    request.headers.set("Upgrade", "websocket") 
    # RFC6455 section 4.2.1 bullet 4
    request.headers.set("Connection", "Upgrade") 
    # RFC6455 section 4.2.1 bullet 5
    request.headers.set("Sec-WebSocket-Key", @key_nonce)
    # RFC6455 section 4.2.1 bullet 6
    request.headers.set("Sec-WebSocket-Version", 13)
    # RFC6455 section 4.2.1 bullet 7 (optional)
    # The Origin header is optional for non-browser clients.
    #request.headers.set("Origin", ...)
    # RFC6455 section 4.2.1 bullet 8 (optional)
    #request.headers.set("Sec-Websocket-Protocol", ...)
    # RFC6455 section 4.2.1 bullet 9 (optional)
    #request.headers.set("Sec-Websocket-Extensions", ...)
    # RFC6455 section 4.2.1 bullet 10 (optional)
    # TODO(sissel): Any other headers like cookies, auth headers, are allowed.
  end # def prepare

  private
  def generate_key_nonce
    # RFC6455 section 4.1 says:
    # ---
    # 7.   The request MUST include a header field with the name
    #      |Sec-WebSocket-Key|.  The value of this header field MUST be a
    #      nonce consisting of a randomly selected 16-byte value that has
    #      been base64-encoded (see Section 4 of [RFC4648]).  The nonce
    #      MUST be selected randomly for each connection.
    # ---
    #
    # It's not totally clear to me how cryptographically strong this random
    # nonce needs to be, and if it does not need to be strong and it would
    # benefit users who do not have ruby with openssl enabled, maybe just use
    # rand() to generate this string.
    #
    # Thus, generate a random 16 byte string and encode i with base64.
    # Array#pack("m") packs with base64 encoding.
    return Base64.strict_encode64(OpenSSL::Random.random_bytes(16))
  end # def generate_key_nonce

  public
  def handshake_ok?(response)
    # See RFC6455 section 4.2.2
    return false unless response.status == 101 # "Switching Protocols"
    return false unless response.headers.get("upgrade") == "websocket"
    return false unless response.headers.get("connection") == "Upgrade"

    # Now verify Sec-WebSocket-Accept. It should be the SHA-1 of the
    # Sec-WebSocket-Key (in base64) + WEBSOCKET_ACCEPT_UUID
    expected = @key_nonce + WEBSOCKET_ACCEPT_UUID
    expected_hash = Digest::SHA1.base64digest(expected)
    return false unless response.headers.get("Sec-WebSocket-Accept") == expected_hash

    return true
  end # def handshake_ok?

  def inspect
    return "<#{self.class.name} ...>"
  end # def inspect
end # class FTW::WebSocket

