require "http"

require "./tracer"
require "./span"
require "./configuration"

class HTTP::Client
  def exec_without_instrumentation(request : HTTP::Request)
    exec_internal request
  end
end

class Fiber
  property current_datadog_span : Datadog::Span?
  property current_datadog_trace : Datadog::Trace?
end

module Datadog
  class DefaultTracer
    include Tracer

    getter traces = TraceSet.new
    @lock = Mutex.new # Don't want to lose spans while we report them
    @config : Configuration

    def initialize(@config)
    end

    def active_trace
      Fiber.current.current_datadog_trace
    end

    def active_span
      Fiber.current.current_datadog_span
    end

    def trace(
      name : String,
      resource : String,
      current_span = active_span,
      parent_id = current_span.try(&.id) || 0i64,
      trace_id = current_span.try(&.trace_id) || Random::Secure.rand(Int64).abs,
      span_id = Random::Secure.rand(Int64).abs,
      service = @config.default_service,
      service_name = service.name,
      start = Time.utc,
      type = service.type,
      tags = Span::Metadata.new,
    )
      if current_span = active_span
        current_trace_id = current_span.trace_id
      end

      span = Span.new(
        trace_id: current_trace_id || Random::Secure.rand(Int64).abs,
        id: span_id,
        parent_id: parent_id,
        name: name,
        service: service_name[0...100], # Service name must be <= 100 characters
        resource: resource[0...5000], # Resource must be <= 5000 characters
        type: type,
        start: (start.to_unix_f * 1_000_000_000).to_i64,
        duration: 0i64,
        tags: @config.tags.merge(tags),
        metrics: Span::Metrics.new,
        allocations: 0i64,
        error: 0,
      )
      if parent_id == 0
        span.metrics["system.pid"] = Process.pid.to_f64
      end

      # If tracing is disabled, we yield a span that we then just throw away
      unless @config.tracing_enabled?
        return yield span
      end

      unless active_trace = Fiber.current.current_datadog_trace
        top_level_span = true
        Fiber.current.current_datadog_trace = active_trace = Trace.new
      end
      active_trace << span
      previous_span = active_span
      Fiber.current.current_datadog_span = span
      start_monotonic = Time.monotonic
      
      begin
        yield span
      rescue ex
        span.error += 1
        raise ex
      ensure
        duration = (Time.monotonic - start_monotonic).total_nanoseconds.to_i64
        span.duration = duration
        Fiber.current.current_datadog_span = previous_span
        if previous_span.nil?
          Fiber.current.current_datadog_trace = nil
        end
        if top_level_span
          active_trace.each do |span|
            Log.context.metadata.each do |key, value|
              span[key] = value
            end
          end
          @lock.synchronize { @traces << active_trace }
        end
      end
    end

    # :nodoc:
    def report
      @lock.synchronize do
        return if @traces.empty?

        Log.debug { "Reporting #{@traces.size} traces to Datadog" }

        response = HTTP::Client.new(@config.apm_base_url).exec_without_instrumentation(
          pp HTTP::Request.new(
            method: "POST",
            resource: "/v0.4/traces",
            headers: HTTP::Headers {
              "Content-Type" => "application/msgpack",
              "Datadog-Meta-Lang" => "crystal",
              "Datadog-Meta-Lang-Version" => Crystal::VERSION,
              "Datadog-Meta-Tracer-Version" => VERSION,
              "Host" => "#{@config.agent_host}:#{@config.trace_agent_port}",
              "User-Agent" => "Crystal Datadog shard (https://github.com/jgaskins/datadog)",
              "X-Datadog-Trace-Count" => @traces.size.to_s,
            },
            body: @traces.to_msgpack,
          )
        )

        if response.success?
          @traces.clear
        else
          Log.warn { "Reporting Datadog traces unsuccessful: #{response.status_code} #{response.status} - #{response.body}" }
        end
      end
    end

    def handle_error(ex)
      # ...
    end
  end
end
