require 'spec_helper'
require 'orm/models/person'
require 'orm/models/test_class'

describe "Default scope in" do
  include SetUpHbaseConnectionBeforeAll
  include SetTableNamesToTestTable

  describe Person do
    let(:subject) { Person.new "ID1", :name => "Person1", :email => "one@person.com", :age => 11, :points => 111, :status => true }

    before do
      subject.save!

      Person.class_eval do
        default_scope select(:info)
      end
    end

    after do
      Person.class_eval do
        default_scope nil
      end
    end



    it "should be possible to find the a record and use the default scope" do
      expect(Person.find(subject.id).points).to be_nil
    end

    it "should only load column family info as a default with first" do
      expect(Person.first.points).to be_nil # its in :base
    end

    it "should only load column family info as default with all" do
      expect(Person.all.first.points).to be_nil
    end

    it "should be possible to bypass default scope by unscoped" do
      expect(Person.unscoped.first.points).to eq(111)
    end

    it "should be possible to set default_scope with a hash" do
      Person.class_eval do
        default_scope :select => :base
      end

      person = Person.first
      expect(person.points).to eq(111)
      expect(person.name).to be_nil
    end

    it "should not share scopes between classes" do
      Person.class_eval { default_scope :select => :base }
      expect(Person.default_scoping).to be_instance_of MassiveRecord::ORM::Finders::Scope
      expect(TestClass.default_scoping).to be_nil
    end

    it "returns a new scope object when default_scope are set" do
      expect(Person.finder_scope).not_to eq Person.finder_scope
    end
  end
end
