require 'nokogiri'

require 'saml2/endpoint'
require 'saml2/sso'

module SAML2
  class ServiceProvider < SSO
    attr_reader :entity

    def initialize(entity, root)
      @entity, @root = entity, root
    end

    def assertion_consumer_services
      @assertion_consumer_services ||= begin
        nodes = @root.xpath('md:AssertionConsumerService', Namespaces::ALL)
        Endpoint::Indexed::Array.from_xml(nodes)
      end
    end

    def attribute_consuming_services
      @attribute_consuming_services ||= begin
        nodes = @root.xpath('md:AttributeConsumingService', Namespaces::ALL)
        AttributeConsumingService::Array.from_xml(nodes)
      end
    end
  end
end