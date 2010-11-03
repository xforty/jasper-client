# Contiainer for things belonging to jasper client.
module JasperClient
  # a Jasper Server resource.
  #
  # A Jasperserver resource is a generic concept used to represent almost anything
  # in a jasper server.  It can be a file, an image, pre-run report output, a query, 
  # a report control, etc.  We attempt to boil down the resource to something 
  # relatively consumable by application developers.
  class Resource
    attr_reader :name, :type, :uri_string, :label, :description, :creation_date, :properties, :resources
    
    # Take a Nokogiri::XML object of a 
    def initialize(soap)
      return unless soap.respond_to?(:search)
      
      @name = soap['name']
      @type = soap['wsType']
      @uri_string = soap['uriString']
      @label = soap.search('./label/node()').inner_text
      @description = soap.search('./description/node()').inner_text
      @creation_date = soap.search('./creation_date/node()').inner_text
      
      initialize_properties soap.search('./resourceProperty')
      initialize_resources soap.search('./resourceDescriptor')
    end
    
    private 
    
    # extract all <resourceProperty> tags from the resource and turn them
    # into a hash in @properties.
    def initialize_properties(properties)
      @properties = Hash.new
      properties.each do |prop|
        @properties[prop['name']] = prop.inner_text.strip
      end
    end
    
    # extract all <resourceDescriptor> tags and turn them into Resource objects.
    def initialize_resources(resources)
      @resources = []
      resources.each do |res|
        @resources << Resource.new(res)
      end
    end
  end
  
  # A crack at a Jasper Server client for the repository service.
  #
  # This client sits on top of several common Ruby APIs including
  # the Savon SOAP API, XmlBuilder, and nokogiri.
  class RepositoryService < ::Savon::Client
  
    # Set this to true if you'd like to have Savon log to stderr
    ::Savon::Request.log = false;
    
    # Request XML is built using the Request.
    #
    # A request looks like:
    #
    # <?xml version="1.0" encoding="utf-8"?>
    # <soapenv:Envelope 
    #     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
    #     xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
    #     xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" 
    #     xmlns:axis="http://axis2.ws.jasperserver.jaspersoft.com">
    #   <soapenv:Body>
    #     <axis:list soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
    #       <requestXmlString xsi:type="xsd:string">
    #       <![CDATA[
    #          <request operationName="list"> 
    #            <argument name="LIST_RESOURCES"/> 
    #            <argument name="RESOURCE_TYPE">reportUnit</argument> 
    #            <argument name="START_FROM_DIRECTORY">/Reports/xforty</argument> 
    #         </request>
    #         ]]>
    #       </requestXmlString>
    #      </axis:list>
    #   </soapenv:Body>
    # </soapenv:Envelope>
    #
    # The soap envelope, body, and action (in this case axis:list) elements
    # are automatically constructed by Savon.  The requestXmlString element and 
    # sub elements are created by the build() method.  This method yields a builder
    # that is expected to create the contents of the request element (the arugment 
    # tags in this case).
    class Request
      attr_reader :name
      
      ##
      # :method: list
      #
      #
      # Retrive a list

      ##
      # :method: get
      #

      ##
      # :method: runReport    

      # Create a new Request.  The name passed is the
      # request name (eg list, get, runReport).
      def initialize(name)
        @name = name
      end
    
      # Takes a block which is yielded with an XML builder
      # that represents the internal XML inside the <request>
      # tags in the request.
      def build(&block)
        inner_xml = Builder::XmlMarkup.new :indent => 2
        inner_xml.request 'operationName' => soap_method do |request|
          yield request
        end
      
        body = Builder::XmlMarkup.new :indent => 2
        body.requestXmlString { |request_string| request_string.cdata! inner_xml.target! }
      end
    
      # Returns the soap method name for this request.  
      def soap_method
        self.name.to_s.underscore
      end
    end

    # A response subclass exists for each type of response.  There is a response type for
    # each type of request (list, get, runReport).  Code common to all response types is
    # put into the Response class, otherwise responses are named CamelizedRequestNameResponse.
    # So for example ListResponse, GetResponse, RunReportResponse.
    class Response
      attr_reader :xml_doc, :resources
    
      # "0" if the request was successfully processed by the server.
      def return_code
        xml_doc.search('//returnCode').inner_text
      end
    
      # return true if the response is successful.
      def success?
        "0" == return_code
      end
    
      # return "OK" on success, since successful responses don't seem to have
      # messages.  When the response is not successful, the message is pulled
      # from the response xml.
      def message
        if success?
          "OK"
        else
          xml_doc.search('//returnMessage/node()').inner_text
        end
      end
      
      # Search the response using xpath.  When this Responses xml_doc
      # does not have a search method, a string with inner_text and inner_html
      # methods are added.  The reson for this is so unwitting callers
      # won't need to have the extra logic to make sure that that this response
      # has a valid xml_doc.
      def search(path)
        return xml_doc.search(path) if xml_doc.respond_to?(:search)
      
        # return something that acts like a dom element (nokogiri)
        x = ""
        class << x
          def inner_text; ""; end
          alias inner_html inner_text
        end
        x
      end
      
      # Extract resourceDescriptors from the response and drop them into @resources.
      def collect_resources
        @resources = @xml_doc.search('./operationResult/resourceDescriptor').map { |r| Resource.new(r) }
      end
      
      # Response from a list request.
      class ListResponse < Response
        include Enumerable
        # Initialize the list response from a Savon response.  The listReturn element is 
        # pulled from the response, and each resourceDescriptor child of that element is
        # collected into a list as each item in the list.
        def initialize(savon_response)
          soap_doc = Nokogiri::XML savon_response.to_xml
          @xml_doc = Nokogiri::XML soap_doc.search('//listReturn/node()').inner_text
          collect_resources
        end
      
        # Get a list of items from the list response.  Each of the items in the list
        # returned is a JasperClient::Resource.
        def items
          resources
        end
        
        def each(&blk); @resources.each(&blk); end
      end
    
      # Response from a get request.
      class GetResponse < Response
        # Initialize the list response from a Savon response.  The getReturn element is
        # pulled from the response, and each resourceDescriptor is processed into info about
        # the resource involved.
        def initialize(savon_response)
          savon_response.tap do |soap|
            soap_doc = Nokogiri::XML soap.to_xml
            @xml_doc = Nokogiri::XML soap_doc.search('//getReturn/node()').inner_text
            collect_resources
          end
        end
      end
    
      # Response from a runReport request.
      class RunReportResponse < Response
        attr_reader :http
        def initialize(savon_response)
          savon_response.tap do |soap|
            @http = soap.http
            xml = http.multipart? ? http.start_part : soap.http.body # soap.to_hash.fetch(:run_report_response).fetch(:run_report_return)
            soap_doc = Nokogiri::XML xml
            @xml_doc = Nokogiri::XML soap_doc.search('//runReportReturn/node()').inner_text
          end
        end
        
        # return the multipart related parts from the http response.
        # When the response is not multipart, an empty list is returned.
        def parts
          http.multipart? ? http.parts : []
        end
      end
    end
  
    attr_reader :wsdl_url, :username, :password
  
    # Initialize the JapserClient with a URL (points to the
    # repository service), a username, and a password.
    def initialize(wsdl_url, username, password)
      @wsdl_url = wsdl_url.to_s
      @username = username.to_s
      @password = password.to_s
      
      super @wsdl_url
      request.basic_auth @username, @password
    end
  
    # return true if name indicates a supported request.
    def supported_request?(name)
      [:get, :list, :run_report].include? name.to_sym
    end
  
    # Essentially a proxy to method_missing for Savon.  If the method call is
    # to a known request type, build XML with a request object and then 
    # execute the Savon request.
    def method_missing(name, *params, &block)
      if supported_request?(name)
        req = Request.new(name)
        request_xml = req.build(&block)
      
        savon_response = super(name) { |soap| soap.body = request_xml.to_s }
        response_class = Response.const_get "%sResponse" % [ name.to_s.humpify.to_sym ]
        response_class.new savon_response
      else
        super(name, params)
      end
    end
  end
end