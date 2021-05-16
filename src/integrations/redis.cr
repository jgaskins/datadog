require "redis"

require "../integrations"

module Datadog::Integrations
  class Redis
    include Integration

    getter service_name : String
    getter key : Array(String)
    getter service : Service

    def initialize(@service_name, uri : URI, @type : String = "db")
      @service = CONFIG.service service_name, type: type
      @key = [uri.to_s]
    end

    def register(integrations)
      integrations[@key] = self
    end

    def trace(name, resource, tags = Span::Metadata.new)
      Datadog.tracer.trace name, service: service, resource: resource, tags: tags do |span|
        yield span
      end
    end
  end
end

module Redis
  module DatadogIntegration
  end

  class Connection
    include DatadogIntegration

    def run(command, retries = 5)
      if command.first == "auth"
        resource = "auth [REDACTED]"
      else
        resource = command.join(' ')
      end

      datadog_integration.trace "connection.query", resource: resource do |span|
        previous_def
      end
    end

    def pipeline
      datadog_integration.trace "pipeline", resource: "" do
        previous_def
      end
    end

    private def datadog_integration
      Datadog.integration([@uri.to_s])
    end
  end

  class Pipeline
    @commands = ""

    def run(command)
      if command.first == "auth"
        @commands += "auth [REDACTED]"
      else
        @commands += command.join(", ")
      end

      previous_def
    end

    def commit
      result = previous_def
      if span = Datadog.tracer.active_span
        span.resource = @commands
      end

      result
    end
  end
end
