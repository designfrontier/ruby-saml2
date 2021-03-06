require 'saml2/namespaces'

module SAML2
  class Base
    def self.from_xml(node)
      return nil unless node
      result = new
      result.from_xml(node)
      result
    end

    attr_reader :xml

    def initialize
      @pretty = true
    end

    def from_xml(node)
      @xml = node
    end

    def to_s(pretty: nil)
      pretty = @pretty if pretty.nil?
      if xml
        xml.to_s
      elsif pretty
        to_xml.to_s
      else
        # make sure to not FORMAT it - it breaks signatures!
        to_xml.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML | Nokogiri::XML::Node::SaveOptions::NO_DECLARATION)
      end
    end

    def inspect
      "#<#{self.class.name} #{instance_variables.map { |iv| next if iv == :@xml; "#{iv}=#{instance_variable_get(iv).inspect}" }.compact.join(", ") }>"
    end

    def to_xml
      unless instance_variable_defined?(:@document)
        builder = Nokogiri::XML::Builder.new
        build(builder)
        @document = builder.doc
        # if we're re-serializing a parsed document (i.e. after mutating/parsing it),
        # forget the original document we parsed
        @xml = nil
      end
      @document
    end

    def build(builder)
    end

    def self.load_string_array(node, element)
      node.xpath(element, Namespaces::ALL).map do |element_node|
        element_node.content&.strip
      end
    end

    def self.load_object_array(node, element, klass = nil)
      node.xpath(element, Namespaces::ALL).map do |element_node|
        if klass.nil?
          SAML2.const_get(element_node.name, false).from_xml(element_node)
        elsif klass.is_a?(Hash)
          klass[element_node.name].from_xml(element_node)
        else
          klass.from_xml(element_node)
        end
      end
    end

    def self.lookup_qname(qname, namespaces)
      prefix, local_name = split_qname(qname)
      [lookup_namespace(prefix, namespaces), local_name]
    end

    protected

    def load_string_array(node, element)
      self.class.load_string_array(node, element)
    end

    def load_object_array(node, element, klass = nil)
      self.class.load_object_array(node, element, klass)
    end

    def self.split_qname(qname)
      if qname.include?(':')
        qname.split(':', 2)
      else
        [nil, qname]
      end
    end

    def self.lookup_namespace(prefix, namespaces)
      return nil if namespaces.empty?
      namespaces[prefix.empty? ? 'xmlns' : "xmlns:#{prefix}"]
    end
  end
end
