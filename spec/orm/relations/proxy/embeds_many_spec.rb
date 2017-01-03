require 'spec_helper'

class TestEmbedsManyProxy < MassiveRecord::ORM::Relations::Proxy::EmbedsMany; end

describe TestEmbedsManyProxy do
  include SetUpHbaseConnectionBeforeAll 
  include SetTableNamesToTestTable

  let(:proxy_owner) { Person.new "person-id-1", :name => "Test", :age => 29 }
  let(:proxy_target) { Address.new "address-1", :street => "Asker", :number => 1 }
  let(:proxy_target_2) { Address.new "address-2", :street => "Asker", :number => 2 }
  let(:proxy_target_3) { Address.new "address-3", :street => "Asker", :number => 3 }
  let(:metadata) { subject.metadata }

  let(:raw_data) do
    {
      proxy_target.database_id => MassiveRecord::ORM::RawData.new(value: proxy_target.attributes_db_raw_data_hash, created_at: Time.now),
      proxy_target_2.database_id => MassiveRecord::ORM::RawData.new(value: proxy_target_2.attributes_db_raw_data_hash, created_at: Time.now),
      proxy_target_3.database_id => MassiveRecord::ORM::RawData.new(value: proxy_target_3.attributes_db_raw_data_hash, created_at: Time.now),
    }
  end

  let(:raw_data_transformed_ids) do
    Hash[raw_data.collect do |database_id, value|
      [MassiveRecord::ORM::Embedded.parse_database_id(database_id)[1], value]
    end]
  end


  subject { proxy_owner.send(:relation_proxy, 'addresses') }


  it_should_behave_like "relation proxy"



  describe "#proxy_targets_raw" do
    it "is a hash" do
      expect(subject.proxy_targets_raw).to be_instance_of Hash
    end

    context "proxy owner is new record" do
      describe '#proxy_targets_raw' do
        subject { super().proxy_targets_raw }
        it { should be_empty }
      end
    end

    context "proxy owner is saved and has records" do
      before do
        proxy_owner.instance_variable_set(:@raw_data, {'addresses' => raw_data})
      end

      it "includes raw data from database" do
        expect(subject.proxy_targets_raw).to eq raw_data_transformed_ids
      end

      it "ignores values which keys does not seem to be parsable" do
        raw_data_with_name = proxy_owner.instance_variable_get(:@raw_data)['addresses'].merge({'name' => 'Thorbjorn'})

        proxy_owner.instance_variable_set(:@raw_data, {'addresses' => raw_data_with_name})
        expect(subject.proxy_targets_raw).to eq raw_data_transformed_ids
      end

      it "ignores values which kees seems to belong to other collections" do
        raw_data_with_car = proxy_owner.instance_variable_get(:@raw_data)['addresses'].merge(
          {"car#{MassiveRecord::ORM::Embedded::DATABASE_ID_SEPARATOR}123" => MassiveRecord::ORM::RawData.new(value: Car.new.attributes_db_raw_data_hash, created_at: Time.now)
        })

        proxy_owner.instance_variable_set(:@raw_data, {'addresses' => raw_data_with_car})
        expect(subject.proxy_targets_raw).to eq raw_data_transformed_ids
      end
    end
  end

  describe "#reload" do
    it "forces the raw data to be reloaded from database" do
      expect(subject).to receive(:reload_raw_data)
      subject.reload
    end
  end

  describe "#reload_raw_data" do
    before do
      subject << proxy_target
      subject << proxy_target_2
    end

    it "loads only the raw data" do
      proxy_owner.save!
      proxy_owner.raw_data[metadata.store_in] = {}
      subject.send(:reload_raw_data)
      expect(Hash[proxy_owner.raw_data[metadata.store_in].collect { |k,v| [k, v.to_s] }]).to eq({
        "address#{MassiveRecord::ORM::Embedded::DATABASE_ID_SEPARATOR}address-1" => "{\"street\":\"Asker\",\"number\":1,\"nice_place\":\"true\",\"postal_code\":null}",
        "address#{MassiveRecord::ORM::Embedded::DATABASE_ID_SEPARATOR}address-2" => "{\"street\":\"Asker\",\"number\":2,\"nice_place\":\"true\",\"postal_code\":null}"
      })
    end

    it "does nothing if proxy_owner is not persisted" do
      proxy_owner.raw_data[metadata.store_in] = {}
      subject.send(:reload_raw_data)
      expect(proxy_owner.raw_data[metadata.store_in]).to eq({})
    end
  end


  describe "adding records to collection" do
    [:<<, :push, :concat].each do |add_method|
      describe "by ##{add_method}" do
        it "includes added record in proxy target" do
          subject.send add_method, proxy_target
          expect(subject.proxy_target).to include proxy_target
        end

        it "returns self so you can chain calls" do
          subject.send(add_method, proxy_target).send(add_method, proxy_target_2)
          expect(subject.proxy_target).to include proxy_target, proxy_target_2
        end

        it "saves proxy owner if it is already persisted" do
          allow(proxy_owner).to receive(:persisted?).and_return true
          expect(proxy_owner).to receive(:save).once
          subject.send add_method, proxy_target
        end

        it "does not save added records if owner is not persisted" do
          subject.send add_method, proxy_target
          expect(proxy_target).to be_new_record
        end

        it "is possible to add invalid record if parent is not persisted" do
          subject.send add_method, proxy_target
          expect(subject).to include proxy_target
        end

        it "accepts invalid records, but does not save them" do
          proxy_owner.save
          expect(proxy_target).to receive(:valid?).and_return false
          subject.send add_method, proxy_target
          expect(subject).to include proxy_target
          expect(proxy_target).to be_new_record
        end


        it "saves proxy target if it is a new record" do
          proxy_owner.save
          subject.send add_method, proxy_target
          expect(proxy_target).to be_persisted
        end

        it "does not add existing records" do
          2.times { subject.send add_method, proxy_target }
          expect(subject.proxy_target.length).to eq 1
        end

        it "raises an error if there is a type mismatch" do
          expect { subject.send add_method, Person.new(:name => "Foo", :age => 2) }.to raise_error MassiveRecord::ORM::RelationTypeMismatch
        end

        it "sets the inverse of relation in target" do
          subject.send add_method, proxy_target
          expect(proxy_target.person).to eq proxy_owner
        end
      end
    end
  end

  describe "#destroy" do
    before do
      subject << proxy_target << proxy_target_2 << proxy_target_3
      proxy_owner.save!
    end

    it "destroys one record" do
      subject.destroy(proxy_target)
      expect(subject).not_to include proxy_target
    end

    it "destroys multiple records" do
      subject.destroy(proxy_target, proxy_target_2)
      expect(subject).not_to include proxy_target, proxy_target_2
    end

    it "is destroyed from the database as well" do
      subject.destroy(proxy_target)
      subject.reload
      expect(subject).not_to include proxy_target
    end

    it "makes destroyed objects know about it after being destroyed" do
      subject.destroy(proxy_target)
      expect(proxy_target).to be_destroyed
    end

    it "does not call save on proxy owner if it is not persisted" do
      expect(proxy_owner).to receive(:persisted?).and_return false
      expect(proxy_owner).not_to receive(:save)
      subject.destroy(proxy_target)
    end
  end

  describe "#destroy_all" do
    before do
      subject << proxy_target << proxy_target_2 << proxy_target_3
      proxy_owner.save!
    end

    it "destroys all records" do
      subject.destroy_all
      expect(subject).not_to include proxy_target, proxy_target_2, proxy_target_3
    end

    it "returns all destroyed records" do
      removed = subject.destroy_all
      expect(removed).to include proxy_target, proxy_target_2, proxy_target_3
      removed.each { |r| expect(r).to be_destroyed }
    end
  end

  describe "#delete" do
    before do
      subject << proxy_target
      subject << proxy_target_2
      subject << proxy_target_3
      proxy_owner.save!
    end

    it "deletes one record from the collection" do
      subject.delete(proxy_target)
      expect(subject).not_to include proxy_target
    end

    it "deletes multiple records from collection" do
      subject.delete(proxy_target, proxy_target_2)
      expect(subject).not_to include proxy_target, proxy_target_2
    end

    it "is not destroyed from the database as well" do
      subject.delete(proxy_target)
      subject.reload
      expect(subject).to include proxy_target
    end

    it "makes deleted objects not know about it after being deleted" do
      subject.delete(proxy_target)
      expect(proxy_target).not_to be_destroyed
    end

    it "is being destroyed if parent are saved" do
      subject.delete(proxy_target)
      proxy_owner.save
      subject.reload
      expect(subject).not_to include proxy_target
    end

    it "is being destroed on save" do
      subject.delete(proxy_target)
      proxy_owner.save
      expect(proxy_target).to be_destroyed
    end
  end

  describe "#delete_all" do
    before do
      subject << proxy_target << proxy_target_2 << proxy_target_3
      proxy_owner.save!
    end

    it "deletes all records" do
      subject.delete_all
      expect(subject).not_to include proxy_target, proxy_target_2, proxy_target_3
    end

    it "returns all removed records" do
      removed = subject.delete_all
      expect(removed).to include proxy_target, proxy_target_2, proxy_target_3
      removed.each { |r| expect(r).not_to be_destroyed }
    end
  end


  describe "#can_find_proxy_target?" do
    it "is true" do
      expect(subject).to be_can_find_proxy_target
    end
  end


  describe "#find" do
    let(:not_among_targets) { proxy_target_3 }

    context "owner persisted" do
      before { proxy_owner.save! }

      context "and proxy loaded" do
        before do
          subject.concat proxy_target, proxy_target_2
        end

        it "finds record by id" do
          expect(subject.find(proxy_target.id)).to eq proxy_target
        end

        it "finds records which are not new records" do
          expect(subject.find(proxy_target.id)).to be_persisted
        end

        it "does not call load_proxy_target" do
          expect(subject).not_to receive :load_proxy_target
          subject.find(proxy_target.id)
        end

        it "raises error if record is not found" do
          expect { subject.find(not_among_targets.id) }.to raise_error MassiveRecord::ORM::RecordNotFound
        end
      end

      context "and proxy not loaded" do
        before do
          subject.concat proxy_target, proxy_target_2
          subject.reset
        end

        context "with raw data loaded" do
          it "finds record by id" do
            expect(subject.find(proxy_target.id)).to eq proxy_target
          end

          it "does not load from target's class.table.get" do
            expect(subject).not_to receive(:find_raw_data_for_id)
            expect(subject.find(proxy_target.id)).to eq proxy_target
          end

          it "raises error if record is not found" do
            expect { subject.find(not_among_targets.id) }.to raise_error MassiveRecord::ORM::RecordNotFound
          end
        end

        context "without raw data loaded" do
          before { proxy_owner.update_raw_data_for_column_family(metadata.store_in, {}) }

          it "finds record by id" do
            expect(subject.find(proxy_target.id)).to eq proxy_target
          end

          it "does not call load_proxy_target" do
            expect(subject).not_to receive(:load_proxy_target)
            subject.find(proxy_target.id)
          end

          it "raises error if record is not found" do
            expect { subject.find(not_among_targets.id) }.to raise_error MassiveRecord::ORM::RecordNotFound
          end
        end
      end
    end

    context "owner new record" do
      it "finds the added record" do
        subject << proxy_target
        expect(subject.find(proxy_target.id)).to eq proxy_target
      end
    end
  end


  describe "#limit" do
    before do
      subject << proxy_target_2
      subject << proxy_target_3
      subject << proxy_target
    end

    context "owner persisted" do
      before { proxy_owner.save! }

      context "and proxy loaded" do
        it "returns the two first records" do
          expect(subject.limit(2)).to eq [proxy_target, proxy_target_2]
        end

        it "does not call load_proxy_target" do
          expect(subject).not_to receive :find_proxy_target
          subject.limit(2)
        end
      end

      context "and proxy not loaded" do
        before do
          subject.reset
        end

        context "with raw data loaded" do
          it "returns the two first records" do
            expect(subject.limit(2)).to eq [proxy_target, proxy_target_2]
          end
        end

        context "without raw data loaded" do
          before { proxy_owner.update_raw_data_for_column_family(metadata.store_in, {}) }

          it "returns the two first records" do
            expect(subject.limit(2)).to eq [proxy_target, proxy_target_2]
          end
        end
      end
    end

    context "owner new record" do
      it "returns the two first records" do
        expect(subject.limit(2)).to eq [proxy_target, proxy_target_2]
      end
    end
  end


  describe "#load_proxy_target" do
    context "empty proxy targets raw" do
      before { proxy_owner.instance_variable_set(:@raw_data, {'addresses' => {}}) }

      describe '#load_proxy_target' do
        subject { super().load_proxy_target }
        it { should eq [] }
      end

      it "includes added records to collection" do
        subject << proxy_target
        expect(subject.load_proxy_target).to include proxy_target
      end
    end

    context "filled proxy_targets_raw" do
      before { proxy_owner.instance_variable_set(:@raw_data, {'addresses' => raw_data}) }

      describe '#load_proxy_target' do
        subject { super().load_proxy_target }
        it { should include proxy_target, proxy_target_2, proxy_target_3 }
      end

      it "sets inverse of in loaded records" do
        expect(subject.load_proxy_target.all? { |r| expect(r.person).to eq proxy_owner }).to be_true
      end
    end
  end




  describe "#parent_will_be_saved!" do
    describe "building of proxy_target_update_hash" do
      before do
        proxy_owner.save!
      end

      context "no changes" do
        before do
          subject << proxy_target
          expect(proxy_target).to receive(:destroyed?).and_return false
          expect(proxy_target).to receive(:new_record?).and_return false
          expect(proxy_target).to receive(:changed?).and_return false

          subject.parent_will_be_saved!
        end

        describe '#proxy_targets_update_hash' do
          subject { super().proxy_targets_update_hash }
          it { should be_empty }
        end
      end

      context "insert" do
        before do
          subject << proxy_target
          expect(proxy_target).to receive(:destroyed?).and_return false
          allow(proxy_target).to receive(:new_record?).and_return true
          expect(proxy_target).not_to receive(:changed?)

          subject.parent_will_be_saved!
        end

        it "includes id for record to be inserted" do
          expect(subject.proxy_targets_update_hash.keys).to eq [proxy_target.database_id]
        end

        it "includes attributes for record to be inserted" do
          expect(subject.proxy_targets_update_hash.values).to eq [MassiveRecord::ORM::Base.coder.dump(proxy_target.attributes_db_raw_data_hash)]
        end
      end

      context "update" do
        before do
          subject << proxy_target
          expect(proxy_target).to receive(:destroyed?).and_return false
          allow(proxy_target).to receive(:new_record?).and_return false
          expect(proxy_target).to receive(:changed?).and_return true

          subject.parent_will_be_saved!
        end

        it "includes id for record to be updated" do
          expect(subject.proxy_targets_update_hash.keys).to eq [proxy_target.database_id]
        end

        it "includes attributes for record to be updated" do
          expect(subject.proxy_targets_update_hash.values).to eq [MassiveRecord::ORM::Base.coder.dump(proxy_target.attributes_db_raw_data_hash)]
        end
      end

      context "destroy" do
        before do
          subject << proxy_target
        end

        it "includes id for record to be updated" do
          expect(proxy_target).to receive(:destroyed?).and_return true
          subject.parent_will_be_saved!
          expect(subject.proxy_targets_update_hash.keys).to eq [proxy_target.database_id]
        end

        it "includes attributes for record to be updated" do
          expect(proxy_target).to receive(:destroyed?).and_return true
          subject.parent_will_be_saved!
          expect(subject.proxy_targets_update_hash.values).to eq [nil]
        end

        it "includes records in the to_be_destroyed array" do
          # Don't want it to actually trigger save as that will
          # clear out the update hash..
          expect(proxy_owner).to receive(:save).and_return true

          subject.destroy(proxy_target)
          subject.parent_will_be_saved!

          expect(subject.proxy_targets_update_hash.keys).to eq [proxy_target.database_id]
          expect(subject.proxy_targets_update_hash.values).to eq [nil]
        end
      end
    end





    it "marks new records as persisted" do
      subject << proxy_target
      subject.parent_will_be_saved!
      expect(proxy_target).to be_persisted
    end

    it "resets dirty state of records" do
      subject << proxy_target
      proxy_target.street += "_NEW"
      subject.parent_will_be_saved!
      expect(proxy_target).not_to be_changed
    end

    it "marks destroyed objects as destroyed" do
      subject.send(:to_be_destroyed) << proxy_target
      subject.parent_will_be_saved!
      expect(proxy_target).to be_destroyed
    end

    it "does not mark targets as destroyed if target's owner has been changed" do
      subject << proxy_target
      subject.send(:to_be_destroyed) << proxy_target
      proxy_target.person = Person.new
      subject.parent_will_be_saved!
      expect(proxy_target).not_to be_destroyed
    end

    it "clears to_be_destroyed array" do
      subject.send(:to_be_destroyed) << proxy_target
      subject.parent_will_be_saved!
      expect(subject.send(:to_be_destroyed)).to be_empty
    end
  end

  describe "#parent_has_been_saved!" do
    it "clears the proxy_target_update_hash" do
      hash = {}
      expect(hash).to receive :clear
      expect(subject).to receive(:proxy_targets_update_hash).and_return(hash)
      subject.parent_has_been_saved!
    end

    it "reloads raw data" do
      expect(subject).to receive(:reload_raw_data)
      subject.parent_has_been_saved!
    end
  end

  describe "#changed?" do
    before do
      subject << proxy_target
      allow(proxy_target).to receive(:destroyed?).and_return false
      allow(proxy_target).to receive(:new_record?).and_return false
      allow(proxy_target).to receive(:changed?).and_return false
    end

    it "returns false if no changes has been made which needs persistence" do
      should_not be_changed
    end

    it "returns true if it contains new records" do
      expect(proxy_target).to receive(:new_record?).and_return true
      should be_changed
    end

    it "returns true if it contains destroyed records" do
      expect(proxy_target).to receive(:destroyed?).and_return true
      should be_changed
    end

    it "returns true if it contains changed records" do
      expect(proxy_target).to receive(:changed?).and_return true
      should be_changed
    end

    it "returns true if some records has been asked to be destroyed through proxy" do
      subject.destroy(proxy_target)
      should be_changed
    end
  end

  describe "#changes" do
    before do
      proxy_owner.save!
      subject << proxy_target
    end

    it "has no changes when no changes has been made" do
      expect(subject.changes).to be_empty
    end

    it "accumelates the changes for the complete collection" do
      proxy_target.street = proxy_target.street + "_NEW"
      expect(subject.changes).to eq({"address-1" => {"street" => ["Asker", "Asker_NEW"]}})
    end
  end



  describe "sorting of records" do
    describe "when added to a persisted proxy owner" do
      before { proxy_owner.save! }

      it "sorts record when proxy target is loaded" do
        subject << proxy_target_2
        subject << proxy_target
        subject.reload
        expect(subject.load_proxy_target).to eq [proxy_target, proxy_target_2]
      end
    end

    describe "When adding to a proxy owner which is a new record" do
      it "sorts record in expected order" do
        subject << proxy_target_2
        subject << proxy_target
        expect(subject.load_proxy_target).to eq [proxy_target, proxy_target_2]
      end
    end
  end
end
