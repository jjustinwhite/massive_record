require 'spec_helper'
require 'orm/models/model_without_default_id'

describe ModelWithoutDefaultId do
  include MockMassiveRecordConnection
  #include SetUpHbaseConnectionBeforeAll
  #include SetTableNamesToTestTable

  context "with auto increment id" do
    describe '#id' do
      subject { super().id }
      it { be_nil }
    end

    describe '#set_id_from_factory_before_create' do
      subject { super().set_id_from_factory_before_create }
      it { be_true }
    end

    it "sets id to what next_id returns" do
      expect(MassiveRecord::ORM::IdFactory::AtomicIncrementation).to receive(:next_for).and_return 1
      subject.save
      expect(subject.id).to eq "1"
    end

    it "does nothing if the id is set before create" do
      subject.id = 2
      expect(MassiveRecord::ORM::IdFactory::AtomicIncrementation).not_to receive(:next_for)
      subject.save
      expect(subject.id).to eq "2"
    end

    it "is configurable which factory to use" do
      id_factory_was = ModelWithoutDefaultId.id_factory
      ModelWithoutDefaultId.id_factory = MassiveRecord::ORM::IdFactory::Timestamp

      expect(MassiveRecord::ORM::IdFactory::Timestamp).to receive(:next_for).and_return 123
      subject.save
      expect(subject.id).to eq "123"

      ModelWithoutDefaultId.id_factory = MassiveRecord::ORM::IdFactory::AtomicIncrementation
    end
  end

  context "without auto increment id" do
    before(:all) { subject.class.set_id_from_factory_before_create = false }
    after(:all) { subject.class.set_id_from_factory_before_create = true }

    describe '#id' do
      subject { super().id }
      it { be_nil }
    end

    describe '#set_id_from_factory_before_create' do
      subject { super().set_id_from_factory_before_create }
      it { be_false }
    end

    it "raises error as expected when id is missing" do
      expect { subject.save }.to raise_error MassiveRecord::ORM::IdMissing
    end
  end

  it "is AtomicIncrementation on ORM::Table" do
    expect(Person.id_factory.instance).to be_instance_of MassiveRecord::ORM::IdFactory::AtomicIncrementation
  end

  it "is Timestamp on ORM::Embedded" do
    expect(Address.id_factory.instance).to be_instance_of MassiveRecord::ORM::IdFactory::Timestamp
  end
end
