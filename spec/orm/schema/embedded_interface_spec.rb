require 'spec_helper'

class TestEmbeddedInterface
  include MassiveRecord::ORM::Schema::EmbeddedInterface
end

describe MassiveRecord::ORM::Schema::EmbeddedInterface do
  after do
    TestEmbeddedInterface.fields = nil
  end

  it "should respond_to default_attributes_from_schema" do
    expect(TestEmbeddedInterface).to respond_to :default_attributes_from_schema
  end

  it "should have fields set to nil if no fields are defined" do
    expect(TestEmbeddedInterface.fields).to be_nil
  end

  it "should have one field if one field is added" do
    class TestEmbeddedInterface
      field :field_name, :string
    end

    expect(TestEmbeddedInterface.fields.size).to eq(1)
    expect(TestEmbeddedInterface.fields.first.name).to eq("field_name")
  end

  it "should not be possible to have to fields with the same name" do
    expect {
      class TestEmbeddedInterface
        field :will_raise_error
        field :will_raise_error
      end
    }.to raise_error MassiveRecord::ORM::Schema::InvalidField
  end

  it "should return attributes schema based on DSL" do
    class TestEmbeddedInterface
      field :name
      field :age, :integer, :default => 1
    end

    expect(TestEmbeddedInterface.attributes_schema["name"].type).to eq(:string)
    expect(TestEmbeddedInterface.attributes_schema["age"].type).to eq(:integer)
    expect(TestEmbeddedInterface.attributes_schema["age"].default).to eq(1)
  end

  it "should make attributes_schema readable from instances" do
    class TestEmbeddedInterface
      field :name
    end

    expect(TestEmbeddedInterface.new.attributes_schema["name"].type).to eq(:string)
  end

  it "should have a list of known attribute names" do
    class TestEmbeddedInterface
      field :name, :string
      field :age, :integer
    end

    expect(TestEmbeddedInterface.known_attribute_names.size).to eq(2)
    expect(TestEmbeddedInterface.known_attribute_names).to include("name", "age")
  end

  it "should make known_attribute_names readable for instances" do
    class TestEmbeddedInterface
      field :name, :string
    end

    expect(TestEmbeddedInterface.new.known_attribute_names).to include('name')
  end


  it "should give us default attributes from schema" do
    class TestEmbeddedInterface
      field :name
      field :age, :integer, :default => 1
    end

    defaults = TestEmbeddedInterface.default_attributes_from_schema
    expect(defaults["name"]).to be_nil
    expect(defaults["age"]).to eq(1)
  end

  describe "timestamps" do
    before do
      class TestEmbeddedInterface
        timestamps
      end
    end

    it "should have a created_at time field" do
      expect(TestEmbeddedInterface.attributes_schema['created_at'].type).to eq(:time)
    end
  end


  describe "dynamically adding a field" do
    it "should be possible to dynamically add a field" do
      TestEmbeddedInterface.add_field :name, :default => "NA"

      expect(TestEmbeddedInterface.fields.size).to eq(1)

      field = TestEmbeddedInterface.fields.first

      expect(field.name).to eq("name")
      expect(field.default).to eq("NA")
    end

    it "should be possible to set field's type just like the DSL" do
      TestEmbeddedInterface.add_field :age, :integer, :default => 0

      expect(TestEmbeddedInterface.fields.first.name).to eq("age")
      expect(TestEmbeddedInterface.fields.first.type).to eq(:integer)
      expect(TestEmbeddedInterface.fields.first.default).to eq(0)
    end

    it "should call class' undefine_attribute_methods to make sure it regenerates for newly added" do
      expect(TestEmbeddedInterface).to receive(:undefine_attribute_methods)
      TestEmbeddedInterface.add_field :name, :default => "NA"
    end

    it "should return the new field" do
      field = TestEmbeddedInterface.add_field :age, :integer, :default => 0
      expect(field).to eq(TestEmbeddedInterface.fields.first)
    end

    it "should insert the new field's default value right away" do
      test_interface = TestEmbeddedInterface.new
      expect(test_interface).to receive("age=").with(1)
      test_interface.add_field :age, :integer, :default => 1
    end
  end

  describe "#attributes_db_raw_data_hash" do
    subject { Address.new("id", :street => "Asker", :number => 2, :nice_place => true, :zip => '1384') }

    it "returns hash with correct key-value pairs" do
      expect(subject.attributes_db_raw_data_hash).to eq({
        "street" => "Asker",
        "number" => 2,
        "nice_place" => "true",
        "postal_code" => "1384"
      })
    end
  end

  describe ".transpose_raw_data_to_record_attributes_and_raw_data" do
    let(:id) { "id" }
    let(:raw_data) do
      MassiveRecord::ORM::RawData.new(value: {
        "street" => "Oslo",
        "number" => 3,
        "nice_place" => "false",
        "postal_code" => "1111"
      })
    end

    it "returns attributes" do
      attributes, raw = Address.transpose_raw_data_to_record_attributes_and_raw_data id, raw_data
      expect(attributes).to eq({:id=>"id", "street"=>"Oslo", "number"=>3, "nice_place"=>false, "zip"=>"1111", "updated_at" => nil})
    end

    it "returns raw data" do
      attributes, raw = Address.transpose_raw_data_to_record_attributes_and_raw_data id, raw_data
      expect(raw).to eq Hash[raw_data.value.collect do |attr, value|
        [attr, MassiveRecord::ORM::RawData.new(value: value, created_at: raw_data.created_at)]
      end]
    end

    it "returns correct attributes from serialized db values hash" do
      attributes, raw = Address.transpose_raw_data_to_record_attributes_and_raw_data(
        id,
        MassiveRecord::ORM::RawData.new(value: MassiveRecord::ORM::Base.coder.dump(raw_data.value))
      )
      expect(attributes).to eq({:id=>"id", "street"=>"Oslo", "number"=>3, "nice_place"=>false, "zip"=>"1111", "updated_at" => nil})
    end
  end
end
