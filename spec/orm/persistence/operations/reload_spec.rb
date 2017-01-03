require 'spec_helper'

describe MassiveRecord::ORM::Persistence::Operations::Reload do
  include MockMassiveRecordConnection

  let(:record) { TestClass.new("id-1") }
  let(:options) { {:this => 'hash', :has => 'options'} }
  
  subject { described_class.new(record, options) }

  it_should_behave_like "a persistence table operation class"

  before { record.save! }

  describe "#execute" do
    context "new record" do
      before { allow(record).to receive(:persisted?).and_return false }

      describe '#execute' do
        subject { super().execute }
        it { is_expected.to be_falsey }
      end

      it "does no find" do
        expect(subject.klass).not_to receive(:find)
        subject.execute
      end
    end

    context "persisted" do
      describe '#execute' do
        subject { super().execute }
        it { is_expected.to be_truthy }
      end

      it "asks class to find it's id" do
        expect(subject.klass).to receive(:find).with(record.id).and_return(record)
        subject.execute
      end

      it "reinit record with found record's attributes and raw_data" do
        expect(subject.klass).to receive(:find).with(record.id).and_return(record)
        expect(record).to receive(:attributes).and_return('attributes' => {})
        expect(record).to receive(:raw_data).and_return('raw_data' => {})
        expect(record).to receive(:reinit_with).with({
          'attributes' => {'attributes' => {}},
          'raw_data' => {'raw_data' => {}}
        })
        subject.execute
      end
    end
  end
end

