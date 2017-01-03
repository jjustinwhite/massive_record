require 'spec_helper'

describe MassiveRecord::ORM::Persistence::Operations::Destroy do
  include MockMassiveRecordConnection

  let(:record) { TestClass.new("id-1") }
  let(:options) { {:this => 'hash', :has => 'options'} }
  
  subject { described_class.new(record, options) }

  it_should_behave_like "a persistence table operation class"


  describe "#execute" do
    it "asks row_for_record to destroy itself" do
      row = double(Object)
      expect(row).to receive(:destroy).and_return true
      expect(subject).to receive(:row_for_record).and_return(row) 
      subject.execute
    end
  end
end
