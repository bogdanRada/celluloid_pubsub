require_relative './helper'
module CelluloidPubsub
  # The reactor handles new connections. Based on what the client sends it either subscribes to a channel
  # or will publish to a channel or just dispatch to the server if command is neither subscribe, publish or unsubscribe
  class HttpReactor
    include CelluloidPubsub::BaseActor

    attr_reader :server
    finalizer :shutdown

    def work(request, server)
      @server = server
      handle_request(request)
    end

    # the method will terminate the current actor
    #
    #
    # @return [void]
    #
    # @api public
    def shutdown
      debug "#{self.class} tries to 'shudown'"
      terminate
    end

    # Compile the regex once
    CONTENT_LENGTH_HEADER = %r{^content-length$}i

    #  HTTP connections are not accepted so this method will show 404 message "Not Found"
    #
    # @param [Reel::Request] request The request that was made to the webserver and contains the type , the url, and the parameters
    #
    # @return [void]
    #
    # @api public
    def handle_request(request)
      options = {
        :method       => request.method,
        :input        => request.body.to_s,
        "REMOTE_ADDR" => request.remote_addr
      }.merge(convert_headers(request.headers))

      normalize_env(options)

      status, headers, body = @server.app.call ::Rack::MockRequest.env_for(request.url, options)

      if body.respond_to? :each
        # If Content-Length was specified we can send the response all at once
        if headers.keys.detect { |h| h =~ CONTENT_LENGTH_HEADER }
          # Can't use collect here because Rack::BodyProxy/Rack::Lint isn't a real Enumerable
          full_body = ''
          body.each { |b| full_body << b }
          request.respond status_symbol(status), headers, full_body
        else
          request.respond status_symbol(status), headers.merge(:transfer_encoding => :chunked)
          body.each { |chunk| request << chunk }
          request.finish_response
        end
      else
        Logger.error("don't know how to render: #{body.inspect}")
        request.respond :internal_server_error, "An error occurred processing your request"
      end

      body.close if body.respond_to? :close
    end

    # Those headers must not start with 'HTTP_'.
    NO_PREFIX_HEADERS=%w[CONTENT_TYPE CONTENT_LENGTH].freeze

    def convert_headers(headers)
      Hash[
        headers.map do |key, value|
          header = key.upcase.gsub('-','_')

          if NO_PREFIX_HEADERS.member?(header)
            [header, value]
          else
            ['HTTP_' + header, value]
          end
        end
      ]
    end

    # Copied from lib/puma/server.rb
    def normalize_env(env)
      if host = env["HTTP_HOST"]
        if colon = host.index(":")
          env["SERVER_NAME"] = host[0, colon]
          env["SERVER_PORT"] = host[colon+1, host.bytesize]
        else
          env["SERVER_NAME"] = host
          env["SERVER_PORT"] = default_server_port(env)
        end
      else
        env["SERVER_NAME"] = "localhost"
        env["SERVER_PORT"] = default_server_port(env)
      end
    end

    def default_server_port(env)
      env['HTTP_X_FORWARDED_PROTO'] == 'https' ? 443 : 80
    end

    def status_symbol(status)
      if status.is_a?(Fixnum)
        Reel::Response::STATUS_CODES[status].downcase.gsub(/\s|-/, '_').to_sym
      else
        status.to_sym
      end
    end

  end
end
