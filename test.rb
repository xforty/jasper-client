#!/usr/bin/env ruby

require 'rubygems'
require 'jasper_client'

wsdl = 'http://127.0.0.1:8080/jasperserver/services/repository?wsdl'
user = 'jasperadmin'
pass = user

client = JasperClient.new(wsdl, user, pass)

response = client.list :LIST_RESOURCES => true, 
  :RESOURCE_TYPE => 'reportUnit', 
  :START_FROM_DIRECTORY => '/reports/xforty'
  

puts "Return code: %s" % [ response.return_code ]

p response.items.map { |i| i.ws_type }


# puts response.xml_doc.to_xml