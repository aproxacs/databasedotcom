require 'rspec'
require 'spec_helper'
require 'databasedotcom'

describe "hash extensions" do
  describe "#deep_symbolize_keys!" do
    it "symbolizes keys in depth" do
      hash = {"key" => {"inner_key" => 3}}
      hash.deep_symbolize_keys!
      hash[:key][:inner_key].should == 3
    end
  end
end
