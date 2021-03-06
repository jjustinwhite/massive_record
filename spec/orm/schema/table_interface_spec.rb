require 'spec_helper'

class TestInterface
  include MassiveRecord::ORM::Schema::TableInterface
end

class TestInterfaceSubClass < TestInterface
end

describe MassiveRecord::ORM::Schema::TableInterface do
  after do
    TestInterface.column_families = nil
    TestInterfaceSubClass.column_families = nil
  end


  it "should respond_to column_family" do
    expect(TestInterface).to respond_to :column_family
  end

  it "should respond_to column_families" do
    expect(TestInterface).to respond_to :column_families
  end

  it "should be possible to add column familiy through DSL" do
    class TestInterface
      column_family :misc do; end
    end

    expect(TestInterface.column_families.collect(&:name)).to include("misc")
  end

  it "adds a column family" do
    TestInterface.add_column_family(:foo)
    expect(TestInterface.column_families.collect(&:name)).to include("foo")
  end

  it "should be possible to add fields to a column families" do
    class TestInterface
      column_family :info do
        field :name
      end
    end

    expect(TestInterface.known_attribute_names).to eq(["name"])
  end

  it "should return a list of known collum families" do
    class TestInterface
      column_family :info do
        field :name
      end
    end

    expect(TestInterface.known_column_family_names).to eq(["info"])
  end

  it "returns no known column family names if no one are defined" do
    expect(TestInterface.known_column_family_names).to eq([])
  end

  it "should return attributes schema based on DSL" do
    class TestInterface
      column_family :info do
        field :name
        field :age, :integer, :default => 1
      end
    end

    expect(TestInterface.attributes_schema["name"].type).to eq(:string)
    expect(TestInterface.attributes_schema["age"].type).to eq(:integer)
    expect(TestInterface.attributes_schema["age"].default).to eq(1)
  end

  it "should raise an error if you try to add same field name twice" do
    expect { 
      class TestInterface
        column_family :info do
          field :name
          field :name
        end
      end
    }.to raise_error MassiveRecord::ORM::Schema::InvalidField
  end

  it "should give us default attributes from schema" do
    class TestInterface
      column_family :info do
        field :name
        field :age, :integer, :default => 1
      end
    end

    defaults = TestInterface.default_attributes_from_schema
    expect(defaults["name"]).to be_nil
    expect(defaults["age"]).to eq(1)
  end

  it "should make attributes_schema readable from instances" do
    class TestInterface
      column_family :info do
        field :name
      end
    end

    expect(TestInterface.new.attributes_schema["name"].type).to eq(:string)
  end

  it "should make known_attribute_names readable for instances" do
    class TestInterface
      column_family :info do
        field :name
      end
    end

    expect(TestInterface.new.known_attribute_names).to include('name')
  end

  it "should not be shared amonb subclasses" do
    class TestInterface
      column_family :info do
        autoload_fields
      end
    end

    expect(TestInterface.column_families).not_to be_nil
    expect(TestInterfaceSubClass.column_families).to be_nil
  end

  describe "timestamps" do
    before do
      class TestInterface
        column_family :info do
          timestamps
        end
      end
    end

    it "should have a created_at time field" do
      expect(TestInterface.attributes_schema['created_at'].type).to eq(:time)
    end
  end


  describe "dynamically adding a field" do
    it "should be possible to dynamically add a field" do
      TestInterface.add_field_to_column_family :info, :name, :default => "NA"

      expect(TestInterface.column_families.size).to eq(1)

      family = TestInterface.column_families.first
      expect(family.name).to eq("info")

      expect(family.fields.first.name).to eq("name")
      expect(family.fields.first.default).to eq("NA")
    end

    it "should be possible to set field's type just like the DSL" do
      TestInterface.add_field_to_column_family :info, :age, :integer, :default => 0

      expect(TestInterface.column_families.first.fields.first.name).to eq("age")
      expect(TestInterface.column_families.first.fields.first.type).to eq(:integer)
      expect(TestInterface.column_families.first.fields.first.default).to eq(0)
    end

    it "should call class' undefine_attribute_methods to make sure it regenerates for newly added" do
      expect(TestInterface).to receive(:undefine_attribute_methods)
      TestInterface.add_field_to_column_family :info, :name, :default => "NA"
    end

    it "should return the new field" do
      field = TestInterface.add_field_to_column_family :info, :age, :integer, :default => 0
      expect(field).to eq(TestInterface.column_families.first.fields.first)
    end

    it "should insert the new field's default value right away" do
      test_interface = TestInterface.new
      expect(test_interface).to receive("age=").with(1)
      test_interface.add_field_to_column_family :info, :age, :integer, :default => 1
    end
  end



  describe "autoload_column_families_and_fields_with" do
    before do
      class TestInterface
        column_family :info do
          autoload_fields
        end

        column_family :integers_only do
          autoload_fields :type => :integer
        end

        column_family :misc do
          field :text
        end
      end

      @column_names = %w(info:name misc:other integers_only:number)
    end

    it "should not add fields to misc" do
      expect(TestInterface.column_families.family_by_name("misc")).not_to receive(:add?)
      TestInterface.autoload_column_families_and_fields_with(@column_names)
    end

    it "should add fields to info" do
      expect(TestInterface.column_families.family_by_name("info")).to receive(:add?)
      TestInterface.autoload_column_families_and_fields_with(@column_names)
    end

    it "creates fields with same options as you give to autoload fields" do
      TestInterface.autoload_column_families_and_fields_with(@column_names)
      family = TestInterface.column_families.family_by_name("integers_only")
      autoloaded_field = family.field_by_name(:number)
      expect(autoloaded_field.type).to eq :integer
    end

    it "should be possible to run twice" do
      2.times { TestInterface.autoload_column_families_and_fields_with(@column_names) }
    end
  end
end
