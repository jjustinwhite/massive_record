require 'spec_helper'
require 'orm/models/person'

describe MassiveRecord::ORM::Relations::Metadata do
  subject { MassiveRecord::ORM::Relations::Metadata.new(nil) }

  %w(name foreign_key class_name relation_type find_with polymorphic records_starts_from inverse_of).each do |attr|
    it { should respond_to attr }
    it { should respond_to attr+"=" }
  end


  it "should be setting values by initializer" do
    metadata = subject.class.new(:car, {
      :foreign_key => :my_car_id, :class_name => "Vehicle", :store_in => :info,
      :polymorphic => true, :records_starts_from => :records_starts_from, :inverse_of => :inverse_of
    })
    expect(metadata.name).to eq("car")
    expect(metadata.foreign_key).to eq("my_car_id")
    expect(metadata.class_name).to eq("Vehicle")
    expect(metadata.store_in).to eq("info")
    expect(metadata.records_starts_from).to eq(:records_starts_from)
    expect(metadata.inverse_of).to eq 'inverse_of'
    expect(metadata).to be_polymorphic
  end

  it "should not be possible to set relation type through initializer" do
    metadata = subject.class.new :car, :relation_type => :foo
    expect(metadata.relation_type).to be_nil
  end


  describe '#name' do
    subject { super().name }
    it { should be_nil }
  end

  it "should return name as string" do
    subject.name = :foo
    expect(subject.name).to eq("foo")
  end


  describe "#class_name" do
    it "should return whatever it's being set to" do
      subject.class_name = "Person"
      expect(subject.class_name).to eq("Person")
    end

    it "should return class name as a string" do
      subject.class_name = Person
      expect(subject.class_name).to eq("Person")
    end

    it "should calculate it from name" do
      subject.name = :employee
      expect(subject.class_name).to eq("Employee")
    end

    it "should calculate correct class name if represents a collection" do
      subject.relation_type = "references_many"
      subject.name = "persons"
      expect(subject.class_name).to eq("Person")
    end
  end




  describe "#foreign_key" do
    it "should return whatever it's being set to" do
      subject.foreign_key = "person_id"
      expect(subject.foreign_key).to eq("person_id")
    end

    it "should return foreign key as string" do
      subject.foreign_key = :person_id
      expect(subject.foreign_key).to eq("person_id")
    end

    it "should try and calculate the foreign key from the name" do
      subject.class_name = "PersonWithSomething"
      subject.name = :person
      expect(subject.foreign_key).to eq("person_id")
    end

    it "should return plural for if meta data is representing a many relation" do
      subject.relation_type = :references_many
      subject.name = :persons
      expect(subject.foreign_key).to eq("person_ids")
    end
  end

  describe "#foreign_key_setter" do
    it "should return whatever the foreign_key is pluss =" do
      expect(subject).to receive(:foreign_key).and_return("custom_key")
      expect(subject.foreign_key_setter).to eq("custom_key=")
    end
  end

  describe "#embedded?" do
    %w(references_one references_one_polymorphic, references_many).each do |type|
      context type do
        before { subject.relation_type = type }

        describe '#embedded?' do
          subject { super().embedded? }
          it { should be_false }
        end
      end
    end

    %w(embeds_many).each do |type|
      context type do
        before { subject.relation_type = type }

        describe '#embedded?' do
          subject { super().embedded? }
          it { should be_true }
        end
      end
    end
  end

  describe "#store_in" do
    context "references" do
      before { subject.relation_type = :references_many }

      describe '#store_in' do
        subject { super().store_in }
        it { should be_nil }
      end

      it "should be able to set column family to store foreign key in" do
        subject.store_in = :info
        expect(subject.store_in).to eq("info")
      end

      it "should know its persisting foreign key if foreign key stored in has been set" do
        subject.store_in = :info
        should be_persisting_foreign_key
      end

      it "should not be storing the foreign key if records_starts_from is defined" do
        subject.store_in = :info
        subject.records_starts_from = :method_which_returns_a_starting_point
        should_not be_persisting_foreign_key
      end
    end

    context "embedded" do
      before do
        subject.name = :addresses
        subject.relation_type = :embeds_many
      end

      describe '#store_in' do
        subject { super().store_in }
        it { should eq "addresses" }
      end

      describe '#persisting_foreign_key?' do
        subject { super().persisting_foreign_key? }
        it { should be_false }
      end
    end
  end


  describe "owner_class" do
    it "is settable" do
      subject.owner_class = Address
    end

    it "is readable" do
      subject.owner_class = Address
      expect(subject.owner_class).to eq(Address)
    end
  end

  describe "#inverse_of" do
    it "returns whatever it is set to" do
      subject.inverse_of = :addresses
      expect(subject.inverse_of).to eq 'addresses'
    end

    it "calculates inverse of from the owner_class for embedded_in" do
      subject.relation_type = :embedded_in
      subject.owner_class = Address
      expect(subject.inverse_of).to eq 'addresses'
    end

    it "calculates inverse of from the owner_class for embedded_in" do
      subject.relation_type = :embedded_in
      subject.owner_class = AddressWithTimestamp
      expect(subject.inverse_of).to eq 'address_with_timestamps'
    end

    it "calculates inverse of from the owner_class for embeds_many" do
      subject.relation_type = :embeds_many
      subject.owner_class = Person
      expect(subject.inverse_of).to eq 'person'
    end

    it "raises an error if not set nor owner class" do
      subject.inverse_of = nil
      subject.owner_class = nil
      expect { subject.inverse_of }.to raise_error "Can't return inverse of without it being explicitly set or without an owner_class"
    end
  end



  it "should compare two meta datas based on name" do
    other = MassiveRecord::ORM::Relations::Metadata.new(subject.name)
    expect(other).to eq(subject)
  end

  it "should have the same hash value for the same name" do
    subject.hash == subject.name.hash
  end



  describe "#new_relation_proxy" do
    let(:proxy_owner) { Person.new }
    let(:proxy) { subject.relation_type = "references_one" and subject.new_relation_proxy(proxy_owner) }

    it "should return a proxy where proxy_owner is assigned" do
      expect(proxy.proxy_owner).to eq(proxy_owner)
    end

    it "should return a proxy where metadata is assigned" do
      expect(proxy.metadata).to eq(subject)
    end

    it "should append _polymorphic to the proxy name if it is polymorphic" do
      subject.polymorphic = true
      subject.relation_type = "references_one"
      expect(subject.relation_type).to eq("references_one_polymorphic")
    end
  end


  describe "#polymorphic_type_column" do
    before do
      subject.polymorphic = true
    end

    it "should remove _id and add _type to foreign_key" do
      expect(subject).to receive(:foreign_key).and_return("foo_id")
      expect(subject.polymorphic_type_column).to eq("foo_type")
    end

    it "should simply add _type if foreign_key does not end on _id" do
      expect(subject).to receive(:foreign_key).and_return("foo_id_b")
      expect(subject.polymorphic_type_column).to eq("foo_id_b_type")
    end

    it "should return setter method" do
      expect(subject).to receive(:polymorphic_type_column).and_return("yey")
      expect(subject.polymorphic_type_column_setter).to eq("yey=")
    end
  end


  describe "records_starts_from" do
    it "should not have any proc if records_starts_from is nil" do
      subject.find_with = "foo"
      subject.records_starts_from = nil
      expect(subject.find_with).to be_nil
    end

    it "should buld a proc with records_starts_from set" do
      subject.records_starts_from = :friends_records_starts_from_id
      expect(subject.find_with).to be_instance_of Proc
    end

    describe "proc" do
      let(:proxy_owner) { Person.new "person-1" }
      let(:find_with_proc) { subject.records_starts_from = :friends_records_starts_from_id; subject.find_with }

      before do
        subject.class_name = "Person"
      end

      it "should call proxy_target class with all, start with proxy_owner's start from id response" do
        expect(Person).to receive(:all).with(hash_including(:starts_with => proxy_owner.friends_records_starts_from_id))
        find_with_proc.call(proxy_owner)
      end

      it "should be possible to send in options to the proc" do
        expect(Person).to receive(:all).with(hash_including(:limit => 10, :starts_with => proxy_owner.friends_records_starts_from_id))
        find_with_proc.call(proxy_owner, {:limit => 10})
      end
    end
  end
end
