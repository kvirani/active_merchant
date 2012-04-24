module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class GpnGlobalGateway < Gateway
      TEST_URL = 'https://txtest.txpmnts.com/api/transaction/'
      LIVE_URL = 'https://txpmnts.com/api/transaction/'
      
      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']
      self.ssl_strict = false # otherwise tests fail. Not sure how to have this set JUST for test URL.
      
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      
      # The homepage URL of the gateway
      self.homepage_url = 'http://www.example.net/'
      
      # The name of the gateway
      self.display_name = 'GPN Global Gateway'
      
      def initialize(options = {})
        requires!(options, :login, :password, :key)
        @options = options
        super
      end  
      
      # options: trans_id
      # 
      def authorize(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard) if creditcard        
        add_address(post, creditcard, options[:billing_address]) if options[:billing_address]
        add_customer_data(post, options)
        
        commit(700, money, post)
      end
      
      # def purchase(money, creditcard, options = {})
      #   post = {}
      #   add_invoice(post, options)
      #   add_creditcard(post, creditcard)        
      #   add_address(post, creditcard, options)   
      #   add_customer_data(post, options)
      #        
      #   commit('sale', money, post)
      # end                       
      #     
      def capture(money, authorization, options = {})
        commit('capture', money, post)
      end
      
      def test?
        @options[:test] || Base.gateway_mode == :test || super
      end
    
      private                       
      
      # <customer> information, with shipping address
      def add_customer_data(post, options)
        a = options[:address] || {} # shipping address
        
        phone = get_phone_number(a[:phone])
        
        c = {
          :firstname => options[:first_name],
          :lastname  => options[:last_name],
          :email     => options[:email],
          :zippostal => a[:zip],
          :city      => a[:city],
          :address1  => a[:address1],
          :address2  => nil,
          :stateregioniso => iso_code_for(a[:state]),
          :countryiso => iso_code_for(a[:country]),
          
          :phone1phone => phone[:number],
          :phone1country => phone[:country],
          :phone1area => phone[:area],
          
          :phone2phone => nil,
          :phone2country => nil,
          :phone2area => nil,
          
          :birthday => options[:birth_day] || 01,
          :birthmonth => options[:birth_month] || 01,
          :birthyear => options[:birth_year] || 1980,
          :ipaddress => options[:ip],
          :accountid => options[:id]
        }

        post[:customer] = c
        post
      end

      # <creditcard> billing address
      def add_address(post, creditcard, options)
        post[:creditcard] ||= {}
        
        phone = get_phone_number(options[:phone])
        
        a = {
          :billingzippostal => options[:zip],
          :billingcity      => options[:city],
          :billingaddress1  => options[:address1],
          :billingaddress2  => nil,
          :billingstateregioniso => iso_code_for(options[:state]),
          :billingcountryiso => iso_code_for(options[:country]),
          :billingphone1phone => phone[:number],
          :billingphone1country => phone[:country],
          :billingphone1area => phone[:area],
        }
        post[:creditcard].merge!(a)
        post
      end

      # <transaction> information
      def add_invoice(post, options)
        post[:transaction] ||= {}
        post[:transaction][:merchanttransid] = options[:trans_id]
        post[:transaction][:curcode] = options[:curcode] || "USD"
        post[:transaction][:description] = options[:description]
        post[:transaction][:statement] = options[:statement]
        
        # This gateway is terrible - even empty attributes need to have their elements present - jeebus!! - KV
        post[:transaction][:merchantspecific1] = nil
        post[:transaction][:merchantspecific2] = nil
        post[:transaction][:merchantspecific3] = nil
        post
      end
      
      # <creditcard> information
      def add_creditcard(post, creditcard)      
        post[:creditcard] ||= {}
        post[:creditcard][:ccnumber]   = creditcard.number
        post[:creditcard][:cccvv]  = creditcard.verification_value if creditcard.verification_value?
        post[:creditcard][:expmonth]   = sprintf("%.2i", creditcard.month)        
        post[:creditcard][:expyear]    = sprintf("%.4i", creditcard.year)
        post[:creditcard][:nameoncard] = creditcard.first_name + " " + creditcard.last_name

        post
      end
      
      def parse(body)
        response = {}
        xml = REXML::Document.new(body)
        root = REXML::XPath.first(xml, "//transaction")
        if root
          response = parse_element(root).with_indifferent_access
        end

        response[:transaction_id] = response.delete :gp_ntransid # rename weird key name (FIXME: don't need to do this anymore I don't think - KV)
        response
      end
      
      def commit(action, money, parameters)
        parameters[:amount] = amount(money)

        url = test? ? TEST_URL : LIVE_URL
        data = ssl_post url, post_data(action, parameters)

        response = parse(data)
        
        message = message_from(response)

        Response.new(success?(response), message, response, 
          :test => test?, 
          :authorization => response[:transref], # transaction_id is nil
          :fraud_review => fraud_review?(response),
          :avs_result => nil,
          :cvv_result => nil
        )
      end
      
      def post_data(action, parameters = {})
        xml = Builder::XmlMarkup.new(:indent => 2)
        xml.instruct!(:xml, :version => '1.0', :encoding => 'utf-8')
        xml.tag!("transaction") do
          xml.tag!("apiUser", @options[:login])
          xml.tag!("apiPassword", @options[:password])
          xml.tag!("apiCmd", action)
          build_transaction(xml, parameters) if parameters[:transaction]
          build_customer(xml, parameters) if parameters[:customer]
          build_creditcard(xml, parameters) if parameters[:creditcard]
          xml.tag!("checksum", generate_checksum(action, parameters))
        end
        
        request = "strrequest=#{CGI.escape(xml.target!)}"

        request
      end

      def build_creditcard(xml, parameters)
        xml.tag!("creditcard") do 
          parameters[:creditcard].each do |k, v|
            xml.tag!(k.to_s, v)
          end
        end
      end
      
      def build_customer(xml, parameters)
        xml.tag!("customer") do 
          parameters[:customer].each do |k, v|
            xml.tag!(k.to_s, v)
          end
        end
      end
      
      def build_transaction(xml, parameters)
        xml.tag!("transaction") do 
          parameters[:transaction].each do |k, v|
            xml.tag!(k.to_s, v)
          end
          xml.tag!('amount', parameters[:amount])
        end
      end
      
      def generate_checksum(action, parameters)
        key = @options[:key]
        s = [
          @options[:login].to_s,
          @options[:password].to_s,
          action.to_s,
          nested_key(parameters[:transaction], :merchanttransid).to_s,
          parameters[:amount].to_s,
          nested_key(parameters[:transaction], :curcode).to_s,
          nested_key(parameters[:creditcard], :ccnumber).to_s,
          nested_key(parameters[:creditcard], :cccvv).to_s,
          nested_key(parameters[:creditcard], :nameoncard).to_s,
          key
        ].join

        Digest::SHA1.hexdigest s
      end
      
      def message_from(response)
        s = response[:result]
        s << ": #{response[:description]}" if response[:description]
        s << " (#{response[:errormessage]})" if response[:errormessage]
        s
      end
      
      def fraud_review?(response)
        false
      end

      def success?(response)
        response[:result] == "SUCCESS" # Ignore PENDING workflow, for now.
      end
      
      # convenience method for generate_checksum
      def nested_key(hash, key)
        hash[key] if hash
      end
      
      def parse_element(node)
        if node.has_elements?
          response = {}
          node.elements.each{ |e|
            key = e.name.underscore
            value = parse_element(e)
            if response.has_key?(key)
              if response[key].is_a?(Array)
                response[key].push(value)
              else
                response[key] = [response[key], value]
              end
            else
              response[key] = parse_element(e) 
            end 
          }
        else
          response = node.text
        end

        response
      end
      
      def iso_code_for(s)
        case s
        when 'CA'
          'CAN'
        when 'US'
          'USA'
        else
          s
        end
      end
      
      def get_phone_number(phone)
        phone = phone.to_s.gsub(/\D/, '')[1..-1]
        if phone 
          phone = {
            :number => phone.last(7),
            :area => phone.first(3),
            :country => '1',
          }
        else 
          phone = {
            :number => '0001111',
            :area => '0',
            :country => '1',
          }
        end
      end
      
    end
  end
end

