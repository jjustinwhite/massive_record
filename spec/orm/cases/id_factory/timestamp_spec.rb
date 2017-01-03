require 'spec_helper'
require 'orm/models/person'

describe MassiveRecord::ORM::IdFactory::Timestamp do
  subject { described_class.instance }

  it_should_behave_like "an id factory"


  describe "settings" do
    after do
      described_class.precision = :microseconds
      described_class.reverse_time = true
    end

    describe "#precision" do
      it "can be set to seconds" do
        described_class.precision = :seconds
        expect(subject.next_for(Person).length).to eq 10
      end

      it "can be set to milliseconds" do
        described_class.precision = :milliseconds
        expect(subject.next_for(Person).length).to eq 13
      end

      it "can be set to microseconds" do
        described_class.precision = :microseconds
        expect(subject.next_for(Person).length).to eq 16
      end
    end

    describe "#reverse_time" do
      let(:time) { double(Time) }

      before do
        time.stub_chain(:getutc, :to_f).and_return(1)
        allow(Time).to receive(:now).and_return time
      end

      it "can be normal time" do
        described_class.reverse_time = false
        described_class.precision = :seconds

        expect(subject.next_for(Person)).to eq "1"

        described_class.reverse_time = true
        described_class.precision = :microseconds
      end

      it "can be reverse time" do
        described_class.reverse_time = true
        described_class.precision = :seconds

        expect(subject.next_for(Person)).to eq "9999999998"

        described_class.precision = :microseconds
      end
    end
  end
end
