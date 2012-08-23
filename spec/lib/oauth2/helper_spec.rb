require 'spec_helper'
require 'databasedotcom'

describe Databasedotcom::OAuth2::Helpers do

  class TestApp
    include Databasedotcom::OAuth2::Helpers

    def env
      @env ||= {
        Databasedotcom::OAuth2::CLIENT_KEY => Databasedotcom::Client.new
      }
    end
  end

  let(:client_key) { Databasedotcom::OAuth2::CLIENT_KEY }
  let(:app) { TestApp.new }

  it "supports client which is env['databasedotcom.client']" do
    app.client.should == app.env[client_key]
  end

  it "supports authenticated? and unauthenticated?" do
    app.should be_authenticated
    app.should_not be_unauthenticated

    app.env[client_key] = nil

    app.should_not be_authenticated
    app.should be_unauthenticated
  end

end