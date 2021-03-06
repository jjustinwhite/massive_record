require 'spec_helper'

class TestReferencesOneProxy < MassiveRecord::ORM::Relations::Proxy::ReferencesOne; end

describe TestReferencesOneProxy do
  include SetUpHbaseConnectionBeforeAll 
  include SetTableNamesToTestTable

  let(:proxy_owner) { Person.new }
  let(:proxy_target) { PersonWithTimestamp.new }
  let(:metadata) { subject.metadata }

  subject { proxy_owner.send(:relation_proxy, 'boss') }

  it_should_behave_like "relation proxy"
  it_should_behave_like "singular proxy"

  it "should be possible to assign relation in new" do
    expect { Person.new(:boss => PersonWithTimestamp.new) }.not_to raise_error
  end

  describe "#find_proxy_target" do
    it "should not try to find anything if foreign key is nil" do
      proxy_owner.boss_id = nil
      expect(PersonWithTimestamp).not_to receive(:find)
      expect(subject.load_proxy_target).to be_nil
    end

    it "should try to find the proxy_target if foreign key is set" do
      proxy_owner.boss_id = "id"
      expect(PersonWithTimestamp).to receive(:find).with("id").and_return(proxy_target)
      expect(subject.load_proxy_target).to eq(proxy_target)
    end
  end

  describe "find with proc" do
    let(:person) { Person.new }

    before do
      subject.metadata.find_with = Proc.new { |proxy_target| Person.find("testing-123") }
      proxy_owner.boss_id = nil
    end

    after do
      subject.metadata.find_with = nil
    end

    it "should not call find_proxy_target" do
      should_not_receive :find_proxy_target
      subject.load_proxy_target
    end

    it "should load by given proc" do
      expect(Person).to receive(:find).with("testing-123").and_return(person)
      expect(subject.load_proxy_target).to eq(person)
    end
  end

  describe "setting proxy_target object" do
    it "should set the proxy_target's id as the foreign key in proxy_owner" do
      proxy_owner.boss = proxy_target
      expect(proxy_owner.boss_id).to eq(proxy_target.id)
    end

    it "should reset the proxy_targets foreign key if proxy_target is nil" do
      proxy_owner.boss = proxy_target
      proxy_owner.boss = nil
      expect(proxy_owner.boss_id).to be_nil
    end

    it "should not set the proxy_target's id as the foreign key if we are not persisting the foreign key" do
      allow(proxy_owner).to receive(:respond_to?).and_return(false)
      proxy_owner.boss = proxy_target
      expect(proxy_owner.boss_id).to be_nil
    end

    it "should not set the proxy_target's id as the foreign key if the owner has been destroyed" do
      expect(proxy_owner).to receive(:destroyed?).and_return true
      proxy_owner.boss = proxy_target
      expect(proxy_owner.boss_id).to be_nil
    end

    it "should set the proxy_target's id as the foreign key even if we are not persisting it if the record responds to setter method" do
      proxy_owner.boss = proxy_target
      expect(proxy_owner.boss_id).to eq(proxy_target.id)
    end

    it "should raise an error if there is a type mismatch" do
      expect { proxy_owner.boss = Person.new }.to raise_error MassiveRecord::ORM::RelationTypeMismatch
    end
  end


  describe "type checking of proxy_targets" do
    let(:metadata) { MassiveRecord::ORM::Relations::Metadata.new 'person' }
    let(:person) { Person.new }
    let(:person_with_timestamp) { PersonWithTimestamp.new }

    before do
      subject.metadata = metadata
    end

    it "should not raise error if metadata's class corresponds to given proxy_target" do
      expect { subject.send :raise_if_type_mismatch, person }.not_to raise_error
    end

    it "should not raise error if metadata's class corresponds to given proxy_target" do
      expect { subject.send :raise_if_type_mismatch, person_with_timestamp }.to raise_error MassiveRecord::ORM::RelationTypeMismatch
    end
  end


  it "resets when the proxy owner is asked to reload" do
    subject.loaded!
    proxy_owner.reload
    should_not be_loaded
  end
end
