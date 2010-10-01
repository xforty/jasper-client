require 'helper'

class TestJasperClient < Test::Unit::TestCase
  def setup_connection
    wsdl = 'http://127.0.0.1:8080/jasperserver/services/repository?wsdl'
    user = 'jasperadmin'
    pass = user
    JasperClient::RepositoryService.new(wsdl, user, pass)    
  end
  
  def bad_connection
    wsdl = 'http://127.0.0.1:8081/jasperserver/services/repository?wsdl'
    user = 'jasperadmin'
    pass = user
    JasperClient::RepositoryService.new(wsdl, user, pass)
  end
  
  should "respond to list requests" do 
    client = setup_connection
    response = client.list do |request|
      request.argument :name => "LIST_RESOURCES"
      request.argument 'reportUnit', :name => "RESOURCE_TYPE"
      request.argument '/Reports/xforty', :name => 'START_FROM_DIRECTORY'
    end

    assert(response.return_code == "0")
  end
  
  should "respond to get requests" do
    client = setup_connection
    response = client.get do |req|
      req.resourceDescriptor :name => 'jrlogo', :wsType => 'img', :uriString => '/Reports/xforty/user_list', :isNew => 'false'
    end
    assert(response.return_code == "0")
  end

  should "respond to runReport requests" do
    client = setup_connection
    response = client.run_report do |req|
      req.argument 'HTML', :name => 'RUN_OUTPUT_FORMAT'
  
      req.resourceDescriptor :name => 'JRLogo', 
        :wsType => 'img', 
        :uriString => '/reports/xforty/user_list', 
        :isNew => 'false'
    end
    assert(response.return_code == "0")
    assert(response.parts.count > 0)
  end

  should "should detect bad connection" do
    assert_raise(Errno::ECONNREFUSED) do 
      client = bad_connection
      response = client.run_report do |req|
        req.argument 'HTML', :name => 'RUN_OUTPUT_FORMAT'
  
        req.resourceDescriptor :name => 'JRLogo', 
          :wsType => 'img', 
          :uriString => '/reports/xforty/user_list', 
          :isNew => 'false'
      end
    end
  end
end