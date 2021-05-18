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
      datadog_integration.trace "query", resource: command.first do |span|
        previous_def
      end
    end

    def pipeline
      datadog_integration.trace "pipeline", resource: "" do
        previous_def
      end
    end

    @datadog_integration : Datadog::Integrations::Integration?
    private def datadog_integration
      @datadog_integration ||= Datadog.integration([@uri.to_s])
    end
  end

  class Pipeline
    @commands = []

    def run(command)
      @commands << command.first

      previous_def
    end

    def commit
      result = previous_def

      # Set the resource to the list of commands run inside the pipeline
      if span = Datadog.tracer.active_span
        span.resource = @commands.join(", ")
      end

      result
    end
  end
end
