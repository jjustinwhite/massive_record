require 'spec_helper'

describe "dirty" do
  describe "dry run" do
    include MockMassiveRecordConnection
    include TimeZoneHelper

    context "new record" do
      subject { Person.new '1', :name => "Alice", :age => 20, :email => "foo@bar.com" }
      let(:address) { Address.new("id1", :street => "foo") }

      it "is not changed when first created" do
        expect(Person.new).not_to be_changed
      end

      it "initial values are changed" do
        expect(subject).to be_email_changed
      end


      describe "changes in embedded relations" do
        before { subject.addresses << address }

        it "iterates over embedded relations and asks them if they have changes" do
          is_expected.to be_changed
        end

        it "includes addresses in changed" do
          expect(subject.changed).to include "addresses"
        end

        it "includes knowledge of changes" do
          address.street = address.street + "_NEW"
          subject.name = subject.name + "_NEW"
          expect(subject.changes).to eq({
            "name" => [nil, "Alice_NEW"],
            "age" => [nil, 20],
            "email" => [nil, "foo@bar.com"],
            "addresses" => {
              "id1" => {
                "street" => [nil, "foo_NEW"]
              }
            }
          })
        end
      end
    end

    context "persisted" do
      subject { Person.create '1', :name => "Alice", :age => 20, :email => "foo@bar.com" }

      it "should not be changed if attribute is set to what it currently is" do
        subject.name = "Alice"
        is_expected.not_to be_changed
      end

      it "should notice changes" do
        subject.name = "Bob"
        is_expected.to be_changed
      end

      it "should notice changes in boolean values from false to true" do
        subject.status = !subject.status
        is_expected.to be_status_changed
      end

      it "notices changes in time attributes" do
        in_time_zone "utc" do
          test = TestClass.new
          test.tested_at = Time.now
          expect(test).to be_tested_at_changed
        end
      end

      it "should notice changes in boolean values from true to false" do
        subject.status = true
        subject.save
        subject.status = false
        is_expected.to be_status_changed
      end

      it "should not consider age set as string to the same as integer a change" do
        subject.age = "20"
        is_expected.not_to be_age_changed
      end

      it "should not consider age set as string back to original value a change" do
        subject.age = 30
        subject.age = "20"
        is_expected.not_to be_age_changed
      end


      it "should know when a attribute is set to it's original value" do
        original_name = subject.name
        subject.name = "Bob"
        subject.name = original_name
        is_expected.not_to be_changed
      end

      it "should always keep the objects original value as _was" do
        original_name = subject.name
        subject.name = "Bob"
        subject.name = "Foo"
        expect(subject.name_was).to eq(original_name)
      end

      it "should return what name was" do
        subject.name = "Bob"
        expect(subject.name_was).to eq("Alice")
      end


      describe "should reset changes" do
        it "on save" do
          subject.name = "Bob"
          subject.save
          is_expected.not_to be_changed
        end

        it "on save, but don't do it if save fails validation" do
          expect(subject).to receive(:valid?).and_return(false)
          subject.name = "Bob"
          subject.save
          is_expected.to be_changed
        end

        it "on save!" do
          subject.name = "Bob"
          subject.save!
          is_expected.not_to be_changed
        end

        it "on reload" do
          subject.name = "Bob"
          subject.reload
          is_expected.not_to be_changed
        end
      end

      describe "previous changes" do
        it "should be blank before after reload" do
          subject.reload
          expect(subject.previous_changes).to be_blank
        end

        it "should equal to changes before save" do
          subject.name = "Bob"
          changes_before_save = subject.changes

          subject.save

          expect(subject.changes).to be_empty
          expect(subject.previous_changes).to eq(changes_before_save)
        end

        it "should equal to changes before save!" do
          subject.name = "Bob"
          changes_before_save = subject.changes

          subject.save!

          expect(subject.changes).to be_empty
          expect(subject.previous_changes).to eq(changes_before_save)
        end

        it "should be nil after a reload" do
          subject.name = "Bob"
          subject.save
          subject.reload
          expect(subject.previous_changes).to be_blank
        end
      end
    end
  end


  describe "database run" do
    include SetUpHbaseConnectionBeforeAll
    include SetTableNamesToTestTable

    subject { Person.new }

    before do
      subject.id = "test"
      subject.points = "25"
      subject.date_of_birth = "19850730"
      subject.status = "0"
    end

    it "should update dirty status correctly after a reload" do
      subject.dictionary = {:something => "strage"}
      subject.save! :validate => false
      subject.reload
      subject.dictionary = {}
      subject.save! :validate => false
      subject.reload
      expect(subject.dictionary).to eq({})
    end
  end
end
