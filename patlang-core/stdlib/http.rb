# frozen_string_literal: true

# PatLang Standard Library - HTTP Module
# Provides HTTP client and server functionality using Ruby's built-in libraries

require 'socket'
require 'json'
require 'uri'
require 'net/http'

module Patlang
  module Stdlib
    module Http
      FUNCTIONS = {}

      def self.register(name, arity, &block)
        FUNCTIONS[name] = { arity: arity, impl: block }
      end

      def self.get(name)
        FUNCTIONS[name]
      end

      def self.all
        FUNCTIONS.keys
      end

      # Thread-local storage for HTTP servers
      @servers = {}

      class << self
        attr_accessor :_servers
      end

      self._servers = {}

      def self.init!
        # ========================================================================
        # TCP LISTENER
        # ========================================================================

        # tcp_listen(port) -> listener_id
        register("tcp_listen", 1) do |args, env|
          port = args[0].to_i
          server = TCPServer.new('0.0.0.0', port)
          listener_id = server.object_id.to_s
          self._servers[listener_id] = { server: server, type: :tcp }
          listener_id
        end

        # tcp_accept(listener_id) -> stream_id or nil
        register("tcp_accept", 1) do |args, env|
          listener_id = args[0].to_s
          entry = self._servers[listener_id]
          return nil unless entry && entry[:type] == :tcp

          begin
            client = entry[:server].accept_nonblock
            stream_id = client.object_id.to_s
            self._servers[stream_id] = { io: client, type: :tcp_stream }
            stream_id
          rescue IO::WaitReadable
            nil
          end
        end

        # tcp_read(stream_id, size) -> string
        register("tcp_read", 2) do |args, env|
          stream_id = args[0].to_s
          size = args[1].to_i
          entry = self._servers[stream_id]
          return "" unless entry && entry[:type] == :tcp_stream

          begin
            entry[:io].read_nonblock(size)
          rescue IO::WaitReadable
            ""
          rescue EOFError
            nil
          end
        end

        # tcp_write(stream_id, data) -> bytes_written
        register("tcp_write", 2) do |args, env|
          stream_id = args[0].to_s
          data = args[1].to_s
          entry = self._servers[stream_id]
          return 0 unless entry && entry[:type] == :tcp_stream

          entry[:io].write(data)
        end

        # tcp_close(stream_id)
        register("tcp_close", 1) do |args, env|
          stream_id = args[0].to_s
          entry = self._servers.delete(stream_id)
          entry[:io].close if entry && entry[:io]
          nil
        end

        # tcp_listener_close(listener_id)
        register("tcp_listener_close", 1) do |args, env|
          listener_id = args[0].to_s
          entry = self._servers.delete(listener_id)
          entry[:server].close if entry && entry[:server]
          nil
        end

        # tcp_peer_address(stream_id) -> "ip:port"
        register("tcp_peer_address", 1) do |args, env|
          stream_id = args[0].to_s
          entry = self._servers[stream_id]
          return "" unless entry && entry[:type] == :tcp_stream

          begin
            addr = entry[:io].peeraddr
            "#{addr[3]}:#{addr[1]}"
          rescue
            ""
          end
        end

        # ========================================================================
        # HTTP REQUEST PARSING
        # ========================================================================

        # http_parse_request(raw_request_string) -> { method, path, headers, body, query_params }
        register("http_parse_request", 1) do |args, env|
          raw = args[0].to_s
          lines = raw.split("\r\n")
          return {} if lines.empty?

          # Parse request line
          request_line = lines[0]
          method, path, version = request_line.split(' ', 3)
          return {} unless method && path

          # Parse headers
          headers = {}
          i = 1
          while i < lines.length && !lines[i].empty?
            header_line = lines[i]
            if header_line.include?(':')
              key, value = header_line.split(':', 2)
              headers[key.strip.downcase] = value.strip
            end
            i += 1
          end

          # Body is everything after the blank line
          body = lines[i+1..]&.join("\r\n") || ""

          # Parse query params
          query_params = {}
          if path.include?('?')
            path_part, query_string = path.split('?', 2)
            path = path_part
            query_string.split('&').each do |param|
              key, value = param.split('=', 2)
              query_params[key] = value || ''
            end
          end

          {
            'method' => method,
            'path' => path,
            'headers' => headers,
            'body' => body,
            'query_params' => query_params,
            'url' => path
          }
        end

        # http_build_response(status, headers, body) -> string
        register("http_build_response", 3) do |args, env|
          status = args[0].to_i
          headers = args[1] || {}
          body = args[2].to_s

          status_text = case status
            when 200 then "OK"
            when 201 then "Created"
            when 301 then "Moved Permanently"
            when 302 then "Found"
            when 400 then "Bad Request"
            when 404 then "Not Found"
            when 500 then "Internal Server Error"
            else "Unknown"
          end

          response = "HTTP/1.1 #{status} #{status_text}\r\n"
          
          # Add Content-Length if not present and we have a body
          unless headers['content-length'] || headers['Content-Length']
            headers['content-length'] = body.bytesize.to_s
          end
          
          # Add Content-Type if not present
          unless headers['content-type'] || headers['Content-Type']
            headers['content-type'] = 'text/html; charset=utf-8'
          end

          headers.each do |key, value|
            response += "#{key}: #{value}\r\n"
          end

          response += "\r\n"
          response + body
        end

        # ========================================================================
        # HTTP SERVER (high-level)
        # ========================================================================

        # http_server_start(port, handler_fn) -> server_id
        register("http_server", 2) do |args, env|
          port = args[0].to_i
          handler_fn = args[1]
          
          server = TCPServer.new('0.0.0.0', port)
          server_id = server.object_id.to_s
          
          self._servers[server_id] = { 
            server: server, 
            handler: handler_fn,
            type: :http_server,
            running: true 
          }
          
          Thread.new do
            loop do
              break unless self._servers[server_id]&.dig(:running)
              
              begin
                client = server.accept_nonblock
                stream_id = client.object_id.to_s
                self._servers[stream_id] = { io: client, type: :tcp_stream, server_id: server_id }
              rescue IO::WaitReadable
                sleep 0.01
                next
              rescue => e
                break
              end
            end
          end
          
          server_id
        end

        # http_server_stop(server_id)
        register("http_server_stop", 1) do |args, env|
          server_id = args[0].to_s
          entry = self._servers[server_id]
          if entry && entry[:type] == :http_server
            entry[:running] = false
            entry[:server].close
            self._servers.delete(server_id)
          end
          nil
        end

        # http_server_is_running(server_id) -> boolean
        register("http_server_is_running", 1) do |args, env|
          server_id = args[0].to_s
          entry = self._servers[server_id]
          entry && entry[:type] == :http_server && entry[:running]
        end

        # ========================================================================
        # HTTP CLIENT
        # ========================================================================

        # http_get(url, headers) -> { status, headers, body }
        register("http_get", 2) do |args, env|
          url = args[0].to_s
          headers = (args[1] || {}).transform_keys(&:to_s)
          
          uri = URI(url)
          req = Net::HTTP::Get.new(uri)
          headers.each { |k, v| req[k] = v }
          
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = (uri.scheme == 'https')
          http.read_timeout = 30
          
          res = http.request(req)
          {
            'status' => res.code.to_i,
            'headers' => res.to_hash.transform_keys(&:downcase),
            'body' => res.body
          }
        end

        # http_post(url, body, headers) -> { status, headers, body }
        register("http_post", 3) do |args, env|
          url = args[0].to_s
          body = args[1] || ""
          headers = (args[2] || {}).transform_keys(&:to_s)
          
          uri = URI(url)
          req = Net::HTTP::Post.new(uri)
          headers.each { |k, v| req[k] = v }
          req.body = body
          req['content-length'] = body.bytesize.to_s if body
          
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = (uri.scheme == 'https')
          http.read_timeout = 30
          
          res = http.request(req)
          {
            'status' => res.code.to_i,
            'headers' => res.to_hash.transform_keys(&:downcase),
            'body' => res.body
          }
        end

        # http_request(method, url, body, headers) -> { status, headers, body }
        register("http_request", 4) do |args, env|
          method = args[0].to_s.upcase
          url = args[1].to_s
          body = args[2] || ""
          headers = (args[3] || {}).transform_keys(&:to_s)
          
          uri = URI(url)
          req_class = Net::HTTP.const_get(method.capitalize)
          req = req_class.new(uri)
          headers.each { |k, v| req[k] = v }
          req.body = body if body && !body.empty?
          req['content-length'] = body.bytesize.to_s if body && !body.empty?
          
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = (uri.scheme == 'https')
          http.read_timeout = 30
          
          res = http.request(req)
          {
            'status' => res.code.to_i,
            'headers' => res.to_hash.transform_keys(&:downcase),
            'body' => res.body
          }
        end

        # ========================================================================
        # HTTP GLOBAL MODULE
        # ========================================================================

        # Global Http module object
        register("Http", 0) do |args, env|
          {
            'server' => proc { |port, handler| http_server(port, handler) },
            'client' => proc { { 'type' => 'http_client' } },
            'router' => proc { { 'type' => 'http_router', 'routes' => [] } },
            'Response' => proc { |status, headers, body|
              { 'status' => status, 'headers' => headers || {}, 'body' => body || '' }
            }
          }
        end

        # http_server_start(port, handler_fn) -> server_id
        register("http_server", 2) do |args, env|
          port = args[0].to_i
          handler_fn = args[1]
          
          server = TCPServer.new('0.0.0.0', port)
          server_id = server.object_id.to_s
          
          self._servers[server_id] = { 
            server: server, 
            handler: handler_fn,
            type: :http_server,
            running: true 
          }
          
          Thread.new do
            loop do
              break unless self._servers[server_id]&.dig(:running)
              
              begin
                client = server.accept_nonblock
                stream_id = client.object_id.to_s
                self._servers[stream_id] = { io: client, type: :tcp_stream, server_id: server_id }
              rescue IO::WaitReadable
                sleep 0.01
                next
              rescue => e
                break
              end
            end
          end
          
          server_id
        end

        # http_server_stop(server_id)
        register("http_server_stop", 1) do |args, env|
          server_id = args[0].to_s
          entry = self._servers[server_id]
          if entry && entry[:type] == :http_server
            entry[:running] = false
            entry[:server].close
            self._servers.delete(server_id)
          end
          nil
        end

        # http_server_is_running(server_id) -> boolean
        register("http_server_is_running", 1) do |args, env|
          server_id = args[0].to_s
          entry = self._servers[server_id]
          entry && entry[:type] == :http_server && entry[:running]
        end

      end

      init!
    end
  end
end