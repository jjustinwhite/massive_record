require 'spec_helper'
require 'orm/models/person'
require 'orm/models/address'

shared_examples_for "validateable massive record model" do
  it "should include ActiveModel::Validations" do
    expect(@model.class.included_modules).to include(ActiveModel::Validations)
  end

  describe "behaviour from active model" do
    it "should respond to valid?" do
      expect(@model).to respond_to :valid?
    end

    it "should respond to errors" do
      expect(@model).to respond_to :errors
    end

    it "should have one error" do
      @invalidate_model.call(@model)
      @model.valid?
      expect(@model.size).to eq(1)
    end
  end

  describe "persistance" do
    it "should not interrupt saving of a model if its valid" do
      expect(@model.save).to be_truthy
      expect(@model).to be_persisted
    end


    it "should return false on save if record is not valid" do
      @invalidate_model.call(@model)
      expect(@model.save).to be_false
    end

    it "should not save recurd if record is not valid" do
      @invalidate_model.call(@model)
      @model.save
      expect(@model).to be_new_record
    end

    it "should skip validation if asked to" do
      @invalidate_model.call(@model)
      @model.save :validate => false
      expect(@model).to be_persisted
    end

    it "should raise record invalid if save! is called on invalid record" do
      @invalidate_model.call(@model)
      expect(@model).to receive(:valid?).and_return(false)
      expect { @model.save! }.to raise_error MassiveRecord::ORM::RecordInvalid
    end

    it "should raise record invalid if create! is called with invalid attributes" do
      @invalidate_model.call(@model)
      allow(@model.class).to receive(:new).and_return(@model)
      expect { @model.class.create! }.to raise_error MassiveRecord::ORM::RecordInvalid
    end

    describe ":on option" do
      before { @model.consider_carma = true }

      it "takes :on => create into consideration" do
        expect(@model).not_to be_valid
        expect(@model.errors[:carma].length).to eq 1
      end
    end
  end
end


describe "MassiveRecord::Base::Table" do
  include MockMassiveRecordConnection

  before do
    @model = Person.new "1", :name => "Alice", :email => "alice@gmail.com", :age => 20
    @invalidate_model = Proc.new { |p| p.name = nil }
  end

  it_should_behave_like "validateable massive record model"
end

#
# TODO  We might have to decouple some stuff when it comes to calling
#       save on a column, as it's save call should populate up to it's parent
#       and so..
#
#       Guess we have some thinking to do..
#
#describe "MassiveRecord::Base::Column" do
  #include MockMassiveRecordConnection

  #before do
    #@model = Address.new "1", :street => "Henrik Ibsens gate 1"
    #@invalidate_model = Proc.new { |a| a.street = nil }
  #end

  #it_should_behave_like "validateable massive record model"
#end
