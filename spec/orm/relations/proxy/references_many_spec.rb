require 'spec_helper'

class TestReferencesManyProxy < MassiveRecord::ORM::Relations::Proxy::ReferencesMany; end

describe TestReferencesManyProxy do
  include SetUpHbaseConnectionBeforeAll 
  include SetTableNamesToTestTable

  let(:proxy_owner) { Person.new "person-id-1", :name => "Test", :age => 29 }
  let(:proxy_target) { TestClass.new "test-class-id-1" }
  let(:proxy_target_2) { TestClass.new "test-class-id-2" }
  let(:proxy_target_3) { TestClass.new "test-class-id-3" }
  let(:metadata) { subject.metadata }

  subject { proxy_owner.send(:relation_proxy, 'test_classes') }

  it_should_behave_like "relation proxy"

  

  describe "#find_proxy_target" do
    describe "with foreig keys stored in proxy_owner" do
      it "should not try to find proxy_target if foreign_keys is blank" do
        proxy_owner.test_class_ids.clear
        expect(TestClass).not_to receive(:find)
        expect(subject.load_proxy_target).to be_empty
      end

      it "should try to load proxy_target if foreign_keys has any keys" do
        proxy_owner.test_class_ids << proxy_target.id
        expect(TestClass).to receive(:find).with([proxy_target.id], anything).and_return([proxy_target])
        expect(subject.load_proxy_target).to eq([proxy_target])
      end

      it "should not die when loading foreign keys which does not exist in proxy_target table" do
        proxy_owner.save!
        proxy_owner.test_classes << proxy_target
        proxy_owner.test_classes.reset
        proxy_owner.test_class_ids << "does_not_exists"
        proxy_owner.test_classes.reload
        expect(proxy_owner.test_classes.length).to eq(1)
      end
    end

    describe "with start from" do
      let(:proxy_target) { Person.new proxy_owner.id+"-friend-1", :name => "T", :age => 2 }
      let(:proxy_target_2) { Person.new proxy_owner.id+"-friend-2", :name => "H", :age => 9 }
      let(:not_proxy_target) { Person.new "foo"+"-friend-2", :name => "H", :age => 1 }
      let(:metadata) { subject.metadata }

      subject { proxy_owner.send(:relation_proxy, 'friends') }

      before do
        proxy_target.save!
        proxy_target_2.save!
        not_proxy_target.save!
      end

      it "should not try to find proxy_target if start from method is blank" do
        expect(proxy_owner).to receive(:friends_records_starts_from_id).and_return(nil)
        expect(Person).not_to receive(:all)
        expect(subject.load_proxy_target).to be_empty
      end

      it "should find all friends when loading" do
        friends = subject.load_proxy_target
        expect(friends.length).to eq(2)
        expect(friends).to include(proxy_target)
        expect(friends).to include(proxy_target_2)
        expect(friends).not_to include(not_proxy_target)
      end
    end
  end

  describe "find with proc" do
    let(:test_class) { TestClass.new }

    before do
      subject.metadata.find_with = Proc.new { |proxy_target| TestClass.find("testing-123") }
    end

    after do
      subject.metadata.find_with = nil
    end

    it "should not call find_proxy_target" do
      should_not_receive :find_proxy_target
      subject.load_proxy_target
    end

    it "should load by given proc" do
      expect(TestClass).to receive(:find).with("testing-123").and_return([test_class])
      expect(subject.load_proxy_target).to eq([test_class])
    end

    it "should always wrap the proc's result in an array" do
      expect(TestClass).to receive(:find).with("testing-123").and_return(test_class)
      expect(subject.load_proxy_target).to eq([test_class])
    end

    it "should be empty if the proc return nil" do
      expect(TestClass).to receive(:find).with("testing-123").and_return(nil)
      expect(subject.load_proxy_target).to be_empty
    end
  end


  describe "#find_in_batches" do
    context "when the proxy is loaded" do
      before do
        proxy_owner.save!
        proxy_owner.test_classes.concat(proxy_target, proxy_target_2, proxy_target_3)
      end

      it "returns records in batches of given size" do
        result = []

        subject.find_in_batches(:batch_size => 1) do |records_batch|
          result << records_batch 
        end

        expect(result).to eq [[proxy_target], [proxy_target_2], [proxy_target_3]]
      end

      it "filters when given :starts_with" do
        proxy_target_3_3 = TestClass.new("test-class-id-3-1")
        proxy_owner.test_classes << proxy_target_3_3

        result = []

        subject.find_in_batches(:batch_size => 1, :starts_with => "test-class-id-3") do |records_batch|
          result << records_batch 
        end

        expect(result).to eq [[proxy_target_3], [proxy_target_3_3]]
      end
    end

    context "when persisted foreign keys" do
      before do
        proxy_owner.save!
        proxy_owner.test_classes.concat(proxy_target, proxy_target_2, proxy_target_3)
        subject.reset
      end

      it "returns records in batches of given size" do
        result = []

        subject.find_in_batches(:batch_size => 1) do |records_batch|
          result << records_batch 
        end

        expect(result).to eq [[proxy_target], [proxy_target_2], [proxy_target_3]]
      end

      it "filters when given :starts_with" do
        proxy_target_3_3 = TestClass.new("test-class-id-3-1")
        proxy_owner.test_classes << proxy_target_3_3
        subject.reset

        result = []

        subject.find_in_batches(:batch_size => 1, :starts_with => "test-class-id-3") do |records_batch|
          result << records_batch 
        end

        expect(result).to eq [[proxy_target_3], [proxy_target_3_3]]
      end

      it "does not alter foreign keys in proxy owner" do
        foreign_keys_before_batches = proxy_owner.test_class_ids.dup

        subject.find_in_batches(:batch_size => 1, :starts_with => "test-class-id-3") do |records_batch|
        end

        expect(proxy_owner.test_class_ids).to eq foreign_keys_before_batches
      end
    end

    context "when finding with a given start id" do
      (1..6).each do |i|
        let("record_#{i}") { TestClass.create! "test-#{i}" }
      end

      let(:records) { (1..6).collect { |i| send("record_#{i}") } }

      before do
        records # touch to save

        subject.metadata.records_starts_from = :test_classes_starts_from
        expect(subject.proxy_owner).to receive(:test_classes_starts_from).and_return("test-")
      end

      after { subject.metadata.records_starts_from = nil }


      it "returns records in one batch" do
        result = []

        subject.find_in_batches(:batch_size => 10) do |records_batch|
          result << records_batch
        end

        expect(result).to eq [records]
      end

      it "returns records in one batch" do
        result = []

        subject.find_in_batches(:batch_size => 3) do |records_batch|
          result << records_batch
        end

        expect(result).to eq [records.slice(0, 3), records.slice(3, 3)]
      end

      describe "an overridden start id" do
        (11..16).each do |i|
          let("record_#{i}") { TestClass.create! "test-1-#{i}" }
        end

        let(:records_above_10) { (11..16).collect { |i| send("record_#{i}") } }

        before { records_above_10 }

        it "returns only records with given start" do
          result = []

          subject.find_in_batches(:batch_size => 3, :starts_with => "test-1-") do |records_batch|
            result << records_batch
          end

          expect(result).to eq [records_above_10.slice(0, 3), records_above_10.slice(3, 3)]
        end

        it "raises an error if your start option starst with some incorrect value" do
          expect {
            subject.find_in_batches(:starts_with => 'incorrect_value') { |b| }
          }.to raise_error MassiveRecord::ORM::Relations::InvalidStartsWithOption
        end
      end
    end
  end


  describe "#find_each" do
    it "delegate to find_in_batches" do
      expect(subject).to receive(:find_in_batches).with(:batch_size => 2, :starts_with => :from_here)
      subject.find_each(:batch_size => 2, :starts_with => :from_here)  
    end

    it "yields one and one record" do
      proxy_owner.save!
      proxy_owner.test_classes.concat(proxy_target, proxy_target_2, proxy_target_3)

      result = []

      subject.find_each do |record|
        result << record
      end

      expect(result).to eq [proxy_target, proxy_target_2, proxy_target_3]
    end
  end


  describe "adding records to collection" do
    [:<<, :push, :concat].each do |add_method|
      describe "by ##{add_method}" do
        it "should include the proxy_target in the proxy" do
          subject.send(add_method, proxy_target)
          expect(subject.proxy_target).to include proxy_target
        end

        it "should not add invalid objects to collection" do
          expect(proxy_target).to receive(:valid?).and_return false
          expect(subject.send(add_method, proxy_target)).to be_false
          expect(subject.proxy_target).not_to include proxy_target
        end

        it "should update array of foreign keys in proxy_owner" do
          expect(proxy_owner.test_class_ids).to be_empty
          subject.send(add_method, proxy_target)
          expect(proxy_owner.test_class_ids).to include(proxy_target.id)
        end

        it "should auto-persist foreign keys if owner has been persisted" do
          proxy_owner.save!
          subject.send(add_method, proxy_target)
          proxy_owner.reload
          expect(proxy_owner.test_class_ids).to include(proxy_target.id)
        end

        it "should not persist proxy owner (and it's foreign keys) if owner is a new record" do
          subject.send(add_method, proxy_target)
          expect(proxy_owner).to be_new_record
        end

        it "should not update array of foreign keys in proxy_owner if it does not respond to it" do
          expect(proxy_owner).to receive(:respond_to?).and_return(false)
          subject.send(add_method, proxy_target)
          expect(proxy_owner.test_class_ids).not_to include(proxy_target.id)
        end

        it "should not update array of foreign keys in the proxy owner if it has been destroyed" do
          expect(proxy_owner).to receive(:destroyed?).and_return true
          subject.send(add_method, proxy_target)
          expect(proxy_owner.test_class_ids).not_to include(proxy_target.id)
        end

        it "should not do anything adding the same record twice" do
          2.times { subject.send(add_method, proxy_target) }
          expect(subject.proxy_target.length).to eq(1)
          expect(proxy_owner.test_class_ids.length).to eq(1)
        end

        it "should be able to add two records at the same time" do
          subject.send add_method, [proxy_target, proxy_target_2]
          expect(subject.proxy_target).to include proxy_target
          expect(subject.proxy_target).to include proxy_target_2
        end

        it "should return proxy so calls can be chained" do
          expect(subject.send(add_method, proxy_target).object_id).to eq(subject.object_id)
        end

        it "should raise an error if there is a type mismatch" do
          expect { subject.send add_method, Person.new(:name => "Foo", :age => 2) }.to raise_error MassiveRecord::ORM::RelationTypeMismatch
        end

        it "should not save the pushed proxy_target if proxy_owner is not persisted" do
          expect(proxy_owner).to receive(:persisted?).and_return false
          expect(proxy_target).not_to receive(:save)
          subject.send(add_method, proxy_target)
        end

        it "should not save the proxy_owner object if it has not been persisted before" do
          expect(proxy_owner).to receive(:persisted?).and_return false
          expect(proxy_owner).not_to receive(:save)
          subject.send(add_method, proxy_target)
        end

        it "should save the pushed proxy_target if proxy_owner is persisted" do
          proxy_owner.save!
          expect(proxy_target).to receive(:save).and_return(true)
          subject.send(add_method, proxy_target)
        end

        it "should not save anything if one record is invalid" do
          proxy_owner.save!

          expect(proxy_target).to receive(:valid?).and_return(true)
          expect(proxy_target_2).to receive(:valid?).and_return(false)
          
          expect(proxy_target).not_to receive(:save)
          expect(proxy_target_2).not_to receive(:save)
          expect(proxy_owner).not_to receive(:save)

          expect(subject.send(add_method, [proxy_target, proxy_target_2])).to be_false
        end
      end
    end
  end

  describe "removing records from the collection" do
    [:destroy, :delete].each do |delete_method|
      describe "with ##{delete_method}" do
        before do
          subject << proxy_target
        end

        it "should not be in proxy after being removed" do
          subject.send(delete_method, proxy_target)
          expect(subject.proxy_target).not_to include proxy_target
        end

        it "should remove the destroyed records id from proxy_owner foreign keys" do
          subject.send(delete_method, proxy_target)
          expect(proxy_owner.test_class_ids).not_to include(proxy_target.id)
        end

        it "should not remove foreign keys in proxy_owner if it does not respond to it" do
          expect(proxy_owner).to receive(:respond_to?).and_return false
          subject.send(delete_method, proxy_target)
          expect(proxy_owner.test_class_ids).to include(proxy_target.id)
        end

        it "should not save the proxy_owner if it has not been persisted" do
          expect(proxy_owner).to receive(:persisted?).and_return(false)
          expect(proxy_owner).not_to receive(:save)
          subject.send(delete_method, proxy_target)
        end

        it "should save the proxy_owner if it has been persisted" do
          proxy_owner.save!
          expect(proxy_owner).to receive(:save)
          subject.send(delete_method, proxy_target)
        end
      end
    end

    describe "with #destroy" do
      before do
        subject << proxy_target
      end

      it "should ask the record to destroy self" do
        expect(proxy_target).to receive(:destroy)
        subject.destroy proxy_target
      end
    end
    
    describe "with #delete" do
      before do
        subject << proxy_target
      end

      it "should not ask the record to destroy self" do
        expect(proxy_target).not_to receive(:destroy)
        expect(proxy_target).not_to receive(:delete)
        subject.delete(proxy_target)
      end
    end



    describe "with destroy_all" do
      before do
        proxy_owner.save!
        subject << proxy_target << proxy_target_2
      end

      it "should not include any records after destroying all" do
        subject.destroy_all
        expect(subject.proxy_target).to be_empty
      end

      it "should remove all foreign keys in proxy_owner" do
        subject.destroy_all
        expect(proxy_owner.test_class_ids).to be_empty
      end

      it "should call reset after all destroyed" do
        expect(subject).to receive(:reset)
        subject.destroy_all
      end

      it "should be loaded after all being destroyed" do
        subject.destroy_all
        should be_loaded
      end

      it "should call destroy on each record" do
        expect(proxy_target).to receive(:destroy)
        expect(proxy_target_2).to receive(:destroy)
        subject.destroy_all
      end

      it "returns destroyed records" do
        removed = subject.destroy_all
        expect(removed).to include proxy_target, proxy_target_2
      end
    end

    describe "with delete_all" do
      before do
        proxy_owner.save!
        subject << proxy_target << proxy_target_2
      end

      it "should not include any records after destroying all" do
        subject.delete_all
        expect(subject.proxy_target).to be_empty
      end

      it "should remove all foreign keys in proxy_owner" do
        subject.delete_all
        expect(proxy_owner.test_class_ids).to be_empty
      end

      it "should call reset after all destroyed" do
        expect(subject).to receive(:reset)
        subject.delete_all
      end

      it "should be loaded after all being destroyed" do
        subject.delete_all
        should be_loaded
      end

      it "should not call destroy on each record" do
        expect(proxy_target).not_to receive(:destroy)
        expect(proxy_target_2).not_to receive(:destroy)
        subject.delete_all
      end

      it "returns deleted records" do
        removed = subject.delete_all
        expect(removed).to include proxy_target, proxy_target_2
      end
    end
  end

  [:length, :size, :count].each do |method|
    describe "##{method}" do
      [true, false].each do |should_persist_proxy_owner|
        describe "with proxy_owner " + (should_persist_proxy_owner ? "persisted" : "not persisted") do
          before do
            proxy_owner.save! if should_persist_proxy_owner
            subject << proxy_target
          end

          it "should return the correct #{method} when loaded" do
            subject.reload if should_persist_proxy_owner
            expect(subject.send(method)).to eq(1)
          end

          it "should return the correct #{method} when not loaded" do
            subject.reset if should_persist_proxy_owner
            expect(subject.send(method)).to eq(1)
          end

          it "should return the correct #{method} when a record is added" do
            subject << proxy_target_2
            expect(subject.send(method)).to eq(2)
          end

          it "should return the correct #{method} when a record is added to an unloaded proxy" do
            subject.reset if should_persist_proxy_owner
            subject << proxy_target_2
            expect(subject.send(method)).to eq(2)
          end

          it "returns correct length if new proxy gets records added" do
            subject.destroy_all
            subject.reset
            allow(proxy_owner).to receive(:persisted?).and_return false
            allow(proxy_owner).to receive(:new_record?).and_return true

            new_proxy_target = proxy_target.class.new "id-1"
            subject << new_proxy_target
            expect(subject.length).to eq 1
          end
        end
      end

      context "foreign keys persisted in owner" do
        before do
          proxy_owner.save!
          subject << proxy_target << proxy_target_2
        end

        context "targets not loaded" do
          before { subject.reset }

          it "loads nothing" do
            expect(TestClass).not_to receive(:find)
            subject.length
          end

          it "reads length from proxy owner's foreign keys list" do
            expect(proxy_owner).to receive(:test_class_ids).and_return([proxy_target.id, proxy_target_2.id])
            subject.length
          end

          it "returns correct length" do
            expect(subject.length).to eq 2
          end
        end

        context "targets loaded" do
          before { subject.reload }

          it "loads nothing" do
            expect(TestClass).not_to receive(:find)
            subject.length
          end

          it "reads length from proxy_target" do
            expect(subject).to receive(:proxy_target).and_return([proxy_target, proxy_target_2])
            subject.length
          end

          it "returns correct length" do
            expect(subject.length).to eq 2
          end
        end
      end

      context "when we are using a starts_with to find related records" do
        let(:proxy_target) { Person.new proxy_owner.id+"-friend-1", :name => "T", :age => 2 }
        let(:proxy_target_2) { Person.new proxy_owner.id+"-friend-2", :name => "H", :age => 9 }
        let(:not_proxy_target) { Person.new "foo"+"-friend-2", :name => "H", :age => 1 }
        let(:metadata) { subject.metadata }

        subject { proxy_owner.send(:relation_proxy, 'friends') }

        before do
          proxy_owner.save!
          subject << proxy_target << proxy_target_2
        end

        context "targets not loaded" do
          before { subject.reset }

          it "loads all the targets and returns it's length" do
            expect(subject).to receive(:load_proxy_target).and_return [proxy_target, proxy_target_2] 
            subject.length
          end

          it "returns correct length" do
            expect(subject.length).to eq 2
          end

          it "returns correct length after adding a record" do
            subject <<  Person.new(proxy_owner.id+"-friend-3", :name => "H", :age => 9)
            expect(subject.length).to eq 3
          end
        end

        context "targets loaded" do
          before { subject.reload }

          it "loads nothing" do
            expect(subject).not_to receive(:load_proxy_target)
            subject.length
          end

          it "returns correct length" do
            expect(subject.length).to eq 2
          end
        end
      end
    end
  end

  describe "#any?" do
    before { subject.reset }

    it "checks the length and return true if it is greater than 0" do
      expect(subject).to receive(:length).and_return 1
      expect(subject.any?).to be_true
    end

    it "checks the length and return false if it is 0" do
      expect(subject).to receive(:length).and_return 0
      expect(subject.any?).to be_false
    end

    context "when find with proc" do
      before do
        expect(subject).to receive(:loaded?).and_return false
        expect(subject).to receive(:find_with_proc?).and_return true
      end

      it "asks for first and returns false if first is nil" do
        expect(subject).to receive(:first).and_return nil
        expect(subject.any?).to be_false
      end

      it "asks for first and returns true if first is a record" do
        expect(subject).to receive(:first).and_return proxy_target
        expect(subject.any?).to be_true
      end
    end
  end

  describe "#present?" do
    before { subject.reset }

    it "checks the length and return true if it is greater than 0" do
      expect(subject).to receive(:length).and_return 1
      expect(subject.present?).to be_true
    end

    it "checks the length and return false if it is 0" do
      expect(subject).to receive(:length).and_return 0
      expect(subject.present?).to be_false
    end
  end

  describe "#include?" do
    it "uses find as it's query method when loaded" do
      expect(subject).to receive(:loaded?).and_return true
      expect(subject).to receive(:find).with(proxy_target.id).and_return true
      expect(subject).to include proxy_target
    end

    it "uses find as it's query method when find with proc" do
      expect(subject).to receive(:find_with_proc?).and_return true
      expect(subject).to receive(:find).with(proxy_target.id).and_return true
      expect(subject).to include proxy_target
    end

    it "can answer to ids as well" do
      expect(subject).to receive(:foreign_key_in_proxy_owner_exists?).with(proxy_target.id).and_return true
      expect(subject).to include proxy_target.id
    end

    it "does not load record if foreign keys are presisted in proxy owner" do
      proxy_owner.save!
      subject << proxy_target
      subject.reset

      expect(TestClass).not_to receive(:find)
      expect(subject).to include proxy_target
    end

    [true, false].each do |should_persist_proxy_owner|
      describe "with proxy_owner " + (should_persist_proxy_owner ? "persisted" : "not persisted") do
        before do
          proxy_owner.save! if should_persist_proxy_owner
          subject << proxy_target
        end

        it "should return that it includes it's proxy_target when loaded" do
          subject.reload if should_persist_proxy_owner
          should include proxy_target
        end

        it "should return that it includes it's proxy_target when not loaded" do
          subject.reset if should_persist_proxy_owner
          should include proxy_target
        end

        it "should return that it includes it's proxy_target when a record is added" do
          subject << proxy_target_2
          should include proxy_target, proxy_target_2
        end

        it "should return that it includes it's proxy_target when a record is added to an unloaded proxy" do
          subject.reset if should_persist_proxy_owner
          subject << proxy_target_2
          should include proxy_target, proxy_target_2
        end
      end
    end
  end



  describe "#first" do
    describe "stored foreign keys" do
      before do
        proxy_owner.save!
        subject << proxy_target << proxy_target_2
        subject.reset
      end

      it "should return nil if no relations are found" do
        subject.destroy_all
        expect(subject.first).to be_nil
      end

      it "should return the first proxy_target" do
        expect(subject.first).to eq(proxy_target)
      end

      it "should not be loaded" do
        subject.first
        expect(subject).not_to be_loaded
      end

      it "should just find the first foreign key" do
        expect(TestClass).to receive(:find).with(proxy_target.id, anything).and_return(proxy_target)
        subject.first
      end
    end

    describe "with records_starts_from (proc)" do
      let(:proxy_target) { Person.new proxy_owner.id+"-friend-1", :name => "T", :age => 2 }
      let(:proxy_target_2) { Person.new proxy_owner.id+"-friend-2", :name => "H", :age => 9 }
      let(:metadata) { subject.metadata }

      subject { proxy_owner.send(:relation_proxy, 'friends') }

      before do
        proxy_owner.save!
        subject << proxy_target << proxy_target_2
        subject.reset
      end

      it "should return nil if no relations are found" do
        subject.destroy_all
        expect(subject.first).to be_nil
      end

      it "should return the first proxy_target" do
        expect(subject.first).to eq(proxy_target)
      end

      it "should not be loaded" do
        subject.first
        expect(subject).not_to be_loaded
      end

      it "should find the first with a limit" do
        expect(Person).to receive(:all).with(hash_including(:limit => 1))
        subject.first
      end
    end
  end


  describe "#find" do
    let(:not_among_targets) { proxy_target_3 }

    describe "stored foreign keys" do
      before do
        proxy_owner.save!
        subject << proxy_target << proxy_target_2
        subject.reset

        not_among_targets.save!
      end

      it "should find the object from database if id exists among foreig keys" do
        expect(subject.find(proxy_target.id)).to eq(proxy_target)
      end

      it "should raise error if record is not among records in association" do
        expect { subject.find(not_among_targets.id) }.to raise_error MassiveRecord::ORM::RecordNotFound
      end

      it "should not hit database if proxy has been loaded" do
        subject.load_proxy_target
        expect(TestClass).not_to receive(:find)
        expect(subject.find(proxy_target.id)).to eq(proxy_target)
      end

      it "should raise error if proxy is loaded, but record is not found in association" do
        subject.load_proxy_target
        expect { subject.find(not_among_targets.id) }.to raise_error MassiveRecord::ORM::RecordNotFound
      end
    end


    describe "with records_starts_from (proc)" do
      let(:proxy_target) { Person.new proxy_owner.id+"-friend-1", :name => "T", :age => 2 }
      let(:proxy_target_2) { Person.new proxy_owner.id+"-friend-2", :name => "H", :age => 9 }
      let(:not_among_targets) { Person.new "NOT-friend-1", :name => "H", :age => 9 }
      let(:metadata) { subject.metadata }

      subject { proxy_owner.send(:relation_proxy, 'friends') }

      before do
        proxy_owner.save!
        subject << proxy_target << proxy_target_2
        subject.reset

        not_among_targets.save!
      end


      it "should find the object from database if id exists among foreig keys" do
        expect(subject.find(proxy_target.id)).to eq(proxy_target)
      end

      it "should raise error if record is not among records in association" do
        expect { subject.find(not_among_targets.id) }.to raise_error MassiveRecord::ORM::RecordNotFound
      end

      it "returns record if in a dirty state, when no objects are saved" do
        subject.destroy_all
        subject.reset
        allow(proxy_owner).to receive(:persisted?).and_return false
        allow(proxy_owner).to receive(:new_record?).and_return true

        new_proxy_target = Person.new proxy_owner.id+"-friend-2", :name => "H", :age => 9
        subject << new_proxy_target
        expect(subject.find(new_proxy_target.id)).to eq new_proxy_target
      end



      it "should not hit database if proxy has been loaded" do
        subject.load_proxy_target
        expect(Person).not_to receive(:find)
        expect(subject.find(proxy_target.id)).to eq(proxy_target)
      end

      it "should raise error if proxy is loaded, but record is not found in association" do
        subject.load_proxy_target
        expect { subject.find(not_among_targets.id) }.to raise_error MassiveRecord::ORM::RecordNotFound
      end
    end
  end

  describe "#all" do
    let(:not_among_targets) { proxy_target_3 }

    describe "stored foreign keys" do
      before do
        proxy_owner.save!
        subject << proxy_target << proxy_target_2
        subject.reset

        not_among_targets.save!
      end

      it "returns all the targets" do
        expect(subject.all).to include proxy_target, proxy_target_2
        expect(subject.all).not_to include proxy_target_3
      end

      [:limit, :offset, :starts_with].each do |finder_option|
        it "raises an error when asked to do a #{finder_option}" do
          expect {
            subject.all(finder_option => "value")
          }.to raise_error MassiveRecord::ORM::Relations::Proxy::ReferencesMany::UnsupportedFinderOption
        end
      end

      it "does not hit database if targets has been loaded" do
        subject.load_proxy_target
        expect(subject.proxy_target_class).not_to receive :find
        subject.all
      end
    end

    describe "with records starts from (proc)" do
      let(:proxy_target) { Person.new proxy_owner.id+"-friend-1", :name => "T", :age => 2 }
      let(:proxy_target_2) { Person.new proxy_owner.id+"-friend-2", :name => "H", :age => 9 }
      let(:not_among_targets) { Person.new "NOT-friend-1", :name => "H", :age => 9 }
      let(:metadata) { subject.metadata }

      subject { proxy_owner.send(:relation_proxy, 'friends') }

      before do
        proxy_owner.save!
        subject << proxy_target << proxy_target_2
        subject.reset

        not_among_targets.save!
      end

      it "returns all the targets" do
        expect(subject.all).to include proxy_target, proxy_target_2
        expect(subject.all).not_to include proxy_target_3
      end

      it "accepts to limit the result" do
        expect(subject.all(:limit => 1)).to include proxy_target
        expect(subject.all).not_to include proxy_target_3, proxy_target_2
      end

      it "accepts to offset the result" do
        expect(subject.all(:offset => proxy_owner.id+"-friend-2")).to include proxy_target_2
        expect(subject.all).not_to include proxy_target_3, proxy_target
      end

      it "accepts to modify the starts_with" do
        expect(subject.all(:starts_with => proxy_owner.id+"-friend-1")).to include proxy_target
        expect(subject.all).not_to include proxy_target_3, proxy_target_2
      end

      it "raises an error on invalid starts_with option" do
        expect {
          subject.all(:starts_with => "foobar")
        }.to raise_error MassiveRecord::ORM::Relations::InvalidStartsWithOption
      end

      it "accepts option offset" do
        records = subject.all(:offset => proxy_owner.id+"-friend-2")
        expect(records).not_to include proxy_target, proxy_target_3
        expect(records).to include proxy_target_2
      end

      it "does not hit database if targets has been loaded" do
        subject.load_proxy_target
        expect(Person).not_to receive(:do_find)
        subject.all
      end
    end
  end



  describe "#limit" do
    let(:not_among_targets) { proxy_target_3 }

    describe "stored foreign keys" do
      before do
        proxy_owner.save!
        subject << proxy_target << proxy_target_2
        subject.reset

        not_among_targets.save!
      end

      it "should return empty array if no targets are found" do
        subject.destroy_all
        expect(subject.limit(1)).to be_empty
      end


      it "should do db query with a limited set of ids" do
        expect(subject.limit(1)).to eq([proxy_target])
      end

      it "should not be loaded after a limit query" do
        expect(subject.limit(1)).to eq([proxy_target])
        expect(subject).not_to be_loaded
      end

      it "should not hit the database if the proxy is loaded" do
        subject.load_proxy_target
        expect(TestClass).not_to receive(:find)
        subject.limit(1)
      end

      it "should return correct result set if proxy is loaded" do
        subject.load_proxy_target
        expect(subject.limit(1)).to eq([proxy_target])
      end

      it "returns first record if in a dirty state" do
        subject.delete(proxy_target_2)
        subject.reset
        subject << proxy_target_2
        expect(subject.limit(1)).to eq [proxy_target]
      end
    end


    describe "with records_starts_from (proc)" do
      let(:proxy_target) { Person.new proxy_owner.id+"-friend-1", :name => "T", :age => 2 }
      let(:proxy_target_2) { Person.new proxy_owner.id+"-friend-2", :name => "H", :age => 9 }
      let(:not_among_targets) { Person.new "NOT-friend-1", :name => "H", :age => 9 }
      let(:metadata) { subject.metadata }

      subject { proxy_owner.send(:relation_proxy, 'friends') }

      before do
        proxy_owner.save!
        subject << proxy_target << proxy_target_2
        subject.reset

        not_among_targets.save!
      end

      it "should return empty array if no targets are found" do
        subject.destroy_all
        expect(subject.limit(1)).to be_empty
      end


      it "should do db query with a limited set of ids" do
        expect(subject.limit(1)).to eq([proxy_target])
      end

      it "should not be loaded after a limit query" do
        expect(subject.limit(1)).to eq([proxy_target])
        expect(subject).not_to be_loaded
      end

      it "should not hit the database if the proxy is loaded" do
        subject.load_proxy_target
        expect(Person).not_to receive(:find)
        subject.limit(1)
      end

      it "should return correct result set if proxy is loaded" do
        subject.load_proxy_target
        expect(subject.limit(1)).to eq([proxy_target])
      end

      it "returns first record if in a dirty state" do
        proxy_target_2.destroy
        new_proxy_target = Person.new proxy_owner.id+"-friend-2", :name => "H", :age => 9
        subject.reset
        subject << new_proxy_target
        expect(subject.limit(1)).to eq [proxy_target]
      end

      it "returns first record if in a dirty state, when no objects are saved" do
        subject.destroy_all
        subject.reset
        allow(proxy_owner).to receive(:persisted?).and_return false
        allow(proxy_owner).to receive(:new_record?).and_return true

        new_proxy_target = Person.new proxy_owner.id+"-friend-2", :name => "H", :age => 9
        subject << new_proxy_target
        expect(subject.limit(1)).to eq [new_proxy_target]
      end
    end
  end

  it "resets when the proxy owner is asked to reload" do
    subject.loaded!
    proxy_owner.reload
    should_not be_loaded
  end
end
