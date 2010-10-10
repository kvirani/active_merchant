module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # Bogus Gateway
    class SmartBogusGateway < BogusGateway
      AUTHORIZATION = '53433'
      
      SUCCESS_MESSAGE = "Bogus Gateway: Forced success"
      FAILURE_MESSAGE = "Bogus Gateway: Forced failure"
      ERROR_MESSAGE = "Bogus Gateway: Use CreditCard number 1 for success, 2 for exception and anything else for error"
      CREDIT_ERROR_MESSAGE = "Bogus Gateway: Use trans_id 1 for success, 2 for exception and anything else for error"
      UNSTORE_ERROR_MESSAGE = "Bogus Gateway: Use trans_id 1 for success, 2 for exception and anything else for error"
      CAPTURE_ERROR_MESSAGE = "Bogus Gateway: Use authorization number 1 for exception, 2 for error and anything else for success"
      VOID_ERROR_MESSAGE = "Bogus Gateway: Use authorization number 1 for exception, 2 for error and anything else for success"
      
      self.supported_countries = ['US']
      self.supported_cardtypes = [:bogus]
      self.homepage_url = 'http://example.com'
      self.display_name = 'SmartBogus'
      
      def authorize(money, creditcard, options = {})
        if creditcard.is_a?(String) || creditcard.is_a?(Integer)
          money = amount(money)
          Response.new(true, SUCCESS_MESSAGE, {:authorized_amount => money}, :test => true, :authorization => AUTHORIZATION )
        else
          super(money, creditcard, options)
        end
      end
  
      def purchase(money, creditcard, options = {})
        if creditcard.is_a?(String) || creditcard.is_a?(Integer)
          money = amount(money)
          Response.new(true, SUCCESS_MESSAGE, {:authorized_amount => money}, :test => true, :authorization => AUTHORIZATION )
        else
          super(money, creditcard, options)
        end
      end
 
    end
  end
end
