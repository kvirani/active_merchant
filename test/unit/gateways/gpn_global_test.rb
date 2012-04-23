require 'test_helper'

class GpnGlobalTest < Test::Unit::TestCase
  def setup
    @gateway = GpnGlobalGateway.new(
                 :login    => 'login',
                 :password => 'password',
                 :key      => 'key'
               )

    @credit_card = credit_card
    @amount = 100
    
    @options = { 
      :trans_id => '1123',
      :description => 'Store Purchase',
      
      :first_name => 'John',
      :last_name => 'Doe',
      :email => 'jd@span6.com',
      
      :billing_address => address,
      :address => address, # shipping address
      
      :ip => '127.0.0.1',
      :id => 'customer-id',
      
      :statement => 'STATEMENT ON BILL' # REQUIRED BY GPN

    }
  end
  
  def test_successful_auth
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    #assert_instance_of 
    assert_success response
    
    # Replace with authorization number from the successful response
    assert_equal '5678', response.authorization
    assert response.test?
  end

  def test_unsuccessful_auth
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  private
  
  # Place raw successful response from gateway here
  def successful_purchase_response
    <<-XML
<?xml version="1.0" encoding="utf-8" ?>
<transaction>
  <result>SUCCESS</result>
  <merchanttransid>1234</merchanttransid>
  <GPNtransid>5678</GPNtransid>
  <errorcode>000</errorcode>
  <errormsg></errormsg>
  <description></description>
</transaction>
    XML
  end
  
  # Place raw failed response from gateway here
  def failed_purchase_response
        <<-XML
    <?xml version="1.0" encoding="utf-8" ?>
    <transaction>
      <result>DECLINED</result>
      <merchanttransid>1234</merchanttransid>
      <GPNtransid></GPNtransid>
      <errorcode>123</errorcode>
      <errormsg>Declined</errormsg>
      <description>Insufficient Funds</description>
    </transaction>
        XML

  end
end
