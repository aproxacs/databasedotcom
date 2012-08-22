require 'spec_helper'
require 'databasedotcom'

describe Databasedotcom::OAuth2::WebServerFlow do
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
