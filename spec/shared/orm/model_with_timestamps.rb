require 'spec_helper'

shared_examples_for "a model with timestamps" do
  include TimeZoneHelper

  describe "#created_at" do
    it "is instructed to create it on create :-)" do
      expect(subject).to be_set_created_at_on_create
    end

    it "is nil on new records" do
      expect(described_class.new.created_at).to be_nil
    end

    it "is not possible to set" do
      expect { subject.created_at = Time.now }.to raise_error MassiveRecord::ORM::CantBeManuallyAssigned
      expect { subject['created_at'] = Time.now }.to raise_error MassiveRecord::ORM::CantBeManuallyAssigned
      expect { subject.write_attribute(:created_at, Time.now) }.to raise_error MassiveRecord::ORM::CantBeManuallyAssigned
    end

    it "is set on persisted records" do
      expect(subject.created_at).to be_a_kind_of Time
    end

    it "is not changed on update" do
      created_at_was = subject.created_at

      sleep(1)

      subject.update_attribute attribute_to_be_changed, subject[attribute_to_be_changed] + "NEW"
      expect(subject.created_at).to eq(created_at_was)
    end

    it "is included in list of #known_attribute_names_for_inspect" do
      expect(subject.send(:known_attribute_names_for_inspect)).to include 'created_at'
    end

    it "is included in inspect" do
      expect(subject.inspect).to include(%q{created_at:})
    end

    it "raises error if created_at is not time" do
      described_class.attributes_schema['created_at'].type = :string
      expect { described_class.new.save(:validate => false) }.to raise_error "created_at must be of type time"
      described_class.attributes_schema['created_at'].type = :time
    end
  end
end





shared_examples_for "a model without timestamps" do
  include TimeZoneHelper

  describe "#created_at" do
    it "is instructed not to create it on create :-)" do
      expect(subject).not_to be_set_created_at_on_create
    end

    it "does not raise cant-set-error" do
      expect { subject.created_at = Time.now }.to_not raise_error
    end

    it "does not include created_at in the list of known attributes" do
      expect(subject.send(:known_attribute_names_for_inspect)).not_to include 'created_at'
    end
  end

  # Might be a bit strange, but HBase gives you time stamps on cells
  # regardless, so we'll always make it available to the client
  describe "#updated_at" do
    it "is nil on new records" do
      expect(described_class.new.updated_at).to be_nil
    end

    it "is not possible to set" do
      expect { subject.updated_at = Time.now }.to raise_error MassiveRecord::ORM::CantBeManuallyAssigned
      expect { subject['updated_at'] = Time.now }.to raise_error MassiveRecord::ORM::CantBeManuallyAssigned
      expect { subject.write_attribute(:updated_at, Time.now) }.to raise_error MassiveRecord::ORM::CantBeManuallyAssigned
    end

    it "is set on persisted records" do
      expect(subject.updated_at).to be_a_kind_of Time
    end

    it "is included in list of #known_attribute_names_for_inspect" do
      expect(subject.send(:known_attribute_names_for_inspect)).to include 'updated_at'
    end

    it "includes updated_at in inspect" do
      expect(subject.inspect).to include(%q{updated_at:})
    end

    it "is updated after save" do
      sleep(1)

      updated_at_was = subject.updated_at
      subject.update_attribute attribute_to_be_changed, "Should Give Me New Updated At"

      expect(subject.updated_at).not_to eq updated_at_was
    end

    it "is not updated when save fails" do
      sleep(1)

      updated_at_was = subject.updated_at
      subject[attribute_to_be_changed] = nil

      expect(subject).not_to be_valid

      expect(subject.updated_at).to eq updated_at_was
    end

    context "with time zone awarenesswith zone enabled" do
      it "should return time with zone" do
        in_time_zone "Europe/Stockholm" do
          expect(subject.updated_at).to be_instance_of ActiveSupport::TimeWithZone
        end
      end

      it "should be nil on new records" do
        in_time_zone "Europe/Stockholm" do
          expect(Person.new.updated_at).to be_nil
        end
      end
    end
  end
end


