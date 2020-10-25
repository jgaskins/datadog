require "db"

require "../integrations"

module Datadog::Integrations
  class DB
    include Integration

    getter service_name : String
    getter host : String?
    getter db : String
    getter service : Service

    def initialize(@service_name, @host, @db)
      @service = Service.new("postgresql", type: "db")
    end

    def register(integrations)
      @service = CONFIG.service @service_name, type: "db"
      integrations[[@host || "", @db]] = self
    end

    def trace(name, resource, tags = Span::Metadata.new)
      Datadog.tracer.trace name, service: service, resource: resource, tags: tags do |span|
        yield span
      end
    end
  end
end

module DB::QueryMethods
  def exec(query, *args_, args : Array? = nil) : DB::ExecResult
    case context = self
    in DB::Database
      host = context.@uri.host
      db = context.@uri.path[1..-1]
    in DB::Connection
      host = context.connection.@conninfo.host
      db = context.connection.@conninfo.database
    end

    Datadog.integration([host, db]).trace "db.query", resource: query do |span|
      previous_def(query, *args_, args: args)
    end
  end

  def query(query, *args_, args : Array? = nil) : DB::ResultSet
    case context = self
    in DB::Database
      host = context.@uri.host
      db = context.@uri.path[1..-1]
    in DB::Connection
      host = context.connection.@conninfo.host
      db = context.connection.@conninfo.database
    end

    Datadog.integration([host, db]).trace "db.query", resource: query do |span|
      previous_def(query, *args_, args: args)
    end
  end

  def scalar(query, *args_, args : Array? = nil)
    case context = self
    in DB::Database
      host = context.@uri.host
      db = context.@uri.path[1..-1]
    in DB::Connection
      host = context.connection.@conninfo.host
      db = context.connection.@conninfo.database
    end

    Datadog.integration([host, db]).trace "db.query", resource: query do |span|
      previous_def(query, *args_, args: args)
    end
  end
end

module DB::Serializable
  macro finished
    {% for includer in @type.includers %}
      def {{includer}}.new(rs : ::DB::ResultSet) : self
        Datadog.integration(["db.serializable.initialize"]).trace "db.serializable.initialize", resource: name do |span|
          previous_def
        end
      end
    {% end %}
  end
end
