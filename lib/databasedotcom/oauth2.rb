require "cgi"
require "base64"
require "openssl"
require "addressable/uri"
require "hashie"
require "gibberish"
require "oauth2"

require 'databasedotcom/oauth2/web_server_flow'
require 'databasedotcom/oauth2/helpers'

module Databasedotcom
  class Client

    attr_accessor :org_id
    attr_accessor :user_id
    attr_accessor :endpoint
    attr_accessor :last_seen
    attr_accessor :logout_flag

    def logout
      @logout_flag = true
    end

  end
end
