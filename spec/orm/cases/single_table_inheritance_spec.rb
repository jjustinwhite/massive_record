require 'spec_helper'
require 'orm/models/friend'
require 'orm/models/best_friend'

describe "Single table inheritance" do
  include SetUpHbaseConnectionBeforeAll
  include SetTableNamesToTestTable

  [Friend, BestFriend, BestFriend::SuperBestFriend].each do |klass|
    describe klass do
      let(:subject) { klass.new("ID1", :name => "Person1", :email => "one@person.com", :age => 11, :points => 111, :status => true) }

      describe '#type' do
        subject { super().type }
        it { is_expected.to eq(klass.to_s) }
      end

      it "instantiates correct class when reading from database via super class" do
        subject.save!
        expect(Person.find(subject.id)).to eq(subject)
      end
    end
  end

  it "sets no type when saving base class" do
    person = Person.new "ID1", :name => "Person1", :email => "one@person.com", :age => 11, :points => 111, :status => true
    expect(person.type).to be_nil
  end

  describe "fetching and restrictions" do
    describe "#first" do
      it "returns record if class found is the look-up class" do
        person = Person.create!("ID1", :name => "Person1", :email => "one@person.com", :age => 11, :points => 111, :status => true)
        expect(Person.first).to eq person
      end

      it "returns record if class found is subclass of look up class" do
        friend = Friend.create!("ID1", :name => "Person1", :email => "one@person.com", :age => 11, :points => 111, :status => true)
        expect(Person.first).to eq friend
      end

      it "raises an error if you call first on sub class" do
        expect { Friend.first }.to raise_error MassiveRecord::ORM::SingleTableInheritance::FirstUnsupported
      end

      it "does not raise error if you call first on base class" do
        expect(Person.first).to eq nil
      end
    end

    describe "#all" do
      it "returns [] if class found is a super class of look-up class" do
        Person.create!("ID1", :name => "Person1", :email => "one@person.com", :age => 11, :points => 111, :status => true)
        expect(Friend.all).to eq []
      end

      it "returns record if class found is the look-up class" do
        person = Person.create!("ID1", :name => "Person1", :email => "one@person.com", :age => 11, :points => 111, :status => true)
        expect(Person.all).to eq [person]
      end

      it "returns record if class found is subclass of look up class" do
        friend = Friend.create!("ID1", :name => "Person1", :email => "one@person.com", :age => 11, :points => 111, :status => true)
        expect(Person.all).to eq [friend]
      end

      it "returns record if class found is subclass of look up class, when class is not base class" do
        person = Person.create!("ID1", :name => "Person1", :email => "one@person.com", :age => 11, :points => 111, :status => true)
        friend = Friend.create!("ID2", :name => "Person1", :email => "one@person.com", :age => 11, :points => 111, :status => true)
        best_friend = BestFriend.create!("ID3", :name => "Person1", :email => "one@person.com", :age => 11, :points => 111, :status => true)

        Friend.all.tap do |result|
          expect(result).to include friend, best_friend
          expect(result).not_to include person
        end
      end
    end

    it "does not check kind of records if class is not STI enabled" do
      record = TestClass.create! :foo => 'wee'
      expect(TestClass).not_to receive(:ensure_only_class_or_subclass_of_self_are_returned)
      TestClass.first
    end
  end
end
