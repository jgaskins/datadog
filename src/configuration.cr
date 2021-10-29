require "socket"
require "./span"
require "./tracer"

module Datadog
  # :nodoc:
  class Service
    getter name : String
    getter type : String

    def initialize(@name, @type)
    end
  end

  # Datadog can be configured by passing a block to `Datadog.configure`.
  #
  # ```
  # Datadog.configure do |c|
  #   # Define your service
  #   c.service "my-web-app", type: "http"
  #
  #   # Set global tags
  #   c.tags = {
  #     "environment" => ENV["APP_ENV"],
  #     "k8s_pod" => ENV["HOSTNAME"],
  #     "k8s_deployment" => ENV["HOSTNAME"][/\A\w+-\w+/],
  #   }
  # end
  # ```
  class Configuration
    property? tracing_enabled : Bool = ENV["DD_TRACING_ENABLED"]? == "true"

    # The agent host is the physical or logical IP address where your Datadog agent is running, defaults to `localhost`
    getter agent_host : String = resolve_ip(ENV.fetch("DD_AGENT_HOST", "localhost"))
    def agent_host=(host)
      @agent_host = self.class.resolve_ip(host)
    end

    # The trace-agent port is the TCP port that the APM server is listening on, defaults to 8126.
    property trace_agent_port : Int32 = ENV.fetch("DD_TRACE_AGENT_PORT", "8126").to_i

    # The metrics-agent port is the UDP port that the metrics agent is listening on, defaults to 8125.
    property metrics_agent_port : Int32 = ENV.fetch("DD_METRICS_AGENT_PORT", "8125").to_i

    # Returns a `Datadog::Span::Metadata` containing any tags you want to set globally on your spans and metrics.
    getter tags = Span::Metadata.new

    # Set tags you want to set globally on your spans and metrics.
    def tags=(tags : Hash)
      @tags = tags.transform_values(&.as(String))
    end

    # Declare a service name with a given type, the first will become the default service when reporting spans.
    def service(name : String, type = "http")
      service = Service.new(name: name, type: type)
      @service ||= name
      @services[name] = service
    end

    # :nodoc:
    def apm_base_url
      URI.parse("http://#{agent_host}:#{trace_agent_port}")
    end

    # Return the current tracer adapter, defaults to the Datadog MessagePack/HTTP tracer.
    # This interface is still being defined to allow for adapters like OpenTracing.
    setter tracer : Tracer?
    def tracer
      @tracer || DEFAULT_TRACER
    end

    # Get or set the default service name to use when no other services are specified.
    property service : String?

    # :nodoc:
    def default_service
      @services[@service]
    end

    alias ServiceMap = Hash(String?, Service)
    @services : ServiceMap = ServiceMap.new(
      default_value: Service.new(
        name: "unknown-service",
        type: "http",
      ),
    )

    # :nodoc:
    def self.resolve_ip(host)
      return host if host =~ /(\d+\.){3}\d+/ # If we received an IP address, just return it

      # It doesn't seem to work well with IPv6, so let's stick with IPv4 addresses
      Socket::Addrinfo
        .udp(host, "")
        .map(&.ip_address.address)
        .reject { |addr| addr.includes? ':' }
        .first
    end
  end
end
