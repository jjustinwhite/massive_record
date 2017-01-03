require 'spec_helper'

describe MassiveRecord::ORM::Table do
  include SetUpHbaseConnectionBeforeAll
  include SetTableNamesToTestTable

  let(:old_id) { "old_id" }
  let(:new_id) { "new_id" }

  subject do
    Person.create!(old_id, {
      :name => "Thorbjorn",
      :age => 22,
      :points => 1
    })
  end

  describe "#change_id!" do
    describe "successfully" do
      before do
        subject.change_id! new_id
      end

      describe '#id' do
        subject { super().id }
        it { is_expected.to eq new_id }
      end

      it "saves itself with new id" do
        expect(Person.find(new_id)).to eq subject
      end

      it "has same attributes" do
        expect(Person.find(new_id).attributes).to eq subject.attributes
      end

      it "deletes the old id from the database" do
        expect(Person).not_to be_exists old_id
      end

      describe "with identity map" do
        it "works as expected" do
          MassiveRecord::ORM::IdentityMap.use do
            person = Person.create!("id", {:name => "Thorbjorn", :age => 22, :points => 1})
            person.change_id! "id-2"
            expect(Person.find("id-2")).to eq person
            expect(Person).not_to be_exists "id"
          end
        end
      end
    end

    describe "unsuccessfully" do
      it "raises error if unable to save new id" do
        expect(subject).to receive(:save).and_return false
        expect { subject.change_id! new_id }.to raise_error
      end

      it "raises error if unable to destroy old record" do
        allow_any_instance_of(Person).to receive(:destroy).and_return false
        expect { subject.change_id! new_id }.to raise_error
      end
    end
  end
end
