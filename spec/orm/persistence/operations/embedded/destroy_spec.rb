require 'spec_helper'

describe MassiveRecord::ORM::Persistence::Operations::Embedded::Destroy do
  include SetUpHbaseConnectionBeforeAll 
  include SetTableNamesToTestTable

  let(:another_address) { Address.new("addresss-id-2", :street => "Asker too", :number => 5) }
  let(:record) { Address.new("addresss-id", :street => "Asker", :number => 5) }
  let(:person) { Person.new "person-id", :name => "Thorbjorn", :age => "22" }
  let(:options) { {:this => 'hash', :has => 'options'} }
  
  subject { described_class.new(record, options) }

  describe "generic behaviour" do
    before { record.person = person }
    it_should_behave_like "a persistence embedded operation class"
  end


  describe "#execute" do
    before do
      record.person = person
      person.save
    end

    context "not embedded" do
      before { record.person = nil }

      it "returns true" do
        expect(subject.execute).to eq true
      end

      it "does not call destroy" do
        subject.execute
        expect(subject).not_to receive(:update_embedded)
      end
    end

    context "embedded" do
      context "collection owner new record" do
        before { record.person = person }

        it "returns true" do
          expect(subject.execute).to eq true
        end

        it "does not call destroy" do
          subject.execute
          expect(subject).not_to receive(:update_embedded)
        end
      end

      context "collection owner persisted" do
        before do
          record.person = person
          person.save!
        end
        
        it "removes record from collection owher" do
          subject.execute
          expect(person.addresses).to be_empty
        end

        it "persists the removal of record from collection owner" do
          subject.execute
          expect(person.reload.addresses).to be_empty
        end
      end
    end
  end
end
