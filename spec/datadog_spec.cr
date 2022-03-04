require "./spec_helper"

require "../src/datadog"

describe Datadog::DefaultTracer do
  tracer = Datadog::DefaultTracer.new

  it "traces things" do
    tracer.trace "name", resource: "resource name" do |span|
      span.name.should eq "name"
      span.resource.should eq "resource name"
    end
  end
end
