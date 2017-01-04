require 'spec_helper'

describe MassiveRecord::ORM::Schema::Fields do
  before do
    @fields = MassiveRecord::ORM::Schema::Fields.new
  end

  it "should be a kind of set" do
    expect(@fields).to be_a_kind_of Set
  end

  describe "add fields to the set" do
    it "should be possible to add fields" do
      @fields << MassiveRecord::ORM::Schema::Field.new(:name => "field")
    end

    it "should add self to field's fields attribute" do
      field = MassiveRecord::ORM::Schema::Field.new(:name => :field)
      @fields << field
      expect(field.fields).to eq(@fields)
    end

    it "should not be possible to add two fields with the same name" do
      @fields << MassiveRecord::ORM::Schema::Field.new(:name => "attr")
      expect(@fields.add?(MassiveRecord::ORM::Schema::Field.new(:name => "attr"))).to be_nil
    end

    it "should raise error if invalid column familiy is added" do
      invalid_field = MassiveRecord::ORM::Schema::Field.new
      expect { @fields << invalid_field }.to raise_error MassiveRecord::ORM::Schema::InvalidField
    end
  end

  describe "#to_hash" do
    before do
      @name_field = MassiveRecord::ORM::Schema::Field.new(:name => :name)
      @phone_field = MassiveRecord::ORM::Schema::Field.new(:name => :phone)
      @fields << @name_field << @phone_field
    end

    it "should return nil if no fields are added" do
      @fields.clear
      expect(@fields.to_hash).to eq({})
    end

    it "should contain added fields" do
      expect(@fields.to_hash).to include("name" => @name_field)
      expect(@fields.to_hash).to include("phone" => @phone_field)
    end
  end

  describe "#attribute_names" do
    before do
      @name_field = MassiveRecord::ORM::Schema::Field.new(:name => :name)
      @phone_field = MassiveRecord::ORM::Schema::Field.new(:name => :phone)
      @fields << @name_field << @phone_field
    end

    it "should return nil if no fields are added" do
      @fields.clear
      expect(@fields.attribute_names).to eq([])
    end

    it "should contain added fields" do
      expect(@fields.attribute_names).to include("name", "phone")
    end
  end

  describe "#attribute_name_taken?" do
    before do
      @name_field = MassiveRecord::ORM::Schema::Field.new(:name => :name)
      @phone_field = MassiveRecord::ORM::Schema::Field.new(:name => :phone)
      @fields << @name_field << @phone_field
    end

    describe "with no contained_in" do
      it "should return true if name is taken" do
        expect(@fields.attribute_name_taken?("phone")).to eq false
      end

      it "should accept and return true if name, given as a symbol, is taken" do
        expect(@fields.attribute_name_taken?(:phone)).to eq true
      end

      it "should return false if name is not taken" do
        expect(@fields.attribute_name_taken?("not_taken")).to eq false
      end
    end

    describe "with contained_in set" do
      before do
        @fields.contained_in = MassiveRecord::ORM::Schema::ColumnFamily.new :name => "Family"
      end

      it "should ask object it is contained in for the truth about if attribute name is taken" do
        expect(@fields.contained_in).to receive(:attribute_name_taken?).and_return true
        expect(@fields.attribute_name_taken?(:foo)).to eq true
      end

      it "should not ask object it is contained in if asked not to" do
        expect(@fields.contained_in).not_to receive(:attribute_name_taken?)
        expect(@fields.attribute_name_taken?(:foo, true)).to eq false
      end
    end
  end

  describe "#field_by_name" do
    before do
      @name_field = MassiveRecord::ORM::Schema::Field.new(:name => :name)
      @phone_field = MassiveRecord::ORM::Schema::Field.new(:name => :phone)
      @fields << @name_field << @phone_field
    end

    it "should return nil if nothing is found" do
      expect(@fields.field_by_name("unkown")).to be_nil
    end

    it "should return found field" do
      expect(@fields.field_by_name("name")).to eq(@name_field)
    end

    it "should return found field given as symbol" do
      expect(@fields.field_by_name(:name)).to eq(@name_field)
    end
  end
end
