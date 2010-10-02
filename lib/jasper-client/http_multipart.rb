require 'net/http'

# A mixin to add basic RFC 2387 MIME Multipart/Related
# response support. 
#
# A multipart http response has several sections which are
# intended to be treated as indpendent objects.  The
# Multipart/Related response is used when all of the objects
# are related to one another.  Typcially multipart is used
# to have alternative versions of the same content. This is
# not the case with multipart related.
#
# This mixen was written while using the Savon SOAP API, but 
# it's intended to be mixed in to Net::HTTP and does not have
# any known dependencies on Savon.
#
# http://www.faqs.org/rfcs/rfc2387.html
module HTTPMultipart
  
    # An RFC2387 multipart part.  
    #
    # http://www.faqs.org/rfcs/rfc2387.html
    class Part
      # This makes headers for each part have the same interface
      # as they do on Net::HTTPResponse.
      include ::Net::HTTPHeader
      
      attr_reader :body
      # Initialize this response part.
      def initialize(part_str) 
        h,b = part_str.split("\r\n\r\n", 2)
        initialize_http_header Hash[ *h.split("\r\n").map { |hdr| hdr.split(/:\s*/, 2) }.flatten ]
        @body = b
      end
      
      # Content type supertype (for text/html, this would be 'text')
      def content_supertype
        content_type.split('/')[0]
      end
      
      # Content type subtype.  (for text/html, this woudl be 'html')
      def content_subtype
        content_type.split('/')[1]
      end
      
      # The suggested filename is the content_id witout the surrounding <> characters.
      # the extension is derived from the mime-subtype.  
      def suggested_filename
        "%s.%s" % [ content_id.first.gsub(/<|>/, ''), content_subtype ]
      end
      
      # get the content id.  Each part has a content-id  It's typical to use this as a basis
      # for a fhile name.
      def content_id
        to_hash.fetch('content-id')
      end
      
      # Write the content from this part to a file having name.
      def write_to_file(name = :internal)
        name = suggested_filename if :internal == name
        
        open(name, 'w') do |fh|
          fh.write self.body
        end
      end
    end

    # Am I multipart?
    def multipart?
      %w{multipart/related}.include? content_type
    end
    
    # Fetch the multipart boundary.
    def multipart_boundary
      content_type_fields['boundary']
    end
    
    # The ID of the "start part" or initial part of the multipart related
    # response.  
    def start
      content_type_fields['start']
    end
    
    # Return the start part.
    def start_part
      parts.select { |p| p.content_id.first == start }.first.body
    end
    
    # return an array of parts.
    def parts
        pts = body.split("--%s" % [ multipart_boundary ])
        pts.shift
        pts.reject { |part| part == "--\r\n" }.map { |part| Part.new(part) }
    end
    
    # Iterate through each part calling the block.
    # A Part is yielded to the block.
    def each_part(&block)
      if multipart?
        parts.each do |part|
          yield part
        end
      else
        yield self
      end
    end

    private
    
    # Digest a content type header value into it's component parts.
    # When we've got a multipart response, there are a few fields in the 
    # content-type header like the boundary, start content id, etc.  For
    # more info on this see RFC 2387 The MIME Multipart/Related content-type
    def content_type_fields
      headers_split = to_hash.fetch('content-type').first.split(/\s*;\s*/)
      headers_split.shift # skip first element which is the mime type and subtype (text/xml or the like)
      Hash[ *headers_split.map { |pair| 
        
        # The regex below is intended match things like charset="utf-8" and charset=utf-8.
        matches = pair.match(/^(.*?)=(?:"(.*)"|(.*))$/)
        matches[1,2] if matches
      }.flatten ]
    end
end

class Net::HTTPResponse
  include HTTPMultipart
end

class Net::HTTPOK
  include HTTPMultipart
end
