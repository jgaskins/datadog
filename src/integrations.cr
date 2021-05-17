require "./datadog"

module Datadog
  def self.integration(key)
    CONFIG.@integrations.fetch(key) do
      Log.debug { "Integration loaded but not used: #{key.inspect}" }
      Configuration::NO_INTEGRATION
    end
  end

  module Integrations
    module Integration
      abstract def register(integrations)
      abstract def trace(name, resource, tags, & : Span ->)
    end

    class NoIntegration
      include Integration

      EMPTY_SPAN = Span.new(0u64, 0u64, 0u64, "", "", "", "", 0i64, 0i64, Span::Metadata.new, Span::Metadata.new, 0i64, 0)

      def register(integrations)
      end

      def trace(name, resource, tags = Span::Metadata.new, & : Span ->)
        yield EMPTY_SPAN
      end
    end
  end

  class Configuration
    alias IntegrationMap = Hash(Array(String), Integrations::Integration)

    NO_INTEGRATION = Integrations::NoIntegration.new
    @integrations : IntegrationMap = IntegrationMap.new(default_value: NO_INTEGRATION)

    def use(integration)
      integration.register @integrations
    end
  end
end
