# encoding: utf-8
require 'spec_helper'
require 'orm/models/test_class'
require 'orm/models/person'

describe "finders" do
  describe "#find dry test" do
    include MockMassiveRecordConnection

    before do
      @mocked_table = double(MassiveRecord::Wrapper::Table, :to_ary => []).as_null_object
      allow(Person).to receive(:table).and_return(@mocked_table)
      
      @row = MassiveRecord::Wrapper::Row.new
      @row.id = "ID1"
      @row.values = { :info => { :name => "John Doe", :age => "29" } }

      @row_2 = MassiveRecord::Wrapper::Row.new
      @row_2.id = "ID2"
      @row_2.values = { :info => { :name => "Bob", :age => "18" } }
    end

    it "should have at least one argument" do
      expect { Person.find }.to raise_error ArgumentError
    end

    it "should raise RecordNotFound if id is nil" do
      expect { Person.find(nil) }.to raise_error MassiveRecord::ORM::RecordNotFound
    end

    describe "conditions" do
      it "should raise an error if conditions are given to first" do
        expect { Person.first(:conditions => "foo = 'bar'") }.to raise_error ArgumentError
      end

      it "should raise an error if conditions are given to all" do
        expect { Person.all(:conditions => "foo = 'bar'") }.to raise_error ArgumentError
      end

      it "should raise an error if conditions are given to find" do
        expect { Person.find(:conditions => "foo = 'bar'") }.to raise_error ArgumentError
      end
    end

    describe "default select" do
      it "applies all the known column families to finder options as a default on all()" do
        expect(@mocked_table).to receive(:all).with(hash_including(:select => Person.known_column_family_names)).and_return []
        Person.all
      end

      it "applies all the known column families to finder options as a default on first()" do
        expect(@mocked_table).to receive(:all).with(hash_including(:select => Person.known_column_family_names)).and_return []
        Person.first
      end

      it "applies all the known column families to finder options as a default on first()" do
        expect(@mocked_table).to receive(:find).with("ID1", hash_including(:select => Person.known_column_family_names)).and_return(@row)
        Person.find("ID1")
      end
    end

    it "should ask the table to look up by it's id" do
      expect(@mocked_table).to receive(:find).with("ID1", anything).and_return(@row)
      Person.find("ID1")
    end

    it "persists the raw values from table" do
      expect(@mocked_table).to receive(:find).with("ID1", anything).and_return(@row)
      person = Person.find("ID1")
      expect(person.raw_data).to eq @row.values_raw_data_hash
    end
    
    it "should ask the table to fetch rows from a list of ids given as array" do
      expect(@mocked_table).to receive(:find).with(["ID1", "ID2"], anything).and_return([@row, @row_2])
      people = Person.find(["ID1", "ID2"])
      expect(people).to be_instance_of Array
      expect(people.first).to be_instance_of Person
      expect(people.first.id).to eq("ID1")
      expect(people.last.id).to eq("ID2")
    end
    
    it "should ask table to fetch rows from a list of ids given as arguments" do
      expect(@mocked_table).to receive(:find).with(["ID1", "ID2"], anything).and_return([@row, @row_2])
      people = Person.find("ID1", "ID2")
      expect(people).to be_instance_of Array
      expect(people.first).to be_instance_of Person
      expect(people.first.id).to eq("ID1")
      expect(people.last.id).to eq("ID2")
    end

    it "should raise error if not all multiple ids are found" do
      expect(@mocked_table).to receive(:find).with(["ID1", "ID2"], anything).and_return([@row])
      expect { Person.find("ID1", "ID2") }.to raise_error MassiveRecord::ORM::RecordNotFound
    end
    
    it "should call table's all with limit 1 on find(:first)" do
      expect(@mocked_table).to receive(:all).with(hash_including(:limit => 1)).and_return([@row])
      expect(Person.find(:first)).to be_instance_of Person
    end

    it "should call table's all on find(:all)" do
      expect(@mocked_table).to receive(:all).and_return([@row])
      Person.find(:all)
    end

    it "should return empty array on all if no results was found" do
      expect(@mocked_table).to receive(:all).and_return([])
      expect(Person.all).to eq([])
    end

    it "should return nil on first if no results was found" do
      expect(Person.first).to be_nil
    end

    it "should raise an error if not exactly the id is found" do
      expect(@mocked_table).to receive(:find).and_return(@row)
      expect { Person.find("ID") }.to raise_error(MassiveRecord::ORM::RecordNotFound)
    end

    it "should raise error if not all ids are found" do
      expect(@mocked_table).to receive(:find).and_return([@row, @row_2])
      expect { Person.find("ID", "ID2") }.to raise_error(MassiveRecord::ORM::RecordNotFound)
    end
  end

  describe "all" do
    it "should respond to all" do
      expect(TestClass).to respond_to :all
    end

    it "should call find with :all" do
      expect(TestClass).to receive(:do_find).with(:all, anything)
      TestClass.all
    end

    it "should delegate all's call to find with it's args as second argument" do
      options = {:foo => :bar}
      expect(TestClass).to receive(:do_find).with(anything, options)
      TestClass.all options
    end
  end

  describe "first" do
    it "should respond to first" do
      expect(TestClass).to respond_to :first
    end

    it "should call find with :first" do
      expect(TestClass).to receive(:do_find).with(:all, {:limit => 1}).and_return([])
      TestClass.first
    end

    it "should delegate first's call to find with it's args as second argument" do
      options = {:foo => :bar}
      expect(TestClass).to receive(:do_find).with(anything, hash_including(options)).and_return([])
      TestClass.first options
    end
  end

  describe "#find database test" do
    include CreatePersonBeforeEach

    before do
      @person = Person.find("ID1")

      @row = MassiveRecord::Wrapper::Row.new
      @row.id = "ID2"
      @row.values = {:info => {:name => "Bob", :email => "bob@base.com", :age => "26"}}
      @row.table = @table
      @row.save

      @bob = Person.find("ID2")
    end

    it "should raise record not found error" do
      expect { Person.find("not_found") }.to raise_error MassiveRecord::ORM::RecordNotFound
    end

    it "should raise record not found error if table does not exist" do
      Person.table.destroy
      expect { Person.find("id") }.to raise_error MassiveRecord::ORM::RecordNotFound
    end

    it "should return the person object when found" do
      expect(@person.name).to eq("John Doe")
      expect(@person.email).to eq("john@base.com")
      expect(@person.age).to eq(20)
    end

    it "should maintain encoding of ids" do
      id = "thorbjørn"
      person = Person.create! id, :name => "Thorbjørn", :age => 20
      expect(Person.find(id)).to eq person
    end

    it "should find first person" do
      expect(Person.first).to eq(@person)
    end

    it "should find all" do
      all = Person.all
      expect(all).to include @person, @bob
      expect(all.length).to eq(2)
    end

    it "should find all persons, even if it is more than 10" do
      15.times { |i| Person.create! "id-#{i}", :name => "Going to die :-(", :age => i + 20 }
      expect(Person.all.length).to be > 10
    end

    it "should raise error if not all requested records was found" do
      expect { Person.find(["ID1", "not exists"]) }.to raise_error MassiveRecord::ORM::RecordNotFound
    end

    it "should return what it finds if asked to" do
      expect { Person.find(["ID1", "not exists"], :skip_expected_result_check => true) }.not_to raise_error
    end


    describe "embedded records" do
      subject { Person.find("ID1") }
      let(:address) { Address.new "address-1", :street => "Asker", :number => 1 }

      before do
        subject.addresses << address
        subject.reload
      end

      it "is able to load embeds many relations" do
        expect(subject.addresses).to eq [address]
      end
    end
  end
  
  describe "#find_in_batches" do
    include CreatePeopleBeforeEach
        
    it "should iterate through a collection of group of rows using a batch process" do
      group_number = 0
      batch_size = 3
      Person.find_in_batches(:batch_size => batch_size) do |rows|
        group_number += 1
        rows.each do |row|
          expect(row.id).not_to be_nil
        end
      end        
      expect(group_number).to eq(@table_size / 3)
    end

    it "should not do a thing if table does not exist" do
      Person.table.destroy

      counter = 0

      Person.find_in_batches(:batch_size => 3) do |rows|
        rows.each do |row|
          counter += 1
        end
      end

      expect(counter).to eq(0)
    end
    
    it "should iterate through a collection of rows using a batch process" do
      rows_number = 0
      Person.find_each(:batch_size => 3) do |row|
        expect(row.id).not_to be_nil
        rows_number += 1
      end
      expect(rows_number).to eq(@table_size)
    end
  end

  describe "#exists?" do
    include CreatePersonBeforeEach

    it "should return true if a row exists with given id" do
      expect(Person.exists?("ID1")).to be_true
    end

    it "should return false if a row does not exists with given id" do
      expect(Person.exists?("unkown")).to be_false
    end
  end
end
