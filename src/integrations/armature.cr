require "armature/route"

require "../integrations"

module Datadog::Integrations
  class Armature
    include Integration

    class_property service_name : String = "armature"
    getter service : Service

    def initialize(@service_name = "armature", type : String = "http")
      @service = Service.new(self.class.service_name, type: "http")
      self.class.service_name = service_name
    end

    def register(integrations)
      integrations[[@service_name]] = self
    end

    def trace(name, resource, tags = Span::Metadata.new)
      Datadog.tracer.trace name, service: service, resource: resource, tags: tags do |span|
        yield span
      end
    end
  end
end

module Armature::Route
  module DatadogIntegration
    def datadog_integration
      Datadog.integration([Datadog::Integrations::Armature.service_name])
    end
  end

  include DatadogIntegration

  def route(context)
    tags = Datadog::Span::Metadata {
      "class" => self.class.name,
    }
    datadog_integration.trace "route", resource: query, tags: tags do |span|
      previous_def
    end
  end

  macro render(template, to io = response)
    Datadog.integration([Datadog::Integrations::Armature.service_name]).trace "render", resource: "{{template.id}}" do
      ECR.embed "views/{{template.id}}.ecr", {{io}}
    end
  end

  class Request
    include DatadogIntegration

    def root
      return if handled? # Don't add this to the trace if we aren't matching

      datadog_integration.trace "match", resource: "/" do
        previous_def
      end
    end

    def on(path : String)
      return if handled? # Don't add this to the trace if we aren't matching

      datadog_integration.trace "match", resource: path do
        previous_def
      end
    end

    def on(capture : Symbol)
      return if handled? # Don't add this to the trace if we aren't matching

      datadog_integration.trace "match", resource: path.to_s do |span|
        previous_def capture do |value|
          span.tags["value"] = value
          yield value
        end
      end
    end
  end
end
