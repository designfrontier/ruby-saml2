require 'active_support/core_ext/array/wrap'

require 'saml2/attribute'
require 'saml2/indexed_object'
require 'saml2/localized_name'
require 'saml2/namespaces'

module SAML2
  class RequestedAttribute < Attribute
    class << self
      def namespace
        'md'
      end

      def element
        'RequestedAttribute'
      end

      def create(name, is_required = nil)
        # use Attribute.create to get other subclasses to automatically fill out friendly_name
        # and name_format, but still return a RequestedAttribute object
        attribute = Attribute.create(name)
        new(attribute.name, is_required, attribute.friendly_name, attribute.name_format)
      end
    end

    def initialize(name = nil, is_required = nil, friendly_name = nil, name_format = nil)
      super(name, nil, friendly_name, name_format)
      @is_required = is_required
    end

    def from_xml(node)
      super
      @is_required = node['isRequired'] && node['isRequired'] == 'true'
    end

    def required?
      @is_required
    end
  end

  class RequiredAttributeMissing < RuntimeError
    attr_reader :requested_attribute

    def initialize(requested_attribute)
      super("Required attribute #{requested_attribute.name} not provided")
      @requested_attribute = requested_attribute
    end
  end

  class InvalidAttributeValue < RuntimeError
    attr_reader :requested_attribute, :provided_value

    def initialize(requested_attribute, provided_value)
      super("Attribute #{requested_attribute.name} is provided value " \
        "#{provided_value.inspect}, but only allows "                  \
        "#{Array.wrap(requested_attribute.value).inspect}")
      @requested_attribute, @provided_value = requested_attribute, provided_value
    end
  end

  class AttributeConsumingService < Base
    include IndexedObject

    attr_reader :name, :description, :requested_attributes

    def initialize(name = nil, requested_attributes = [])
      super()
      @name = LocalizedName.new('ServiceName', name)
      @description = LocalizedName.new('ServiceDescription')
      @requested_attributes = requested_attributes
    end

    def from_xml(node)
      super
      name.from_xml(node.xpath('md:ServiceName', Namespaces::ALL))
      description.from_xml(node.xpath('md:ServiceDescription', Namespaces::ALL))
      @requested_attributes = load_object_array(node, "md:RequestedAttribute", RequestedAttribute)
    end

    def create_statement(attributes)
      if attributes.is_a?(Hash)
        attributes = attributes.map { |k, v| Attribute.create(k, v) }
      end

      attributes_hash = {}
      attributes.each do |attr|
        attr.value = attr.value.call if attr.value.respond_to?(:call)
        attributes_hash[[attr.name, attr.name_format]] = attr
        if attr.name_format
          attributes_hash[[attr.name, nil]] = attr
        end
      end

      attributes = []
      requested_attributes.each do |requested_attr|
        attr = attributes_hash[[requested_attr.name, requested_attr.name_format]]
        if requested_attr.name_format
          attr ||= attributes_hash[[requested_attr.name, nil]]
        end
        if attr
          if requested_attr.value &&
            !Array.wrap(requested_attr.value).include?(attr.value)
            raise InvalidAttributeValue.new(requested_attr, attr.value)
          end
          attributes << attr
        elsif requested_attr.required?
          # if the metadata includes only one possible value, helpfully set
          # that value
          if requested_attr.value && !requested_attr.value.is_a?(::Array)
            attributes << Attribute.create(requested_attr.name,
                                           requested_attr.value)
          else
            raise RequiredAttributeMissing.new(requested_attr)
          end
        end
      end
      return nil if attributes.empty?
      AttributeStatement.new(attributes)
    end

    def build(builder)
      builder['md'].AttributeConsumingService do |attribute_consuming_service|
        name.build(attribute_consuming_service)
        description.build(attribute_consuming_service)
        requested_attributes.each do |requested_attribute|
          requested_attribute.build(attribute_consuming_service)
        end
      end
      super
    end
  end
end
