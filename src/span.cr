require "msgpack"

module Datadog
  # A span is a unit of measurable work for Datadog.
  class Span
    include MessagePack::Serializable

    alias Metadata = Hash(String, String)
    alias Metrics = Hash(String, String | Float64)

    getter trace_id : Int64
    @[MessagePack::Field(key: "span_id")]
    getter id : Int64
    getter parent_id : Int64
    getter name : String
    getter service : String
    property resource : String
    getter type : String
    getter start : Int64
    property duration : Int64
    @[MessagePack::Field(key: "meta")]
    getter tags : Metadata
    getter metrics : Metrics
    getter allocations : Int64
    property error : Int32

    def initialize(@trace_id, @id, @parent_id, @name, @service, @resource, @type, @start, @duration, @tags, @metrics, @allocations, @error)
    end

    def []=(key, value : ::Log::Metadata::Value)
      tags[key.to_s] = value.raw.to_s
    end

    def []=(key, value)
      tags[key.to_s] = value
    end

    def []?(key)
      tags[key.to_s]?
    end
  end
end
