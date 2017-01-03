require 'spec_helper'
require 'orm/models/test_class'
require 'orm/models/friend'
require 'orm/models/best_friend'

describe MassiveRecord::ORM::IdentityMap do
  before do
    MassiveRecord::ORM::IdentityMap.clear
    MassiveRecord::ORM::IdentityMap.enabled = true
  end

  after(:all) { MassiveRecord::ORM::IdentityMap.enabled = false }


  describe "class methods" do
    subject { described_class }

    describe "confirguration" do
      describe ".enabled" do
        context "when disabled" do
          before { MassiveRecord::ORM::IdentityMap.enabled = false }

          describe '#enabled' do
            subject { super().enabled }
            it { is_expected.to be_falsey }
          end

          describe '#enabled?' do
            subject { super().enabled? }
            it { is_expected.to be_falsey }
          end
        end

        context "when enabled" do
          before { MassiveRecord::ORM::IdentityMap.enabled = true }

          describe '#enabled' do
            subject { super().enabled }
            it { is_expected.to be_truthy }
          end

          describe '#enabled?' do
            subject { super().enabled? }
            it { is_expected.to be_truthy }
          end
        end
      end

      it ".use sets enabled to true, yield block and ensure to reset it to what it was" do
        MassiveRecord::ORM::IdentityMap.enabled = false

        MassiveRecord::ORM::IdentityMap.use do
          expect(MassiveRecord::ORM::IdentityMap).to be_enabled
        end

        expect(MassiveRecord::ORM::IdentityMap).not_to be_enabled
      end

      it ".without sets enabled to true, yield block and ensure to reset it to what it was" do
        MassiveRecord::ORM::IdentityMap.enabled = true

        MassiveRecord::ORM::IdentityMap.without do
          expect(MassiveRecord::ORM::IdentityMap).not_to be_enabled
        end

        expect(MassiveRecord::ORM::IdentityMap).to be_enabled
      end
    end

    describe "persistence" do
      let(:person) { Person.new "id1" }
      let(:friend) { Friend.new "id2" }
      let(:test_class) { TestClass.new "id2" }

      describe ".repository" do
        describe '#repository' do
          subject { super().repository }
          it { is_expected.to eq Hash.new }
        end

        it "has values as a hash by default for any key" do
          expect(subject.send(:repository)['some_class']).to eq Hash.new
        end
      end

      describe ".clear" do
        it "removes all values from repository" do
          subject.send(:repository)['some_class']['an_id'] = Object.new
          subject.clear
          expect(subject.send(:repository)).to be_empty
        end
      end

      describe ".get" do
        it "raises error if no ids are given" do
          expect { subject.get(person.class) }.to raise_error ArgumentError
        end

        context "when it does not has the record" do
          it "returns nil" do
            expect(subject.get(person.class, person.id)).to be_nil
          end

          it "returns empty array if asked for multiple records" do
            expect(subject.get(person.class, 1, 2)).to eq []
          end
        end

        context "when it has the record" do
          it "returns the record" do
            subject.add person
            expect(subject.get(person.class, person.id)).to eq person
          end

          describe "single table inheritahce" do
            before { subject.add friend }

            it "returns the record when looked up by it's class" do
              expect(subject.get(friend.class, friend.id)).to eq friend
            end

            it "returns the record when looked up by it's parent class" do
              expect(subject.get(person.class, friend.id)).to eq friend
            end

            it "raises an error when you request a parent class via a descendant class" do
              subject.add person
              expect {
                subject.get(friend.class, person.id)
              }.to raise_error MassiveRecord::ORM::IdentityMap::RecordIsSuperClassOfQueriedClass
            end
          end

          describe "get multiple" do
            it "returns multiple records when asked for multiple ids" do
              subject.add person
              subject.add friend
              expect(subject.get(person.class, person.id, friend.id)).to include person, friend
            end

            it "returns multiple records when asked for multiple ids as an array" do
              subject.add person
              subject.add friend
              expect(subject.get(person.class, [person.id, friend.id])).to include person, friend
            end

            it "returns array when get got an array, even with only one id" do
              subject.add friend
              expect(subject.get(person.class, [friend.id])).to eq [friend]
            end

            it "returns nothing for unkown ids" do
              subject.add person
              subject.add friend
              expect(subject.get(person.class, person.id, friend.id, "unkown").length).to eq 2
            end
          end

          it "returns the correct record when they have the same id" do
            person.id = test_class.id = "same_id"

            subject.add(person)
            subject.add(test_class)

            expect(subject.get(person.class, person.id)).to eq person
            expect(subject.get(test_class.class, "same_id")).to eq test_class
          end
        end
      end

      describe ".add" do
        it "does not do anything if trying to add nil" do
          expect(subject.add(nil)).to be_nil
        end

        it "persists the record" do
          subject.add person
          expect(subject.get(person.class, person.id)).to eq person
        end

        it "persists a single table inheritance record" do
          subject.add friend
          expect(subject.get(friend.class, friend.id)).to eq friend
        end
      end

      describe ".remove" do
        it "returns nil if record was not found" do
          expect(subject.remove(person)).to eq nil
        end

        it "removes the record" do
          subject.add person
          subject.remove person
          expect(subject.get(person.class, person.id)).to be_nil
        end

        it "returns the removed record" do
          subject.add person
          expect(subject.remove(person)).to eq person
        end

        it "removes a single table inheritance record" do
          subject.add friend
          subject.remove friend
          expect(subject.get(friend.class, friend.id)).to be_nil
        end
      end

      describe ".remove_by_id" do
        it "removes the record by it's class and id directly" do
          subject.add person
          subject.remove_by_id person.class, person.id
          expect(subject.get(person.class, person.id)).to be_nil
        end

        it "returns the removed record" do
          subject.add person
          expect(subject.remove_by_id(person.class, person.id)).to eq person
        end
      end
    end
  end


  describe "lifecycles on records" do
    include SetUpHbaseConnectionBeforeAll
    include SetTableNamesToTestTable

    let(:id) { "ID1" }
    let(:id_2) { "ID2" }
    let(:person) { Person.create!(id, :name => "Person1", :email => "one@person.com", :age => 11, :points => 111, :status => true) }
    let(:friend) { Friend.create!(id_2, :name => "Person1", :email => "one@person.com", :age => 11, :points => 111, :status => true) }

    describe "#find" do
      describe "one" do
        context "when the record is not in the identity map" do
          it "asks do find for the record" do
            expect(Person).to receive(:do_find).and_return(nil)
            expect(Person.find(id)).to be_nil
          end

          it "adds the found record" do
            MassiveRecord::ORM::IdentityMap.without { person }

            expect(MassiveRecord::ORM::IdentityMap.get(person.class, person.id)).to be_nil
            Person.find(id)
            expect(MassiveRecord::ORM::IdentityMap.get(person.class, person.id)).to eq person
          end
        end

        context "when record is in identity map" do
          before { MassiveRecord::ORM::IdentityMap.add(person) }

          it "returns that record" do
            expect(Person.table).not_to receive(:find)
            expect(Person.find(person.id)).to eq person
          end

          it "returns record from database when select option is used" do
            expect(MassiveRecord::ORM::IdentityMap).not_to receive(:get)
            expect(Person.select(:info).find(person.id)).to eq person
          end

          it "returns record from identity map when you ask for a sub class by its parent class" do
            MassiveRecord::ORM::IdentityMap.add(friend)
            expect(Person.table).not_to receive(:find)
            expect(Person.find(friend.id)).to eq friend
          end

          it "returns nil when you ask for a parent class" do
            expect(Friend.table).not_to receive(:find)
            expect(Friend.find(person.id)).to be_nil
          end
        end
      end

      describe "many" do
        it "returns records from database when select option is used" do
          expect(MassiveRecord::ORM::IdentityMap).not_to receive(:get)
          expect(Person.select(:info).find([person.id, friend.id])).to include person, friend
        end

        context "when no records are in the identity map" do
          it "asks find for the two records" do
            expect(Person).to receive(:do_find).with([id, id_2], anything).and_return []
            expect(Person.find([id, id_2])).to eq []
          end

          it "adds the found recods" do
            MassiveRecord::ORM::IdentityMap.without { person; friend }
            expect(MassiveRecord::ORM::IdentityMap.get(person.class, person.id, friend.id)).to be_empty

            Person.find([id, id_2])
            expect(MassiveRecord::ORM::IdentityMap.get(person.class, person.id, friend.id)).to include person, friend
          end
        end

        context "when all records are in the identity map" do
          before do
            MassiveRecord::ORM::IdentityMap.add(person)
            MassiveRecord::ORM::IdentityMap.add(friend)
          end

          it "returns records from identity map" do
            expect(Person.table).not_to receive(:find)
            Person.find([person.id, friend.id])
          end

          it "returns only records equal to or descendants of queried class" do
            expect(Friend.find([person.id, friend.id])).to eq [friend]
          end
        end

        context "when some records are in the identity map" do
          before do
            MassiveRecord::ORM::IdentityMap.add(person)
            MassiveRecord::ORM::IdentityMap.without { friend }
          end

          it "returns records from identity map" do
            expect(Person).to receive(:query_hbase).with([friend.id], anything).and_return [friend]
            Person.find([person.id, friend.id])
          end
        end
      end
    end

    describe "#save" do
      context "a new record" do
        it "adds the record to the identity map after being created" do
          person
          expect(Person.table).not_to receive(:find)
          expect(Person.find(person.id)).to eq person
        end

        it "does not add the record if validation fails" do
          invalid_person = Person.create "ID2", :name => "Person2"
          expect(Person).not_to be_exists invalid_person.id
        end
      end
    end

    describe "#destroy" do
      it "removes the record from identiy map" do
        person.destroy
        expect(Person).not_to be_exists person.id
      end
    end

    describe "#destroy_all" do
      it "removes the record from identiy map" do
        person
        Person.destroy_all
        expect(Person).not_to be_exists person.id
      end
    end

    describe "#delete" do
      it "removes the record from identiy map" do
        person.delete
        expect(Person).not_to be_exists person.id
      end
    end

    describe "#reload" do
      it "reloads it's attributes" do
        what_it_was = person.name
        person.name = person.name.reverse

        person.reload
        expect(person.name).to eq what_it_was
      end
    end
  end
end
