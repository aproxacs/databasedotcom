require 'spec_helper'
require 'databasedotcom'
require 'rack/test'

describe Databasedotcom::OAuth2::WebServerFlow do
  include Rack::Test::Methods
  let(:blank_app){ lambda{|env| [200, {}, [@body]]} }
  let(:endpoints) { 
    {
      "login.salesforce.com" => {:key => "login_endpoint_key", :secret => "login_endpoint_secret"},
      "test.salesforce.com"  => {:key => "test_endpoint_key", :secret => "test_endpoint_secret"}
    } 
  }
  let(:token_encryption_key) { "9rg/hsK8ZSi+jc8R40ruJQ==" }
  let(:app_options) { {} }
  let(:app) { Databasedotcom::OAuth2::WebServerFlow.new(blank_app, app_options.merge(endpoints: endpoints, token_encryption_key: token_encryption_key)) }
  
  describe "initialization" do    
    context "failure case" do
      it "fails if endpoint is not present" do
        expect { Databasedotcom::OAuth2::WebServerFlow.new(blank_app) }.to raise_error(RuntimeError)
      end
      it "fails when endpoints are not hash" do
        expect { Databasedotcom::OAuth2::WebServerFlow.new(blank_app,  endpoints: "endpoint") }.to raise_error(RuntimeError)
      end

      it "fails when token_encryption_key is not present" do
        expect { Databasedotcom::OAuth2::WebServerFlow.new(blank_app,  endpoints: endpoints) }.to raise_error(RuntimeError)
      end
      it "fails when token_encryption_key is invalid" do
        expect { Databasedotcom::OAuth2::WebServerFlow.new(blank_app,  endpoints: endpoints, token_encryption_key: "invalid") }.to raise_error(RuntimeError)
      end      
    end
    
    context "default values" do
      it "path_prefix is '/auth/salesforce" do
        app.path_prefix.should == "/auth/salesforce"
      end
    end
  end
  
  describe "authorize call" do
    it "intercepts request" do
      blank_app.should_not_receive(:call)
      get '/auth/salesforce'
    end
    
    def redirect_uri
      Addressable::URI.parse(last_response.location)
    end
    
    context "when using default endpoint" do
      before(:each) do
        get '/auth/salesforce'
      end
      
      it "redirects to the authorize path of default endpoint" do
        last_response.should be_redirect
        
        redirect_uri.host.should == "login.salesforce.com"
        redirect_uri.path.should == "/services/oauth2/authorize"
      end
      
      context "redirect url" do
        it "includes client_id of default endpoint" do
          redirect_uri.query_values["client_id"].should == "login_endpoint_key"
        end
        
        it "includes state which has endpoint" do
          redirect_uri.query_values["state"].should == "/?endpoint=login.salesforce.com"
        end
        
        it "includes redirect_uri which has callback path" do
          redirect_uri.query_values["redirect_uri"].should == "http://example.org/auth/salesforce/callback"
        end
      end
    end

    
    context "when mydomain is set from params" do
      it "redirects to mydomain" do
        get '/auth/salesforce', mydomain: "forceuser"

        redirect_uri.host.should == "forceuser.my.salesforce.com"
      end
    end
    
    context "when state is set from params" do
      it "endpoint is added to state" do
        get '/auth/salesforce', state: "/?user_name=tom"

        redirect_uri.query_values["state"].should == "/?endpoint=login.salesforce.com&user_name=tom"
      end
    end
    
    context "when endpoint is test.salesforce.com" do
      let(:endpoint) { "test.salesforce.com" }
      
      before(:each) do
        get '/auth/salesforce', endpoint: endpoint
      end
      
      it "redirects to test endpoint" do
        redirect_uri.host.should == "test.salesforce.com"
      end
      
      context "redirect url" do
        it "includes client_id of default endpoint" do
          redirect_uri.query_values["client_id"].should == "test_endpoint_key"
        end
        
        it "includes state which has endpoint" do
          redirect_uri.query_values["state"].should == "/?endpoint=test.salesforce.com"
        end        
      end
    end
  end
  
  
  
  describe ".client_from_oauth_token" do
    let(:token) { "acess_token" }
    let(:ref_token) { "refresh_token" }
    let(:instance_url) { "http://host.instance/url" }
    let(:org_id) { "org_id" }
    let(:user_id) { "user_id" }
    let(:token_id) { "/id/#{org_id}/#{user_id}"}
    let(:access_token) { OAuth2::AccessToken.new(nil, token, refresh_token: ref_token, "id" => token_id, "instance_url" => instance_url) }

    let(:client) { Databasedotcom::OAuth2::WebServerFlow.client_from_oauth_token(access_token) }
    it "returns authorized client" do
      client.org_id.should == org_id
      client.user_id.should == user_id
      client.instance_url.should == instance_url
      client.host.should == "host.instance"
      client.oauth_token.should == token
      client.refresh_token.should == ref_token
    end
  end

  describe ".parse_domain" do
    it "parses host from url" do
      url = "http://my.domain/some/path"
      host = Databasedotcom::OAuth2::WebServerFlow.parse_domain(url)
      host.should == "my.domain"
    end

    it "parses host if url starts with https" do
      url = "https://my.domain/some/path"
      host = Databasedotcom::OAuth2::WebServerFlow.parse_domain(url)
      host.should == "my.domain"
    end

    it "parses host if url omits http" do
      url = "my.domain/some/path"
      host = Databasedotcom::OAuth2::WebServerFlow.parse_domain(url)
      host.should == "my.domain"
    end

    it "returns nil if url is invalid" do
      url = "/invalid/url"
      host = Databasedotcom::OAuth2::WebServerFlow.parse_domain(url)
      host.should == nil
    end

    it "returns nil if url is empty string" do
      url = ""
      host = Databasedotcom::OAuth2::WebServerFlow.parse_domain(url)
      host.should == nil
    end
  end
end
