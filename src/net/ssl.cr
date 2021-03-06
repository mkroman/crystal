lib OpenSSL("ssl")
  type SSLMethod : Void*
  type SSLContext : Void*
  type SSL : Void*

  fun ssl_load_error_strings = SSL_load_error_strings()
  fun ssl_library_init = SSL_library_init()
  fun sslv23_client_method = SSLv23_client_method() : SSLMethod
  fun ssl_ctx_new = SSL_CTX_new(method : SSLMethod) : SSLContext
  fun ssl_ctx_free = SSL_CTX_free(context : SSLContext)
  fun ssl_new = SSL_new(context : SSLContext) : SSL
  fun ssl_set_fd = SSL_set_fd(handle : SSL, socket : Int32) : Int32
  fun ssl_connect = SSL_connect(handle : SSL) : Int32
  fun ssl_write = SSL_write(handle : SSL, text : UInt8*, length : Int32) : Int32
  fun ssl_read = SSL_read(handle : SSL, buffer : UInt8*, read_size : Int32) : Int32
  fun ssl_shutdown = SSL_shutdown(handle : SSL)
  fun ssl_free = SSL_free(handle : SSL)
end

OpenSSL.ssl_load_error_strings
OpenSSL.ssl_library_init

class SSLSocket
  include IO

  def initialize(sock)
    @context = OpenSSL.ssl_ctx_new(OpenSSL.sslv23_client_method)
    @ssl = OpenSSL.ssl_new(@context)
    OpenSSL.ssl_set_fd(@ssl, sock.fd)
    OpenSSL.ssl_connect(@ssl)
  end

  def read(buffer : UInt8*, count)
    OpenSSL.ssl_read(@ssl, buffer, count)
  end

  def write(buffer : UInt8*, count)
    OpenSSL.ssl_write(@ssl, buffer, count)
  end

  def close
    OpenSSL.ssl_shutdown(@ssl)
    OpenSSL.ssl_free(@ssl)
    OpenSSL.ssl_ctx_free(@context)
  end

  def self.open(sock)
    ssl_sock = new(sock)
    begin
      yield ssl_sock
    ensure
      ssl_sock.close
    end
  end
end
