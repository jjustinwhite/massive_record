require 'spec_helper'

module MassiveRecord
  module ORM
    module Persistence
      module Operations


        class TestTableOperationHelpers
          include Operations, TableOperationHelpers
        end


        describe TableOperationHelpers do
          include MockMassiveRecordConnection

          let(:person) { Person.new("id-1", :name => "Thorbjorn", :age => 30) }
          let(:address) { Address.new "address-1", :street => "Asker", :number => 1 }
          let(:options) { {:this => 'hash', :has => 'options'} }
          
          subject { TestTableOperationHelpers.new(person, options) }

          before do
            person.addresses << address
          end

          
          describe "#row_for_record" do
            it "raises an error if id for person is blank" do
              person.id = nil
              expect { subject.row_for_record }.to raise_error MassiveRecord::ORM::IdMissing
            end

            it "returns a row with id and table set" do
              row = subject.row_for_record
              expect(row.id).to eq person.id
              expect(row.table).to eq person.class.table
            end
          end

          describe "#attributes_to_row_values_hash" do
            before { person.addresses.parent_will_be_saved! }

            it "should include the 'pts' field in the database which has 'points' as an alias" do
              expect(subject.attributes_to_row_values_hash["base"].keys).to include("pts")
              expect(subject.attributes_to_row_values_hash["base"].keys).not_to include("points")
            end

            it "should include integer value, even if it is set as string" do
              person.age = "20"
              expect(subject.attributes_to_row_values_hash["info"]["age"]).to eq(20)
            end

            describe "embedded attributes" do
              it "includes the column family for the embedded relation" do
                expect(subject.attributes_to_row_values_hash.keys).to include "addresses"
              end

              it "asks the proxy for update hash and uses whatever it delivers" do
                dummy_hash = {:foo => {:bar => :dummy}}
                allow(person.addresses).to receive(:proxy_targets_update_hash).and_return(dummy_hash)
                expect(subject.attributes_to_row_values_hash["addresses"]).to eq dummy_hash
              end

              it "merges embedded collections in to existing column families" do
                attributes_from_person = subject.attributes_to_row_values_hash["info"]
                attributes_from_cars = {:foo => {:bar => :dummy}}
                allow(person.cars).to receive(:proxy_targets_update_hash).and_return(attributes_from_cars)
                expect(subject.attributes_to_row_values_hash["info"]).to eq attributes_from_person.merge(attributes_from_cars)
              end
            end
          end



          describe "#store_record_to_database" do
            let(:row) { double(Object, :save => true, :values= => true) }

            before { expect(subject).to receive(:row_for_record).and_return(row) }

            it "assigns row it's values from what attributes_to_row_values_hash returns" do
              expect(row).to receive(:values=).with(subject.attributes_to_row_values_hash)
              subject.store_record_to_database('create')
            end

            it "calls save on the row" do
              expect(row).to receive(:save)
              subject.store_record_to_database('create')
            end
          end
        end



      end
    end
  end
end
