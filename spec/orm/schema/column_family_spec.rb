require 'spec_helper'

describe MassiveRecord::ORM::Schema::ColumnFamily do

  let(:families) { MassiveRecord::ORM::Schema::ColumnFamilies.new }
  subject { MassiveRecord::ORM::Schema::ColumnFamily.new :name => "family_name", :column_families => families }

  describe "initializer" do
    it "should take a name" do
      column_family = MassiveRecord::ORM::Schema::ColumnFamily.new :name => "family_name"
      expect(column_family.name).to eq("family_name")
    end

    it "should take the column families it belongs to" do
      families = MassiveRecord::ORM::Schema::ColumnFamilies.new
      column_family = MassiveRecord::ORM::Schema::ColumnFamily.new :name => "family_name"
      column_family.column_families = families
      expect(column_family.column_families).to eq(families)
    end

    it "should set fields contained_in" do
      column_family = MassiveRecord::ORM::Schema::ColumnFamily.new :name => "family_name"
      expect(column_family.fields.contained_in).to eq(column_family)
    end

    it "should set autoload_fields to true" do
      column_family = MassiveRecord::ORM::Schema::ColumnFamily.new :name => "family_name", :autoload_fields => true
      expect(column_family).to be_autoload_fields
    end
  end

  describe "validations" do
    before do
      @families = MassiveRecord::ORM::Schema::ColumnFamilies.new
      @column_family = MassiveRecord::ORM::Schema::ColumnFamily.new :name => "family_name", :column_families => @families
    end

    it "should be valid from before hook" do
      expect(@column_family).to be_valid
    end

    it "should not be valid with a blank name" do
      @column_family.send(:name=, nil)
      expect(@column_family).not_to be_valid
    end

    it "should not be valid without column_families" do
      @column_family.column_families = nil
      expect(@column_family).not_to be_valid
    end

    it "should not be valid if one of it's field is not valid" do
      @field = MassiveRecord::ORM::Schema::Field.new(:name => :name)
      @column_family << @field
      expect(@field).to receive(:valid?).and_return(false)
      expect(@column_family).not_to be_valid
    end
  end


  it "should cast name to string" do
    column_family = MassiveRecord::ORM::Schema::ColumnFamily.new(:name => :name)
    expect(column_family.name).to eq("name")
  end

  it "should compare two column families based on name" do
    column_family_1 = MassiveRecord::ORM::Schema::ColumnFamily.new(:name => :name)
    column_family_2 = MassiveRecord::ORM::Schema::ColumnFamily.new(:name => :name)

    expect(column_family_1).to eq(column_family_2)
    expect(column_family_1.eql?(column_family_2)).to be_true
  end

  it "should have the same hash value for two families with the same name" do
    column_family_1 = MassiveRecord::ORM::Schema::ColumnFamily.new(:name => :name)
    column_family_2 = MassiveRecord::ORM::Schema::ColumnFamily.new(:name => :name)

    expect(column_family_1.hash).to eq(column_family_2.hash)
  end



  describe "delegation to fields" do
    before do
      @families = MassiveRecord::ORM::Schema::ColumnFamilies.new
      @column_family = MassiveRecord::ORM::Schema::ColumnFamily.new :name => "family_name", :column_families => @families
    end

    %w(add add? << to_hash attribute_names field_by_name).each do |method_to_delegate_to_fields|
      it "should delegate #{method_to_delegate_to_fields} to fields" do
        expect(@column_family.fields).to receive(method_to_delegate_to_fields)
        @column_family.send(method_to_delegate_to_fields)
      end
    end
  end

  describe "#attribute_name_taken?" do
    before do
      @column_family = MassiveRecord::ORM::Schema::ColumnFamily.new :name => "family_name", :column_families => @families
      @name_field = MassiveRecord::ORM::Schema::Field.new(:name => :name)
      @phone_field = MassiveRecord::ORM::Schema::Field.new(:name => :phone)
      @column_family << @name_field << @phone_field
    end

    describe "with no contained_in" do
      it "should return true if name is taken" do
        expect(@column_family.attribute_name_taken?("phone")).to be_true
      end

      it "should accept and return true if name, given as a symbol, is taken" do
        expect(@column_family.attribute_name_taken?(:phone)).to be_true
      end

      it "should return false if name is not taken" do
        expect(@column_family.attribute_name_taken?("not_taken")).to be_false
      end
    end

    describe "with contained_in set" do
      before do
        @column_family.contained_in = MassiveRecord::ORM::Schema::ColumnFamilies
      end

      it "should ask object it is contained in for the truth about if attribute name is taken" do
        expect(@column_family.contained_in).to receive(:attribute_name_taken?).and_return true
        expect(@column_family.attribute_name_taken?(:foo)).to be_true
      end

      it "should not ask object it is contained in if asked not to" do
        expect(@column_family.contained_in).not_to receive(:attribute_name_taken?)
        expect(@column_family.attribute_name_taken?(:foo, true)).to be_false
      end
    end
  end

  describe "#autoload_fields" do
    it "sets self to be autoloaded" do
      subject.instance_eval do
        autoload_fields 
      end
      expect(subject).to be_autoload_fields
    end

    it "takes options for created fields when autoloading" do
      options = {:type => :integer}
      subject.instance_eval do
        autoload_fields options
      end
      expect(subject.options_for_autoload_created_fields).to eq options
    end
  end
end
