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
    in DB::SessionMethods::UnpreparedQuery
      host = context.@session.context.uri.host
      db = context.@session.context.uri.path[1..-1]
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
    in DB::SessionMethods::UnpreparedQuery
      host = context.@session.context.uri.host
      db = context.@session.context.uri.path[1..-1]
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
    in DB::SessionMethods::UnpreparedQuery
      host = context.@session.context.uri.host
      db = context.@session.context.uri.path[1..-1]
    end

    Datadog.integration([host, db]).trace "db.query", resource: query do |span|
      previous_def(query, *args_, args: args)
    end
  end
end

class DB::ResultSet
  def each
    uri = statement.connection.context.uri
    host = uri.host
    db = uri.path[1..-1]

    Datadog.integration([host, db]).trace "result_set.each", resource: statement.command do |span|
      result_count = 0
      begin
        previous_def do
          result_count += 1
          yield
        end
      ensure
        span.tags["row_count"] = result_count.to_s
        span.tags["column_count"] = column_count.to_s
      end
    end
  end
end
