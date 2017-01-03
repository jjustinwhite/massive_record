require 'spec_helper'

module MassiveRecord
  module ORM
    module Persistence
      module Operations
        module Embedded
          class TestEmbeddedOperationHelpers
            include Operations, OperationHelpers
          end

          describe TestEmbeddedOperationHelpers do
            include SetUpHbaseConnectionBeforeAll 
            include SetTableNamesToTestTable

            let(:address) { Address.new("addresss-id", :street => "Asker", :number => 5) }
            let(:person) { Person.new "person-id", :name => "Thorbjorn", :age => "22" }
            let(:options) { {:this => 'hash', :has => 'options'} }


            let(:proxy_for_person) { address.send(:relation_proxy, :person) }

            let(:row) do
              MassiveRecord::Wrapper::Row.new({
                :id => person.id,
                :table => person.class.table
              })
            end


            subject { TestEmbeddedOperationHelpers.new(address, options) }

            before { address.person = person }


            describe "#embedded_in_proxies" do
              it "returns some proxies" do
                expect(subject.embedded_in_proxies).not_to be_empty
              end

              it "returns proxies which represents embedded in relations" do
                expect(subject.embedded_in_proxies.all? { |p| p.metadata.embedded_in? }).to be_true
              end
            end

            describe "#embedded_in_proxy_targets" do
              describe '#embedded_in_proxy_targets' do
                subject { super().embedded_in_proxy_targets }
                it { should include person }
              end
            end

            describe "#row_for_record" do
              it "returns row for given record" do
                row = subject.row_for_record(person)
                expect(row.id).to eq person.id
                expect(row.table).to eq person.class.table
              end
            end



            describe "update_embedded" do
              before { allow(subject).to receive(:row_for_record).and_return(row) }

              it "ask for record's row" do
                expect(subject).to receive(:row_for_record).with(person).and_return(row)
                subject.update_embedded(proxy_for_person, "new_value")
              end

              it "sets value on row" do
                expect(row).to receive(:values=).with(
                  'addresses' => {
                    address.database_id => "new_value"
                  }
                ) 
                subject.update_embedded(proxy_for_person, "new_value")
              end

              it "asks row to be saved" do
                expect(row).to receive(:save)
                subject.update_embedded(proxy_for_person, "new_value")
              end
            end
          end



        end
      end
    end
  end
end


