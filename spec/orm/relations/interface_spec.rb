require 'spec_helper'
require 'orm/models/person'
require 'orm/models/person_with_timestamp'

describe MassiveRecord::ORM::Relations::Interface do
  include SetUpHbaseConnectionBeforeAll 
  include SetTableNamesToTestTable

  describe "class methods" do
    subject { Person }

    describe "should include" do
      %w(references_one).each do |relation|
        it { is_expected.to respond_to relation }
      end
    end

    it "should not share relations" do
      expect(Person.relations).not_to eq(PersonWithTimestamp.relations)
    end
  end


  describe "references one" do
    describe "relation's meta data" do
      subject { Person.relations.detect { |relation| relation.name == "boss" } }

      it "should have the reference one meta data stored in relations" do
        expect(Person.relations.detect { |relation| relation.name == "boss" }).not_to be_nil
      end

      it "should have type set to references_one" do
        expect(subject.relation_type).to eq("references_one")
      end

      it "should raise an error if the same relaton is called for twice" do
        expect { Person.references_one :boss }.to raise_error MassiveRecord::ORM::RelationAlreadyDefined
      end
    end


    describe "instance" do
      subject { Person.new }
      let(:boss) { PersonWithTimestamp.new }
      let(:proxy) { subject.send(:relation_proxy, "boss") }

      it { is_expected.to respond_to :boss }
      it { is_expected.to respond_to :boss= }
      it { is_expected.to respond_to :boss_id }
      it { is_expected.to respond_to :boss_id= }


      describe "record getter and setter" do
        it "should return nil if foreign_key is nil" do
          expect(subject.boss).to be_nil 
        end

        it "should return the proxy's proxy_target if boss is set" do
          subject.boss = boss
          expect(subject.boss).to eq(boss)
        end

        it "should be able to reset the proxy" do
          expect(proxy).to receive(:load_proxy_target).and_return(true)
          expect(proxy).to receive(:reset) 
          subject.boss.reset
        end

        it "should be able to reload the proxy" do
          expect(proxy).to receive(:load_proxy_target).and_return(true)
          expect(proxy).to receive(:reload)
          subject.boss.reload
        end

        it "should set the foreign_key in proxy_owner when proxy_target is set" do
          subject.boss = boss
          expect(subject.boss_id).to eq(boss.id)
        end

        it "should load proxy_target object when read method is called" do
          expect(PersonWithTimestamp).to receive(:find).and_return(boss)
          subject.boss_id = boss.id
          expect(subject.boss).to eq(boss)
        end

        it "should not load proxy_target twice" do
          expect(PersonWithTimestamp).to receive(:find).once.and_return(boss)
          subject.boss_id = boss.id
          2.times { subject.boss }
        end
      end


      it "should be assignable in initializer" do
        person = Person.new :boss => boss
        expect(person.boss).to eq(boss)
      end
    end
  end


  describe "references one polymorphic" do
    describe "relation's meta data" do
      subject { TestClass.relations.detect { |relation| relation.name == "attachable" } }

      it "should have the reference one polymorphic meta data stored in relations" do
        expect(TestClass.relations.detect { |relation| relation.name == "attachable" }).not_to be_nil
      end

      it "should have type set to correct type" do
        expect(subject.relation_type).to eq("references_one_polymorphic")
      end

      it "should raise an error if the same relaton is called for twice" do
        expect { TestClass.references_one :attachable }.to raise_error MassiveRecord::ORM::RelationAlreadyDefined
      end
    end


    describe "instance" do
      subject { TestClass.new }
      let(:attachable) { Person.new }

      it { is_expected.to respond_to :attachable }
      it { is_expected.to respond_to :attachable= }
      it { is_expected.to respond_to :attachable_id }
      it { is_expected.to respond_to :attachable_id= }
      it { is_expected.to respond_to :attachable_type }
      it { is_expected.to respond_to :attachable_type= }


      describe "record getter and setter" do
        it "should return nil if foreign_key is nil" do
          expect(subject.attachable).to be_nil 
        end

        it "should return the proxy's proxy_target if attachable is set" do
          subject.attachable = attachable
          expect(subject.attachable).to eq(attachable)
        end

        it "should set the foreign_key in proxy_owner when proxy_target is set" do
          subject.attachable = attachable
          expect(subject.attachable_id).to eq(attachable.id)
        end

        it "should set the type in proxy_owner when proxy_target is set" do
          subject.attachable = attachable
          expect(subject.attachable_type).to eq(attachable.class.to_s)
        end



        [Person, PersonWithTimestamp].each do |polymorphic_class|
          describe "polymorphic association to class #{polymorphic_class}" do
            let (:attachable) { polymorphic_class.new "ID1" }

            before do
              subject.attachable_id = attachable.id
              subject.attachable_type = polymorphic_class.to_s.underscore
            end

            it "should load proxy_target object when read method is called" do
              expect(polymorphic_class).to receive(:find).and_return(attachable)
              expect(subject.attachable).to eq(attachable)
            end

            it "should not load proxy_target twice" do
              expect(polymorphic_class).to receive(:find).once.and_return(attachable)
              2.times { subject.attachable }
            end
          end
        end
      end
    end
  end




  describe "references many" do
    describe "relation's meta data" do
      subject { Person.relations.detect { |relation| relation.name == "test_classes" } }

      it "should have the reference one meta data stored in relations" do
        expect(Person.relations.detect { |relation| relation.name == "test_classes" }).not_to be_nil
      end

      it "should have type set to references_many" do
        expect(subject.relation_type).to eq("references_many")
      end

      it "should raise an error if the same relaton is called for twice" do
        expect { Person.references_one :test_classes }.to raise_error MassiveRecord::ORM::RelationAlreadyDefined
      end
    end


    describe "instance" do
      subject { Person.new }
      let(:test_class) { TestClass.new }
      let(:proxy) { subject.send(:relation_proxy, "test_classes") }

      it { is_expected.to respond_to :test_classes }
      it { is_expected.to respond_to :test_classes= }
      it { is_expected.to respond_to :test_class_ids }
      it { is_expected.to respond_to :test_class_ids= }

      it "should have an array as foreign_key attribute" do
        expect(subject.test_class_ids).to be_instance_of Array
      end

      it "should be assignable" do
        subject.test_classes = [test_class]
        expect(subject.test_classes).to eq([test_class])
      end

      it "should be assignable in initializer" do
        person = Person.new :test_classes => [test_class]
        expect(person.test_classes).to eq([test_class])
      end
    end
  end


  describe "embeds many" do
    context "inside of it's own column family" do
      describe "relation's meta data" do
        subject { Person.relations.detect { |relation| relation.name == "addresses" } }

        it "stores the relation on the class" do
          expect(Person.relations.detect { |relation| relation.name == "addresses" }).not_to be_nil
        end

        it "has correct type on relation" do
          expect(subject.relation_type).to eq("embeds_many")
        end

        it "raises error if relation defined twice" do
          expect { Person.embeds_many :addresses }.to raise_error MassiveRecord::ORM::RelationAlreadyDefined
        end
      end

      describe "instance" do
        subject { Person.new :name => "Thorbjorn", :email => "thhermansen@skalar.no", :age => 30 }
        let(:address) { Address.new :street => "Asker" }
        let(:proxy) { subject.send(:relation_proxy, "addresses") }

        it { is_expected.to respond_to :addresses }

        it "should be empty when no addresses has been added" do
          expect(subject.addresses).to be_empty
        end

        it "has a known column family for the embedded records" do
          expect(subject.column_families.collect(&:name)).to include "addresses"
        end

        it "is assignable" do
          subject.addresses = [address]
          expect(subject.addresses).to eq([address])
        end

        it "is assignable in initializer" do
          person = Person.new :addresses => [address]
          expect(person.addresses).to eq([address])
        end

        it "parent is invalid when one of embedded records is" do
          subject.addresses << address
          subject.save!
          address.street = nil
          expect(subject).not_to be_valid
        end
      end
    end

    context "inside of a shared column family" do
      describe "relation's meta data" do
        subject { Person.relations.detect { |relation| relation.name == "cars" } }

        it "stores the relation on the class" do
          expect(Person.relations.detect { |relation| relation.name == "cars" }).not_to be_nil
        end

        it "has correct type on relation" do
          expect(subject.relation_type).to eq("embeds_many")
        end

        it "raises error if relation defined twice" do
          expect { Person.embeds_many :cars }.to raise_error MassiveRecord::ORM::RelationAlreadyDefined
        end
      end

      describe "instance" do
        subject { Person.new :name => "Thorbjorn", :email => "thhermansen@skalar.no", :age => 30 }
        let(:car) { Car.new :color => "blue" }
        let(:proxy) { subject.send(:relation_proxy, "cars") }

        it { is_expected.to respond_to :cars }

        it "should be empty when no cars has been added" do
          expect(subject.cars).to be_empty
        end

        it "has a known column family for the embedded records" do
          expect(subject.column_families.collect(&:name)).to include "info"
        end

        it "is assignable" do
          subject.cars = [car]
          expect(subject.cars).to eq([car])
        end

        it "is assignable in initializer" do
          person = Person.new :cars => [car]
          expect(person.cars).to eq([car])
        end

        it "is persistable" do
          subject.cars << car
          subject.save!
          from_database = Person.find subject.id

          expect(from_database.name).to eq subject.name
          expect(from_database.email).to eq subject.email
          expect(from_database.age).to eq subject.age

          expect(from_database.cars).to eq subject.cars
        end
      end
    end
  end


  describe "embedded in" do
    describe "non polymorphism" do
      describe "metadata" do
        subject { Address.relations.detect { |relation| relation.name == "person" } }

        it "stores the relation on the class" do
          expect(subject).not_to be_nil
        end

        it "has correct type on relation" do
          expect(subject.relation_type).to eq("embedded_in")
        end

        it "raises error if relation defined twice" do
          expect { Address.embedded_in :person }.to raise_error MassiveRecord::ORM::RelationAlreadyDefined
        end
      end

      describe "instance" do
        subject { Address.new "id1", :street => "Asker" }
        let(:person) { Person.new "person-id-1", :name => "Test", :age => 29 }
        let(:proxy) { subject.send(:relation_proxy, "person") }

        it "sets and gets the person" do
          subject.person = person
          expect(subject.person).to eq person
        end

        it "adds itself to the collection within the target's class" do
          allow(person).to receive(:valid?).and_return true
          subject.person = person
          expect(person.addresses).to include subject
        end

        it "assigns embedded in attributes with initialize" do
          address = Address.new "id1", :person => person, :street => "Asker"
          expect(address.person).to eq person
          expect(person.addresses).to include address
        end
      end
    end

    describe "polymorphism" do
      describe "metadata" do
        subject { Address.relations.detect { |relation| relation.name == "addressable" } }

        it "stores the relation on the class" do
          expect(subject).not_to be_nil
        end

        it "has correct type on relation" do
          expect(subject.relation_type).to eq("embedded_in_polymorphic")
        end

        it "raises error if relation defined twice" do
          expect { Address.embedded_in :addressable }.to raise_error MassiveRecord::ORM::RelationAlreadyDefined
        end
      end

      describe "instance" do
        subject { Address.new "id1", :street => "Asker" }
        let(:test_class) { TestClass.new }
        let(:proxy) { subject.send(:relation_proxy, "addressable") }

        it "sets and gets the test class" do
          subject.addressable = test_class
          expect(subject.addressable).to eq test_class
        end

        it "adds itself to the collection within the target's class" do
          subject.addressable = test_class
          expect(test_class.addresses).to include subject
        end
      end
    end
  end
end
