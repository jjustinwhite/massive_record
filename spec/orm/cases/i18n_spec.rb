require 'spec_helper'
require 'orm/models/person'

describe "translation and naming" do
  before do
    I18n.backend = I18n::Backend::Simple.new
  end

  describe "of an attribute" do
    before do
      I18n.backend.store_translations 'en', :activemodel => {:attributes => {:person => {:name => "person's name"} } }
    end

    it "should look up an by a string" do
      expect(Person.human_attribute_name("name")).to eq("person's name")
    end

    it "should look up an by a symbol" do
      expect(Person.human_attribute_name(:name)).to eq("person's name")
    end
  end

  describe "of a model" do
    before do
      I18n.backend.store_translations 'en', :activemodel => {:models => {:person => 'A person object'}}
    end

    it "should return it's human name" do
      expect(Person.model_name.human).to eq("A person object")
    end
  end
end
