require 'spec_helper'
require 'orm/models/person'
require 'orm/models/test_class'

describe "table classes" do
  before do
    @subject = MassiveRecord::ORM::Table
    
    @subject.column_family(:info) do
      field :first_name
      field :last_name
    end
    
    @subject.column_family(:misc) do
      field :status, :boolean, :default => false
    end
    
    @subject.column_family(:sandbox) do
      autoload_fields
    end
  end

  after do
    @subject.column_families = nil
  end
  
  describe "column_families" do
    it "should have a collection of column families" do
      expect(@subject.column_families).to be_a_kind_of(Set)
    end
    
    it "should have an attributes schema" do
      expect(@subject.attributes_schema).to include("first_name", "last_name", "status")
    end
  end
end

describe "Person which is a table" do
  include SetUpHbaseConnectionBeforeAll
  include SetTableNamesToTestTable

  before do
    @person = Person.new
    @person.id = "test"
    @person.points = "25"
    @person.date_of_birth = "19850730"
    @person.status = "0"
  end
  
  it "should have a list of column families" do
    expect(Person.column_families.collect(&:name)).to include("info")
  end

  it "should keep different column families per sub class" do
    expect(Person.column_families.collect(&:name)).to include "info", "base"
    expect(TestClass.column_families.collect(&:name)).to include "test_family", "addresses"
  end
  
  it "should have a list of attributes created from the column family 'info'" do
    expect(@person.attributes.keys).to include("name", "email", "points", "date_of_birth", "status")
  end
  
  it "should default an attribute to its default value" do
    expect(@person.points).to eq(25)
  end
  
  it "should parse a Date field properly" do
    expect(@person.date_of_birth).to be_a_kind_of(Date)
  end
  
  it "should parse a Boolean field properly" do
    expect(@person.status).to be_falsey
  end

  it "should decode/encode empty hashes correctly" do
    @person.dictionary = {}
    @person.save! :validate => false
    @person.reload
    expect(@person.dictionary).to be_instance_of Hash
  end
end
