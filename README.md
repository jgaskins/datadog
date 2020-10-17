# Datadog

This is a Crystal library providing an APM tracing client for [Datadog](https://datadoghq.com/).

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     datadog_trace:
       github: jgaskins/datadog
   ```

2. Run `shards install`

## Usage

```crystal
require "datadog"

Datadog.configure do |c|
  # Define your service
  c.service "my-web-app", type: "http"

  # Define tags you want on every span
  c.tags = Datadog::Span::Metadata {
    "environment" => ENV["ENVIRONMENT"],
    "k8s_pod" => ENV["HOSTNAME"],
    "k8s_deployment" => ENV["HOSTNAME"][/\A\w+-\w+/],
  }

  # You can set up values for where to contact the Datadog agent.
  # These are the defaults.
  c.agent_host = ENV["DD_AGENT_HOST"]
  c.trace_agent_port = ENV["DD_TRACE_AGENT_PORT"]
  c.metrics_agent_port = ENV["DD_METRICS_AGENT_PORT"]
end
```

### Report spans to Datadog APM

```crystal
tags = Datadog::Span::Metadata {
  "user_id" => context.user.try(&.id),
  # ...
}

Datadog.tracer.trace "my.span.name", resource: "my.resource.name", tags: tags do |span|
  # do work here
end
```

This can get pretty verbose if you're instrumenting heavily. It might be worth defining a method for it:

```crystal
def instrument(name, resource, tags = Datadog::Span::Metadata.new) do |span|
  Datadog.tracer.trace name, resource: resource, tags: tags do |span|
    yield span
  end
end
```

Then your code only needs to call this:

```crystal
instrument "my.span.name", "my.resource.name" do |span|
  # do work here
end
```

If most of your span names are the same with different resources, you can instrument it even more easily by setting a default `name`.

### Report Datadog custom metrics

Datadog custom metrics are handled via [Statsd](https://github.com/statsd/statsd). `Datadog.metrics` is currently implemented as a [`Statsd::Client`](https://github.com/miketheman/statsd.cr).

```crystal
# Set a value
Datadog.metrics.gauge "my.metric.name", 1, tags: %w[key1:value1 key2:value2]

# Increment or decrement a gauge
Datadog.metrics.increment "my.metric.name", tags: %w[key1:value1 key2:value2]
Datadog.metrics.increment "my.metric.name", tags: %w[key1:value1 key2:value2]

# Set a counter
Datadog.metrics.set "my.metric.name, 1

# Report how long it takes to execute a block
Datadog.metrics.time "my.metric.name" do
  # ...
end

# Maintain a histogram for how long it takes to execute a block
Datadog.metrics.histogram "my.metric.name" do
  # ...
end
```

## Contributing

1. Fork it (<https://github.com/jgaskins/datadog/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Jamie Gaskins](https://github.com/jgaskins) - creator and maintainer
