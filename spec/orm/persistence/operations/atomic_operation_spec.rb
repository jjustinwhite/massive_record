require 'spec_helper'

describe MassiveRecord::ORM::Persistence::Operations::AtomicOperation do
  include MockMassiveRecordConnection

  let(:record) { Person.new("id-1") }
  let(:options) { {:operation => :increment, :attr_name => 'age', :by => 1} }
  
  subject { described_class.new(record, options) }

  it_should_behave_like "a persistence table operation class"


  describe "#execute" do
    it "raises NotNumericalFieldError if field is not numerical" do
      options[:attr_name] = :name
      expect { subject.execute }.to raise_error MassiveRecord::ORM::NotNumericalFieldError
    end

    it "ensures that we have table and column families" do
      expect(subject).to receive(:ensure_that_we_have_table_and_column_families!)
      subject.execute
    end

    it "ensures that we have binary representation of integer value" do
      expect(subject).to receive(:ensure_proper_binary_integer_representation)
      subject.execute
    end

    it "asks adapter's row to do the atomic operation" do
      row = double(Object)
      expect(row).to receive(:atomic_increment).and_return(1)
      expect(subject).to receive(:row_for_record).and_return row
      subject.execute
    end

    it "assigns the attribute in record with whatever row for record atomic operation returns" do
      row = double(Object)
      expect(row).to receive(:atomic_increment).and_return(111)
      expect(subject).to receive(:row_for_record).and_return row
      subject.execute
      expect(record.age).to eq 111
    end

    it "sets record's @new_record flag to false" do
      record.instance_variable_set(:@new_record, true)
      subject.execute
      expect(record.instance_variable_get(:@new_record)).to eq false
    end

    it "returns the new state of attribute updated" do
      row = double(Object)
      expect(row).to receive(:atomic_increment).and_return(123)
      expect(subject).to receive(:row_for_record).and_return row
      expect(subject.execute).to eq 123
    end
  end
end
