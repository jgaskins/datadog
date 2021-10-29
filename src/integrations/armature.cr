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
  extend self
end

module Datadog::Armature::Route
  include ::Armature::Route

  module DatadogIntegration
    def datadog_integration
      Datadog.integration([Datadog::Integrations::Armature.service_name])
    end
  end

  include DatadogIntegration

  def route(context)
    datadog_integration.trace "route", resource: self.class.name do |span|
      ::Armature::Route.route context do |r, response, session|
        span["path"] = r.path

        yield Request.new(r), response, session
      end
    end
  end

  macro render(template, to io = response)
    ::Datadog.integration([::Datadog::Integrations::Armature.service_name]).trace "render", resource: "{{template.id}}" do
      ECR.embed "views/{{template.id}}.ecr", {{io}}
    end
  end

  class Request
    include DatadogIntegration

    def initialize(@request : ::Armature::Route::Request)
    end

    forward_missing_to @request

    def root
      return if handled? # Don't add this to the trace if we aren't matching

      @request.root do
        datadog_integration.trace "match", resource: "/" do
          yield
        end
      end
    end

    def on(path : String)
      return if handled? # Don't add this to the trace if we aren't matching

      @request.on path do
        datadog_integration.trace "match", resource: path do
          yield
        end
      end
    end

    def on(capture : Symbol)
      return if handled? # Don't add this to the trace if we aren't matching

      @request.on capture do |value|
        datadog_integration.trace "match", resource: path.to_s do |span|
          span.tags["value"] = value
          yield value
        end
      end
    end
  end
end
