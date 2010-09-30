require 'rubygems'
require 'savon'
require 'builder'
require 'ostruct'
require 'nokogiri'

::Savon::Request.log = false;

class String
  def underscore
    word = self.to_s.dup
    word.gsub!(/::/, '/')
    word.gsub!(/([A-Z]+)([A-Z][a-z])/,'\1_\2')
    word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
    word.tr!("-", "_")
    word.downcase!
    word
  end
end

class JasperClient < ::Savon::Client

  #--------------------------------------------------------------------
  # Resources
  #--------------------------------------------------------------------
  class Resource < OpenStruct
    def initialize(xml_doc)
      puts xml_doc.to_xml
      super
      xml_doc.attribute_nodes.each { |node|
        send("%s=" % [ node.name.underscore ], node.value)
      }
    end
  end
  
  #--------------------------------------------------------------------
  # Requests
  #--------------------------------------------------------------------
  class Request
    def build_request(&blk) 
      inner_xml = Builder::XmlMarkup.new :indent => 2
      inner_xml.request 'operationName' => soap_method do |request|
        yield request
      end
      
      body = Builder::XmlMarkup.new :indent => 2
      body.requestXmlString { |request_string| request_string.cdata! inner_xml.target! }
    end
    
    alias to_s to_xml
    
    class List < Request
      def to_xml
        build_request do |body|
          arguments.each_pair { |name,value| body.argument(value, :name => name) }
        end
      end
    end
    
    class Get < Request
      def to_xml
        build_rquest do |body|
            <resourceDescriptor name="JRLogo" wsType="img" uriString="/Reports/xforty/user_list" isNew="false">
            </resourceDescriptor>
          
        end
      end
    end
    
    class RunReport < Request
      def to_xml
        build_rquest do |body|
          
        end
      end
    end
        
    attr_accessor :arguments, :client
    
    def soap_method
      self.class.name.underscore
    end
  end

  #--------------------------------------------------------------------
  # Responses
  #--------------------------------------------------------------------
  class Response
    attr_reader :xml_doc
    
    def return_code
      xml_doc.search('//returnCode').inner_text
    end
    
    class ListResponse < Response
      def initialize(response_xml)
        soap_doc = Nokogiri::XML response_xml
        @xml_doc = Nokogiri::XML soap_doc.search('//listReturn/node()').inner_text
      end
      
      def items
        xml_doc.search('//resourceDescriptor').map { |rd| Resource.new rd }
      end
    end
    
    class GetResponse < Response
      
    end
    
    class RunReportResponse < Response
      
    end
  end
  
  attr_reader :wsdl_url, :username, :password
  
  def initialize(wsdl_url, username, password)
    super wsdl_url
    request.basic_auth username, password  
    @wsdl_url = wsdl_url
    @username = username
    @password = password
  end
  
  def supported_request?(name)
    Request.const_get name.to_s.capitalize.to_sym
    return true
  rescue NameError
    return false
  end
  
  def method_missing(name, params)
    if supported_request?(name)
      request_class = Request.const_get name.to_s.capitalize.to_sym
      request = request_class.new
      request.arguments = params
      savon_response = super(name, params) { |soap| soap.body = request.to_xml }
      response_xml = savon_response.to_xml
      response_class = Response.const_get "%sResponse" % [ name.to_s.capitalize.to_sym ]
      response_class.new response_xml
    else
      super(params)
    end
  end
end
