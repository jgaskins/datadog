require "msgpack"
require "statsd"
require "log"

require "./configuration"
require "./default_tracer"
require "./span"

module Datadog
  CONFIG = Configuration.new
  DEFAULT_TRACER = DefaultTracer.new(CONFIG)
  VERSION = "0.1.0"
  Log = ::Log.for(self)

  # Yields the `Datadog::Configuration` in use
  def self.configure
    yield CONFIG
  end

  # Return the currently configured tracer
  def self.tracer
    CONFIG.tracer
  end

  @@metrics : Statsd::Client?

  # Return a metrics client to allow you to report metrics via Statsd.
  def self.metrics
    @@metrics ||= Statsd::Client.new(CONFIG.agent_host, CONFIG.metrics_agent_port)
  end
end

spawn do
  loop do
    sleep 1
    spawn Datadog.tracer.report
  rescue ex
    # Make some sort of affordance to report to an error-tracking service
    Datadog.tracer.handle_error ex
  end
end

at_exit { Datadog.tracer.report }
