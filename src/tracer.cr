require "./span"

module Datadog
  alias Trace = Array(Span)
  alias TraceSet = Array(Trace)

  # All tracer implementations must implement this interface
  module Tracer
    # Yields a new span to the given block, setting all of the values you pass to it
    abstract def trace(name : String, resource : String, current_span, parent_id, trace_id, span_id, service, service_name, start, type, tags, & : Span ->)
  end
end
