require 'spec_helper'
require 'orm/models/test_class'
require 'orm/models/friend'
require 'orm/models/best_friend'

describe MassiveRecord::ORM::Base do
  include MockMassiveRecordConnection

  describe "table name" do
    before do
      TestClass.reset_table_name_configuration!
      Friend.reset_table_name_configuration!
      BestFriend.reset_table_name_configuration!
    end

    after do
      TestClass.reset_table_name_configuration!
      Friend.reset_table_name_configuration!
      BestFriend.reset_table_name_configuration!
    end

    it "should have a table name" do
      expect(TestClass.table_name).to eq("test_classes")
    end
    
    it "should have a table name with prefix" do
      TestClass.table_name_prefix = "prefix_"
      expect(TestClass.table_name).to eq("prefix_test_classes")
    end
    
    it "should have a table name with suffix" do
      TestClass.table_name_suffix = "_suffix"
      expect(TestClass.table_name).to eq("test_classes_suffix")
    end

    it "first sub class should have the same table name as base class" do
      expect(Friend.table_name).to eq(Person.table_name)
    end

    it "second sub class should have the same table name as base class" do
      expect(BestFriend.table_name).to eq(Person.table_name)
    end
    
    describe "set explicitly" do
      it "should be able to set it" do
        TestClass.table_name = "foo"
        expect(TestClass.table_name).to eq("foo")
      end

      it "should have a table name with prefix" do
        TestClass.table_name = "foo"
        TestClass.table_name_prefix = "prefix_"
        expect(TestClass.table_name).to eq("prefix_foo")
      end
      
      it "should have a table name with suffix" do
        TestClass.table_name = "foo"
        TestClass.table_name_suffix = "_suffix"
        expect(TestClass.table_name).to eq("foo_suffix")
      end

      it "should be possible to call set_table_name" do
        TestClass.set_table_name("foo")
        expect(TestClass.table_name).to eq("foo")
      end

      it "sub class should have have table name overridden" do
        Friend.table_name = "foo"
        expect(Friend.table_name).to eq("foo")
      end
    end
  end

  it "should have a model name" do
    expect(TestClass.model_name).to eq("TestClass")
  end

  describe "#initialize" do
    it "should take a set of attributes and make them readable" do
      model = TestClass.new :foo => 'bar'
      expect(model.foo).to eq('bar')
    end

    it "should raise error if attribute is unknown" do
      expect { TestClass.new :unknown => 'attribute' }.to raise_error MassiveRecord::ORM::UnknownAttributeError
    end

    it "should initialize an object via init_with()" do
      model = TestClass.allocate
      model.init_with 'attributes' => {:foo => 'bar'}
      expect(model.foo).to eq('bar')
    end

    it "should set attributes where nil is not allowed if it is not included in attributes list" do
      model = TestClass.allocate
      model.init_with 'attributes' => {:foo => 'bar'}
      expect(model.hash_not_allow_nil).to eq({})
    end

    it "should set attributes where nil is not allowed if it is included, but the value is nil" do
      model = TestClass.allocate
      model.init_with 'attributes' => {:hash_not_allow_nil => nil, :foo => 'bar'}
      expect(model.hash_not_allow_nil).to eq({})
    end

    it "should not set override attributes where nil is allowed" do
      model = TestClass.allocate
      model.init_with 'attributes' => {:foo => nil}
      expect(model.foo).to be_nil
    end

    it "should set attributes where nil is not allowed when calling new" do
      expect(TestClass.new.hash_not_allow_nil).to eq({})
    end

    it "should stringify keys set on attributes" do
      model = TestClass.allocate
      model.init_with 'attributes' => {:foo => 'bar'}
      expect(model.attributes.keys).to include("foo")
    end

    it "should return nil as id by default" do
      expect(TestClass.new.id).to be_nil
    end

    it "should be possible to create an object with nil as argument" do
      expect { TestClass.new(nil) }.not_to raise_error
    end
  end

  describe "equality" do
    it "should evaluate one object the same as equal" do
      person = Person.find(1)
      expect(person).to eq(person)
    end

    it "should evaluate two objects of same class and id as ==" do
      expect(Person.find(1)).to eq(Person.find(1))
    end

    it "should evaluate two objects of same class and id as eql?" do
      expect(Person.find(1).eql?(Person.find(1))).to be_truthy
    end

    it "should not be equal if ids are different" do
      expect(Person.find(1)).not_to eq(Person.find(2))
    end

    it "should not be equal if class are different" do
      expect(TestClass.find(1)).not_to eq(Person.find(2))
    end
  end

  describe "intersection and union operation" do
    it "should correctly find intersection two sets" do
      expect([Person.find(1)] & [Person.find(1), Person.find(2)]).to eq([Person.find(1)])
    end

    it "should correctly find union of two sets" do
      expect([Person.find(1)] | [Person.find(1), Person.find(2)]).to eq([Person.find(1), Person.find(2)])
    end

    it "should correctly find intersection between two sets with different classes" do
      expect([Person.find(1)] & [TestClass.find(1)]).to eq([])
    end

    it "should correctly find union between two sets with different classes" do
      expect([Person.find(1)] | [TestClass.find(1)]).to eq([Person.find(1), TestClass.find(1)])
    end
  end

  describe "#to_param" do
    it "should return nil if new record" do
      expect(TestClass.new.to_param).to be_nil
    end

    it "should return the id if persisted" do
      expect(TestClass.create!(1).to_param).to eq("1")
    end
  end

  describe "#to_key" do
    it "should return nil if new record" do
      expect(TestClass.new.to_key).to be_nil
    end

    it "should return id in an array persisted" do
      expect(TestClass.create!("1").to_key).to eq(["1"])
    end
  end

  it "should be able to freeze objects" do
    test_object = TestClass.new
    test_object.freeze
    expect(test_object).to be_frozen
  end


  describe "#inspect" do
    before do
      @person = Person.new({
        :name => "Bob",
        :age => 3,
        :date_of_birth => Date.today
      })
    end

    it "should wrap inspection string inside of #< >" do
      expect(@person.inspect).to match(/^#<.*?>$/);
    end

    it "should contain it's class name" do
      expect(@person.inspect).to include("Person")
    end

    it "should start with the record's id if it has any" do
      @person.id = 3
      expect(@person.inspect).to include '#<Person id: "3",'
    end

    it "should start with the record's id if it has any" do
      @person.id = nil
      expect(@person.inspect).to include "#<Person id: nil,"
    end

    it "should contain a nice list of it's attributes" do
      i = @person.inspect
      expect(i).to include(%q{name: "Bob"})
      expect(i).to include(%q{age: 3})
    end
  end

  describe "attribute read / write alias" do
    before do
      @test_object = TestClass.new :foo => 'bar'
    end

    it "should read attributes by object[attr]" do
      expect(@test_object[:foo]).to eq('bar')
    end

    it "should write attributes by object[attr] = new_value" do
      @test_object["foo"] = "new_value"
      expect(@test_object.foo).to eq("new_value")
    end
  end


  describe "logger" do
    it "should respond to logger" do
      expect(MassiveRecord::ORM::Base).to respond_to :logger
    end

    it "should respond to logger=" do
      expect(MassiveRecord::ORM::Base).to respond_to :logger=
    end
  end

  describe "read only" do
    it "should not be read only by default" do
      expect(TestClass.new).not_to be_readonly
    end

    it "should be read only if asked to" do
      test = TestClass.new
      test.readonly!
      expect(test).to be_readonly
    end
  end


  describe "#base_class" do
    it "should return correct base class for direct descendant of Base" do
      expect(Person.base_class).to eq(Person)
    end

    it "should return Person when asking a descendant of Person" do
      expect(Friend.base_class).to eq(Person)
    end

    it "should return Person when asking a descendant of Person multiple levels" do
      expect(BestFriend.base_class).to eq(Person)
    end
  end
  
  
  describe "#clone" do
    before do
      @test_object = TestClass.create!("1", :foo => 'bar')
      @clone_object = @test_object.clone
    end
    
    it "should be the same object class" do
      expect(@test_object.class).to eq(@clone_object.class)
    end
    
    it "should have a different object_id" do
      expect(@test_object.object_id).not_to eq(@clone_object.object_id)
    end
    
    it "should have the same attributes" do
      expect(@test_object.foo).to eq(@clone_object.foo)
    end
    
    it "should have a nil id" do
      expect(@clone_object.id).to be_nil
    end
  end


  describe "coder" do
    it "should have a default coder" do
      expect(Person.coder).to be_instance_of MassiveRecord::ORM::Coders::JSON
    end
  end

  describe "id as first argument to" do
    [:new, :create, :create!].each do |creation_method|
      describe creation_method do
        it "sets first argument as records id" do
          expect(TestClass.send(creation_method, "idfirstarg").id).to eq("idfirstarg")
        end

        it "sets first argument as record id, hash as it's attribute" do
          expect(TestClass.send(creation_method, "idfirstarg", foo: 'works').foo).to eq('works')
        end
      end
    end
  end
end
