require 'spec_helper'

describe MassiveRecord::ORM::RawData do
  let(:value) { "FooBar!" }
  let(:created_at) { Time.now.to_s }

  subject { MassiveRecord::ORM::RawData.new(value: value, created_at: created_at) }

  describe "#initialize" do
    it "assigns value" do
      expect(subject.value).to eq value
    end

    it "assigns created_at" do
      expect(subject.created_at).to eq created_at
    end
  end


  describe ".new_with_data_from" do
    describe "thrift cell" do
      let(:cell) { MassiveRecord::Wrapper::Cell.new(value: value, created_at: created_at) }

      subject { described_class.new_with_data_from(cell) }

      it "assigns value" do
        expect(subject.value).to eq value
      end

      it "assigns created_at" do
        expect(subject.created_at).to eq created_at
      end
    end
  end


  describe "#to_s" do
    it "represents itself with it's value" do
      expect(subject.to_s).to eq value
    end
  end

  describe "#inspect" do
    it "represents itself with it's value" do
      expect(subject.to_s).to eq value
    end
  end

  
  describe "equality" do
    it "considered equal if created at and value are the same" do
      cell = described_class.new_with_data_from(
        MassiveRecord::Wrapper::Cell.new(value: value, created_at: created_at)
      )
      expect(cell).to eq subject
    end
  end
end
