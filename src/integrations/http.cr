require "db"

require "../integrations"

module Datadog::Integrations
  module HTTP
    class Client
      include Integration

      # Returns a configuration that will report every different domain as a separate service
      def self.split_by_domain
        new
      end

      def register(integrations)
        integrations[%w(http)] = self
      end

      def trace(name, resource, tags = Span::Metadata.new)
        Datadog.tracer.trace "http.request", service_name: name, type: "http", resource: resource, tags: tags do |span|
          yield span
        end
      end
    end
  end
end

class HTTP::Client
  def exec(request : HTTP::Request) : HTTP::Client::Response
    resource = "GET http#{@tls ? 's' : ""}://#{@host}#{request.resource}"
    Datadog.integration(%w[http]).trace @host, resource: resource do |span|
      previous_def
    end
  end
end
