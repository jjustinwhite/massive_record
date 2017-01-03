require 'spec_helper'

shared_examples_for 'an id factory' do
  it "is a singleton" do
    expect(MassiveRecord::ORM::IdFactory::AtomicIncrementation.included_modules).to include(Singleton)
  end

  describe "#next_for" do
    it "responds_to next_for" do
      expect(subject).to respond_to :next_for
    end

    it "uses incomming table name if it's a string" do
      expect(subject).to receive(:next_id).with(hash_including(:table => "test_table"))
      subject.next_for "test_table"
    end

    it "usees incomming table name if it's a symbol" do
      expect(subject).to receive(:next_id).with(hash_including(:table => "test_table"))
      subject.next_for :test_table
    end

    it "asks object for it's table name if it responds to that" do
      allow(Person).to receive(:table_name).and_return("people")
      expect(subject).to receive(:next_id).with(hash_including(:table => "people"))
      subject.next_for(Person)
    end

    it "returns uniq ids" do
      ids = 10.times.inject([]) do |ids|
        ids << subject.next_for(Person)
      end

      expect(ids).to eq ids.uniq
    end
  end

  describe ".next_for" do
    it "delegates to it's instance" do
      expect(subject).to receive(:next_for).with("cars")
      described_class.next_for("cars")
    end
  end
end
