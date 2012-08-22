module Databasedotcom
  module OAuth2
    module Helpers
      def client
        env[CLIENT_KEY]
      end

    	def unauthenticated?
    	  client.nil?
  	  end

    	def authenticated?
    	  !unauthenticated?
    	end
    	
    	def me
    	  @me ||= ::Hashie::Mash.new(Databasedotcom::Chatter::User.find(client, "me").raw_hash)
  	  end
    end
  end
end