# -*- encoding: utf-8 -*-
require 'spec_helper'
require 'orm/models/person'

describe "encoding" do

  describe "with ORM" do
    include SetUpHbaseConnectionBeforeAll
    include SetTableNamesToTestTable

    before do
      @person = Person.create! "new_id", :name => "Thorbjørn", :age => "22"
      @person_from_db = Person.find(@person.id)
    end

    it "should be able to store UTF-8 encoded strings" do
      expect(@person_from_db).to eq(@person)
      expect(@person_from_db.name).to eq("Thorbjørn")
    end

    it "should return string as UTF-8 encoded strings" do
      expect(@person_from_db.name.encoding).to eq(Encoding::UTF_8)
    end
  end

  describe "without ORM" do
    include CreatePersonBeforeEach

    before do
      @id = "ID-encoding-test"

      @row = MassiveRecord::Wrapper::Row.new
      @row.table = @table
      @row.id = @id
      @row.values = {:info => {:name => "Thorbjørn", :email => "john@base.com", :age => "20"}}
      @row.save

      @row_from_db = @table.find(@id) 
    end

    it "should be able to store UTF-8 encoded strings" do
      expect(@row_from_db.values["info:name"].force_encoding(Encoding::UTF_8)).to eq("Thorbjørn")
    end

    it "should return string as UTF-8 encoded strings" do
      expect(@row_from_db.values["info:name"].encoding).to eq(Encoding::UTF_8)
    end
  end
end
