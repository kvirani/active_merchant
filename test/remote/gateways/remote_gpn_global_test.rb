require 'test_helper'

class RemoteGpnGlobalTest < Test::Unit::TestCase
  

  def setup
    @gateway = GpnGlobalGateway.new(fixtures(:gpn_global))
    
    @amount = 100
    @credit_card = credit_card('4000100011112224')
    @declined_card = credit_card('4000300011112220', :verification_value => '501')
    
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
  
  def test_successful_authorization
    sleep 1 # to make sure the ids are unique (since they are based on Time.now)
    @options[:trans_id] = Time.now.to_i # otherwise we'll get a dupe error
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_unsuccessful_authorization
    sleep 1 # to make sure the ids are unique (since they are based on Time.now)
    @options[:trans_id] = Time.now.to_i # otherwise we'll get a dupe error
    assert response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'DECLINED: Test declined', response.message
  end

  # def test_authorize_and_capture
  #   amount = @amount
  #   assert auth = @gateway.authorize(amount, @credit_card, @options)
  #   assert_success auth
  #   assert_equal 'Success', auth.message
  #   assert auth.authorization
  #   assert capture = @gateway.capture(amount, auth.authorization)
  #   assert_success capture
  # end
  # 
  # def test_failed_capture
  #   assert response = @gateway.capture(@amount, '')
  #   assert_failure response
  #   assert_equal 'REPLACE WITH GATEWAY FAILURE MESSAGE', response.message
  # end

  # def test_invalid_login
  #   gateway = GpnGlobalGateway.new(
  #               :login => '',
  #               :password => ''
  #             )
  #   assert response = gateway.purchase(@amount, @credit_card, @options)
  #   assert_failure response
  #   assert_equal 'REPLACE WITH FAILURE MESSAGE', response.message
  # end
end
