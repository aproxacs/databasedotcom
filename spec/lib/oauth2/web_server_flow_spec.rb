require 'spec_helper'
require 'databasedotcom'
require 'rack/test'

describe Databasedotcom::OAuth2::WebServerFlow do
  include Rack::Test::Methods

  let(:client_key) { Databasedotcom::OAuth2::CLIENT_KEY }
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

      it "xxx_override is false" do
        app.display_override.should == false
        app.immediate_override.should == false
        app.prompt_override.should == false
        app.scope_override.should == false
      end

      it "api_version is '25.0'" do
        app.api_version.should == "25.0"
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
        get '/auth/salesforce', state: "/resource?user_name=tom"

        redirect_uri.query_values["state"].should == "/resource?endpoint=login.salesforce.com&user_name=tom"
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

    context "with optional configurations" do
      let(:app_options) {
        {
          :display   => "touch"        ,
          :immediate => true           ,
          :prompt    => "login consent",
          :scope     => "full"
        }
      }
      it "sets optional configurations to redirect uri's query" do
        get '/auth/salesforce'

        redirect_uri.query_values["display"].should == "touch"
        redirect_uri.query_values["immediate"].should == "true"
        redirect_uri.query_values["prompt"].should == "login consent"
        redirect_uri.query_values["scope"].should == "full"
      end
    end
  end


  describe "callback call" do
    let(:code) { "aPrxaSyVmC8fBbcC1ICrxChWKeijMiaEmBJI9ffNRd2A9PK59xdg8NBAk4s7qY2NODiFo5jrBg==" }
    let(:state) { "/?endpoint=login.salesforce.com" }
    let(:callback_params) { {code: code, state: state} }
    let(:refresh_token) { "5Aep8617VFpoP.M.4shLYDVt1xSb.pe3AybT2avEVqEGfjK7oLQv_E5Vkx0UEN7r23RtP.DIgLmKA==" }
    let(:access_token) { "00D90000000gMbi!AQQAQNOFj9qi9ahV9xwx0lqg4dzlDvED7f2EFsuTMU6cgAuia3uhkNPJD3P18b4FG_fE9Qf8hiW7_gJB3wUDyPx8Gh1FJNua" }
    let(:org_id) { "org_id" }
    let(:user_id) { "user_id" }
    let(:instance_url) { "https://ap1.salesforce.com" }
    let(:token_body) {
      {
        "id"=>"https://login.salesforce.com/id/#{org_id}/#{user_id}",
        "issued_at"=>"1345695997104", "scope"=>"id api refresh_token",
        "instance_url"=> instance_url,
        "refresh_token"=> refresh_token,
        "signature"=>"L9DbTRS248+MT2AYG7LK96BrRWCYkT+cw0UlqVJ1WMQ=",
        "access_token" => access_token
      }.to_json
    }
    before(:each) do
      stub_request(:post, "https://login.salesforce.com/services/oauth2/token").
        to_return(:status => 200, :body => token_body, :headers => {'Content-Type' => "application/json"})
    end

    def redirect_uri
      Addressable::URI.parse(last_response.location)
    end


    it "intercepts request" do
      blank_app.should_not_receive(:call)

      get '/auth/salesforce/callback', callback_params
    end

    context "in case of error" do
      let(:callback_params) { {error: "error", error_description: "some error"} }

      it "redirects to failure path" do
        app.class.stub(:_log_exception) # to avoid runtime error message to be displayed.
        get '/auth/salesforce/callback', callback_params

        last_response.should be_redirect
        redirect_uri.path.should == "/auth/salesforce/failure"
      end
    end

    context "when using login endpoint" do
      let(:state) { "/?endpoint=login.salesforce.com" }

      it "redirects to state path with endpoint removed" do
        get '/auth/salesforce/callback', callback_params

        last_response.should be_redirect
        redirect_uri.path.should == "/"
      end

      it "saves client to session" do
        get '/auth/salesforce/callback', callback_params

        last_request.session[client_key].should_not be_nil
      end

      context "about client" do
        let(:client) { Marshal.load(Gibberish::AES.new(token_encryption_key).decrypt(last_request.session[client_key]))  }
        before(:each) do
          get '/auth/salesforce/callback', callback_params
        end

        it "endpoint is login" do
          client.endpoint.to_s.should == "login.salesforce.com"
        end

        it "has oauth_token" do
          client.oauth_token.should == access_token
        end

        it "has refresh_token" do
          client.refresh_token.should == refresh_token
        end

        it "has instance_url" do
          client.instance_url.should == instance_url
        end

        it "has org_id" do
          client.org_id.should == org_id
        end

        it "has user_id" do
          client.user_id.should == user_id
        end

        it "does not have client_id" do
          client.client_id.should be_nil
        end

        it "does not have client_secret" do
          client.client_secret.should be_nil
        end
      end

    end

    context "when using test endpoint" do
      let(:state) { "/?endpoint=test.salesforce.com" }
      let(:client) { Marshal.load(Gibberish::AES.new(token_encryption_key).decrypt(last_request.session[client_key]))  }
      before(:each) do
        stub_request(:post, "https://test.salesforce.com/services/oauth2/token").
          to_return(:status => 200, :body => token_body, :headers => {'Content-Type' => "application/json"})


        get '/auth/salesforce/callback', callback_params
      end

      it "endpoint is test"  do
        client.endpoint.to_s.should == "test.salesforce.com"
      end
    end
  end


  describe "normal call" do
    class BlankApp
      attr_reader :saved_client
      def call(env)
        client = env["databasedotcom.client"]
        @saved_client = client.dup
        client.username = "sales king"
        [200, {}, [@body]]
      end
    end
    let(:blank_app){ BlankApp.new }
    let(:client) { Databasedotcom::Client.new }
    let(:client_dump_str) { Gibberish::AES.new(token_encryption_key).encrypt(Marshal.dump(client)) }

    before(:each) do
      client.endpoint = "login.salesforce.com"
    end

    it "blank_app is called" do
      blank_app.should_receive(:call).and_return([200, {}, [@body]])

      get '/resources'
    end

    it "client is retrived for blank_app" do
      get '/resources', {}, "rack.session" => {"databasedotcom.client" => client_dump_str}

      blank_app.saved_client.should be_instance_of(Databasedotcom::Client)
    end

    context "about retrieved client" do
      let(:retrieved_client) { blank_app.saved_client }

      before(:each) do
        get '/resources', {}, "rack.session" => {"databasedotcom.client" => client_dump_str}
      end

      it "has client_id" do
        retrieved_client.client_id.should == "login_endpoint_key"
      end
      it "has client_secret" do
        retrieved_client.client_secret.should == "login_endpoint_secret"
      end
      it "has endpoint" do
        retrieved_client.endpoint.should == "login.salesforce.com"
      end
    end

    it "saves changed client" do
       get '/resources', {}, "rack.session" => {"databasedotcom.client" => client_dump_str}

       new_client = Marshal.load(Gibberish::AES.new(token_encryption_key).decrypt(last_request.session[client_key]))
       new_client.username.should == "sales king"
    end

    context "when client is logged out" do
      class LogoutApp
        def call(env)
          client = env["databasedotcom.client"]
          client.logout
          [200, {}, [@body]]
        end
      end

      let(:blank_app){ LogoutApp.new }

      it "clears client from session" do
        get '/resources', {}, "rack.session" => {"databasedotcom.client" => client_dump_str}

        last_request.session[client_key].should be_nil
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
