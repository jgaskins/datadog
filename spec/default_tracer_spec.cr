require "./spec_helper"
require "../src/default_tracer"
require "../src/configuration"
require "http"

trace_server = HTTP::Server.new do |context|
  request = context.request
  response = context.response

  if body = request.body
    pp Datadog::TraceSet.from_msgpack(body)
  end
end

module Datadog
  describe DefaultTracer do
    config = Configuration.new
    config.tracing_enabled = true
    tracer = DefaultTracer.new(config)

    before_all do
      spawn trace_server.listen 8126
    end

    after_all { trace_server.close }

    it "adds traces" do
      tracer.trace "foo", "bar" do |span|
        span["omg"] = "lol"
      end

      span = tracer.traces
        .first # First trace
        .first # First span of the trace

      span["omg"]?.should eq "lol"
    end
  end
end
